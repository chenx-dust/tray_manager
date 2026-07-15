import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('tray_manager');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() {
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
}
