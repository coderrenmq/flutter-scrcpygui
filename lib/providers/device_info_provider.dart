import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_info_model.dart';

class DeviceInfoNotifier extends Notifier<List<DeviceInfo>> {
  @override
  build() {
    return [];
  }

  void setDevicesInfo(List<DeviceInfo> devicesInfo) {
    state = devicesInfo;
  }

  void _addDeviceInfo(DeviceInfo deviceInfo) {
    // 使用 deviceId 作为唯一标识，避免模拟器等 serialNo 相同的问题
    if (state.where((infos) => infos.deviceId == deviceInfo.deviceId).isEmpty) {
      state = [...state, deviceInfo];
    }
  }

  void removeDeviceInfo(DeviceInfo deviceInfo) {
    state = [...state.where((info) => info.deviceId != deviceInfo.deviceId)];
  }

  void addOrEditDeviceInfo(DeviceInfo deviceInfo) {
    removeDeviceInfo(deviceInfo);
    _addDeviceInfo(deviceInfo);
  }
}

final infoProvider = NotifierProvider<DeviceInfoNotifier, List<DeviceInfo>>(
    () => DeviceInfoNotifier());
