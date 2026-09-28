# MoonUndo

[![Test MoonUndo](https://github.com/YeeHh2004/moonundo/actions/workflows/ci.yml/badge.svg)](https://github.com/YeeHh2004/moonundo/actions/workflows/ci.yml)

**给普通应用状态添加撤销、重做、批量取消和历史恢复。**

MoonUndo 是一个以 MoonBit 编写的独立 `History[T]` 库。应用保留自己的数据类型，只需提供复制和相等比较函数。它不要求采用某个 UI 框架、编辑器或 CRDT 文档模型。适合设置表单、任务工具、图形编辑器，以及其他有可编辑状态的单用户应用。

**[在线体验三个应用](https://yeehh2004.github.io/moonundo/)** · [验收步骤](docs/ACCEPTANCE.md) · [公开接口](pkg.generated.mbti)。在线演示只在 CI 全部通过后部署。

Generic, framework-independent snapshot history for MoonBit application state. Original implementation, Apache-2.0; AI-assisted development is disclosed. Not a port of an existing undo library.

![设置表单示例](docs/screenshots/settings.png)

## 五分钟体验

需要 **Node.js 20+** 和 **MoonBit compiler/core `0.10.14+7d59c7ec9`**。CI 固定了同一版本，安装方法见 [工作流](.github/workflows/ci.yml)。网页、CLI 无第三方 JavaScript 运行时依赖。

```sh
git clone https://github.com/YeeHh2004/moonundo.git
cd moonundo
node scripts/build.mjs
node scripts/serve.mjs
```

浏览器打开 **http://127.0.0.1:4178**。请通过 HTTP 服务打开，避免 `file://` 阻止 ES module 加载。每次更改 MoonBit 源码后重新运行 build。

| 示例 | 完整体验 | 复用的库能力 |
| --- | --- | --- |
| 设置表单 | 开始批量修改 → 改名称与主题 → 取消全部；再次修改并提交 → 一次撤销 | 事务、回滚、原子提交 |
| 任务清单 | 添加任务 → 完成或误删 → 撤销找回 → 批量完成后一次回退 | 类型无关的状态历史、分支管理 |
| 轻量画布 | 拖动图形多次更新位置 → 松开 → 一次撤销；改颜色、删除均可恢复 | 显式编辑分组、时间线 |

点击“保存到本机”，刷新页面后用“恢复本机存档”恢复当前示例。存档包含可撤销、可重做历史；也可导出 JSON 并导入同一示例。数据不上传服务器。浏览器清理站点数据会删除本机存档，应自行导出重要数据。

## 在 MoonBit 中使用

核心包是 `YeeHh2004/moonundo`。当前以 GitHub 源码交付，**尚未发布 Mooncakes 包**。可通过 [MoonBit workspace 本地依赖](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html) 接入：

```text
workspace/
  moon.work       // members = ["moonundo", "my-app"]
  moonundo/       // 本仓库
  my-app/
    moon.mod      // import { "YeeHh2004/moonundo@0.1.0" }
    moon.pkg      // import { "YeeHh2004/moonundo" @undo }
```

```moonbit
let h = @undo.History::new(
  ["draft"],
  copy=fn(items) { items.copy() },
  equal=fn(a, b) { a == b },
  limit=50,
).unwrap()
ignore(h.begin("Prepare document"))
ignore(h.record(["draft", "reviewed"], "Review"))
ignore(h.record(["draft", "reviewed", "ready"], "Ready"))
ignore(h.commit()) // 整组修改只产生一个可撤销步骤
ignore(h.undo())
// h.state() == ["draft"]
```

完整自定义文档类型例子见 [examples/typed](examples/typed/main.mbt)。[独立模块集成检查](scripts/check-consumer.mjs) 实际建立另一个模块并导入公开接口，JS/Wasm GC 两个后端均参与测试。

可变数据必须提供正确的**深复制**函数；上例 `Array[String]` 的数组复制足够，嵌套可变对象需逐层复制。库复制传入及返回的状态，调用方修改这些对象不会改变内部历史。`copy`、`equal`、序列化 codec 必须是纯函数。

## API 与行为

完整接口见 [pkg.generated.mbti](pkg.generated.mbti)，细节见 [设计契约](docs/DESIGN.md)。

| API | 行为 |
| --- | --- |
| `History::new` / `state` | 初始化与隔离的状态副本；容量为 1–10,000 步 |
| `record` / `undo` / `redo` | 相等状态不创建历史；撤销后真实新编辑清除未来分支 |
| `timeline` / `jump_to` | 只读历史元数据与按当前时间线索引导航 |
| `begin` / `commit` / `rollback` | 最多 64 层嵌套事务；仅最外层提交生成一步历史 |
| `record(..., group="typing")` / `break_group` | 按显式键合并连续编辑，不依赖时钟；保存与导航等会切断分组 |
| `mark_saved` / `is_dirty` / `forget_saved` | 以修订身份判断保存状态；应在实际存储成功后标记保存 |
| `set_capacity` / `clear` / `reset` | 裁剪历史、仅清除导航或加载新基线；不会混淆三种语义 |
| `export_session` / `restore_session` | 用户 codec 编解码任意 `T`；检查存档版本、编号、范围与容量 |

除查询和明确返回 `Unit` 的方法外，错误通过 `Result` 返回。导航、保存、调整容量、清空和导出在未结束事务时被拒绝，避免把临时预览当作最终状态。恢复关闭连续编辑分组。

## JSON / 命令行

```sh
node cli/moonundo.mjs examples/task-session.json
node cli/moonundo.mjs --help
```

无参数或 `-` 从 stdin 读取；输出含当前状态、时间线和可恢复 session。成功退出 0，脚本拒绝退出 1，I/O 或用法错误退出 2。CLI 不覆盖输入文件。JSON 请求格式见 [docs/JSON.md](docs/JSON.md)。ESM 导出 `replay(text)`（核心适配）及 `reduce(text)`（三个示例的 MoonBit 业务逻辑）。

## 验证

```sh
moon fmt --check
moon check --target js
moon test --target js
moon test --target wasm-gc
node scripts/build.mjs
node --test tests/*.test.mjs
node scripts/check-consumer.mjs
```

当前 48 项 MoonBit 测试；独立模块检查额外增加 1 项。16 项 Node 测试包含 8 个种子、合计 4,000 次生成状态转换的独立模型对照，以及 CLI、坏存档、数值边界和示例接入。浏览器验收另行执行：

```sh
npm install --no-save --package-lock=false playwright@1.62.1
npx playwright install chromium
node tests/browser.mjs
```

可设置 `BROWSER_CHANNEL=msedge` 使用已安装的 Edge。浏览器验收覆盖三个场景、保存/恢复、导入/导出、拖动合并及移动端布局。CI 覆盖 Linux Node 20/22、Windows Node 22；Linux Node 22 另运行 Chromium 验收。

## 适用边界与来源

全量快照易于接入，但空间约为 **O(历史步数 × 状态大小)**；容量限制步数，不限制字节。适合中小型可编辑状态，不适合每帧保存巨型文档。它只恢复应用内存状态，不能撤销已发生的 HTTP 请求、付款或文件写入，也不处理多人并发合并。

生态中已有 CRDT 与编辑器内部撤销实现；我们没有声称 MoonBit 从未有过 undo。这里补充的是可直接应用于任意业务数据类型的独立快照历史库。[选题、查重与差异说明](docs/SELECTION.md) 列出检索范围和近邻项目。[验收路径](docs/ACCEPTANCE.md) 对应可复现的交付证据。

原创代码以 [Apache-2.0](LICENSE) 发布。未移植、复制相关项目源码；概念资料和开发工具说明见 [NOTICE.md](NOTICE.md)。
