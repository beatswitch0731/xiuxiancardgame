/**
 * 三维环境灵气系统 (ThreeBackgroundSystem)
 * 采用 2.5D 混合渲染架构，基于 Three.js 实现古典修仙质感的环境氛围。
 * 不加载外部模型，仅依靠柔和的粒子、正弦波缓动和相变颜色过渡，营造“凡人流”深邃、内敛的视觉体验。
 */
class ThreeBackgroundSystem {
  constructor() {
    this.container = null;
    this.scene = null;
    this.camera = null;
    this.renderer = null;
    this.particles = null;
    this.geometry = null;
    this.material = null;

    // 状态与缓动
    this.targetColor = new THREE.Color(0x39d0d8); // 默认青色(风平浪静)
    this.currentColor = new THREE.Color(0x39d0d8);
    this.targetSpeed = 0.0005;
    this.currentSpeed = 0.0005;

    // “古典修仙”配色辞典 (基于 FlowDirector 的 Phase ID)
    this.phaseTheme = {
      'CALM':       { color: 0x39d0d8, speed: 0.0003 }, // 青霜翠玉 (静谧)
      'BUILDUP':    { color: 0xc19a6b, speed: 0.0006 }, // 铜纹暗金 (积蓄)
      'TENSION':    { color: 0x4a4e69, speed: 0.0010 }, // 沉灰幽紫 (压抑)
      'CLIMAX':     { color: 0x800020, speed: 0.0025 }, // 猩红血煞 (狂暴)
      'RESOLUTION': { color: 0xa371f7, speed: 0.0004 }  // 紫气东来 (澄清)
    };
  }

  init() {
    if (typeof THREE === 'undefined') {
      console.warn('[ThreeBackground] Three.js 未加载，灵气系统降级。');
      return;
    }

    this.container = document.getElementById('three-canvas-container');
    if (!this.container) return;

    // 1. 初始化基础场景
    this.scene = new THREE.Scene();
    
    // 摄像机
    this.camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 1, 1000);
    this.camera.position.z = 200;

