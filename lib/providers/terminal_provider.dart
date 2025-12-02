import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 清理 ANSI 转义序列和其他控制字符
String _cleanOutput(String text) {
  return text
      // ANSI 颜色和样式序列
      .replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '')
      // OSC 序列 (如设置终端标题)
      .replaceAll(RegExp(r'\x1B\][^\x07]*\x07'), '')
      // 其他 ESC 序列
      .replaceAll(RegExp(r'\x1B[PX^_].*?\x1B\\'), '')
      .replaceAll(RegExp(r'\x1B.'), '')
      // 光标控制序列
      .replaceAll(RegExp(r'\x1B\[\?[0-9;]*[a-zA-Z]'), '')
      // 回车符（Rich Live 用于覆盖行）
      .replaceAll('\r', '')
      // 清除多余空行
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

/// 终端条目类型
enum TerminalEntryType {
  command,
  output,
  error,
  info,
}

/// 终端条目
class TerminalEntry {
  final TerminalEntryType type;
  final String content;
  final String? directory;
  final DateTime timestamp;

  TerminalEntry({
    required this.type,
    required this.content,
    this.directory,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 单个设备的终端状态
class DeviceTerminalState {
  final String deviceSerialNo;
  final List<TerminalEntry> entries;
  final List<String> commandHistory;
  final String currentDirectory;
  final bool isExecuting;
  final Process? currentProcess;
  final String? runningAppName;  // 当前正在运行的 app 名称

  DeviceTerminalState({
    required this.deviceSerialNo,
    this.entries = const [],
    this.commandHistory = const [],
    String? currentDirectory,
    this.isExecuting = false,
    this.currentProcess,
    this.runningAppName,
  }) : currentDirectory = currentDirectory ?? Platform.environment['HOME'] ?? '/';

  DeviceTerminalState copyWith({
    String? deviceSerialNo,
    List<TerminalEntry>? entries,
    List<String>? commandHistory,
    String? currentDirectory,
    bool? isExecuting,
    Process? currentProcess,
    bool clearProcess = false,
    String? runningAppName,
    bool clearRunningApp = false,
  }) {
    return DeviceTerminalState(
      deviceSerialNo: deviceSerialNo ?? this.deviceSerialNo,
      entries: entries ?? this.entries,
      commandHistory: commandHistory ?? this.commandHistory,
      currentDirectory: currentDirectory ?? this.currentDirectory,
      isExecuting: isExecuting ?? this.isExecuting,
      currentProcess: clearProcess ? null : (currentProcess ?? this.currentProcess),
      runningAppName: clearRunningApp ? null : (runningAppName ?? this.runningAppName),
    );
  }
}

/// 终端状态管理器
class TerminalStateNotifier extends StateNotifier<Map<String, DeviceTerminalState>> {
  TerminalStateNotifier() : super({});

  /// 获取或创建设备的终端状态
  DeviceTerminalState getOrCreate(String serialNo) {
    if (!state.containsKey(serialNo)) {
      final newState = DeviceTerminalState(
        deviceSerialNo: serialNo,
        entries: [],
      );
      state = {...state, serialNo: newState};
    }
    return state[serialNo]!;
  }

  /// 添加终端条目
  void addEntry(String serialNo, TerminalEntry entry) {
    final current = getOrCreate(serialNo);
    state = {
      ...state,
      serialNo: current.copyWith(
        entries: [...current.entries, entry],
      ),
    };
  }

  /// 添加命令到历史记录
  void addToHistory(String serialNo, String command) {
    final current = getOrCreate(serialNo);
    state = {
      ...state,
      serialNo: current.copyWith(
        commandHistory: [...current.commandHistory, command],
      ),
    };
  }

  /// 更新当前目录
  void updateDirectory(String serialNo, String directory) {
    final current = getOrCreate(serialNo);
    state = {
      ...state,
      serialNo: current.copyWith(currentDirectory: directory),
    };
  }

  /// 设置执行状态
  void setExecuting(String serialNo, bool isExecuting, {Process? process, String? appName}) {
    final current = getOrCreate(serialNo);
    state = {
      ...state,
      serialNo: current.copyWith(
        isExecuting: isExecuting,
        currentProcess: process,
        clearProcess: !isExecuting,
        runningAppName: appName,
        clearRunningApp: !isExecuting,
      ),
    };
  }

  /// 清除终端内容
  void clearEntries(String serialNo) {
    final current = getOrCreate(serialNo);
    state = {
      ...state,
      serialNo: current.copyWith(
        entries: [],
      ),
    };
  }

  /// 移除设备的终端状态（设备断开时调用）
  void removeDevice(String serialNo) {
    final current = state[serialNo];
    if (current != null) {
      // 终止正在执行的进程并强制结束
      _killProcess(current.currentProcess);
    }
    state = Map.from(state)..remove(serialNo);
  }

  /// 清理所有设备的终端进程（程序关闭时调用）
  void disposeAll() {
    for (final entry in state.entries) {
      _killProcess(entry.value.currentProcess);
    }
    state = {};
  }

  /// 安全地终止进程，确保释放文件描述符
  void _killProcess(Process? process) {
    if (process == null) return;
    try {
      // 先发送 SIGTERM 让进程优雅退出
      process.kill(ProcessSignal.sigterm);
      // 给进程一点时间清理
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          // 如果还没退出，强制杀死
          process.kill(ProcessSignal.sigkill);
        } catch (_) {}
      });
    } catch (_) {
      // 进程可能已经退出，忽略错误
    }
  }

