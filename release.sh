#!/bin/bash

# 该脚本用于在 GitHub 上为 Swift 包创建新的 release.
#
# 脚本会执行以下操作:
# 1. 检查 git 状态是否干净 (没有未提交或未推送的更改).
# 2. 基于最新的 git 标签确定下一个补丁版本号.
#    - 如果没有标签，则从 0.0.1 开始.
#    - 递增补丁版本号 (例如, 1.0.0 -> 1.0.1).
# 3. 创建一个新的 git 标签并将其推送到远程仓库.
# 4. 使用 'gh' 命令行工具创建一个对应的 GitHub release.

set -e # 如果命令失败，立即退出.

# --- 加载 .env 文件 ---
if [ -f .env ]; then
  echo "检测到 .env 文件，正在加载环境变量..."
  export $(grep -v '^#' .env | xargs)
fi


# --- 环境检查 ---
# 确保 git 和 gh 已安装.
if ! command -v git &> /dev/null; then
    echo "错误：未安装 git。请安装后再继续。" >&2
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "错误：未安装 GitHub CLI (gh)。请安装它以创建 GitHub releases。" >&2
    echo "安装说明: https://cli.github.com/" >&2
    exit 1
fi

# 检查工作目录是否干净
if ! git diff-index --quiet HEAD --; then
    echo "错误：您有未提交的更改。请先提交或暂存这些更改。" >&2
    exit 1
fi

# 检查是否有未推送的提交
# 比较本地 HEAD 与其上游分支.
if [ -n "$(git log @{u}..)" ]; then
    echo "错误：您的本地分支领先于远程分支。请先推送您的更改。" >&2
    exit 1
fi

echo "Git 状态干净，准备发布..."

# --- 版本计算 ---
# 从远程获取所有标签，以确保我们有最新的信息.
git fetch --tags origin

# 基于语义化版本排序获取最新的标签.
# 如果没有标签, `LATEST_TAG` 将为空.
LATEST_TAG=$(git tag -l | sort -V | tail -n 1)

if [ -z "$LATEST_TAG" ]; then
    # 未找到标签，从 0.0.1 开始
    NEW_TAG="0.0.1"
    echo "未找到任何标签。从版本 $NEW_TAG 开始。"
else
    # 解析最新标签并递增补丁版本.
    IFS='.' read -r MAJOR MINOR PATCH <<< "$LATEST_TAG"
    NEW_PATCH=$((PATCH + 1))
    NEW_TAG="$MAJOR.$MINOR.$NEW_PATCH"
    echo "最新标签是 $LATEST_TAG。正在创建新版本 $NEW_TAG。"
fi

# --- 创建 Release ---
echo "正在创建 git 标签..."
git tag "$NEW_TAG"

echo "正在推送标签到远程仓库..."
git push origin "$NEW_TAG"

echo "正在创建 GitHub release..."
# 备注说明了二进制文件的 URL 没有改变，正如所要求的那样.
gh release create "$NEW_TAG" \
    --title "Version $NEW_TAG" \
    --notes "用于测试 Package.swift 配置的新版本。根据测试要求，Package.swift 中的二进制文件校验和与 URL 保持不变。"

echo ""
echo "✅ 成功在 GitHub 上创建了 release $NEW_TAG。"
echo "您现在可以在 Xcode 中添加此包依赖了。"
