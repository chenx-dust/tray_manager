import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';

void main() {
  test('tray menu item serializes its sublabel presentation', () {
    final item = TrayMenuItem.checkbox(
      label: 'Proxy',
      sublabel: '42 ms',
      sublabelStyle: TrayMenuItemSublabelStyle.badge,
      checked: true,
    );

    expect(
      item.toJson(),
      containsPair('sublabel', '42 ms'),
    );
    expect(
      item.toJson(),
      containsPair('sublabelStyle', 'badge'),
    );
  });

  test('tray menu item serializes destructive sublabels', () {
    final item = TrayMenuItem.checkbox(
      label: 'Proxy',
      sublabel: 'Timeout',
      sublabelStyle: TrayMenuItemSublabelStyle.destructive,
      checked: false,
    );

    expect(
      item.toJson(),
      containsPair('sublabelStyle', 'destructive'),
    );
  });

  test('tray menu item serializes secondary sublabels', () {
    final item = TrayMenuItem.submenu(
      label: 'Proxy',
      sublabel: 'Selected Proxy',
      sublabelStyle: TrayMenuItemSublabelStyle.secondary,
      submenu: Menu(items: []),
    );

    expect(
      item.toJson(),
      containsPair('sublabelStyle', 'secondary'),
    );
  });

  test('tray menu item can keep an open native menu tracking', () {
    final item = TrayMenuItem(
      label: 'Delay Test',
      keepsMenuOpen: true,
    );

    expect(item.toJson(), containsPair('usesCustomView', true));
    expect(item.toJson(), containsPair('keepsMenuOpen', true));
  });
}
