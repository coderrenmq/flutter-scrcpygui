import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrcpygui/models/adb_devices.dart';
import 'package:scrcpygui/providers/terminal_provider.dart';
import 'package:scrcpygui/widgets/custom_ui/pg_section_card.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TerminalPanel extends ConsumerStatefulWidget {
  final AdbDevices device;

  const TerminalPanel({super.key, required this.device});

  @override
  ConsumerState<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends ConsumerState<TerminalPanel> {
  final ScrollController _scrollController = ScrollController();
  
  // 性能优化：限制显示的最大日志条数
  static const int _maxDisplayEntries = 500;
  
  // 防止频繁滚动
  bool _isScrolling = false;

  // 使用 id 而非 serialNo 作为唯一标识，避免模拟器等设备 serialNo 相同的问题
  String get _deviceId => widget.device.id;

  @override
  void initState() {
    super.initState();
    // 确保终端状态已初始化（延迟执行避免在 build 期间修改状态）
    Future.microtask(() {
      if (mounted) {
        ref.read(terminalStateProvider.notifier).getOrCreate(_deviceId);
        _scrollToBottomDelayed();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 延迟滚动到底部，避免频繁触发
  void _scrollToBottomDelayed() {
    if (_isScrolling) return;
    _isScrolling = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        // 直接跳转而非动画，提升性能
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
      _isScrolling = false;
    });
  }

  void _interruptCommand() {
    ref.read(terminalStateProvider.notifier).interruptCommand(_deviceId);
  }

  Color _getEntryColor(TerminalEntryType type) {
    switch (type) {
      case TerminalEntryType.command:
        return const Color(0xFF6A9955); // 绿色
      case TerminalEntryType.output:
        return const Color(0xFFD4D4D4); // 白色
      case TerminalEntryType.error:
        return const Color(0xFFF14C4C); // 红色
      case TerminalEntryType.info:
        return const Color(0xFF569CD6); // 蓝色
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // 监听终端状态变化
    final allStates = ref.watch(terminalStateProvider);
    final terminalState = allStates[_deviceId];
    
    // 当 entries 变化时滚动到底部
    ref.listen(terminalStateProvider, (previous, next) {
      final prevEntries = previous?[_deviceId]?.entries.length ?? 0;
      final nextEntries = next[_deviceId]?.entries.length ?? 0;
      if (nextEntries > prevEntries) {
        _scrollToBottomDelayed();
      }
    });

    // 如果终端状态还未初始化，显示加载中
    if (terminalState == null) {
      return PgSectionCardNoScroll(
        cardPadding: EdgeInsets.zero,
        label: '运行日志',
        expandContent: true,
        content: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 性能优化：只显示最新的日志条目
    final allEntries = terminalState.entries;
    final displayEntries = allEntries.length > _maxDisplayEntries
        ? allEntries.sublist(allEntries.length - _maxDisplayEntries)
        : allEntries;
    final entriesCount = displayEntries.length;
    final isTruncated = allEntries.length > _maxDisplayEntries;

    return PgSectionCardNoScroll(
      cardPadding: EdgeInsets.zero,
      label: '运行日志 ${terminalState.isExecuting ? "(运行中)" : ""}'
          '${isTruncated ? " [显示最近$_maxDisplayEntries条]" : ""}',
      labelButton: terminalState.isExecuting
          ? Tooltip(
              tooltip: TooltipContainer(
                child: Text('双击停止当前任务'),
              ),
              child: GestureDetector(
                onDoubleTap: _interruptCommand,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Icon(Icons.stop_rounded, color: Colors.red, size: 18),
                      Text(
                        '停止',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      expandContent: true,
      content: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: theme.borderRadiusSm,
        ),
        child: entriesCount == 0
            ? Center(
                child: Text(
                  '等待任务执行...',
                  style: TextStyle(
                    color: const Color(0xFF569CD6),
                    fontSize: 13,
                  ),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: entriesCount,
                // 性能优化：禁用自动保持存活，减少内存占用
                addAutomaticKeepAlives: false,
                // 性能优化：添加重绘边界
                addRepaintBoundaries: true,
                itemBuilder: (context, index) {
                  final entry = displayEntries[index];
                  // 使用普通 Text 而非 SelectableText 提升性能
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      entry.content,
                      style: TextStyle(
                        fontFamily: 'GeistMono',
                        fontSize: 13,
                        height: 1.4,
                        color: _getEntryColor(entry.type),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
