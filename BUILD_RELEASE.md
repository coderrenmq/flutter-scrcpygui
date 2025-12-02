# UI Pretrain Manager - 构建与发布指南

本文档介绍如何构建、打包和发布 UI Pretrain Manager 应用。

---

## 🏗️ 1. 本地构建

### 1.1 环境准备

```bash
# 确保 Flutter 版本正确
fvm flutter --version

# 获取依赖
fvm flutter pub get
```

### 1.2 构建各平台版本

#### macOS

```bash
# Release 构建
fvm flutter build macos --release

# 输出位置
# build/macos/Build/Products/Release/UI Pretrain Manager.app
```

#### Windows

```bash
fvm flutter build windows --release

# 输出位置
# build/windows/x64/runner/Release/
```

#### Linux

```bash
fvm flutter build linux --release

# 输出位置
# build/linux/x64/release/bundle/
```

### 1.3 使用打包脚本 (macOS)

```bash
# 执行一键打包
./build_macos.sh

# 输出：
# - build/macos/Build/Products/Release/UI Pretrain Manager.app
# - build/macos/Build/Products/Release/UI_Pretrain_Manager.zip
```

---

## 📦 2. 打包发布文件

### 2.1 macOS 打包

```bash
# 进入构建目录
cd build/macos/Build/Products/Release

# 压缩 .app 文件
zip -r -y UI_Pretrain_Manager_macOS_arm64.zip "UI Pretrain Manager.app"

# 或者 x86_64 版本命名
zip -r -y UI_Pretrain_Manager_macOS_x86_64.zip "UI Pretrain Manager.app"
```

### 2.2 Windows 打包

```bash
cd build/windows/x64/runner/Release

# 压缩整个文件夹
zip -r UI_Pretrain_Manager_Windows_x64.zip .
```

### 2.3 Linux 打包

```bash
cd build/linux/x64/release/bundle

# 压缩整个文件夹
tar -czvf UI_Pretrain_Manager_Linux_x86_64.tar.gz .
```

---

## 🚀 3. GitHub Release 发布流程

### 3.1 创建 Git Tag

```bash
# 确保所有更改已提交
git add .
git commit -m "Release v0.1.0"

# 创建标签
git tag v0.1.0

# 推送代码和标签
git push origin main
git push origin v0.1.0
```

### 3.2 在 GitHub 上创建 Release

1. 访问：https://github.com/coderrenmq/flutter-scrcpygui/releases

2. 点击 **"Draft a new release"**

3. 填写信息：
   - **Tag**: 选择 `v0.1.0`
   - **Title**: `v0.1.0 - UI Pretrain Manager`
   - **Description**: 更新说明

4. 上传资源文件：
   ```
   UI_Pretrain_Manager_macOS_arm64.zip
   UI_Pretrain_Manager_macOS_x86_64.zip
   UI_Pretrain_Manager_Windows_x64.zip
   UI_Pretrain_Manager_Linux_x86_64.tar.gz
   ```

5. 点击 **"Publish release"**

### 3.3 Release 文件命名规范

| 平台 | 架构 | 文件名 |
|------|------|--------|
| macOS | arm64 | `UI_Pretrain_Manager_macOS_arm64.zip` |
| macOS | x86_64 | `UI_Pretrain_Manager_macOS_x86_64.zip` |
| Windows | x64 | `UI_Pretrain_Manager_Windows_x64.zip` |
| Linux | x86_64 | `UI_Pretrain_Manager_Linux_x86_64.tar.gz` |

---

## 🔄 4. 版本更新检测

### 4.1 当前配置

应用会从您的仓库检测更新：

```dart
// lib/utils/const.dart
const appLatestUrl =
    'https://api.github.com/repos/coderrenmq/flutter-scrcpygui/releases/latest';
```

### 4.2 API 响应格式

GitHub Release API 返回：

```json
{
  "tag_name": "v0.1.0",
  "name": "v0.1.0 - UI Pretrain Manager",
  "assets": [
    {
      "name": "UI_Pretrain_Manager_macOS_arm64.zip",
      "browser_download_url": "https://github.com/.../releases/download/v0.1.0/..."
    }
  ]
}
```

### 4.3 版本号规范

使用语义化版本号：
- **主版本.次版本.修订版本**
- 例如：`v0.1.0`, `v0.2.0`, `v1.0.0`

---

## 🔧 5. GitHub Actions 自动构建 (可选)

创建 `.github/workflows/build.yml`：

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.1'
          channel: 'stable'
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Build macOS
        run: flutter build macos --release
      
      - name: Package
        run: |
          cd build/macos/Build/Products/Release
          zip -r -y UI_Pretrain_Manager_macOS.zip "UI Pretrain Manager.app"
      
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: macos-build
          path: build/macos/Build/Products/Release/UI_Pretrain_Manager_macOS.zip

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.1'
          channel: 'stable'
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Build Windows
        run: flutter build windows --release
      
      - name: Package
        run: |
          Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath UI_Pretrain_Manager_Windows_x64.zip
      
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: windows-build
          path: UI_Pretrain_Manager_Windows_x64.zip

  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.1'
          channel: 'stable'
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Build Linux
        run: flutter build linux --release
      
      - name: Package
        run: |
          cd build/linux/x64/release/bundle
          tar -czvf ../../../../../UI_Pretrain_Manager_Linux_x86_64.tar.gz .
      
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: linux-build
          path: UI_Pretrain_Manager_Linux_x86_64.tar.gz

  release:
    needs: [build-macos, build-windows, build-linux]
    runs-on: ubuntu-latest
    steps:
      - name: Download all artifacts
        uses: actions/download-artifact@v4
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            macos-build/UI_Pretrain_Manager_macOS.zip
            windows-build/UI_Pretrain_Manager_Windows_x64.zip
            linux-build/UI_Pretrain_Manager_Linux_x86_64.tar.gz
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 📝 6. 发布检查清单

发布前请确认：

- [ ] 更新 `pubspec.yaml` 中的版本号
- [ ] 更新 `lib/widgets/navigation_shell.dart` 中的显示版本
- [ ] 测试所有主要功能
- [ ] 提交所有代码更改
- [ ] 创建 Git tag
- [ ] 构建所有平台版本
- [ ] 上传到 GitHub Release
- [ ] 验证更新检测功能

---

## 🔗 7. 相关链接

- **仓库**: https://github.com/coderrenmq/flutter-scrcpygui
- **Releases**: https://github.com/coderrenmq/flutter-scrcpygui/releases
- **API**: https://api.github.com/repos/coderrenmq/flutter-scrcpygui/releases/latest

---

**版本**: 0.1  
**更新日期**: 2024年12月