    // 渲染器配置：透明背景，方便与底层 CSS 色彩融合
    this.renderer = new THREE.WebGLRenderer({ alpha: true, antialias: false });
    this.renderer.setSize(window.innerWidth, window.innerHeight);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2)); // 限制像素比优化性能
    this.container.appendChild(this.renderer.domElement);

    // 2. 生成“古典水雾/灵光”柔和纹理 (无外部图片依赖)
    const particleTexture = this._createSoftTexture();

    // 3. 构建灵气粒子系统 (1500 个节点，兼顾移动端性能与意境)
    const particleCount = 1500;
    this.geometry = new THREE.BufferGeometry();
    const positions = new Float32Array(particleCount * 3);
    const phases = new Float32Array(particleCount); // 存储每个粒子的独立正弦相位

    for (let i = 0; i < particleCount; i++) {
      // 在球形空间内随机分布
      const r = 250 * Math.cbrt(Math.random());
      const theta = Math.random() * 2 * Math.PI;
      const phi = Math.acos(2 * Math.random() - 1);
      
      positions[i * 3] = r * Math.sin(phi) * Math.cos(theta);     // x
      positions[i * 3 + 1] = r * Math.sin(phi) * Math.sin(theta); // y
      positions[i * 3 + 2] = r * Math.cos(phi);                   // z

      phases[i] = Math.random() * Math.PI * 2;
    }

    this.geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    this.geometry.setAttribute('aPhase', new THREE.BufferAttribute(phases, 1));

    // 使用 PointsMaterial，开启混合实现光晕叠加
    this.material = new THREE.PointsMaterial({
      size: 4,
      map: particleTexture,
      transparent: true,
      opacity: 0.6,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
      color: this.currentColor
    });

    this.particles = new THREE.Points(this.geometry, this.material);
    this.scene.add(this.particles);

    // 4. 事件监听
    window.addEventListener('resize', this._onWindowResize.bind(this), false);
    if (typeof eventBus !== 'undefined') {
      eventBus.on('flow:phaseChanged', this._onPhaseChanged.bind(this));
      eventBus.on('combat:vfx', data => this.triggerVFX(data.type, data));
    }

    // VFX 存储池
    this.vfxObjects = [];

    // 5. 启动渲染循环
    this._animate();
    console.log('[ThreeBackground] 古典灵气系统初始化完成。');
  }

  triggerVFX(type, options) {
    if (!this.scene || typeof THREE === 'undefined') return;
    
    let x = 0, y = 0, z = 100; // 前景
    if (options.target === 'player') { x = -40; y = -20; }
    else if (options.target === 'enemy') { x = 40; y = 20; }
    
    const vfxGroup = new THREE.Group();
    vfxGroup.position.set(x, y, z);
    
    if (type === 'slash') {
        // 一道锐利的剑气
        const geom = new THREE.PlaneGeometry(80, 2);
        const mat = new THREE.MeshBasicMaterial({ color: 0xffdd88, transparent: true, opacity: 1, blending: THREE.AdditiveBlending });
        const mesh = new THREE.Mesh(geom, mat);
        mesh.rotation.z = Math.random() * Math.PI; // 随机斩击角度
        vfxGroup.add(mesh);
        
        vfxGroup.userData = {
            life: 1.0, decay: 0.05,
            update: (group) => {
                group.userData.life -= group.userData.decay;
                mesh.scale.x += 0.2;
                mesh.material.opacity = group.userData.life;
                if (group.userData.life <= 0) this.scene.remove(group);
            }
        };
    } else if (type === 'impact') {
        // 血煞粒子爆点
        const geom = new THREE.BufferGeometry();
        const pts = new Float32Array(15 * 3);
        const vels = [];
        for(let i=0; i<15; i++) {
            pts[i*3] = 0; pts[i*3+1] = 0; pts[i*3+2] = 0;
            vels.push(new THREE.Vector3((Math.random()-0.5)*5, (Math.random()-0.5)*5, (Math.random()-0.5)*5));
        }
        geom.setAttribute('position', new THREE.BufferAttribute(pts, 3));
        const mat = new THREE.PointsMaterial({ color: 0xff3333, size: 6, transparent: true, opacity: 1, blending: THREE.AdditiveBlending });
        const points = new THREE.Points(geom, mat);
        vfxGroup.add(points);
        
        vfxGroup.userData = {
            life: 1.0, decay: 0.03,
            update: (group) => {
                group.userData.life -= group.userData.decay;
                const pos = geom.attributes.position.array;
                for(let i=0; i<15; i++) {
                    pos[i*3] += vels[i].x;
                    pos[i*3+1] += vels[i].y;
                    pos[i*3+2] += vels[i].z;
                }
                geom.attributes.position.needsUpdate = true;
                mat.opacity = group.userData.life;
                if (group.userData.life <= 0) this.scene.remove(group);
            }
        };
    } else if (type === 'shield_gain' || type === 'aura') {
        // 阵法灵光涟漪
        const geom = new THREE.RingGeometry(0.1, 15, 32);
        const mat = new THREE.MeshBasicMaterial({ color: 0x4caf50, transparent: true, opacity: 0.8, side: THREE.DoubleSide, blending: THREE.AdditiveBlending });
        if (type === 'aura') mat.color.setHex(0x39d0d8);
        const mesh = new THREE.Mesh(geom, mat);
        vfxGroup.add(mesh);
        
        vfxGroup.userData = {
            life: 1.0, decay: 0.02,
            update: (group) => {
                group.userData.life -= group.userData.decay;
                mesh.scale.x += 0.1;
                mesh.scale.y += 0.1;
                mat.opacity = group.userData.life;
                if (group.userData.life <= 0) this.scene.remove(group);
            }
        };
    } else if (type === 'shield_break') {
        // 护盾碎裂飞溅
        const geom = new THREE.BufferGeometry();
        const pts = new Float32Array(20 * 3);
        const vels = [];
        for(let i=0; i<20; i++) {
            pts[i*3] = (Math.random()-0.5)*10; pts[i*3+1] = (Math.random()-0.5)*10; pts[i*3+2] = 0;
            vels.push(new THREE.Vector3((Math.random()-0.5)*8, (Math.random()-0.5)*8, (Math.random()-0.5)*8));
        }
        geom.setAttribute('position', new THREE.BufferAttribute(pts, 3));
        const mat = new THREE.PointsMaterial({ color: 0xaaffff, size: 4, transparent: true, opacity: 1, blending: THREE.AdditiveBlending });
        const points = new THREE.Points(geom, mat);
        vfxGroup.add(points);
        
        vfxGroup.userData = {
            life: 1.0, decay: 0.04,
            update: (group) => {
                group.userData.life -= group.userData.decay;
                const pos = geom.attributes.position.array;
                for(let i=0; i<20; i++) {
                    pos[i*3] += vels[i].x;
                    pos[i*3+1] += vels[i].y;
                    pos[i*3+2] += vels[i].z;
                }
                geom.attributes.position.needsUpdate = true;
                mat.opacity = group.userData.life;
                if (group.userData.life <= 0) this.scene.remove(group);
            }
        };
    } else if (type === 'shield_hit') {
        // 护盾受击涟漪
        const geom = new THREE.RingGeometry(14, 15, 32);
        const mat = new THREE.MeshBasicMaterial({ color: 0x4caf50, transparent: true, opacity: 1, side: THREE.DoubleSide, blending: THREE.AdditiveBlending });
        const mesh = new THREE.Mesh(geom, mat);
        vfxGroup.add(mesh);
        
        vfxGroup.userData = {
            life: 1.0, decay: 0.05,
            update: (group) => {
                group.userData.life -= group.userData.decay;
                mesh.scale.x += 0.05;
                mesh.scale.y += 0.05;
                mat.opacity = group.userData.life;
                if (group.userData.life <= 0) this.scene.remove(group);
            }
        };
    }

    if (vfxGroup.children.length > 0) {
        this.scene.add(vfxGroup);
        this.vfxObjects.push(vfxGroup);
    }
  }

  /**
   * 动态生成柔和的光晕纹理 (模拟修仙界的氤氲灵气)
   */
  _createSoftTexture() {
    const canvas = document.createElement('canvas');
    canvas.width = 64;
    canvas.height = 64;
    const ctx = canvas.getContext('2d');

    // 径向渐变，中心亮，边缘完全透明
    const gradient = ctx.createRadialGradient(32, 32, 0, 32, 32, 32);
    gradient.addColorStop(0, 'rgba(255, 255, 255, 1)');
    gradient.addColorStop(0.3, 'rgba(255, 255, 255, 0.5)');
    gradient.addColorStop(1, 'rgba(255, 255, 255, 0)');

    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, 64, 64);

    const texture = new THREE.CanvasTexture(canvas);
    return texture;
  }

  _onWindowResize() {
    if (!this.camera || !this.renderer) return;
    this.camera.aspect = window.innerWidth / window.innerHeight;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(window.innerWidth, window.innerHeight);
  }

  _onPhaseChanged(data) {
    const phaseId = data.phaseId;
    const theme = this.phaseTheme[phaseId];
    if (theme) {
      this.targetColor.setHex(theme.color);
      this.targetSpeed = theme.speed;
    }
  }

  _animate() {
    requestAnimationFrame(this._animate.bind(this));

    // 色彩与速度的古典式平缓过渡 (Lerp)
    this.currentColor.lerp(this.targetColor, 0.02);
    this.material.color.copy(this.currentColor);
    this.currentSpeed += (this.targetSpeed - this.currentSpeed) * 0.05;

    // 整体星阵/灵脉旋转
    this.particles.rotation.y += this.currentSpeed;
    this.particles.rotation.x += this.currentSpeed * 0.5;

    // 如果想让粒子像呼吸一样波动，可以在 Shader 中做，
    // 这里为了不引入复杂 Shader，通过整体缩放模拟灵气吞吐
    const time = Date.now() * 0.0005;
    const scale = 1.0 + Math.sin(time) * 0.05;
    this.particles.scale.set(scale, scale, scale);
    
    // 更新战斗 VFX
    for (let i = this.vfxObjects.length - 1; i >= 0; i--) {
        const vfx = this.vfxObjects[i];
        if (vfx.userData && vfx.userData.update) {
            vfx.userData.update(vfx);
        }
        if (vfx.userData && vfx.userData.life <= 0) {
            this.vfxObjects.splice(i, 1);
        }
    }

    this.renderer.render(this.scene, this.camera);
  }
}
