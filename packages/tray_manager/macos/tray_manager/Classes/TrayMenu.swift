//
//  TrayMenu.swift
//  tray_manager
//
//  Created by Lijy91 on 2022/5/8.
//

import AppKit

private enum TrayMenuItemSublabelStyle: String {
    case badge
    case muted
    case destructive
    case secondary
}

private final class TrayMenuItemView: NSView {
    private enum Metrics {
        static let height: CGFloat = 24
        static let minimumWidth: CGFloat = 270
        static let maximumWidth: CGFloat = 520
        static let checkmarkLeading: CGFloat = 7
        static let titleLeading: CGFloat = 25
        static let titleBadgeSpacing: CGFloat = 18
        static let trailing: CGFloat = 9
        static let badgeHeight: CGFloat = 18
        static let badgeHorizontalPadding: CGFloat = 7
        static let submenuIndicatorWidth: CGFloat = 14
        static let minimumTitleWidth: CGFloat = 60
    }

    private var label: String
    private var sublabel: String?
    private var sublabelStyle: TrayMenuItemSublabelStyle
    private var checked: Bool
    private var keepsMenuOpen: Bool
    private var hasSubmenu: Bool
    private var pointerInside = false
    private var trackingAreaReference: NSTrackingArea?

    private let titleFont = NSFont.menuFont(ofSize: 0)
    private let badgeFont = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.smallSystemFontSize,
        weight: .medium
    )

    init(
        label: String,
        sublabel: String?,
        sublabelStyle: TrayMenuItemSublabelStyle,
        checked: Bool,
        keepsMenuOpen: Bool,
        hasSubmenu: Bool
    ) {
        self.label = label
        self.sublabel = sublabel
        self.sublabelStyle = sublabelStyle
        self.checked = checked
        self.keepsMenuOpen = keepsMenuOpen
        self.hasSubmenu = hasSubmenu
        super.init(
            frame: NSRect(
                x: 0,
                y: 0,
                width: Metrics.minimumWidth,
                height: Metrics.height
            )
        )
        frame.size.width = preferredWidth
    }

    func update(
        label: String,
        sublabel: String?,
        sublabelStyle: TrayMenuItemSublabelStyle,
        checked: Bool,
        keepsMenuOpen: Bool,
        hasSubmenu: Bool
    ) {
        self.label = label
        self.sublabel = sublabel
        self.sublabelStyle = sublabelStyle
        self.checked = checked
        self.keepsMenuOpen = keepsMenuOpen
        self.hasSubmenu = hasSubmenu
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    func updateMenuItem(
        label: String?,
        sublabel: String?,
        sublabelStyle: TrayMenuItemSublabelStyle?,
        checked: Bool?
    ) {
        if let label {
            self.label = label
        }
        if let sublabel {
            self.sublabel = sublabel
        }
        if let sublabelStyle {
            self.sublabelStyle = sublabelStyle
        }
        if let checked {
            self.checked = checked
        }
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: preferredWidth, height: Metrics.height)
    }

    var preferredWidth: CGFloat {
        let titleWidth = ceil(
            (label as NSString).size(withAttributes: [.font: titleFont]).width
        )
        let sublabelWidth = sublabelSize.map {
            Metrics.titleBadgeSpacing + $0.width
        } ?? 0
        let submenuWidth = hasSubmenu ? Metrics.submenuIndicatorWidth : 0
        return min(
            Metrics.maximumWidth,
            max(
                Metrics.minimumWidth,
                Metrics.titleLeading
                    + titleWidth
                    + sublabelWidth
                    + submenuWidth
                    + Metrics.trailing
            )
        )
    }

    private var sublabelSize: NSSize? {
        guard let sublabel, !sublabel.isEmpty else {
            return nil
        }
        let font = sublabelStyle == .secondary ? titleFont : badgeFont
        let textSize = (sublabel as NSString).size(
            withAttributes: [.font: font]
        )
        if sublabelStyle == .secondary {
            return NSSize(
                width: ceil(textSize.width),
                height: ceil(textSize.height)
            )
        }
        return NSSize(
            width: ceil(textSize.width) + Metrics.badgeHorizontalPadding * 2,
            height: Metrics.badgeHeight
        )
    }

    override func updateTrackingAreas() {
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        pointerInside = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        pointerInside = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard
            let menuItem = enclosingMenuItem,
            menuItem.isEnabled,
            let action = menuItem.action
        else {
            return
        }
        if hasSubmenu {
            return
        }
        if !keepsMenuOpen {
            menuItem.menu?.cancelTracking()
        }
        NSApp.sendAction(action, to: menuItem.target, from: menuItem)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let menuItem = enclosingMenuItem else {
            return
        }
        let highlighted = menuItem.isEnabled
            && (pointerInside || menuItem.isHighlighted)
        if highlighted {
            if #available(macOS 10.14, *) {
                NSColor.selectedContentBackgroundColor.setFill()
            } else {
                NSColor.alternateSelectedControlColor.setFill()
            }
            bounds.fill()
        }

        drawCheckmark(highlighted: highlighted, enabled: menuItem.isEnabled)
        drawTitle(highlighted: highlighted, enabled: menuItem.isEnabled)
        drawSublabel(highlighted: highlighted, enabled: menuItem.isEnabled)
        drawSubmenuIndicator(highlighted: highlighted, enabled: menuItem.isEnabled)
    }

    private func drawCheckmark(highlighted: Bool, enabled: Bool) {
        guard checked else {
            return
        }
        let color: NSColor
        if !enabled {
            color = .tertiaryLabelColor
        } else if highlighted {
            color = .alternateSelectedControlTextColor
        } else {
            color = .labelColor
        }
        let font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let text = "✓" as NSString
        let size = text.size(withAttributes: [.font: font])
        text.draw(
            at: NSPoint(
                x: Metrics.checkmarkLeading,
                y: (bounds.height - size.height) / 2
            ),
            withAttributes: [
                .font: font,
                .foregroundColor: color,
            ]
        )
    }

    private func drawTitle(highlighted: Bool, enabled: Bool) {
        let color: NSColor
        if !enabled {
            color = .tertiaryLabelColor
        } else if highlighted {
            color = .alternateSelectedControlTextColor
        } else {
            color = .labelColor
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        let textHeight = ceil(
            (label as NSString).size(withAttributes: attributes).height
        )
        let titleTrailing = sublabelFrame.map {
            $0.minX - Metrics.titleBadgeSpacing
        } ?? (
            bounds.width
                - Metrics.trailing
                - (hasSubmenu ? Metrics.submenuIndicatorWidth : 0)
        )
        let titleRect = NSRect(
            x: Metrics.titleLeading,
            y: (bounds.height - textHeight) / 2,
            width: max(0, titleTrailing - Metrics.titleLeading),
            height: textHeight
        )
        (label as NSString).draw(in: titleRect, withAttributes: attributes)
    }

    private var sublabelFrame: NSRect? {
        guard let size = sublabelSize else {
            return nil
        }
        let indicatorWidth = hasSubmenu ? Metrics.submenuIndicatorWidth : 0
        let trailing = Metrics.trailing + indicatorWidth
        let maximumWidth = max(
            0,
            bounds.width
                - Metrics.titleLeading
                - Metrics.minimumTitleWidth
                - Metrics.titleBadgeSpacing
                - trailing
        )
        let width = min(size.width, maximumWidth)
        return NSRect(
            x: bounds.width - trailing - width,
            y: (bounds.height - size.height) / 2,
            width: width,
            height: size.height
        )
    }

    private func drawSublabel(highlighted: Bool, enabled: Bool) {
        guard let sublabel, let frame = sublabelFrame else {
            return
        }
        if sublabelStyle == .secondary {
            let color: NSColor
            if !enabled {
                color = .tertiaryLabelColor
            } else if highlighted {
                color = .alternateSelectedControlTextColor
            } else {
                color = .secondaryLabelColor
            }
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right
            paragraphStyle.lineBreakMode = .byTruncatingTail
            (sublabel as NSString).draw(
                in: frame,
                withAttributes: [
                    .font: titleFont,
                    .foregroundColor: color,
                    .paragraphStyle: paragraphStyle,
                ]
            )
            return
        }
        let backgroundColor: NSColor
        let foregroundColor: NSColor
        switch sublabelStyle {
        case .badge:
            backgroundColor = NSColor(
                calibratedRed: 0.20,
                green: 0.80,
                blue: 0.04,
                alpha: enabled ? 1 : 0.45
            )
            foregroundColor = .white
        case .muted:
            backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(
                enabled ? 0.18 : 0.10
            )
            foregroundColor = enabled ? .secondaryLabelColor : .tertiaryLabelColor
        case .destructive:
            backgroundColor = NSColor.systemRed.withAlphaComponent(
                enabled ? 1 : 0.45
            )
            foregroundColor = .white
        case .secondary:
            return
        }
        backgroundColor.setFill()
        NSBezierPath(
            roundedRect: frame,
            xRadius: 4,
            yRadius: 4
        ).fill()

        let text = sublabel as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: foregroundColor,
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(
                x: frame.midX - textSize.width / 2,
                y: frame.midY - textSize.height / 2
            ),
            withAttributes: attributes
        )
    }

    private func drawSubmenuIndicator(highlighted: Bool, enabled: Bool) {
        guard hasSubmenu else {
            return
        }
        let color: NSColor
        if !enabled {
            color = .tertiaryLabelColor
        } else if highlighted {
            color = .alternateSelectedControlTextColor
        } else {
            color = .labelColor
        }
        let font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        let text = "›" as NSString
        let size = text.size(withAttributes: [.font: font])
        text.draw(
            at: NSPoint(
                x: bounds.width - Metrics.trailing - size.width,
                y: (bounds.height - size.height) / 2
            ),
            withAttributes: [
                .font: font,
                .foregroundColor: color,
            ]
        )
    }
}

