import 'package:menu_base/menu_base.dart';

/// The visual style used to render a menu item's secondary label.
enum TrayMenuItemSublabelStyle { badge, muted, destructive, secondary }

/// A menu item with an optional secondary label.
///
/// Secondary labels are currently rendered by the macOS implementation. Other
/// platforms safely ignore the additional serialized fields.
class TrayMenuItem extends MenuItem {
  TrayMenuItem({
    super.key,
    super.type,
    super.label,
    super.sublabel,
    super.toolTip,
    super.icon,
    super.checked,
    super.disabled,
    super.submenu,
    super.onClick,
    super.onHighlight,
    super.onLoseHighlight,
    this.sublabelStyle = TrayMenuItemSublabelStyle.badge,
    this.keepsMenuOpen = false,
  });

  TrayMenuItem.checkbox({
    super.key,
    super.label,
    super.sublabel,
    super.toolTip,
    super.icon,
    required super.checked,
    super.disabled,
    super.onClick,
    super.onHighlight,
    super.onLoseHighlight,
    this.sublabelStyle = TrayMenuItemSublabelStyle.badge,
    this.keepsMenuOpen = false,
  }) : super.checkbox();

  TrayMenuItem.submenu({
    super.key,
    super.label,
    super.sublabel,
    super.toolTip,
    super.icon,
    super.disabled,
    super.submenu,
    super.onClick,
    super.onHighlight,
    super.onLoseHighlight,
    this.sublabelStyle = TrayMenuItemSublabelStyle.badge,
    this.keepsMenuOpen = false,
  }) : super.submenu();

  TrayMenuItemSublabelStyle sublabelStyle;
  final bool keepsMenuOpen;

  @override
  Map<String, dynamic> toJson() {
    return super.toJson()
      ..addAll({
        if (sublabel != null) 'sublabel': sublabel,
        'sublabelStyle': sublabelStyle.name,
        'usesCustomView': true,
        'keepsMenuOpen': keepsMenuOpen,
      });
  }
}
