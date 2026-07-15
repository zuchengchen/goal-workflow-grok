# Goal Workflow

`goal-workflow` 是一个自包含的 Grok skill：它通过逐步访谈把粗略任务整理成可执行、可验证的 Goal mode prompt，并在保存和启动前分别取得确认。

```text
/goal-workflow 重构这个项目的认证模块
```

它适合目标模糊、存在多种方案，或需要明确范围、风险、验证、发布与停止条件的任务。skill 自带目标质量检查和方案探索流程，不依赖外部 `$define-goal` 或 `$brainstorming` skill，也没有 npm、pip 等包管理器依赖。

## 安装与更新（推荐）

在 **Grok** 对话中直接输入仓库地址即可，无需先手动 clone：

### 安装

```text
安装 skill https://github.com/zuchengchen/goal-workflow-grok
```

Grok 会 clone 本仓库，把 `skills/goal-workflow/` 安装到：

```text
${GROK_HOME:-$HOME/.grok}/skills/goal-workflow
```

### 更新

```text
更新 skill https://github.com/zuchengchen/goal-workflow-grok
```

Grok 会拉取最新内容，以 `--replace` 方式替换已安装 skill，并保留备份目录。

### Agent 应执行的命令

当用户发出上述自然语言请求时，按模式执行其一（需要 `git`）：

```bash
# 安装
git clone --depth 1 https://github.com/zuchengchen/goal-workflow-grok.git /tmp/goal-workflow-grok-src
/tmp/goal-workflow-grok-src/scripts/install-from-github.sh install https://github.com/zuchengchen/goal-workflow-grok
# 或等价地：
# /tmp/goal-workflow-grok-src/scripts/install-local.sh

# 更新
git clone --depth 1 https://github.com/zuchengchen/goal-workflow-grok.git /tmp/goal-workflow-grok-src
/tmp/goal-workflow-grok-src/scripts/install-from-github.sh update https://github.com/zuchengchen/goal-workflow-grok
```

更稳妥的单行方式（脚本内部会再次 shallow clone，不依赖当前工作目录）：

```bash
# 安装
bash -c 'tmp=$(mktemp -d) && git clone --depth 1 https://github.com/zuchengchen/goal-workflow-grok.git "$tmp/s" && "$tmp/s/scripts/install-from-github.sh" install https://github.com/zuchengchen/goal-workflow-grok; ec=$?; rm -rf "$tmp"; exit $ec'

# 更新
bash -c 'tmp=$(mktemp -d) && git clone --depth 1 https://github.com/zuchengchen/goal-workflow-grok.git "$tmp/s" && "$tmp/s/scripts/install-from-github.sh" update https://github.com/zuchengchen/goal-workflow-grok; ec=$?; rm -rf "$tmp"; exit $ec'
```

安装完成后可用 `/goal-workflow` 或 `grok inspect` 确认。详细路径、项目级安装、迁移与排错见 [INSTALL.md](INSTALL.md)。

当前 source 版本为 `0.3.0`。

## 工作流摘要

- 根据任务复杂度选择适当的访谈深度，一次只问一个问题。
- 在需要时检查项目上下文、比较 2-3 个方案并确认方向。
- 覆盖目标、范围、约束、兼容性、安全、测试、发布、回滚和停止条件。
- 将每项自动验证视为需要校准的判定器，保留生产命令退出码、使用当前运行证据，并防止文本扫描的假阳性和假阴性。
- 起草后先确认是否保存，保存后再确认是否启动 Goal mode。
- 默认将 goal 文件直接保存到当前工作目录：`<cwd>/<YYYY-MM-DD>-<slug>.md`（不使用 `.grok/goals/` 子目录，也不以项目根为准）。
- 启动后通过 `/goal <objective>` 激活；执行阶段用 `update_goal` 报告进度、完成或阻塞。

是否提交这些 goal 文件由项目决定：个人 goal 通常应加入 `.gitignore`（例如根目录的 `/????-??-??-*.md`），团队共享的 goal 可以显式纳入版本控制。

## 要求

- 支持 Agent Skills 的 Grok（技能目录：`~/.grok/skills/` 或项目 `.grok/skills/`）。
- 可用的 Goal mode；`/goal` 仅在 goal 功能已启用且会话工具集包含 `update_goal` 时出现。
- 从 GitHub 安装或更新时需要 Git。

## 仓库布局

```text
goal-workflow-grok/
├── skills/goal-workflow/   # canonical 可安装 skill（仅 SKILL.md）
├── SKILL.md                # 与 canonical 同步的兼容镜像
├── scripts/                # 安装、卸载、烟测和结构验证
├── tests/                  # 行为与结构测试
├── .github/workflows/      # CI 验证
├── docs/history/           # 历史 goal 文档
├── INSTALL.md              # 完整安装与迁移说明
├── CHANGELOG.md
├── VERSION
└── LICENSE
```

新安装只复制 `skills/goal-workflow/`。根目录 `SKILL.md` 是兼容镜像，不是独立安装入口。

发布历史见 [CHANGELOG.md](CHANGELOG.md)。
