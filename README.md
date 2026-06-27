# cj-memo

一个用**仓颉语言**写的待办 + 积分 + 抽奖系统后端服务。

## 功能特性

- 用户注册 / 登录（JWT + SHA-256 密码哈希）
- 事件（待办）CRUD，按优先级 / 标签 / 截止时间管理
- 完成事件自动 +10 积分；累计积分自动升级（6 级）
- 每日免费抽奖 + 积分抽奖（10 连 9.3 折）
- 积分商城 + 实物奖品库存管理
- 每日提醒（一次性，按截止时间前 N 分钟）

## 技术栈

| 类别 | 选型 |
|------|------|
| 语言 | 仓颉 (Cangjie) 1.1.3 |
| HTTP | `stdx.net.http` |
| 存储 | JSON 文件 + `std.sync.Mutex` |
| 哈希 | `stdx.crypto.digest.SHA256` |
| 测试 | `std.unittest` |

## 项目结构

```
cj-memo/
├── src/                     # 业务代码
│   ├── auth_service.cj      # 鉴权
│   ├── event_service.cj     # 事件业务
│   ├── reward_service.cj    # 积分 / 商城
│   ├── lottery.cj           # 抽奖
│   ├── level.cj             # 等级规则
│   ├── hasher.cj            # SHA-256 哈希
│   ├── time_util.cj         # 时间工具
│   ├── *_test.cj            # 单元测试
│   └── main.cj              # 入口
├── scripts/                 # 工具脚本
│   ├── ci_local.ps1         # 本地模拟流水线
│   └── ci_local.sh          # Linux / Git Bash 版
├── .gitee/
│   └── pipeline.yml         # Gitee Go CI/CD 配置
├── cjpm.toml
└── README.md
```

## 本地运行

```bash
# 编译
cjpm build

# 跑测试
cjpm test

# 启动服务（默认 :8888）
cjpm run
```

## 单元测试

当前覆盖 **19 个测试用例**，分布在 6 个测试文件中：

| 测试文件 | 测试类 | 用例数 | 范围 |
|---------|--------|------|------|
| `level_test.cj` | `LevelRuleTest` | 4 | 等级阈值、等级名称、满级 |
| `enums_test.cj` | `EventStatusTest` / `EventPriorityTest` / `PointReasonTest` | 8 | 枚举 ↔ Int / String |
| `time_util_test.cj` | `TimeUtilTest` | 3 | unix ms 时钟合理范围 |
| `lottery_test.cj` | `PrizeRepositoryTest` | 4 | 加权抽卡分布 + 蒙特卡洛验证 |
| `enums_test.cj` | `PointReasonTest` | (已含) | 积分流水原因枚举 |

跑测：

```bash
cjpm test
# 末尾应出现：
# PASSED: 19, SKIPPED: 0, ERROR: 0
# FAILED: 0
# cjpm test success
```

## CI/CD（Gitee Go）

每次 push 到 master 分支或提交 PR，`.gitee/pipeline.yml` 自动执行：

1. 检出代码
2. 校验仓颉 SDK 已就绪
3. `cjpm build` 编译
4. `cjpm test` 跑全部单元测试
5. 验证 SHA-256 标准向量（独立 stage）

查看流水线状态：在仓库页面点击 **"流水线"** Tab。

### 本地模拟 CI（可选）

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File scripts\ci_local.ps1

# Linux / Git Bash
bash scripts/ci_local.sh
```

输出 `ci_run.log` 包含每一步的完整日志，预期：

```
[OK] cjc detected
[OK] build
[OK] 19 / 19 test cases passed
[OK] SHA-256 vectors all matched
[SUMMARY] all green
```