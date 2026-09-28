# 可复现验收路径

## 交付范围

| 验收目标 | 证据 |
| --- | --- |
| 可独立复用的 MoonBit 库 | History[T]、pkg.generated.mbti、examples/typed、scripts/check-consumer.mjs |
| 原子修改与取消 | transaction_test.mbt；表单批量提交/取消 |
| 可控撤销/重做和分支 | history_test.mbt、timeline_test.mbt；三种应用时间线 |
| 保存点不被合并/裁剪误判 | savepoint_test.mbt、grouping_test.mbt |
| 会话往返及坏数据拒绝 | session_test.mbt、replay_test.mbt、tests/model.test.mjs |
| 可直接体验 | web/、CLI、examples/task-session.json |
| 泛型隔离 | 数值/数组用例、自定义 Document 结构体、单独模块导入测试 |
| 测试覆盖多运行环境 | CI Linux/Windows、Node 20/22、JS/Wasm GC；浏览器 Chromium |

本地基线：48 项 MoonBit 测试分别在 JS 与 Wasm GC 通过；独立 workspace 消费模块另增加 1 项；16 项 Node 测试通过，含 4,000 个生成操作的独立栈模型对照。浏览器脚本覆盖三场景、持久化、坏文件拒绝、移动端宽度以及运行时错误监听。具体远程执行状态以 [Actions](https://github.com/YeeHh2004/moonundo/actions) 为准。

## 3 分钟操作路线

1. 设置表单：开始批量修改，改名称、主题，取消；原值回来且不新增历史。再批量修改并提交，一次撤销同时恢复两个字段。
2. 保存状态：提交后保存到本机；撤销显示未保存，重做回到保存点显示一致。刷新页面，再恢复本机存档，历史仍可导航。
3. 任务清单：添加任务，删除，再撤销。选择全部完成，再撤销，整组复原。撤销后添加不同任务，旧重做分支消失。
4. 画布：拖动图形并松开，时间线仅增加一步；撤销位置复原，重做再次移动。选中图形切换颜色或删除，分别验证恢复。
5. 导出/导入：导出当前示例 JSON，修改状态，再导入，恢复完整历史。导入损坏 JSON 或不同示例文件必须报错并保留原状态。
6. 命令行：运行 `node cli/moonundo.mjs examples/task-session.json`，应得到两个任务、`undo_depth: 1`、`dirty: false`。

## 开发记录

提交按实际功能形成：基础快照 → 时间线容量 → 嵌套事务 → 保存点 → 分组合并 → 会话存储 → JSON/ESM → 三种业务 reducer → CLI → 浏览器应用 → 独立模型与边界测试 → 跨平台 CI → 独立模块消费检查。不存在空提交或把同一修改倒拆成多次提交的操作。可用 `git log --reverse --stat` 核查每一步。

当前交付是 0.1.0 单用户快照历史库；大文档增量存储、协同撤销、外部副作用回滚、Mooncakes 注册发布不在已完成范围内。质量证据不等于赛事初审/验收或奖金承诺。
