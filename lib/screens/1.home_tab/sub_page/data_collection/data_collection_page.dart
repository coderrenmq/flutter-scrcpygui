import 'package:awesome_extensions/awesome_extensions.dart' show NumExtension;
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:scrcpygui/providers/adb_provider.dart';
import 'package:scrcpygui/widgets/custom_ui/pg_scaffold.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../../providers/device_info_provider.dart';
import '../../../../utils/app_utils.dart';
import 'widgets/terminal_panel.dart';
import 'widgets/app_list_panel.dart';

class DataCollectionPage extends ConsumerStatefulWidget {
  static const route = 'data-collection';

  const DataCollectionPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _DataCollectionPageState();
}

class _DataCollectionPageState extends ConsumerState<DataCollectionPage> {
  @override
  Widget build(BuildContext context) {
    final device = ref.watch(selectedDeviceProvider);

    if (device == null) {
      return PgScaffoldCustom(
          onBack: context.pop,
          scaffoldBody: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8,
            children: [
              Text('Device disconnected').small().muted(),
              PrimaryButton(
                onPressed: context.pop,
                child: Text('关闭'),
              )
            ],
          ),
          title: Text('设备已断开').bold().xLarge());
    }

    return PgScaffoldCustom(
      onBack: context.pop,
      title: DataCollectionTitle(),
      scaffoldBody: ResponsiveBuilder(
        builder: (context, sizingInfo) {
          return AnimatedSwitcher(
            duration: 200.milliseconds,
            child: sizingInfo.isMobile || sizingInfo.isTablet
                ? _SmallLayout(device: device)
                : _BigLayout(device: device),
          );
        },
      ),
    );
  }
}

class _BigLayout extends ConsumerStatefulWidget {
  final device;
  const _BigLayout({required this.device});

  @override
  ConsumerState<_BigLayout> createState() => _BigLayoutState();
}

class _BigLayoutState extends ConsumerState<_BigLayout> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      adbProvider,
      (previous, next) {
        if (!next.contains(widget.device)) {
          context.pop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Expanded(
          flex: 1,
          child: TerminalPanel(device: widget.device),
        ),
        Expanded(
          flex: 1,
          child: AppListPanel(device: widget.device),
        ),
      ],
    );
  }
}

class _SmallLayout extends ConsumerStatefulWidget {
  final device;
  const _SmallLayout({required this.device});

  @override
  ConsumerState<_SmallLayout> createState() => _SmallLayoutState();
}

class _SmallLayoutState extends ConsumerState<_SmallLayout> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ButtonGroup(
          children: [
            Button(
              style: _currentIndex == 0
                  ? const ButtonStyle.primary()
                  : const ButtonStyle.outline(),
              onPressed: () => setState(() => _currentIndex = 0),
              child: Text('终端'),
            ),
            Button(
              style: _currentIndex == 1
                  ? const ButtonStyle.primary()
                  : const ButtonStyle.outline(),
              onPressed: () => setState(() => _currentIndex = 1),
              child: Text('应用列表'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              TerminalPanel(device: widget.device),
              AppListPanel(device: widget.device),
            ],
          ),
        ),
      ],
    );
  }
}

class DataCollectionTitle extends ConsumerStatefulWidget {
  const DataCollectionTitle({super.key});

  @override
  ConsumerState<DataCollectionTitle> createState() =>
      _DataCollectionTitleState();
}

class _DataCollectionTitleState extends ConsumerState<DataCollectionTitle> {
  @override
  Widget build(BuildContext context) {
    final device = ref.watch(selectedDeviceProvider)!;
    final connected = ref.watch(adbProvider);

    final deviceInfo = ref
        .watch(infoProvider)
        .firstWhereOrNull((info) => info.deviceId == device.id);

    return Row(
      spacing: 8,
      children: [
        Text('Pretrain Data Crawl').bold.xLarge,
        Text('/'),
        if (connected.length > 1) ...[
          Expanded(
            child: Align(
              alignment: AlignmentGeometry.centerLeft,
              child: Select(
                filled: true,
                onChanged: (value) {
                  ref.read(selectedDeviceProvider.notifier).state = value;
                },
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                value: device,
                popupWidthConstraint: PopoverConstraint.intrinsic,
                popup: SelectPopup.noVirtualization(
                  items: SelectItemList(
                      children: connected.map((e) {
                    final info = ref.read(infoProvider).firstWhereOrNull(
                          (info) => info.deviceId == e.id,
                        );

                    return SelectItemButton(
                      value: e,
                      child: Basic(
                        leading: isWireless(e.id)
                            ? Icon(Icons.wifi_rounded).iconSmall()
                            : Icon(Icons.usb_rounded).iconSmall(),
                        title: Text(info?.deviceName ?? e.modelName),
                        leadingAlignment: AlignmentGeometry.center,
                        subtitle: Text(e.id),
                      ),
                    );
                  }).toList()),
                ).call,
                itemBuilder: (context, dev) {
                  final info = ref.read(infoProvider).firstWhereOrNull(
                        (info) => info.deviceId == dev.id,
                      );
                  return Row(
                    spacing: 4,
                    children: [
                      isWireless(dev.id)
                          ? Icon(Icons.wifi_rounded)
                          : Icon(Icons.usb_rounded),
                      Expanded(
                        child: Text(
                          info?.deviceName ?? dev.modelName,
                          overflow: TextOverflow.ellipsis,
                        ).bold.xLarge,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ] else ...[
          Row(
            spacing: 4,
            children: [
              isWireless(device.id)
                  ? Icon(Icons.wifi_rounded)
                  : Icon(Icons.usb_rounded),
              Text(deviceInfo?.deviceName ?? device.modelName).bold.xLarge,
            ],
          )
        ]
      ],
    );
  }
}

