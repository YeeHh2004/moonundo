# 独立 MoonBit 文档编辑示例

这是拥有自己 `moon.mod` 的消费端模块，不是主库的内部包。它仅导入公开 `@undo` 接口，示范嵌套 `Document → Section → Array[String]` 的深复制、分组事务、版本化 codec、保存点与重做历史的恢复。

从仓库根目录运行：

```sh
node scripts/check-consumer.mjs
```

需要项目固定的 MoonBit compiler/core。脚本把本目录复制到系统临时目录，建立引用主库的 workspace，在 JavaScript 和 Wasm GC 上执行三项完整流程测试并运行示例，完成后清理自己创建的临时目录。无需 Mooncakes 已发布包，也不会写入你的项目目录。

阅读 [workflow.mbt](workflow.mbt) 看接入代码，[workflow_wbtest.mbt](workflow_wbtest.mbt) 看行为断言：

1. 在外层事务编辑文章，内层预览后取消；提交只产生一步历史。修改外部数组不会污染快照。导出并重新打开后，保存点、redo 和嵌套数组隔离仍然成立。
2. 历史中的旧数据版本或错误字段由应用 codec 拒绝；包括非当前快照，不能只检查屏幕上显示的状态。恢复失败时继续保留原编辑器。
3. 撤销后保存会话，再恢复并编辑，原来的未来分支被丢弃且修订编号不复用；裁剪掉旧保存点后仍正确报告未保存状态。

接入自己的项目时，将本目录复制为 workspace 中与库并列的模块，按 README 的 `moon.work` 示例配置路径，再替换 Document、复制函数和 codec。这里的 `unwrap` 用于预先确定合法的演示动作；生产宿主应处理 Result，且只在实际写入成功后标记保存点。示例用内存 JSON 模拟存档传递，不声称已经写入磁盘。
