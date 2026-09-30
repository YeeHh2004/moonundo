# 九项验收要求与仓库证据

对应 2026-09-30 提供的验收指南，当前版本 **0.2.2**。所有内容可从公开仓库、Actions 和 Mooncakes 直接核验，不依赖另外提交表格或仓库外文档。

| 要求 | 项目实现与可核验证据 |
| --- | --- |
| 1. MoonBit 为主要实现语言，moonc ≥ 0.10.14 | 泛型历史、时间线、事务、保存点、分组、会话 codec、JSON 编辑器及示例 reducer 均为 `.mbt`。固定 `moonc v0.10.14+7d59c7ec9`；[CI](../.github/workflows/ci.yml) 输出 `moon version --all`。Mooncakes 包不含 JS 实现，直接在 JS/Wasm GC 后端运行 MoonBit 消费项目。 |
| 2. 仓库公开、提交清晰 | [公开源码](https://github.com/YeeHh2004/moonundo) 与 [提交历史](https://github.com/YeeHh2004/moonundo/commits/main/)；提交按功能、缺陷修复、接入验证和发布工作形成。 |
| 3. 结构清晰、声明功能完成 | 根目录按 history / timeline / transaction / savepoint / grouping / session / editor 分文件；[公开接口](../pkg.generated.mbti)、[设计契约](DESIGN.md)、[完成度](FINAL-ACCEPTANCE.md)；不把未实现的协同或差量存储列作功能。 |
| 4. README 含目标、安装、使用与示例，可复现 | [README](../README.md) 覆盖网页体验、`moon add`、源码 workspace 和测试命令；[Mooncakes 使用说明](MOONCAKES.md) 含可执行 main；安装方式由公开注册表消费测试实际执行。 |
| 5. CI 覆盖检查、构建、测试 | [主 CI](../.github/workflows/ci.yml)：格式、moon check、接口一致性、JS/Wasm GC 测试、JS 构建、Node/浏览器测试、源码包审查、覆盖率与发布打包。另有 [注册表 CI](../.github/workflows/registry.yml)：Linux/Windows 从 Mooncakes 安装后构建、测试并运行示例。 |
| 6. 至少一个可运行样例 | [简洁 MoonBit 示例](../examples/typed/main.mbt)、[独立文档模块](../examples/consumer/)、[在线三个应用](https://yeehh2004.github.io/moonundo/) 和 CLI 示例。 |
| 7. 完整测试覆盖核心路径 | 60 项 MoonBit 测试/每个后端；独立消费项目另 3 项（workspace 总计 63）；31 项 Node 测试、4,000 次模型对照、浏览器完整流程及五组实际数据工作负载。MoonBit 核心包插桩结果 382/384 个检测点，报告由 CI 保存。 |
| 8. 发布到 mooncakes.io | 已发布 [YeeHh2004/moonundo@0.2.2](https://mooncakes.io/docs/YeeHh2004/moonundo)。`node scripts/check-consumer.mjs --registry` 不创建本地 workspace，使用 `moon add` 下载安装并核对版本及核心源码，在两个后端测试运行。 |
| 9. OSI 认可许可，保留上游要求 | 原创源码使用 [Apache-2.0](../LICENSE)，该许可在 [OSI 列表](https://opensource.org/license/apache-2.0)。[NOTICE](../NOTICE.md) 说明来源与 AI 辅助开发；完整上游 [LICENSE](../licenses/MoonBit-core-LICENSE) / [NOTICE](../licenses/MoonBit-core-NOTICE) 随源码包和编译分发物提供。 |

## 语言职责

这是 MoonBit 状态历史库；浏览器页面和 Node CLI 是宿主。泛型 `History[T]` 不依赖 Node、浏览器、第三方 JS 库或 HTTP 服务。仓库的 JavaScript 文件还包括工程脚本与 Node/浏览器测试，因此 GitHub 的按字节语言统计不能单独代表核心实现语言。实际分发边界由 [.moonignore](../.moonignore) 声明，[打包检查](../scripts/check-mooncake.py) 会拒绝混入 JS/Python 实现、构建缓存或凭据的 Mooncakes 包。

## 复现

```sh
moon version --all
node scripts/verify.mjs
node scripts/check-consumer.mjs --registry
python scripts/check-mooncake.py
moon coverage analyze -- -f summary -p YeeHh2004/moonundo
```

浏览器检查需按开发指南安装固定 Playwright 后运行 `node scripts/verify.mjs --browser`；核心库的 MoonBit 检查无需浏览器。完整命令与固定工具链见 [DEVELOPMENT.md](DEVELOPMENT.md)。

覆盖率是 MoonBit 插桩检测点计数，非所有分支百分比，且不合并 Node/浏览器的覆盖。未命中检测点位于元数据预检后的防御性解码异常分支；完整原始报告在 Actions 的 `moonbit-core-coverage` 产物中。测试与报告是可复核证据，具体赛事结论由审核方作出。
