import 'package:menu_base/menu_base.dart';

/// Details associated with a native tray menu item activation.
class TrayMenuItemClickDetails {
  const TrayMenuItemClickDetails({
    this.activationTimestamp,
    this.activationToken,
  });

  /// The native input event timestamp, when the platform provides one.
  ///
  /// On Linux this can be forwarded to a window presentation request so the
  /// window manager can associate it with the user's tray menu interaction.
  final int? activationTimestamp;

  /// The Wayland activation token supplied by the system tray host.
  final String? activationToken;
}

typedef TrayMenuItemClickWithDetails = void Function(
  TrayMenuItem menuItem,
  TrayMenuItemClickDetails details,
);

/// The visual style used to render a menu item's secondary label.
enum TrayMenuItemSublabelStyle { badge, muted, destructive, secondary }

/// A keyboard modifier for a native macOS menu item shortcut.
enum TrayMenuItemModifier {
  capsLock,
  command,
  control,
  function,
  option,
  shift,
}

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
    this.onClickWithDetails,
    super.onHighlight,
    super.onLoseHighlight,
    this.sublabelStyle = TrayMenuItemSublabelStyle.badge,
    this.keepsMenuOpen = false,
    this.usesCustomView = true,
    this.keyEquivalent,
    this.keyEquivalentModifiers = const {},
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
    this.onClickWithDetails,
    super.onHighlight,
    super.onLoseHighlight,
    this.sublabelStyle = TrayMenuItemSublabelStyle.badge,
    this.keepsMenuOpen = false,
    this.usesCustomView = true,
    this.keyEquivalent,
    this.keyEquivalentModifiers = const {},
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
    this.onClickWithDetails,
    super.onHighlight,
    super.onLoseHighlight,
    this.sublabelStyle = TrayMenuItemSublabelStyle.badge,
    this.keepsMenuOpen = false,
    this.usesCustomView = true,
    this.keyEquivalent,
    this.keyEquivalentModifiers = const {},
  }) : super.submenu();

  TrayMenuItemSublabelStyle sublabelStyle;
  final bool keepsMenuOpen;
  final bool usesCustomView;
  final String? keyEquivalent;
  final Set<TrayMenuItemModifier> keyEquivalentModifiers;

  /// Invoked with native activation details when available.
  ///
  /// When this callback is set, it is used instead of [onClick].
  final TrayMenuItemClickWithDetails? onClickWithDetails;

  @override
  Map<String, dynamic> toJson() {
    return super.toJson()
      ..addAll({
        if (sublabel != null) 'sublabel': sublabel,
        'sublabelStyle': sublabelStyle.name,
        'usesCustomView': usesCustomView,
        'keepsMenuOpen': keepsMenuOpen,
        if (keyEquivalent != null) 'keyEquivalent': keyEquivalent,
        if (keyEquivalentModifiers.isNotEmpty)
          'keyEquivalentModifiers':
              keyEquivalentModifiers.map((modifier) => modifier.name).toList(),
      });
  }
}
