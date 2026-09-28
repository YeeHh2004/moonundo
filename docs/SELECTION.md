# 选题与公开生态查重记录

检索日期：2026-09-28。目标是通用 MoonBit 应用状态历史：任意 `T`、独立复制策略、嵌套事务、保存点、显式分组和可恢复会话。表单、任务与画布是接入示例，交付主体为可复用库。

## 为什么选这个方向

可编辑应用经常需要取消一组表单修改、恢复误删项、将连续拖动合为一次撤销，并区分当前状态与保存点。这些需求来自不同产品，而不依赖单一专有格式。三个实际运行的示例复用同一核心；另有独立 MoonBit 模块导入测试，验证它可离开示例页面使用。

通用快照历史是成熟思路。Redux 官方的 [Implementing Undo History](https://redux.js.org/usage/implementing-undo-history) 也将其用于一般应用状态；此处参考问题分类，未移植其代码。MoonBit 的 [Rabbita](https://github.com/moonbit-community/rabbita) 体现了函数式状态更新应用的生态方向，但本项目未声称已完成 Rabbita 适配。

## 检索范围与结果

- [Mooncakes 公开模块目录](https://mooncakes.io/api/v0/modules)：本次获取 2,696 个模块，检索名称、描述、关键字中的 undo / redo / history 等词，未识别到与本项目同定位的独立泛型快照库。
- 目录快照 SHA-256：`41b58797c412846c8f88c6931e691f64d46cc760d319efebc335d73fa4d5cc82`；快照大小 942,763 字节。摘要用于标识本次检索输入，不代表目录以后不会变化。
- GitHub 仓库搜索 `undo language:MoonBit`、`history state language:MoonBit`、`moonundo`；代码搜索 `UndoManager language:MoonBit`、`undo redo language:MoonBit`、`"History[T]" language:MoonBit`、`UndoStack language:MoonBit`。同时查看近邻项目 README 与公开接口。
- 不能只按包名判断无重复；代码检索确实找到了下列相关实现。

| 相关项目 | 已有能力 | 与本项目的边界 |
| --- | --- | --- |
| [Lampese/lomo](https://github.com/Lampese/lomo) | Loro 风格 CRDT 文档及 UndoManager | 撤销接入 LoroDoc/容器；MoonUndo 不要求 CRDT 数据模型，面向普通 `T` 的完整状态 |
| [dowdiness/event-graph-walker](https://github.com/dowdiness/event-graph-walker) | 协同文档、UndoManager/Undoable、补偿操作 | `Undoable` 接口关联操作标识与 delete/undelete；MoonUndo 是单用户快照替换，不实现协同撤销 |
| [zvmsbackend/pretty_prompt](https://github.com/zvmsbackend/pretty_prompt) | 行编辑撤销 | 项目内部文本编辑能力；MoonUndo 可直接接入表单、集合、自定义结构体 |
| [eanzhao-os/pi-moonbit](https://github.com/eanzhao-os/pi-moonbit) | TUI 编辑器 undo stack | 编辑器内部状态栈；MoonUndo 独立封装历史、事务和存档协议 |
| [emadurandal/RhodoniteMBT](https://github.com/emadurandal/RhodoniteMBT) | 场景编辑 undo/redo | 3D/ECS 场景框架内能力；MoonUndo 不依赖场景或渲染器 |

也排除了已有较直接对应包的候选方向，包括重试/限流、feature flags、schema 校验、HTTP cache、脱敏和本地化等。

**结论是有限范围的查重结果：未发现同定位独立库，但存在相关撤销功能。** 不能据此保证未公开报名题目不重复，或保证组委会认可差异。申报时应提交具体接口、三场景演示和本表，而非宣称“生态首个撤销库”。原创实现不等于发明撤销这一概念。
