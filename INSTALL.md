# UI Pretrain Manager 安装指南

## 系统要求

- **操作系统**: macOS 10.14 (Mojave) 或更高版本
- **依赖软件**: 
  - ADB (Android Debug Bridge) - 用于连接 Android 设备
  - scrcpy (可选) - 用于屏幕镜像功能

---

## 安装步骤

### 1. 解压安装包

双击 `UI_Pretrain_Manager.zip` 文件进行解压，得到 `UI Pretrain Manager.app`

### 2. 移动到应用程序文件夹

将 `UI Pretrain Manager.app` 拖动到 `/Applications` 文件夹

### 3. 移除安全限制（首次安装必须）

由于应用没有 Apple 开发者签名，macOS 会阻止运行。请打开 **终端** 执行以下命令：

```bash
xattr -cr /Applications/UI\ Pretrain\ Manager.app
```

> ⚠️ **注意**: 这一步必须执行，否则应用无法正常启动

### 4. 启动应用

双击 `/Applications/UI Pretrain Manager.app` 即可启动

---

## 安装依赖软件

### 安装 Homebrew（如未安装）

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 安装 ADB

```bash
brew install android-platform-tools
```

验证安装：
```bash
adb version
```

### 安装 scrcpy（可选）

```bash
brew install scrcpy
```

---

## 连接 Android 设备

### USB 连接

1. 在 Android 设备上启用 **开发者选项** 和 **USB 调试**
2. 使用 USB 数据线连接设备到 Mac
3. 在设备上允许 USB 调试授权
4. 启动应用，设备将自动显示在已连接设备列表中

### 无线连接

1. 确保 Mac 和 Android 设备在同一 WiFi 网络
2. 先通过 USB 连接设备
3. 在应用中点击设备旁的无线连接按钮
4. 断开 USB 后，设备将保持无线连接

---

## 常见问题

### Q: 双击应用提示"无法打开，因为无法验证开发者"

**A**: 请确保已执行步骤 3 中的命令移除安全限制：
```bash
xattr -cr /Applications/UI\ Pretrain\ Manager.app
```

### Q: 应用启动后看不到设备

**A**: 
1. 检查 ADB 是否正确安装：`adb devices`
2. 确保设备已开启 USB 调试
3. 检查 USB 线是否支持数据传输

### Q: 执行自动化任务时提示项目路径不存在

**A**: 
1. 点击应用列表标题栏的文件夹图标
2. 输入正确的自动化项目路径（包含 `main.py` 的目录）

---

## 卸载

1. 退出应用
2. 将 `/Applications/UI Pretrain Manager.app` 移动到废纸篓
3. 清理配置文件（可选）：
```bash
rm -rf ~/Library/Preferences/com.pizi.scrcpygui.plist
rm -rf ~/Library/Application\ Support/scrcpygui
```

---

## 技术支持

如遇问题，请检查：
1. 是否已正确安装 ADB
2. Android 设备是否开启 USB 调试
3. 是否已执行安全限制移除命令

---

**版本**: 0.1  
**更新日期**: 2024年12月