public class TrayMenu: NSMenu, NSMenuDelegate {
    public var onMenuItemClick: ((NSMenuItem) -> Void)?

    public override init(title: String) {
        super.init(title: title)
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    public init(_ args: [String: Any]) {
        super.init(title: "")

        let items = args["items"] as? [NSDictionary] ?? []
        var customViews: [TrayMenuItemView] = []
        for item in items {
            let itemDict = item as? [String: Any] ?? [:]
            let type = itemDict["type"] as? String ?? "normal"
            let menuItem = type == "separator"
                ? NSMenuItem.separator()
                : NSMenuItem()
            let id = itemDict["id"] as? Int ?? -1
            let label = itemDict["label"] as? String ?? ""
            let sublabel = itemDict["sublabel"] as? String
            let sublabelStyleName = itemDict["sublabelStyle"] as? String ?? "badge"
            let sublabelStyle = TrayMenuItemSublabelStyle(
                rawValue: sublabelStyleName
            ) ?? .badge
            let usesCustomView = itemDict["usesCustomView"] as? Bool
                ?? (sublabel?.isEmpty == false)
            let keepsMenuOpen = itemDict["keepsMenuOpen"] as? Bool ?? false
            let toolTip = itemDict["toolTip"] as? String ?? ""
            let checked = itemDict["checked"] as? Bool
            let disabled = itemDict["disabled"] as? Bool ?? true

            menuItem.tag = id
            menuItem.representedObject = itemDict["key"] as? String
            menuItem.title = label
            menuItem.toolTip = toolTip
            menuItem.isEnabled = !disabled
            menuItem.action = !disabled ? #selector(statusItemMenuButtonClicked) : nil
            menuItem.target = self

            switch type {
            case "separator":
                break
            case "submenu":
                if let submenuDict = itemDict["submenu"] as? NSDictionary {
                    let submenu = TrayMenu(submenuDict as? [String: Any] ?? [:])
                    submenu.onMenuItemClick = { [weak self] menuItem in
                        self?.statusItemMenuButtonClicked(menuItem)
                    }
                    setSubmenu(submenu, for: menuItem)
                }
            case "checkbox":
                if let checked {
                    menuItem.state = checked ? .on : .off
                } else {
                    menuItem.state = .mixed
                }
            default:
                break
            }

            if usesCustomView, type != "separator" {
                let customView = TrayMenuItemView(
                    label: label,
                    sublabel: sublabel,
                    sublabelStyle: sublabelStyle,
                    checked: checked == true,
                    keepsMenuOpen: keepsMenuOpen,
                    hasSubmenu: type == "submenu"
                )
                menuItem.view = customView
                customViews.append(customView)
            }
            addItem(menuItem)
        }

        updateCustomViewWidths(customViews)
        delegate = self
    }

    @discardableResult
    public func update(_ args: [String: Any]) -> Bool {
        let itemArguments = args["items"] as? [NSDictionary] ?? []
        guard itemArguments.count == items.count else {
            return false
        }

        var customViews: [TrayMenuItemView] = []
        for (index, item) in itemArguments.enumerated() {
            let itemDict = item as? [String: Any] ?? [:]
            let menuItem = items[index]
            let type = itemDict["type"] as? String ?? "normal"
            guard menuItem.isSeparatorItem == (type == "separator") else {
                return false
            }

            let id = itemDict["id"] as? Int ?? -1
            let label = itemDict["label"] as? String ?? ""
            let sublabel = itemDict["sublabel"] as? String
            let styleName = itemDict["sublabelStyle"] as? String ?? "badge"
            let style = TrayMenuItemSublabelStyle(rawValue: styleName) ?? .badge
            let usesCustomView = itemDict["usesCustomView"] as? Bool
                ?? (sublabel?.isEmpty == false)
            let keepsMenuOpen = itemDict["keepsMenuOpen"] as? Bool ?? false
            let checked = itemDict["checked"] as? Bool
            let disabled = itemDict["disabled"] as? Bool ?? true

            menuItem.tag = id
            menuItem.representedObject = itemDict["key"] as? String
            menuItem.title = label
            menuItem.toolTip = itemDict["toolTip"] as? String ?? ""
            menuItem.isEnabled = !disabled
            menuItem.action = !disabled
                ? #selector(statusItemMenuButtonClicked)
                : nil
            menuItem.target = self

            if type == "checkbox" {
                if let checked {
                    menuItem.state = checked ? .on : .off
                } else {
                    menuItem.state = .mixed
                }
            }

            if type == "submenu" {
                guard
                    let submenuArguments = itemDict["submenu"] as? NSDictionary,
                    let submenu = menuItem.submenu as? TrayMenu,
                    submenu.update(submenuArguments as? [String: Any] ?? [:])
                else {
                    return false
                }
            }

            if usesCustomView, type != "separator" {
                let customView: TrayMenuItemView
                if let existingView = menuItem.view as? TrayMenuItemView {
                    customView = existingView
                    customView.update(
                        label: label,
                        sublabel: sublabel,
                        sublabelStyle: style,
                        checked: checked == true,
                        keepsMenuOpen: keepsMenuOpen,
                        hasSubmenu: type == "submenu"
                    )
                } else {
                    customView = TrayMenuItemView(
                        label: label,
                        sublabel: sublabel,
                        sublabelStyle: style,
                        checked: checked == true,
                        keepsMenuOpen: keepsMenuOpen,
                        hasSubmenu: type == "submenu"
                    )
                    menuItem.view = customView
                }
                customViews.append(customView)
            } else {
                menuItem.view = nil
            }
        }

        updateCustomViewWidths(customViews)
        return true
    }

    @discardableResult
    public func updateMenuItem(_ args: [String: Any]) -> Bool {
        guard let key = args["key"] as? String else {
            return false
        }
        for menuItem in items {
            if menuItem.representedObject as? String == key {
                let label = args["label"] as? String
                let sublabel = args["sublabel"] as? String
                let style = (args["sublabelStyle"] as? String).flatMap(
                    TrayMenuItemSublabelStyle.init(rawValue:)
                )
                let checked = args["checked"] as? Bool
                if let label {
                    menuItem.title = label
                }
                if let disabled = args["disabled"] as? Bool {
                    menuItem.isEnabled = !disabled
                    menuItem.action = !disabled
                        ? #selector(statusItemMenuButtonClicked)
                        : nil
                }
                if let checked {
                    menuItem.state = checked ? .on : .off
                }
                if let customView = menuItem.view as? TrayMenuItemView {
                    customView.updateMenuItem(
                        label: label,
                        sublabel: sublabel,
                        sublabelStyle: style,
                        checked: checked
                    )
                }
                updateCustomViewWidths(
                    items.compactMap { $0.view as? TrayMenuItemView }
                )
                return true
            }
            if let submenu = menuItem.submenu as? TrayMenu,
               submenu.updateMenuItem(args) {
                return true
            }
        }
        return false
    }

    private func updateCustomViewWidths(_ customViews: [TrayMenuItemView]) {
        let customViewWidth = customViews
            .map(\.preferredWidth)
            .max() ?? 0
        for customView in customViews {
            customView.frame.size.width = customViewWidth
            customView.needsDisplay = true
        }
    }

    @objc func statusItemMenuButtonClicked(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            return
        }
        onMenuItemClick?(menuItem)
    }

    // NSMenuDelegate

    public func menuDidClose(_ menu: NSMenu) {}
}
