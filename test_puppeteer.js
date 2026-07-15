const puppeteer = require('puppeteer');

(async () => {
  try {
    const browser = await puppeteer.launch();
    const page = await browser.newPage();
    
    // 监听 console 错误
    page.on('console', msg => {
      if (msg.type() === 'error' || msg.type() === 'warning') {
        console.log(`PAGE LOG: ${msg.type().toUpperCase()}: ${msg.text()}`);
      }
    });
    
    // 监听未捕获异常
    page.on('pageerror', error => {
      console.log(`PAGE ERROR: ${error.message}`);
    });
    
    // 监听网络错误
    page.on('requestfailed', request => {
      console.log(`REQUEST FAILED: ${request.url()} - ${request.failure().errorText}`);
    });

    console.log("Navigating to http://localhost:1966 ...");
    await page.goto('http://localhost:1966', { waitUntil: 'networkidle0' });
    
    // 模拟点击“踏入仙途”以触发 UI
    console.log("Typing name and clicking start button...");
    await page.type('#name-input', '测试');
    await page.click('#name-confirm-btn');
    
    // 等待 2 秒让选项 UI 有时间渲染
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    console.log("Clicking path 'sword'...");
    await page.click('.path-btn[data-path="sword"]');
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    await browser.close();
    console.log("Test finished.");
  } catch (err) {
    console.error("Test script failed:", err);
  }
})();