  /// 中断当前执行的命令
  void interruptCommand(String serialNo) {
    final current = state[serialNo];
    if (current != null && current.currentProcess != null) {
      try {
        // 发送 SIGINT 模拟 Ctrl+C
        current.currentProcess!.kill(ProcessSignal.sigint);
        addEntry(serialNo, TerminalEntry(
          type: TerminalEntryType.info,
          content: '^C',
        ));
        // 更新状态
        setExecuting(serialNo, false);
      } catch (e) {
        addEntry(serialNo, TerminalEntry(
          type: TerminalEntryType.error,
          content: '停止任务失败: $e',
        ));
      }
    }
  }

  /// 执行自动化任务命令
  Future<void> executeAutomationCommand(String serialNo, String command, String appName) async {
    if (command.trim().isEmpty) return;

    final trimmedCommand = command.trim();
    final current = getOrCreate(serialNo);

    // 添加到历史记录
    addToHistory(serialNo, trimmedCommand);

    // 显示输入的命令
    addEntry(serialNo, TerminalEntry(
      type: TerminalEntryType.command,
      content: '\$ $trimmedCommand',
      directory: current.currentDirectory,
    ));

    // 执行外部命令（带 appName）
    await _runExternalCommandWithApp(serialNo, trimmedCommand, appName);
  }

  /// 执行命令
  Future<void> executeCommand(String serialNo, String command) async {
    if (command.trim().isEmpty) return;

    final trimmedCommand = command.trim();
    final current = getOrCreate(serialNo);

    // 添加到历史记录
    addToHistory(serialNo, trimmedCommand);

    // 显示输入的命令
    addEntry(serialNo, TerminalEntry(
      type: TerminalEntryType.command,
      content: '\$ $trimmedCommand',
      directory: current.currentDirectory,
    ));

    // 处理内置命令
    if (trimmedCommand == 'clear') {
      clearEntries(serialNo);
      return;
    }

    if (trimmedCommand.startsWith('cd ')) {
      _handleCd(serialNo, trimmedCommand.substring(3).trim());
      return;
    }

    if (trimmedCommand == 'cd') {
      _handleCd(serialNo, Platform.environment['HOME'] ?? '/');
      return;
    }

    if (trimmedCommand == 'pwd') {
      addEntry(serialNo, TerminalEntry(
        type: TerminalEntryType.output,
        content: current.currentDirectory,
      ));
      return;
    }

    // 执行外部命令
    await _runExternalCommand(serialNo, trimmedCommand);
  }

  void _handleCd(String serialNo, String path) {
    final current = getOrCreate(serialNo);
    String newPath;

    if (path.startsWith('/')) {
      newPath = path;
    } else if (path.startsWith('~')) {
      newPath = path.replaceFirst('~', Platform.environment['HOME'] ?? '/');
    } else if (path == '..') {
      newPath = Directory(current.currentDirectory).parent.path;
    } else if (path == '.') {
      newPath = current.currentDirectory;
    } else {
      newPath = '${current.currentDirectory}/$path';
    }

    try {
      final dir = Directory(newPath);
      if (dir.existsSync()) {
        updateDirectory(serialNo, dir.absolute.path);
        addEntry(serialNo, TerminalEntry(
          type: TerminalEntryType.output,
          content: dir.absolute.path,
        ));
      } else {
        addEntry(serialNo, TerminalEntry(
          type: TerminalEntryType.error,
          content: 'cd: no such file or directory: $path',
        ));
      }
    } catch (e) {
      addEntry(serialNo, TerminalEntry(
        type: TerminalEntryType.error,
        content: 'cd: $e',
      ));
    }
  }

