/**
 * LitPixelRenderer — WebGL 像素光照渲染器
 *
 * 用法：
 *   const lpr = new LitPixelRenderer();
 *   await lpr.init();
 *   lpr.setLight({ dir: [0.5,-0.8,0.3], rim: [0.4,0.6,0.9] });
 *   const dataUrl = await lpr.renderToDataURL('bai_luoxuan', 128, 192);
 *   // 或直接渲染到 canvas：
 *   lpr.renderToCanvas(document.getElementById('my-canvas'), 'bai_luoxuan');
 *
 * 资产约定：assets/characters/concept_{id}.webp / _normal.png / _material.png
 * 纹理：BaseColor 512×768 RGBA, Normal 512×768 RGBA, Material 512×768 RGBA
 *
 * 性能预算：每角色预加载约 0.4MB GPU 纹理（3张×512×768 RGB）
 */

// ============================================================
// GLSL Shader 源码
// ============================================================

const VERTEX_SHADER_SRC = /* glsl */`
attribute vec2 a_position;
attribute vec2 a_texCoord;
varying vec2 v_texCoord;

void main() {
  gl_Position = vec4(a_position, 0.0, 1.0);
  v_texCoord = a_texCoord;
}`;

const FRAGMENT_SHADER_SRC = /* glsl */`
precision mediump float;

uniform sampler2D u_baseColor;
uniform sampler2D u_normalMap;
uniform sampler2D u_materialMap;

uniform vec3  u_lightDir;
uniform vec3  u_rimColor;
uniform vec3  u_ambientColor;
uniform float u_rimPower;
uniform float u_rimIntensity;
uniform float u_ambientStrength;
uniform float u_specIntensity;
uniform float u_lightIntensity;

varying vec2 v_texCoord;

void main() {
  vec4  baseColor = texture2D(u_baseColor,  v_texCoord);
  vec3  normal    = texture2D(u_normalMap,  v_texCoord).rgb * 2.0 - 1.0;
  vec4  material  = texture2D(u_materialMap, v_texCoord);

  float roughness = material.r;
  float emission  = material.b;

  vec3 L = normalize(u_lightDir);
  float NdotL = max(dot(normal, L), 0.0);

  // 环境光 + 漫反射
  vec3 ambient = u_ambientColor * u_ambientStrength;
  float diffuse = NdotL * u_lightIntensity;

  // 边缘光（Rim Light）— 视线方向 = 屏幕 Z+
  vec3  V   = vec3(0.0, 0.0, 1.0);
  float rim = 1.0 - abs(dot(normal, V));
  rim = pow(rim, u_rimPower) * u_rimIntensity;

  // 高光（Blinn-Phong）
  vec3  H    = normalize(L + V);
  float shininess = mix(64.0, 4.0, roughness);
  float spec = pow(max(dot(normal, H), 0.0), shininess);
  spec *= u_specIntensity * (1.0 - roughness);

  // 合成
  vec3 lit = baseColor.rgb * (ambient + diffuse);
  lit += spec * u_rimColor;
  lit += rim  * u_rimColor;
  lit += baseColor.rgb * emission * 0.5;

  gl_FragColor = vec4(lit, baseColor.a);
}`;


// ============================================================
// LitPixelRenderer 类
// ============================================================

class LitPixelRenderer {
  constructor() {
    /** @type {WebGLRenderingContext|null} */
    this.gl = null;
    /** @type {WebGLProgram|null} */
    this.program = null;
    /** @type {HTMLCanvasElement} */
    this.canvas = null;

    // ── 纹理缓存: charId → { baseColor, normal, material } WebGLTexture ──
    this.textureCache = new Map();

    // ── 渲染缓存: `${charId}::${w}x${h}::${lightHash}` → dataURL ──
    this.renderCache = new Map();
    this._buffers = [];

    // ── 初始化状态 ──
    this.ready = false;

    // ── 光照预设（默认：右上光源 + 青蓝边缘光）──
    this.lightParams = {
      dir:              [0.5, -0.8, 0.3],   // 光线方向（归一化前）
      rimColor:         [0.4, 0.6, 0.9],    // 边缘光颜色（青蓝）
      ambientColor:     [0.25, 0.22, 0.35], // 环境光（暗紫）
      rimPower:         2.5,                 // 边缘光硬度
      rimIntensity:     0.35,                // 边缘光强度
      ambientStrength:  0.28,                // 环境光强度
      specIntensity:    0.12,                // 高光强度
      lightIntensity:   0.72,                // 主光源强度
    };

    // ── 光照动画 ──
    this._animFrame = null;
    this._animUnsubscribe = null;
    this._animAngle = 0;

    // ── Asset base path ──
    this.assetBase = 'assets/characters/';
  }

