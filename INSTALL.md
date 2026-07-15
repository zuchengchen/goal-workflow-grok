# 安装、更新与迁移

本文是 `goal-workflow` 唯一的详细安装说明。README 只提供快速入口；安装路径、验证、项目级安装、迁移和排错以本文为准。

## 安装标识

| 项目 | 值 |
| --- | --- |
| 仓库 | `https://github.com/zuchengchen/goal-workflow-grok` |
| Grok 安装话术 | `安装 skill https://github.com/zuchengchen/goal-workflow-grok` |
| Grok 更新话术 | `更新 skill https://github.com/zuchengchen/goal-workflow-grok` |
| skill 名称 | `goal-workflow` |
| 仓库内 skill 路径 | `skills/goal-workflow` |
| 默认安装目标 | `${GROK_HOME:-$HOME/.grok}/skills/goal-workflow` |
| 安装脚本 | `scripts/install-from-github.sh`、`scripts/install-local.sh` |

推荐只使用**仓库根 URL**。不要要求用户先打开 `tree/master/skills/...` 子路径。

## 推荐方式：在 Grok 里一句话安装 / 更新

### 用户输入

安装：

```text
安装 skill https://github.com/zuchengchen/goal-workflow-grok
```

更新：

```text
更新 skill https://github.com/zuchengchen/goal-workflow-grok
```

同义说法同样有效，例如：`安装skill`、`帮我安装这个 skill`、`更新一下 skill` + 同一仓库 URL。

### Agent 执行规范（给 Grok）

收到上述请求时，**直接执行**，不要再向用户索要复杂手动步骤：

1. 确认本机有 `git` 与 `python3`。
2. 解析 URL：允许仓库根、`.git` 后缀，或带 `/tree/<ref>/...` 的 GitHub 路径；统一得到仓库根与 ref（默认 `master`）。
3. 目标目录默认为 `${GROK_HOME:-$HOME/.grok}/skills/goal-workflow`。若用户明确要求项目级安装，则改为 `<project>/.grok/skills/goal-workflow`。
4. 运行官方脚本：
   - **安装**：`scripts/install-from-github.sh install <REPO_URL>`
   - **更新**：`scripts/install-from-github.sh update <REPO_URL>`
5. 验证 `DEST/SKILL.md` 存在，且 frontmatter 含 `name: goal-workflow`。
6. 用一两句话告诉用户：已安装/已更新路径，以及用法 `/goal-workflow <任务>`。

最小可复制命令（从任意工作目录）：

```bash
# 安装
tmp="$(mktemp -d)"
git clone --depth 1 https://github.com/zuchengchen/goal-workflow-grok.git "$tmp/s"
"$tmp/s/scripts/install-from-github.sh" install https://github.com/zuchengchen/goal-workflow-grok
rm -rf -- "$tmp"

# 更新
tmp="$(mktemp -d)"
git clone --depth 1 https://github.com/zuchengchen/goal-workflow-grok.git "$tmp/s"
"$tmp/s/scripts/install-from-github.sh" update https://github.com/zuchengchen/goal-workflow-grok
rm -rf -- "$tmp"
```

说明：`install-from-github.sh` 会再次 shallow clone 指定 ref，并调用 `install-local.sh` 只复制 `skills/goal-workflow/`（不会把整个仓库塞进 skills 目录）。**更新**使用 `--replace` 事务式替换旧版本，成功后不保留备份目录。

若目标已存在却执行了**安装**，脚本会失败；此时应改走**更新**，或先询问用户。

## 前置条件

- 支持 Agent Skills 的 Grok。
- 从 GitHub 安装/更新需要 `git`；安装脚本校验需要 `python3`。
- skill 自包含，不依赖 `$define-goal`、`$brainstorming` 或 npm/pip 包。

Grok 发现技能的位置（优先级从高到低）：

- 当前目录 / 仓库：`.grok/skills/`
- 用户目录：`${GROK_HOME:-$HOME/.grok}/skills/`

兼容路径 `.agents/skills/` 也可被发现，但新安装优先 `.grok/skills/`。

## 验证安装

```bash
dest="${GROK_HOME:-$HOME/.grok}/skills/goal-workflow"
test -f "$dest/SKILL.md"
grep -q '^name: goal-workflow$' "$dest/SKILL.md"
```

然后在 Grok 中：

```text
/goal-workflow 把这个任务整理成可执行 Goal
```

或运行 `grok inspect` 确认列表中有 `goal-workflow`。技能文件变更后通常数秒内热重载；若未出现，新开一轮会话。

## 项目级安装

只在某个仓库启用、或团队共享 skill 时使用：

