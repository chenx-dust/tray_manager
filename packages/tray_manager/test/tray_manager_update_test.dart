import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('tray_manager');
  final calls = <MethodCall>[];
  final listener = _TestTrayListener();

  setUp(() {
    calls.clear();
    trayManager.addListener(listener);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() {
    trayManager.removeListener(listener);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('updates one keyed menu item without rebuilding the menu', () async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          TrayMenuItem.checkbox(
            key: 'proxy-a',
            label: 'Proxy A',
            checked: false,
          ),
        ],
      ),
    );

    await trayManager.updateMenuItem(
      key: 'proxy-a',
      sublabel: '42 ms',
      sublabelStyle: TrayMenuItemSublabelStyle.badge,
    );

    expect(calls.map((call) => call.method), [
      'setContextMenu',
      'updateMenuItem',
    ]);
    expect(calls.last.arguments, {
      'key': 'proxy-a',
      'sublabel': '42 ms',
      'sublabelStyle': 'badge',
    });
  });

  test('forwards native activation details to a tray menu item', () async {
    int? receivedTimestamp;
    String? receivedToken;
    final item = TrayMenuItem(
      label: 'Show',
      onClickWithDetails: (menuItem, details) {
        receivedTimestamp = details.activationTimestamp;
        receivedToken = details.activationToken;
      },
    );
    await trayManager.setContextMenu(Menu(items: [item]));

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'tray_manager',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onTrayMenuItemClick', {
          'id': item.id,
          'activationTimestamp': 1234,
          'activationToken': 'activation-token',
        }),
      ),
      (_) {},
    );

    expect(receivedTimestamp, 1234);
    expect(receivedToken, 'activation-token');
  });
}

class _TestTrayListener with TrayListener {}
