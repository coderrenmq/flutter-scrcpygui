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

  String get _serialNo => widget.device.serialNo;

  @override
  void initState() {
    super.initState();
    // 确保终端状态已初始化（延迟执行避免在 build 期间修改状态）
    Future.microtask(() {
      if (mounted) {
        ref.read(terminalStateProvider.notifier).getOrCreate(_serialNo);
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _interruptCommand() {
    ref.read(terminalStateProvider.notifier).interruptCommand(_serialNo);
  }

  void _clearTerminal() {
    ref.read(terminalStateProvider.notifier).clearEntries(_serialNo);
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
    final terminalState = allStates[_serialNo];
    
    // 当 entries 变化时滚动到底部
    ref.listen(terminalStateProvider, (previous, next) {
      final prevEntries = previous?[_serialNo]?.entries.length ?? 0;
      final nextEntries = next[_serialNo]?.entries.length ?? 0;
      if (nextEntries > prevEntries) {
        _scrollToBottom();
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

    return PgSectionCardNoScroll(
      cardPadding: EdgeInsets.zero,
      label: '运行日志 ${terminalState.isExecuting ? "(运行中)" : ""}',
      labelButton: Row(
        spacing: 4,
        children: [
          if (terminalState.isExecuting)
            IconButton.ghost(
              density: ButtonDensity.iconDense,
              icon: Icon(Icons.stop_rounded, color: Colors.red),
              onPressed: _interruptCommand,
            ),
          IconButton.ghost(
            density: ButtonDensity.iconDense,
            icon: Icon(Icons.delete_outline_rounded),
            onPressed: _clearTerminal,
          ),
        ],
      ),
      expandContent: true,
      content: GestureDetector(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: theme.borderRadiusSm,
          ),
          child: terminalState.entries.isEmpty
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
                  itemCount: terminalState.entries.length,
                  itemBuilder: (context, index) {
                    final entry = terminalState.entries[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: SelectableText(
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
      ),
    );
  }
}
