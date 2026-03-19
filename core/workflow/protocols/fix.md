# Fix Protocol

## 进入条件

- 用户明确提出缺陷或回归问题

## 问答规则

- 默认轻量修复
- 只有根因不明、多模块连锁或高风险兼容性时才升级

## 完成判定

- 根因已明确
- 修复已落地
- 最相关验证通过
- 修复记录已落盘

## 落盘文件

- `.claude/cx/修复/<问题标题>/修复记录.md`

## 状态迁移

- 独立 fix 不强行绑定无关 feature
- 如果 fix 归属活跃 feature，则必须遵守该 feature 的 lease / handoff 规则

## 下一步路由

- 快修完成：结束
- 需要继续交付：返回 feature 对应的 `cx-exec` 或 `cx-summary`
