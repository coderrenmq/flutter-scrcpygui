import 'dart:io';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrcpygui/db/db.dart';
import 'package:scrcpygui/models/adb_devices.dart';
import 'package:scrcpygui/providers/automation_project_provider.dart';
import 'package:scrcpygui/providers/device_info_provider.dart';
import 'package:scrcpygui/providers/terminal_provider.dart';
import 'package:scrcpygui/providers/version_provider.dart';
import 'package:scrcpygui/utils/adb_utils.dart';
import 'package:scrcpygui/utils/command_runner.dart';
import 'package:scrcpygui/widgets/custom_ui/pg_section_card.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class AppListPanel extends ConsumerStatefulWidget {
  final AdbDevices device;

  const AppListPanel({super.key, required this.device});

  @override
  ConsumerState<AppListPanel> createState() => _AppListPanelState();
}

class _AppListPanelState extends ConsumerState<AppListPanel> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _showSystemApps = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshAppList() async {
    setState(() => _isLoading = true);

    try {
      final workDir = ref.read(execDirProvider);
      var deviceInfo = ref
          .read(infoProvider)
          .firstWhere((info) => info.deviceId == widget.device.id);

      final res = await CommandRunner.runScrcpyCommand(
        workDir,
        widget.device,
        args: ['--list-apps'],
      );

      final applist = getAppsList(res.stdout);
      deviceInfo = deviceInfo.copyWith(appList: applist);

      ref.read(infoProvider.notifier).addOrEditDeviceInfo(deviceInfo);
      await Db.saveDeviceInfos(ref.read(infoProvider));
    } catch (e) {
      debugPrint('刷新应用列表失败: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _startAutomation(String appName) async {
    final projectPath = ref.read(automationProjectPathProvider);
    final deviceId = widget.device.id;  // 使用 id 而非 serialNo，确保唯一性
    final terminalState = ref.read(terminalStateProvider)[deviceId];
    
    // 检查是否有任务正在运行
    if (terminalState?.isExecuting == true && terminalState?.runningAppName != null) {
      final runningApp = terminalState!.runningAppName!;
      
      if (runningApp == appName) {
        // 点击的是同一个 app，不做任何操作
        return;
      }
      
      // 弹出确认对话框
      final confirmed = await _showSwitchConfirmDialog(runningApp, appName);
      if (confirmed != true) {
        return;
      }
      
      // 停止当前任务
      ref.read(terminalStateProvider.notifier).interruptCommand(deviceId);
      
      // 等待一下让进程停止
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    if (projectPath == null || projectPath.isEmpty) {
      // 弹出输入框让用户输入项目路径
      await _showProjectPathDialog();
      return;
    }

    // 验证路径
    if (!AutomationProjectPathNotifier.validatePath(projectPath)) {
      await _showErrorDialog('项目路径不存在', '路径 "$projectPath" 不存在，请重新设置。');
      await _showProjectPathDialog();
      return;
    }

    // 执行自动化命令
    _executeAutomationCommand(projectPath, appName);
  }

  Future<bool?> _showSwitchConfirmDialog(String runningApp, String newApp) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('切换任务确认'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text('当前 "$runningApp" 正在运行'),
              Text('是否取消运行，并开始运行 "$newApp"？'),
            ],
          ),
        ),
        actions: [
          Button.outline(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          Button.primary(
            style: ButtonStyle.destructive(),
            onPressed: () => Navigator.pop(context, true),
            child: Text('确定切换'),
          ),
        ],
      ),
    );
  }

  void _executeAutomationCommand(String projectPath, String appName) {
    final deviceId = widget.device.id;  // 使用设备 ID 作为唯一标识
    
    // 先更新终端的工作目录
    ref.read(terminalStateProvider.notifier).updateDirectory(deviceId, projectPath);
    
    // 只执行 uv 命令（工作目录已设置）
    final command = 'uv run main.py -s "$deviceId" "$appName"';
    
    // 在终端中执行（使用带 appName 的方法）
    ref.read(terminalStateProvider.notifier).executeAutomationCommand(deviceId, command, appName);
    
    // 滚动到顶部，显示运行中的 app
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    
    // 显示提示
    showToast(
      context: context,
      builder: (context, overlay) => Text('已启动: $appName'),
    );
  }

  Future<void> _showProjectPathDialog() async {
    final controller = TextEditingController(
      text: ref.read(automationProjectPathProvider) ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置自动化项目路径'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text('请输入自动化项目的根目录路径：').small().muted(),
              TextField(
                controller: controller,
                placeholder: Text('/Users/xxx/workspace/ui_agent'),
                style: TextStyle(fontFamily: 'GeistMono', fontSize: 13),
              ),
              Text('项目目录下应包含 main.py 文件').xSmall().muted(),
            ],
          ),
        ),
        actions: [
          Button.outline(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          Button.primary(
            onPressed: () {
              final path = controller.text.trim();
              if (path.isNotEmpty) {
                Navigator.pop(context, path);
              }
            },
            child: Text('确认'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // 验证路径是否存在
      if (!AutomationProjectPathNotifier.validatePath(result)) {
        await _showErrorDialog('路径不存在', '目录 "$result" 不存在，请检查路径是否正确。');
        return;
      }

      // 保存路径
      await ref.read(automationProjectPathProvider.notifier).setPath(result);
      
      showToast(
        context: context,
        builder: (context, overlay) => Text('项目路径已保存'),
      );
    }
  }

  Future<void> _showErrorDialog(String title, String content) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          Button.primary(
            onPressed: () => Navigator.pop(context),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 使用 id 匹配设备信息，因为 serialNo 在模拟器上可能重复
    final deviceInfo = ref
        .watch(infoProvider)
        .firstWhereOrNull((info) => info.deviceId == widget.device.id);
    final projectPath = ref.watch(automationProjectPathProvider);
    final terminalState = ref.watch(terminalStateProvider)[widget.device.id];  // 使用 id
    final runningAppName = terminalState?.runningAppName;

    final appList = deviceInfo?.appList ?? [];
    
    // 过滤应用列表
    final filteredApps = appList.where((app) {
      final searchText = _searchController.text.toLowerCase();
      final matchesSearch = app.name.toLowerCase().contains(searchText) ||
          app.packageName.toLowerCase().contains(searchText);
      
      // 如果不显示系统应用，过滤掉 android. 和 com.android. 开头的包
      if (!_showSystemApps) {
        final isSystemApp = app.packageName.startsWith('android.') ||
            app.packageName.startsWith('com.android.') ||
            app.packageName.startsWith('com.google.android.');
        if (isSystemApp) return false;
      }
      
      return matchesSearch;
    }).toList();

    // 排序：运行中的 app 置顶，其他按名称排序
    filteredApps.sort((a, b) {
      // 运行中的 app 优先
      final aIsRunning = a.name == runningAppName;
      final bIsRunning = b.name == runningAppName;
      
      if (aIsRunning && !bIsRunning) return -1;
      if (!aIsRunning && bIsRunning) return 1;
      
      // 其他按名称排序
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return PgSectionCardNoScroll(
      cardPadding: EdgeInsets.zero,
      label: '已安装应用 (${filteredApps.length}/${appList.length})',
      labelButton: Row(
        spacing: 4,
        children: [
          // 设置项目路径按钮
          Tooltip(
            tooltip: TooltipContainer(
              child: Text(projectPath != null ? '项目: $projectPath' : '设置自动化项目路径'),
            ).call,
            child: IconButton.ghost(
              density: ButtonDensity.iconDense,
              icon: Icon(
                Icons.folder_open_rounded,
                color: projectPath != null ? Colors.green : null,
              ),
              onPressed: _showProjectPathDialog,
            ),
          ),
          Tooltip(
            tooltip: TooltipContainer(
              child: Text(_showSystemApps ? '隐藏系统应用' : '显示系统应用'),
            ).call,
            child: Toggle(
              style: ButtonStyle.ghost(density: ButtonDensity.iconDense),
              value: _showSystemApps,
              onChanged: (value) => setState(() => _showSystemApps = value),
              child: Icon(Icons.android_rounded).iconSmall(),
            ),
          ),
          IconButton.ghost(
            enabled: !_isLoading,
            density: ButtonDensity.iconDense,
            icon: _isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.refresh_rounded),
            onPressed: _refreshAppList,
          ),
        ],
      ),
      expandContent: true,
      content: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _searchController,
              placeholder: Text('搜索应用名称或包名...'),
              filled: true,
              features: [
                InputFeature.leading(Icon(Icons.search_rounded)),
                if (_searchController.text.isNotEmpty)
                  InputFeature.trailing(
                    IconButton(
                      variance: ButtonVariance.link,
                      density: ButtonDensity.compact,
                      icon: Icon(Icons.close_rounded),
                      onPressed: () => _searchController.clear(),
                    ),
                  ),
              ],
            ),
          ),
          // 应用列表
          Expanded(
            child: deviceInfo == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 8,
                      children: [
                        CircularProgressIndicator(),
                        Text('正在获取应用列表...').textSmall.muted,
                      ],
                    ),
                  )
                : filteredApps.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? '没有找到应用'
                              : '没有匹配的应用',
                        ).textSmall.muted,
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          final isThisAppRunning = runningAppName == app.name;
                          
                          return _AppListTile(
                            appName: app.name,
                            packageName: app.packageName,
                            device: widget.device,
                            onStart: () => _startAutomation(app.name),
                            isRunning: isThisAppRunning,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AppListTile extends ConsumerWidget {
  final String appName;
  final String packageName;
  final AdbDevices device;
  final VoidCallback? onStart;
  final bool isRunning;

  const _AppListTile({
    required this.appName,
    required this.packageName,
    required this.device,
    this.onStart,
    this.isRunning = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: OutlinedContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderColor: isRunning ? Colors.red : null,
        borderWidth: isRunning ? 2 : 1,
        child: Row(
          children: [
            // App 图标占位
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isRunning ? Colors.red.withOpacity(0.1) : theme.colorScheme.muted,
                borderRadius: theme.borderRadiusSm,
              ),
              child: Center(
                child: Text(
                  appName.isNotEmpty ? appName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isRunning ? Colors.red : theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // App 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          appName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isRunning ? Colors.red : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRunning)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '运行中',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    packageName,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.mutedForeground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 开始/停止按钮
            Tooltip(
              tooltip: TooltipContainer(
                child: Text(isRunning ? '正在运行' : '开始自动化任务'),
              ).call,
              child: isRunning
                  ? Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: theme.borderRadiusSm,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : IconButton(
                      variance: ButtonVariance.primary,
                      density: ButtonDensity.iconDense,
                      icon: Icon(Icons.play_arrow_rounded, size: 18),
                      onPressed: onStart,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
