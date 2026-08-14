import AppKit
//
//  TrayIcon.swift
//  tray_manager
//
//  Created by Lijy91 on 2022/5/15.
//

class SpeedTextView: NSView {
    var attributedString: NSAttributedString? {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 42, height: NSView.noIntrinsicMetric)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let attributedString = attributedString else {
            return
        }
        let textBounds = attributedString.boundingRect(
            with: NSSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let y = max((bounds.height - textBounds.height) / 2, 0)
        attributedString.draw(
            in: NSRect(x: 0, y: y, width: bounds.width, height: ceil(textBounds.height))
        )
    }
}

public class TrayIcon: NSView {
    public var onTrayIconMouseDown:(() -> Void)?
    public var onTrayIconMouseUp:(() -> Void)?
    public var onTrayIconRightMouseDown:(() -> Void)?
    public var onTrayIconRightMouseUp:(() -> Void)?
    
    var statusItem: NSStatusItem?
    
    var textAttributes: [NSAttributedString.Key : Any]?
    
    private let imageView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyDown
        iv.isHidden = true
        iv.setContentHuggingPriority(.required, for: .horizontal)
        return iv
    }()
    
    private let textView: SpeedTextView = {
        let view = SpeedTextView()
        view.isHidden = true
        return view
    }()
    
    private let stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.distribution = .equalSpacing
        return stack
    }()

    private var stackLeadingConstraint: NSLayoutConstraint!
    private var stackTrailingConstraint: NSLayoutConstraint!
    private var stackTopConstraint: NSLayoutConstraint!
    private var stackBottomConstraint: NSLayoutConstraint!
    
    
    public init() {
        super.init(frame: NSRect.zero)
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        statusItem?.autosaveName = "\(Bundle.main.bundleIdentifier ?? "tray_manager").statusItem"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.maximumLineHeight = 9.5
        paragraphStyle.minimumLineHeight = 9.5
        paragraphStyle.alignment = .right
        paragraphStyle.lineBreakMode = .byClipping
        
        textAttributes = [
            .paragraphStyle: paragraphStyle,
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.textColor,
        ]
        
        if let button = statusItem?.button {
            button.addSubview(self)
            self.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                self.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                self.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                self.topAnchor.constraint(equalTo: button.topAnchor),
                self.bottomAnchor.constraint(equalTo: button.bottomAnchor),
                self.heightAnchor.constraint(equalToConstant: NSStatusBar.system.thickness),
            ])
            setupView()
        }
    }
    
    private func setupView() {
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackLeadingConstraint = stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6)
        stackTrailingConstraint = stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6)
        stackTopConstraint = stackView.topAnchor.constraint(equalTo: topAnchor, constant: 0)
        stackBottomConstraint = stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)
        NSLayoutConstraint.activate([
            stackLeadingConstraint,
            stackTrailingConstraint,
            stackTopConstraint,
            stackBottomConstraint,
        ])
        
        applyImagePosition("left")
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.widthAnchor.constraint(equalToConstant: 42),
        ])
    }
    
    
    override init(frame frameRect: NSRect) {
        super.init(frame:frameRect);
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setImage(_ image: NSImage, _ imagePosition: String) {
        let wasHidden = imageView.isHidden
        let previousSize = imageView.image?.size ?? NSSize.zero
        let sizeChanged = previousSize.width != image.size.width || previousSize.height != image.size.height
        imageView.image = image
        imageView.isHidden = false
        applyImagePosition(imagePosition)
        if wasHidden != imageView.isHidden || sizeChanged, let button = statusItem?.button {
            button.sizeToFit()
        }
    }
    
    public func setImagePosition(_ imagePosition: String) {
        applyImagePosition(imagePosition)
        needsLayout = true
    }
    
    public func removeImage() {
        let wasHidden = imageView.isHidden
        imageView.image = nil
        imageView.isHidden = true
        if wasHidden != imageView.isHidden, let button = statusItem?.button {
            button.sizeToFit()
        }
    }
    
    public func setTitle(_ title: String) {
        let wasHidden = textView.isHidden
        let hasTitle = !title.isEmpty
        textView.attributedString = title.isEmpty
            ? nil
            : NSAttributedString(string: title, attributes: textAttributes)
        textView.isHidden = !hasTitle
        updateInsets(hasTitle: hasTitle)
        if wasHidden != textView.isHidden, let button = statusItem?.button {
            button.sizeToFit()
        }
    }

    private func updateInsets(hasTitle: Bool) {
        stackLeadingConstraint.constant = hasTitle ? 4 : 6
        stackTrailingConstraint.constant = hasTitle ? -8 : -6
        stackTopConstraint.constant = 0
        stackBottomConstraint.constant = 0
    }

    private func applyImagePosition(_ imagePosition: String) {
        let views = imagePosition == "right"
            ? [textView, imageView]
            : [imageView, textView]

        if stackView.arrangedSubviews == views {
            return
        }

        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
        }
        for (index, view) in views.enumerated() {
            stackView.insertArrangedSubview(view, at: index)
        }
    }
    
    public func setToolTip(_ toolTip: String) {
        if let button = statusItem?.button {
            button.toolTip  = toolTip
        }
    }
    
    public override func mouseDown(with event: NSEvent) {
        statusItem?.button?.highlight(true)
        self.onTrayIconMouseDown!()
    }
    
    public override func mouseUp(with event: NSEvent) {
        statusItem?.button?.highlight(false)
        self.onTrayIconMouseUp!()
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        self.onTrayIconRightMouseDown!()
    }
    
    public override func rightMouseUp(with event: NSEvent) {
        self.onTrayIconRightMouseUp!()
    }
}
