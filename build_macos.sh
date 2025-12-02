#!/bin/bash

# UI Pretrain Manager - macOS 打包脚本
# 使用方法: ./build_macos.sh

set -e

echo "=========================================="
echo "  UI Pretrain Manager - macOS 打包脚本"
echo "=========================================="
echo ""

# 检查 fvm 是否安装
if ! command -v fvm &> /dev/null; then
    echo "❌ 错误: fvm 未安装"
    echo "请先安装 fvm: https://fvm.app/documentation/getting-started/installation"
    exit 1
fi

# 进入项目目录
cd "$(dirname "$0")"
PROJECT_DIR=$(pwd)
echo "📁 项目目录: $PROJECT_DIR"
echo ""

# 清理旧的构建文件
echo "🧹 清理旧的构建文件..."
fvm flutter clean
echo ""

# 获取依赖
echo "📦 获取依赖..."
fvm flutter pub get
echo ""

# 构建 macOS Release 版本
echo "🔨 构建 macOS Release 版本..."
fvm flutter build macos --release
echo ""

# 设置输出目录
RELEASE_DIR="$PROJECT_DIR/build/macos/Build/Products/Release"
APP_NAME="UI Pretrain Manager"
ZIP_NAME="UI_Pretrain_Manager.zip"

# 检查构建是否成功
if [ ! -d "$RELEASE_DIR/$APP_NAME.app" ]; then
    echo "❌ 构建失败: 未找到应用文件"
    exit 1
fi

# 创建 ZIP 压缩包
echo "📦 创建 ZIP 压缩包..."
cd "$RELEASE_DIR"
rm -f "$ZIP_NAME"
zip -r "$ZIP_NAME" "$APP_NAME.app"
echo ""

# 显示结果
echo "=========================================="
echo "  ✅ 打包完成!"
echo "=========================================="
echo ""
echo "📍 输出文件位置:"
echo "   .app: $RELEASE_DIR/$APP_NAME.app"
echo "   .zip: $RELEASE_DIR/$ZIP_NAME"
echo ""
echo "📊 文件大小:"
ls -lh "$RELEASE_DIR/$ZIP_NAME" | awk '{print "   " $5 " - " $9}'
echo ""
echo "🚀 下一步: 将 $ZIP_NAME 发送给其他用户"
echo "   参考安装文档: INSTALL.md"
echo ""