  // ========== 初始化 ==========

  /**
   * 初始化 WebGL 上下文、编译 Shader、设置几何体。
   * @returns {Promise<boolean>} 是否初始化成功
   */
  async init() {
    if (this.ready) return true;
    this.canvas = document.createElement('canvas');
    this.canvas.width  = 512;
    this.canvas.height = 768;

    const gl = this.canvas.getContext('webgl', {
      alpha: true,
      premultipliedAlpha: false,
      preserveDrawingBuffer: true   // 需要 readPixels
    });

    if (!gl) {
      console.warn('[LitPixel] WebGL 不可用，回退到静态贴图');
      return false;
    }
    this.gl = gl;

    // 编译 shader
    const vs = this._compileShader(gl.VERTEX_SHADER, VERTEX_SHADER_SRC);
    const fs = this._compileShader(gl.FRAGMENT_SHADER, FRAGMENT_SHADER_SRC);
    if (!vs || !fs) return false;

    const program = gl.createProgram();
    gl.attachShader(program, vs);
    gl.attachShader(program, fs);
    gl.linkProgram(program);

    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      console.error('[LitPixel] Shader link error:', gl.getProgramInfoLog(program));
      return false;
    }
    gl.deleteShader?.(vs);
    gl.deleteShader?.(fs);
    this.program = program;
    gl.useProgram(program);

    // ── 全屏四边形 ──
    const positions = new Float32Array([
      -1,-1,  1,-1, -1,1,
      -1, 1,  1,-1,  1,1
    ]);
    const texcoords = new Float32Array([
      0,1,  1,1,  0,0,
      0,0,  1,1,  1,0
    ]);

    this._bindBuffer('a_position', positions, 2);
    this._bindBuffer('a_texCoord', texcoords, 2);

    // 设置固定采样器
    gl.uniform1i(gl.getUniformLocation(program, 'u_baseColor'),  0);
    gl.uniform1i(gl.getUniformLocation(program, 'u_normalMap'),  1);
    gl.uniform1i(gl.getUniformLocation(program, 'u_materialMap'),2);

