import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String trayMenuSource;
  late String trayManagerPluginSource;

  setUpAll(() {
    final sourceFile = [
      File('macos/Classes/TrayMenu.swift'),
      File('macos/tray_manager/Classes/TrayMenu.swift'),
      File('packages/tray_manager/macos/Classes/TrayMenu.swift'),
      File('packages/tray_manager/macos/tray_manager/Classes/TrayMenu.swift'),
    ].firstWhere(
      (file) => file.existsSync(),
      orElse: () => throw StateError('Could not find TrayMenu.swift'),
    );
    trayMenuSource = sourceFile.readAsStringSync();
    final pluginSourceFile = [
      File('macos/Classes/TrayManagerPlugin.swift'),
      File('macos/tray_manager/Classes/TrayManagerPlugin.swift'),
      File('packages/tray_manager/macos/Classes/TrayManagerPlugin.swift'),
      File(
        'packages/tray_manager/macos/tray_manager/Classes/TrayManagerPlugin.swift',
      ),
    ].firstWhere(
      (file) => file.existsSync(),
      orElse: () => throw StateError('Could not find TrayManagerPlugin.swift'),
    );
    trayManagerPluginSource = pluginSourceFile.readAsStringSync();
  });

  test('macOS tray menu renders sublabels in custom menu item views', () {
    expect(trayMenuSource, contains('class TrayMenuItemView: NSView'));
    expect(trayMenuSource, contains('itemDict["sublabel"]'));
    expect(trayMenuSource, contains('menuItem.view = customView'));
  });

  test('macOS tray menu supports delay badge states', () {
    expect(trayMenuSource, contains('case badge'));
    expect(trayMenuSource, contains('case muted'));
    expect(trayMenuSource, contains('case destructive'));
    expect(trayMenuSource, contains('roundedRect: frame'));
  });

  test('macOS tray menu supports plain secondary submenu labels', () {
    expect(trayMenuSource, contains('case secondary'));
    expect(trayMenuSource, contains('drawSubmenuIndicator'));
    expect(trayMenuSource, contains('paragraphStyle.alignment = .right'));
  });

  test('macOS custom menu items use native-style hover highlighting', () {
    expect(trayMenuSource, contains('let highlightRect = bounds.insetBy('));
    expect(trayMenuSource, contains('roundedRect: highlightRect'));
    expect(trayMenuSource, contains('Metrics.highlightCornerRadius'));
    expect(trayMenuSource, contains('.selectedMenuItemTextColor'));
    expect(trayMenuSource, isNot(contains('bounds.fill()')));
  });

  test('macOS custom menu items preserve checkbox and click behavior', () {
    expect(trayMenuSource, contains('drawCheckmark'));
    expect(trayMenuSource, contains('if !keepsMenuOpen'));
    expect(trayMenuSource, contains('menuItem.menu?.cancelTracking()'));
    expect(trayMenuSource, contains('NSApp.sendAction'));
  });

  test('macOS tray menu updates open menu items in place', () {
    expect(trayMenuSource, contains('public func update(_ args:'));
    expect(trayMenuSource, contains('customView.update('));
    expect(trayMenuSource, contains('submenu.update('));
    expect(
      trayManagerPluginSource,
      contains('trayIcon?.statusItem?.menu === currentMenu'),
    );
    expect(trayManagerPluginSource, contains('currentMenu.update(menuArgs)'));
    expect(trayManagerPluginSource, contains('case "updateMenuItem"'));
    expect(
      trayManagerPluginSource,
      contains('trayMenu?.updateMenuItem(args)'),
    );
  });
}
