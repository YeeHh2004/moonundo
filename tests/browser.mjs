import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const {chromium} = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = fileURLToPath(new URL('../',import.meta.url));
const server = spawn(process.execPath,['scripts/serve.mjs'],{cwd:root,env:{...process.env,PORT:'4179'},stdio:'pipe'});
let browser;
try {
  let ready=false;
  for(let i=0;i<50;i++){
    try{if((await fetch('http://127.0.0.1:4179')).ok){ready=true;break;}}catch{}
    await new Promise(resolve=>setTimeout(resolve,100));
  }
  assert.ok(ready,'demo server must start');
  browser=await chromium.launch({headless:true,...(process.env.BROWSER_CHANNEL?{channel:process.env.BROWSER_CHANNEL}:{})});
  const page=await browser.newPage({viewport:{width:1440,height:1040}});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:4179');
  await page.waitForFunction(()=>document.querySelector('#message').textContent.includes('可以开始'));
  const original=await page.locator('#name').inputValue();
  await page.locator('#begin').click();
  await page.locator('#name').fill('临时工作区');
  await page.locator('#theme').selectOption('dark');
  assert.ok(await page.locator('#undo').isDisabled());
  await page.locator('#rollback').click();
  assert.equal(await page.locator('#name').inputValue(),original);
  assert.equal(await page.locator('#theme').inputValue(),'light');
  await page.locator('#begin').click();
  await page.locator('#name').fill('MoonUndo Studio');
  await page.locator('#theme').selectOption('dark');
  await page.locator('#commit').click();
  assert.equal(await page.locator('#depths').textContent(),'1 / 0');
  await page.locator('#save').click();
  await page.locator('#undo').click();
  assert.equal(await page.locator('#name').inputValue(),original);
  await page.locator('#redo').click();
  assert.equal(await page.locator('#dirty').textContent(),'与保存点一致');
  await page.locator('#name').fill('Changed');
  await page.locator('#restore').click();
  assert.equal(await page.locator('#name').inputValue(),'MoonUndo Studio');
  const downloadPromise=page.waitForEvent('download');await page.locator('#export').click();
  const download=await downloadPromise;assert.equal(download.suggestedFilename(),'moonundo-settings.json');
  await page.locator('#name').fill('Before import');
  await page.locator('#import').setInputFiles(await download.path());
  await page.waitForFunction(()=>document.querySelector('#name').value==='MoonUndo Studio');
  await page.locator('#import').setInputFiles({name:'broken.json',mimeType:'application/json',buffer:Buffer.from('{bad')});
  await page.waitForFunction(()=>document.querySelector('#message').textContent.includes('导入失败'));
  assert.equal(await page.locator('#name').inputValue(),'MoonUndo Studio');
  await page.locator('#save').click();
  await mkdir(new URL('../docs/screenshots/',import.meta.url),{recursive:true});
  await page.screenshot({path:new URL('../docs/screenshots/settings.png',import.meta.url).pathname.replace(/^\/(?=[A-Za-z]:)/,''),fullPage:true});

  await page.locator('[data-tab="tasks"]').click();
  await page.locator('#task-title').fill('验收演示 <script>');
  await page.locator('#task-form button').click();
  assert.equal(await page.locator('#task-list li').count(),3);
  await page.locator('#task-list li').last().locator('button').click();
  assert.equal(await page.locator('#task-list li').count(),2);
  await page.locator('#undo').click();
  assert.equal(await page.locator('#task-list li').count(),3);
  await page.locator('#complete-all').click();
  assert.equal(await page.locator('#task-list .done').count(),3);
  await page.locator('#undo').click();
  assert.equal(await page.locator('#task-list .done').count(),0);
  await page.screenshot({path:fileURLToPath(new URL('../docs/screenshots/tasks.png',import.meta.url)),fullPage:true});

  await page.locator('[data-tab="canvas"]').click();
  const shape=page.locator('[data-id="1"]');
  const before=await shape.getAttribute('style');
  const bounds=await shape.boundingBox();
  await page.mouse.move(bounds.x+20,bounds.y+20);await page.mouse.down();
  await page.mouse.move(bounds.x+110,bounds.y+80,{steps:12});await page.mouse.up();
  assert.notEqual(await shape.getAttribute('style'),before);
  assert.equal(await page.locator('#depths').textContent(),'1 / 0');
  await page.locator('#undo').click();
  assert.equal(await shape.getAttribute('style'),before);
  await page.locator('#redo').click();
  await page.locator('#color-shape').click();
  await page.screenshot({path:fileURLToPath(new URL('../docs/screenshots/canvas.png',import.meta.url)),fullPage:true});
  await page.setViewportSize({width:390,height:844});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'mobile page must not overflow horizontally');
  await page.screenshot({path:fileURLToPath(new URL('../docs/screenshots/mobile.png',import.meta.url)),fullPage:true});
  assert.deepEqual(errors,[]);
  console.log('Browser acceptance passed: settings transactions, saved session, export/import, tasks, drag grouping, mobile layout, no runtime errors.');
} finally { await browser?.close(); server.kill(); }

