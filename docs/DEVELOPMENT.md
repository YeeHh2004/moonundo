# 开发、接入与发布

## 环境与启动

运行预编译交付包只需 Node.js 20+。源码维护使用官方当前 MoonBit compiler/core；2026-11-11 的验证基线为 `0.10.20+65efd5b93`。用 `moon version --all` 和 `moonc -v` 确认，安装方法参考 [MoonBit 官方工具链文档](https://docs.moonbitlang.com/en/latest/toolchain/index.html)。[主 CI](../.github/workflows/ci.yml) 固定完整版本，以便复现；[每周兼容流程](../.github/workflows/compatibility.yml) 使用 latest/compiler 和 latest/core，在两个声明后端检查、构建、测试，并验证 Node 宿主和独立接入示例。该独立流程不部署演示或发布产物。

构建脚本不按版本字符串拒绝新版工具链，而是实际编译并拒绝警告。`web/build-info.json` 保存完整 `compilerVersion`、`moonVersion`、`coreVersion`、源码提交和引擎哈希。构建从活动 `MOON_HOME/lib/core`（未设置时为 `~/.moon/lib/core`）读取实际 core manifest、LICENSE 和 NOTICE，保留完整许可并记录哈希；自定义安装应设置正确的 `MOON_HOME`。源码中的 `licenses/` 是本次基线的上游许可副本。无需下载 UI 框架或 npm 运行时依赖。

```sh
node scripts/build.mjs
node scripts/serve.mjs
```

默认只监听 `127.0.0.1:4178`，用 `PORT` 环境变量改端口。`file://` 不能可靠加载 ES modules，应使用提供的 HTTP 服务。GitHub Pages 部署同一套静态文件，不需要后端账号、数据库或 API 密钥。

## 接入自己的 MoonBit 数据类型

核心包通过 [Mooncakes](https://mooncakes.io/docs/YeeHh2004/moonundo) 分发。当前源码声明版本为 `0.2.3`；该版本发布后，普通接入运行 `moon add YeeHh2004/moonundo@0.2.3`，并在包中声明 `import { "YeeHh2004/moonundo" @undo }`。`node scripts/check-consumer.mjs --registry` 要求该版本已在注册表公开，可在无 workspace 的临时项目中复现公开安装、核心源码核对、构建与两个后端的测试/运行。

同时开发库与应用时，也可以把二者放进同一 `moon.work`，模块声明 `import { "YeeHh2004/moonundo@0.2.3" }`；`node scripts/check-consumer.mjs` 使用这一源码 workspace 模式。前者验证正式分发，后者验证当前工作区，两者用途不同。

`History[T]` 接受状态初值、纯深复制函数和纯比较函数。`examples/typed/main.mbt` 展示自定义 `Document` 结构体中可变数组的隔离：调用方修改输入或查询返回值，不改变内部历史。嵌套对象需要逐层复制；不可变数据可以用恒等复制。[examples/consumer](../examples/consumer/) 是可复制的独立模块，包含更完整的嵌套文档、应用 codec 和三个工作流测试；接入检查会在临时 workspace 中验证，并在结束后清理。

在用户开始批量修改时调用 begin，每次预览调用 record，确认后 commit，取消时 rollback。仅最外层 commit 增加一步历史。活动事务内导航和导出会返回 Err，应呈现给用户而非忽略；示例代码里的 unwrap/ignore 用于已知合法的演示步骤，生产接入应处理 Result。

保存普通应用数据成功后才调用 mark_saved；异步保存时，还需核对保存的 revision_id 与当前 revision_id，防止把保存过程中产生的新编辑标为已保存。保存点按修订身份判断，不把“内容恰巧相等”当作同一个已保存修订。

## 接入浏览器或 Node

构建后的 `web/moonundo.mjs` 可直接作为 ES module 引入。历史与示例业务 reducer 均为 MoonBit 编译产物；DOM、文件下载、localStorage 和 CLI I/O 由 JavaScript 宿主承担。

```js
import {open_editor, dispatch_editor, close_editor} from './moonundo.mjs';
const opened = JSON.parse(open_editor(JSON.stringify({initial:{count:0},limit:50,include_session:false})));
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

长期编辑无需维护 commands 数组。`include_session:false` 保留当前状态和元数据，省去每次传输完整历史；需要历史时显式 export 或 prepare_save。不指定该选项仍沿用旧的完整响应。`replay` 留给 CLI/批处理，其 2,000 条脚本上限不适用于长期存活的编辑器。至多同时打开 64 个编辑器，替换/销毁时调用 close；示例中导入失败也会释放候选实例。完整协议、限制与存档格式见 [JSON.md](JSON.md)，实际工作负载及容量选择见 [PERFORMANCE.md](PERFORMANCE.md)。

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

Mooncakes 使用 `.moonignore` 单独定义源码分发范围。运行 `python scripts/check-mooncake.py` 检查 `moon package` 生成的真实 ZIP：必须含 MoonBit 源码、测试、可运行示例、专用 README、LICENSE 和完整上游 NOTICE，且不含浏览器/Node 宿主、缓存或凭据。首次发布按 [官方流程](https://docs.moonbitlang.com/en/stable/toolchain/moon/package-manage-tour.html) 完成 `moon login` 后运行 `moon publish`，随后用 `node scripts/check-consumer.mjs --registry` 验证。凭据只放在本机 MoonBit 配置目录，不写入源码或 CI。已发布版本不可随意覆盖；更新实现应递增版本。

GitHub Release 发布后，[registry.yml](../.github/workflows/registry.yml) 自动在 Linux 和 Windows 验证公开包。该流程没有发布密钥，只执行公开下载、核心源码比对、构建和运行。

打包工具仅依赖 Python 3 标准库、Node、Git 和 MoonBit 工具链；复现同一编译产物时使用 CI 固定基线：

```sh
python scripts/package_release.py
```

它要求工作区干净，重新编译，以 Git 提交对象收集源码，加入预编译引擎、网页许可、启动说明、构建信息及逐文件 SHA-256 清单，然后校验 ZIP 内容。输出 `dist/MoonUndo-v0.2.3.zip`；可用 `--output <目录>` 改路径。固定 ZIP 文件排序、权限和提交时间戳；同一提交、构建元数据与编译产物可得到一致压缩包，完整工具链输出中的安装路径也属于元数据。压缩包不包含 `.git`、依赖缓存或凭据，完整提交历史保留在 GitHub。

先确认目标提交 CI 全绿，再发布同一提交的 tag、Release 和 ZIP。在线演示只部署 CI 成功且仍为 main 最新提交的产物，公开 `build-info.json` 可核对版本和 sourceCommit。保留完整 [NOTICE](../NOTICE.md) 与 [licenses](../licenses)，不要在分发预编译引擎时仅保留项目自己的许可证。
