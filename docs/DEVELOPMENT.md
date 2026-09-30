# 开发、接入与发布

## 环境与启动

运行预编译交付包只需 Node.js 20+。源码编译固定 MoonBit compiler/core `0.10.14+7d59c7ec9`；用 `moon version --all` 确认，构建脚本会拒绝其他 compiler 版本。安装工具参考 [MoonBit 官方工具链文档](https://docs.moonbitlang.com/en/latest/toolchain/index.html)，自动安装该固定版本的已验证配置见 [.github/workflows/ci.yml](../.github/workflows/ci.yml)。不需要下载 UI 框架或 npm 运行时依赖。

```sh
node scripts/build.mjs
node scripts/serve.mjs
```

默认只监听 `127.0.0.1:4178`，用 `PORT` 环境变量改端口。`file://` 不能可靠加载 ES modules，应使用提供的 HTTP 服务。GitHub Pages 部署同一套静态文件，不需要后端账号、数据库或 API 密钥。

## 接入自己的 MoonBit 数据类型

将本库和你的模块放进同一 `moon.work`，模块声明 `import { "YeeHh2004/moonundo@0.2.0" }`，包声明 `import { "YeeHh2004/moonundo" @undo }`。目前尚未发布 Mooncakes 注册包，应使用源码 workspace，不能把 `moon add` 当作已可用的安装路径。可直接运行 `node scripts/check-consumer.mjs` 查看一个真正独立模块的导入验证。

`History[T]` 接受状态初值、纯深复制函数和纯比较函数。`examples/typed/main.mbt` 展示自定义 `Document` 结构体中可变数组的隔离：调用方修改输入或查询返回值，不改变内部历史。嵌套对象需要逐层复制；不可变数据可以用恒等复制。

在用户开始批量修改时调用 begin，每次预览调用 record，确认后 commit，取消时 rollback。仅最外层 commit 增加一步历史。活动事务内导航和导出会返回 Err，应呈现给用户而非忽略；示例代码里的 unwrap/ignore 用于已知合法的演示步骤，生产接入应处理 Result。

保存普通应用数据成功后才调用 mark_saved；异步保存时，还需核对保存的 revision_id 与当前 revision_id，防止把保存过程中产生的新编辑标为已保存。保存点按修订身份判断，不把“内容恰巧相等”当作同一个已保存修订。

## 接入浏览器或 Node

构建后的 `web/moonundo.mjs` 可直接作为 ES module 引入。历史与示例业务 reducer 均为 MoonBit 编译产物；DOM、文件下载、localStorage 和 CLI I/O 由 JavaScript 宿主承担。

```js
import {open_editor, dispatch_editor, close_editor} from './moonundo.mjs';
const opened = JSON.parse(open_editor(JSON.stringify({initial:{count:0},limit:50})));
if (!opened.ok) throw new Error(opened.error);
const send = command => {
  const result = JSON.parse(dispatch_editor(opened.handle,JSON.stringify(command)));
  if (!result.ok) throw new Error(result.error);
  return result;
};
try {
  send({op:'record',value:{count:1},label:'Increment'});
  const prepared = send({op:'prepare_save'});
  localStorage.setItem('my-history',JSON.stringify(prepared.session));
  send({op:'save'}); // 上一步失败时不会执行，也不会误标保存点。
  send({op:'undo'});
} finally {
  close_editor(opened.handle);
}
```

长期编辑无需维护 commands 数组。`replay` 留给 CLI/批处理，其 2,000 条脚本上限不适用于长期存活的编辑器。至多同时打开 64 个编辑器，替换/销毁时调用 close；示例中导入失败也会释放候选实例。完整协议、限制与存档格式见 [JSON.md](JSON.md)。

## 验证与维护

```sh
moon info
moon fmt
node scripts/verify.mjs
```

浏览器测试需安装固定 Playwright：

```sh
npm install --no-save --package-lock=false playwright@1.62.1
npx playwright install chromium
node scripts/verify.mjs --browser
```

已安装 Edge 时，可设置 `BROWSER_CHANNEL=msedge`。截图默认写入忽略的 `dist/browser-screenshots`；只有需要更新 README 展示图时才设置 `BROWSER_SCREENSHOT_DIR=docs/screenshots`。更新公共接口后提交 `moon info` 生成的 `.mbti`，CI 会检查它与源码是否一致。

缺陷报告请附版本、`web/build-info.json`、操作顺序、实际/预期结果和去除私人内容的最小存档。测试覆盖边界不等于覆盖所有业务类型：复制函数、codec、外部副作用仍由接入方负责。开发中按实际功能与修复提交，不以空提交或无意义拆分凑记录。

## 发布

打包工具仅依赖 Python 3 标准库、Node、Git 和固定 MoonBit 工具链：

```sh
python scripts/package_release.py
```

它要求工作区干净，重新编译，以 Git 提交对象收集源码，加入预编译引擎、网页许可、启动说明、构建信息及逐文件 SHA-256 清单，然后校验 ZIP 内容。输出 `dist/MoonUndo-v0.2.0.zip`；可用 `--output <目录>` 改路径。固定 ZIP 文件排序、权限和提交时间戳；同一源码与编译产物可得到一致压缩包。压缩包不包含 `.git`、依赖缓存或凭据，完整提交历史保留在 GitHub。

先确认目标提交 CI 全绿，再发布同一提交的 tag、Release 和 ZIP。在线演示只部署 CI 成功且仍为 main 最新提交的产物，公开 `build-info.json` 可核对版本和 sourceCommit。保留完整 [NOTICE](../NOTICE.md) 与 [licenses](../licenses)，不要在分发预编译引擎时仅保留项目自己的许可证。
