import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kAutomationProjectPath = 'automation_project_path';

/// 自动化项目路径 Provider
final automationProjectPathProvider =
    StateNotifierProvider<AutomationProjectPathNotifier, String?>((ref) {
  return AutomationProjectPathNotifier();
});

class AutomationProjectPathNotifier extends StateNotifier<String?> {
  AutomationProjectPathNotifier() : super(null) {
    _loadPath();
  }

  Future<void> _loadPath() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kAutomationProjectPath);
  }

  Future<void> setPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAutomationProjectPath, path);
    state = path;
  }

  Future<void> clearPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAutomationProjectPath);
    state = null;
  }

  /// 验证路径是否存在
  static bool validatePath(String path) {
    final dir = Directory(path);
    return dir.existsSync();
  }

  /// 验证 main.py 是否存在
  static bool validateMainPy(String path) {
    final file = File('$path/main.py');
    return file.existsSync();
  }
}