  Future<void> _runExternalCommandWithApp(String serialNo, String command, String appName) async {
    final current = getOrCreate(serialNo);
    
    setExecuting(serialNo, true, appName: appName);

    try {
      final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
      final home = Platform.environment['HOME'] ?? '/';
      
      // 构建完整的命令
      String fullCommand;
      if (shell.endsWith('zsh')) {
        fullCommand = '''
source ~/.zshrc 2>/dev/null || true
cd "${current.currentDirectory}"
$command
''';
      } else if (shell.endsWith('bash')) {
        fullCommand = '''
source ~/.bashrc 2>/dev/null || true
source ~/.bash_profile 2>/dev/null || true
cd "${current.currentDirectory}"
$command
''';
      } else {
        fullCommand = 'cd "${current.currentDirectory}" && $command';
      }

      final process = await Process.start(
        shell,
        ['-l', '-c', fullCommand],
        workingDirectory: home,
        environment: {
          ...Platform.environment,
          'TERM': 'dumb',           // 禁用终端控制序列
          'NO_COLOR': '1',          // 禁用颜色输出
          'FORCE_COLOR': '0',       // 强制禁用颜色
          'PYTHONUNBUFFERED': '1',  // Python 不缓冲输出
        },
      );

      setExecuting(serialNo, true, process: process, appName: appName);

      // 监听标准输出
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        final cleanLine = _cleanOutput(line);
        if (cleanLine.trim().isNotEmpty) {
          addEntry(serialNo, TerminalEntry(
            type: TerminalEntryType.output,
            content: cleanLine,
          ));
        }
      });

      // 监听标准错误
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        final cleanLine = _cleanOutput(line);
        if (cleanLine.trim().isNotEmpty) {
          addEntry(serialNo, TerminalEntry(
            type: TerminalEntryType.error,
            content: cleanLine,
          ));
        }
      });

      // 等待命令完成
      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        addEntry(serialNo, TerminalEntry(
          type: TerminalEntryType.info,
          content: '[退出码: $exitCode]',
        ));
      }
      
      setExecuting(serialNo, false);
    } catch (e) {
      addEntry(serialNo, TerminalEntry(
        type: TerminalEntryType.error,
        content: '执行错误: $e',
      ));
      setExecuting(serialNo, false);
    }
  }

  Future<void> _runExternalCommand(String serialNo, String command) async {
    final current = getOrCreate(serialNo);
    
    setExecuting(serialNo, true);

    try {
      final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
      final home = Platform.environment['HOME'] ?? '/';
      
      // 构建完整的命令，先 source 初始化文件以支持 conda/nvm 等工具
      String fullCommand;
      if (shell.endsWith('zsh')) {
        // 对于 zsh，加载配置文件
        fullCommand = '''
source ~/.zshrc 2>/dev/null || true
cd "${current.currentDirectory}"
$command
''';
      } else if (shell.endsWith('bash')) {
        // 对于 bash，加载配置文件
        fullCommand = '''
source ~/.bashrc 2>/dev/null || true
source ~/.bash_profile 2>/dev/null || true
cd "${current.currentDirectory}"
$command
''';
      } else {
        fullCommand = 'cd "${current.currentDirectory}" && $command';
      }

      final process = await Process.start(
        shell,
        ['-l', '-c', fullCommand], // -l 作为登录 shell
        workingDirectory: home, // 从 home 开始，让 source 能找到配置文件
        environment: {
          ...Platform.environment,
          'TERM': 'dumb',           // 禁用终端控制序列
          'NO_COLOR': '1',          // 禁用颜色输出
          'FORCE_COLOR': '0',       // 强制禁用颜色
          'PYTHONUNBUFFERED': '1',  // Python 不缓冲输出
        },
      );

      setExecuting(serialNo, true, process: process);

      // 监听标准输出
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        final cleanLine = _cleanOutput(line);
        if (cleanLine.trim().isNotEmpty) {
          addEntry(serialNo, TerminalEntry(
            type: TerminalEntryType.output,
            content: cleanLine,
          ));
        }
      });

      // 监听标准错误
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        final cleanLine = _cleanOutput(line);
        if (cleanLine.trim().isNotEmpty) {
          addEntry(serialNo, TerminalEntry(
            type: TerminalEntryType.error,
            content: cleanLine,
          ));
        }
      });

      // 等待命令完成
      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        addEntry(serialNo, TerminalEntry(
          type: TerminalEntryType.info,
          content: '[退出码: $exitCode]',
        ));
      }
      
      setExecuting(serialNo, false);
    } catch (e) {
      addEntry(serialNo, TerminalEntry(
        type: TerminalEntryType.error,
        content: '执行错误: $e',
      ));
      setExecuting(serialNo, false);
    }
  }
}

/// 终端状态 Provider
final terminalStateProvider =
    StateNotifierProvider<TerminalStateNotifier, Map<String, DeviceTerminalState>>(
  (ref) => TerminalStateNotifier(),
);