    this.ready = true;
    console.log('[LitPixel] Renderer initialized ✓');
    return true;
  }

  // ========== 纹理加载 ==========

  /**
   * 预加载一个角色的三张贴图到 GPU。
   * @param {string} charId — e.g. "bai_luoxuan"
   */
  async preloadCharacter(charId) {
    if (this.textureCache.has(charId)) return;
    if (!this.ready) throw new Error('[LitPixel] Renderer not initialized');

    const prefix = this.assetBase + 'concept_';
    const urls = [
      prefix + charId + '.webp',
      prefix + charId + '_normal.png',
      prefix + charId + '_material.png',
    ];

    const images = await Promise.all(urls.map(src => this._loadImage(src)));
    const gl = this.gl;

    const textures = images.map((img, i) => {
      const tex = gl.createTexture();
      gl.activeTexture(gl.TEXTURE0 + i);
      gl.bindTexture(gl.TEXTURE_2D, tex);

      // 像素艺术：NEAREST 过滤，无 mipmap
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, img);
      return tex;
    });

    this.textureCache.set(charId, {
      baseColor: textures[0],
      normal:    textures[1],
      material:  textures[2],
    });

    console.log(`[LitPixel] Preloaded: ${charId} (${images[0].width}x${images[0].height})`);
  }

  // ========== 渲染 ==========

  /**
   * 渲染角色到目标 Canvas。
   * @param {HTMLCanvasElement} targetCanvas — 目标画布
   * @param {string} charId — 角色 ID
   * @param {Object} [lightOverride] — 可选光照覆盖
   */
  async renderToCanvas(targetCanvas, charId, lightOverride) {
    const gl = this.gl;
    let textures = this.textureCache.get(charId);
    if (!textures) {
      await this.preloadCharacter(charId);
      textures = this.textureCache.get(charId);
    }
    if (!textures) {
      throw new Error(`[LitPixel] Character "${charId}" could not be loaded.`);
    }

    // 设置光照
    const lp = { ...this.lightParams, ...lightOverride };
    this._setUniforms(gl, lp);

    // 绑定纹理
    const texNames = ['baseColor', 'normal', 'material'];
    texNames.forEach((name, i) => {
      gl.activeTexture(gl.TEXTURE0 + i);
      gl.bindTexture(gl.TEXTURE_2D, textures[name]);
    });

    // 渲染到隐藏缓冲区
    gl.viewport(0, 0, 512, 768);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLES, 0, 6);

    // 读取像素并绘制到目标 canvas
    const pixels = new Uint8Array(512 * 768 * 4);
    gl.readPixels(0, 0, 512, 768, gl.RGBA, gl.UNSIGNED_BYTE, pixels);

    // 翻转 Y 轴（WebGL 原点在左下）
    targetCanvas.width  = 512;
    targetCanvas.height = 768;
    const ctx = targetCanvas.getContext('2d');
    const imgData = ctx.createImageData(512, 768);

    // 逐行翻转
    for (let y = 0; y < 768; y++) {
      const srcRow = (767 - y) * 512 * 4;
      const dstRow = y * 512 * 4;
      imgData.data.set(
        pixels.subarray(srcRow, srcRow + 512 * 4),
        dstRow
      );
    }
    ctx.putImageData(imgData, 0, 0);
  }

  /**
   * 渲染角色并返回 dataURL（用于 <img> 标签）。
   * @param {string} charId
   * @param {number} [outW=512] — 输出宽度
   * @param {number} [outH=768] — 输出高度
   * @param {Object} [lightOverride]
   * @returns {Promise<string>} dataURL
   */
  async renderToDataURL(charId, outW, outH, lightOverride) {
    outW = outW || 512;
    outH = outH || 768;

    const cacheKey = `${charId}::${outW}x${outH}::${this._lightHash(lightOverride)}`;
    if (this.renderCache.has(cacheKey)) {
      return this.renderCache.get(cacheKey);
    }

    const tmpCanvas = document.createElement('canvas');
    await this.renderToCanvas(tmpCanvas, charId, lightOverride);

    // 缩放到目标尺寸（NEAREST 保持像素锐度）
    if (outW !== 512 || outH !== 768) {
      const scaled = document.createElement('canvas');
      scaled.width  = outW;
      scaled.height = outH;
      const sctx = scaled.getContext('2d');
      sctx.imageSmoothingEnabled = false;
      sctx.drawImage(tmpCanvas, 0, 0, outW, outH);
      const dataUrl = scaled.toDataURL('image/png');
      this.renderCache.set(cacheKey, dataUrl);
      return dataUrl;
    }

    const dataUrl = tmpCanvas.toDataURL('image/png');
    this.renderCache.set(cacheKey, dataUrl);
    return dataUrl;
  }

  // ========== 光照控制 ==========

  /**
   * 设置光照参数。
   * @param {Object} params — 部分或全部光照参数
   */
  setLight(params) {
    Object.assign(this.lightParams, params);
    // 清除渲染缓存（光照变了，所有缓存失效）
    this.renderCache.clear();
  }

  /**
   * 开始光照旋转动画（展示法线贴图效果）。
   * @param {HTMLCanvasElement} canvas — 需要持续刷新的 canvas
   * @param {string} charId
   */
  startLightAnimation(canvas, charId) {
    this.stopLightAnimation();
    const coordinator = typeof window !== 'undefined' ? window.renderLoopCoordinator : null;
    if (!coordinator || typeof coordinator.register !== 'function') {
      console.warn('[LitPixel] RenderLoopCoordinator unavailable; light animation skipped.');
      return;
    }
    this._animFrame = true;
    this._animUnsubscribe = coordinator.register(
      'litpixel-light',
      () => {
      this._animAngle += 0.008;
      const dir = [
        Math.cos(this._animAngle) * 0.8,
        -0.6,
        Math.sin(this._animAngle) * 0.5 + 0.2
      ];
      void this.renderToCanvas(canvas, charId, { dir });
      },
      {
        fps: this._animationFps(),
        isActive: () => {
          if (!canvas || !canvas.isConnected || canvas.getBoundingClientRect().width <= 0) return false;
          const panel = canvas.closest?.('#npc-panel, #companion-panel');
          return !panel || getComputedStyle(panel).display !== 'none';
        }
      }
    );
  }

  _animationFps() {
    const quality = typeof document !== 'undefined'
      ? document.documentElement.dataset.effectQuality || 'balanced'
      : 'balanced';
    return { low: 8, balanced: 15, high: 20 }[quality] || 15;
  }

  /** 停止光照动画 */
  stopLightAnimation() {
    if (this._animUnsubscribe) {
      this._animUnsubscribe();
      this._animUnsubscribe = null;
      this._animFrame = null;
    }
    this._animFrame = null;
  }

  /** Release the WebGL context and all cached GPU resources. */
  dispose() {
    this.stopLightAnimation();
    const gl = this.gl;
    if (gl) {
      for (const textures of this.textureCache.values()) {
        Object.values(textures || {}).forEach(texture => texture && gl.deleteTexture?.(texture));
      }
      this._buffers.forEach(buffer => gl.deleteBuffer?.(buffer));
      if (this.program) gl.deleteProgram?.(this.program);
    }
    this.textureCache.clear();
    this.renderCache.clear();
    this._buffers = [];
    this.program = null;
    this.gl = null;
    this.ready = false;
    if (this.canvas?.parentNode) this.canvas.parentNode.removeChild(this.canvas);
    this.canvas = null;
  }

  // ========== Private Helpers ==========

  /** @private 编译单个 shader */
  _compileShader(type, source) {
    const gl = this.gl;
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      const typeName = type === gl.VERTEX_SHADER ? 'VERTEX' : 'FRAGMENT';
      console.error(`[LitPixel] ${typeName} shader error:`, gl.getShaderInfoLog(shader));
      gl.deleteShader(shader);
      return null;
    }
    return shader;
  }

  /** @private 绑定属性缓冲区 */
  _bindBuffer(attribName, data, components) {
    const gl = this.gl;
    const loc = gl.getAttribLocation(this.program, attribName);
    const buf = gl.createBuffer();
    this._buffers.push(buf);
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, data, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, components, gl.FLOAT, false, 0, 0);
  }

  /** @private 设置所有 uniform */
  _setUniforms(gl, lp) {
    const u = (name) => gl.getUniformLocation(this.program, name);

    gl.uniform3fv(u('u_lightDir'),   lp.dir);
    gl.uniform3fv(u('u_rimColor'),   lp.rimColor);
    gl.uniform3fv(u('u_ambientColor'), lp.ambientColor);
    gl.uniform1f (u('u_rimPower'),       lp.rimPower);
    gl.uniform1f (u('u_rimIntensity'),   lp.rimIntensity);
    gl.uniform1f (u('u_ambientStrength'),lp.ambientStrength);
    gl.uniform1f (u('u_specIntensity'),  lp.specIntensity);
    gl.uniform1f (u('u_lightIntensity'), lp.lightIntensity);
  }

  /** @private 加载图片 */
  _loadImage(src) {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = () => reject(new Error(`Failed to load: ${src}`));
      img.src = src;
    });
  }

  /** @private 光照参数哈希（用于缓存 key） */
  _lightHash(override) {
    const p = override ? { ...this.lightParams, ...override } : this.lightParams;
    return `${p.dir[0].toFixed(2)},${p.dir[1].toFixed(2)},${p.dir[2].toFixed(2)}`
         + `|${p.rimIntensity.toFixed(2)}|${p.ambientStrength.toFixed(2)}`;
  }
}

// ============================================================
// 全局单例
// ============================================================
if (typeof window !== 'undefined') {
  window.litPixelRenderer = new LitPixelRenderer();
}