```bash
tmp="$(mktemp -d)"
git clone --depth 1 https://github.com/zuchengchen/goal-workflow-grok.git "$tmp/s"
"$tmp/s/scripts/install-from-github.sh" install https://github.com/zuchengchen/goal-workflow-grok \
  --dest "/path/to/target-project/.grok/skills/goal-workflow"
rm -rf -- "$tmp"
```

更新时把 `install` 换成 `update`，并保留同一 `--dest`。

不要把整个 `goal-workflow-grok` 仓库 clone 成 `.grok/skills/goal-workflow`；安装目录应只含 `SKILL.md`。

## 本地开发安装

若当前目录已是本仓库 checkout：

```bash
# 安装到用户 skills
scripts/install-local.sh

# 更新（直接替换，不备份）
scripts/install-local.sh --replace

# 安装到指定项目
scripts/install-local.sh --dest "/path/to/target-project/.grok/skills/goal-workflow"
```

等价 GitHub 入口（使用默认仓库 URL）：

```bash
scripts/install-from-github.sh install
scripts/install-from-github.sh update
```

## 固定版本

默认跟随 `master`。固定 tag 或 commit：

```bash
scripts/install-from-github.sh install https://github.com/zuchengchen/goal-workflow-grok --ref v0.3.0
# 或把 ref 写进 GitHub tree URL：
scripts/install-from-github.sh update \
  https://github.com/zuchengchen/goal-workflow-grok/tree/v0.3.0/skills/goal-workflow
```

当前 source 版本为 `0.3.0`。tag 未发布前请使用完整 commit SHA 作为 `--ref`。

## 同名冲突与替换

- **安装**：目标已存在则停止，避免静默覆盖。
- **更新**：事务式替换；成功后删除旧安装，不保留备份目录。

检查已安装内容：

```bash
dest="${GROK_HOME:-$HOME/.grok}/skills/goal-workflow"
find "$dest" -maxdepth 2 -type f -print
```

用户级与项目级同名 skill 同时存在时，优先只保留一个来源，避免随 cwd 切换版本漂移。

## 从 Codex / 旧路径迁移

0.3.0 起面向 Grok：默认 `${GROK_HOME:-$HOME/.grok}/skills/goal-workflow`，goal 文件默认直接保存在当前工作目录（`<cwd>/<YYYY-MM-DD>-<slug>.md`），触发 `/goal-workflow`。

常见旧路径：

```text
${CODEX_HOME:-$HOME/.codex}/skills/goal-workflow
$HOME/.agents/skills/goal-workflow
<project>/.agents/skills/goal-workflow
```

建议：备份旧目录后，在 Grok 中执行：

```text
安装 skill https://github.com/zuchengchen/goal-workflow-grok
```

若新路径已有旧版，则用：

```text
更新 skill https://github.com/zuchengchen/goal-workflow-grok
```

Goal 文件不会自动迁移。需要时手动把旧路径（如 `.codex/goals/`、`.grok/goals/`）下的文件移到当前工作目录：

```bash
# mv 或 git mv 旧文件到当前工作目录，例如：
# mv .grok/goals/2026-07-15-example.md ./
```

个人 goal 通常在 `.gitignore` 中忽略根目录日期前缀文件，例如 `/????-??-??-*.md`。

## 卸载

```bash
# 有 source checkout 时
scripts/uninstall-local.sh --dry-run
scripts/uninstall-local.sh

# 或指定路径
scripts/uninstall-local.sh --dest "${GROK_HOME:-$HOME/.grok}/skills/goal-workflow"
```

手工卸载（确认身份后）：

```bash
dest="${GROK_HOME:-$HOME/.grok}/skills/goal-workflow"
test -f "$dest/SKILL.md"
grep -q '^name: goal-workflow$' "$dest/SKILL.md"
rm -rf -- "$dest"
```

## 排错

### Grok 没有自动安装

确认用户话术包含仓库 URL，并由 agent 实际执行 shell（不要只打印命令）。可直接粘贴「Agent 执行规范」中的最小命令块。

### 安装失败：destination already exists

目标已安装。改为：

```text
更新 skill https://github.com/zuchengchen/goal-workflow-grok
```

### `/goal-workflow` 没有出现

确认 `$dest/SKILL.md` 存在，等待热重载或新开会话；`grok inspect` 查看 skill 列表。项目级安装需从该项目目录启动 Grok。

### `/goal` 不可用

Goal 功能需启用，且会话工具集包含 `update_goal`。与 skill 是否安装成功无关。

### 更新后仍是旧行为

检查是否存在多份安装（用户级、项目级、`.agents/skills`、旧 Codex 路径）。只保留一份后重启会话。

### 是否需要 `$define-goal`

不需要。本 skill 自包含质量标准与完整工作流。
