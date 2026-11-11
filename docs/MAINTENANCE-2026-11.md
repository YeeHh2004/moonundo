# 2026 年 11 月工具链维护

源码版本：**0.2.3**。维护日期：**2026-11-11**。本次针对当前官方工具链修复编译兼容问题，保留原有历史行为、公开方法和 v1 会话格式。

## 问题与修复

[issue #1](https://github.com/YeeHh2004/moonundo/issues/1) 报告 `moonc 0.10.20+65efd5b93` / macOS ARM64 下 `editor.mbt:43` 的 `Int.to_json` 无法解析。使用官方当前编译器和配套 core，本地运行旧源码的 `moon check --target js --deny-warn` 同样失败：该位置与 `replay.mbt` 两处转换报 4015；八处旧 `derive(...)` 语法产生弃用警告，在严格模式下报错。

修复把主库、测试、typed/reducers 示例和独立 consumer 的 JSON 转换统一为显式 `@json.to_json` / `@json.ToJson`，typed 包显式导入 JSON，派生实现使用 `#derive(...)`。当前 formatter 规范化了 `Int32` 类型名及带默认值的参数写法，公开接口由当前 `moon info` 重新生成；`RevisionInfo::to_json` 仍保留。没有新增历史算法或会话字段。

构建脚本不再仅因编译器版本不同而拒绝编译。它通过真实编译检查兼容性，在 `web/build-info.json` 记录完整编译器版本、`moon version --all` 输出、core 版本、源码提交、dirty 标记、引擎及许可哈希。分发的 core LICENSE/NOTICE 来自活动安装目录；仓库中的许可副本同步到本次基线，完整 NOTICE 的 LF SHA-256 为 `a20a618afc132a32e340f567fc2fb4296cfbefda7284422b6085afcd394e478d`。

## 实际本地验证

官方二进制来自 [latest 下载入口](https://cli.moonbitlang.com/binaries/latest/moonbit-windows-x86_64.zip)，下载时通过配套 `.sha256` 校验；core 来自[官方 core 下载入口](https://cli.moonbitlang.com/cores/core-latest.zip)。验证环境为 Windows x64 / Node.js 24.22.1：

```text
moonc v0.10.20+65efd5b93 (2026-11-05)
moon 0.1.20261104 (940aa18 2026-11-04)
moonrun 0.1.20261104 (940aa18 2026-11-04)
moonbitlang/core 0.10.20+65efd5b93
```

| 验证项 | 结果 |
| --- | --- |
| `moon fmt --check`、`moon info` | 通过，公共接口已更新 |
| JS / Wasm GC `check`、`build`、`test --deny-warn` | 两个后端均通过，各 60/60 项测试 |
| `examples/typed` | 两个后端均成功运行 |
| 独立 workspace consumer | 两个后端均严格检查、构建、运行，含消费端共 63/63 项测试 |
| 重新编译后的 Node 测试 | 31/31 通过，含 4,000 次生成状态转换的独立模型对照 |
| 现有 Chromium 浏览器验收 | 通过：三个应用、保存/恢复、导入/导出、长事务、分组合并、存储失败、移动布局和运行时错误检查 |
| Mooncakes 源码包检查 | 通过，0.2.3 ZIP 含 35 个文件，无宿主 JS、缓存或凭据 |
| 五组实际任务/嵌套文档工作负载 | 全部校验通过，两种响应模式的最终状态和存档一致 |
| 覆盖率工具入口 | summary 和 Cobertura 报告生成成功；本地核心插桩点 380/382 |

可复现主要验证：

```sh
moon version --all
moon info
node scripts/verify.mjs
node tests/browser.mjs
python scripts/check-mooncake.py
node scripts/benchmark-workloads.mjs --output dist/benchmark-workloads.json
moon coverage analyze -- -f summary -p YeeHh2004/moonundo
moon coverage report -f cobertura -p YeeHh2004/moonundo -o _build/core-coverage.xml
```

浏览器测试工具的安装或复用方式见[开发说明](DEVELOPMENT.md)。历史性能报告保留其 2026-09-30 日期、旧编译器和原始测量，不把不同环境的耗时混为一轮数据。

## 持续维护与发布边界

[主 CI](../.github/workflows/ci.yml) 固定本次已验证完整版本，覆盖 Linux Node 20/22、Windows Node 22、macOS ARM64 Node 22，并输出实际平台/架构。macOS 项用于直接覆盖报告环境；本地 Windows 验证不代替该平台的 Actions 结果。[每周兼容检查](../.github/workflows/compatibility.yml) 单独使用官方 latest/compiler 和 latest/core，检查两个声明后端、Node 宿主、typed 示例与独立 consumer，不部署网页或发布文件。

本地通过不等于 GitHub Actions 或注册表发布已完成。发布后应针对同一提交检查 CI、公开 `build-info.json` 和 `node scripts/check-consumer.mjs --registry`；注册表模式会核对公开安装版本及核心源码，再测试运行两个后端。发布产物和注册表状态以实际公开记录为准。
