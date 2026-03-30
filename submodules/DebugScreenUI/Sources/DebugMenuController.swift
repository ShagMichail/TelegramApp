import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import TelegramBaseController

public final class DebugMenuController: TelegramBaseController {
    private let context: AccountContext
    private var presentationData: PresentationData

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let navTheme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: .white,
            disabledButtonColor: UIColor(white: 0.5, alpha: 1),
            primaryTextColor: .white,
            backgroundColor: UIColor(rgb: 0x1C1C1E),
            opaqueBackgroundColor: UIColor(rgb: 0x1C1C1E),
            enableBackgroundBlur: false,
            separatorColor: UIColor(white: 0.3, alpha: 1),
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear
        )
        super.init(
            context: context,
            navigationBarPresentationData: NavigationBarPresentationData(
                theme: navTheme,
                strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)
            )
        )

        self.title = "Debug"
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let node = DebugMenuNode()
        node.onItemSelected = { [weak self] item in
            self?.handleSelection(item)
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        (self.displayNode as? DebugMenuNode)?.containerLayoutUpdated(layout, navigationBarHeight: navHeight)
    }

    private func handleSelection(_ item: DebugMenuItem) {
        switch item {
        case .accessToken:
            let controller = DebugTokenController(context: context)
            self.push(controller)
        case .requestLogs:
            let controller = DebugRequestLogsController(context: context)
            self.push(controller)
        case .appInfo:
            break
        }
    }
}

// MARK: - Menu Items

enum DebugMenuItem {
    case accessToken
    case requestLogs
    case appInfo
}

// MARK: - Node

private final class DebugMenuNode: ASDisplayNode {
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private let tokenCell = DebugMenuCell()
    private let logsCell = DebugMenuCell()
    private let infoSection = DebugInfoSection()

    var onItemSelected: ((DebugMenuItem) -> Void)?

    override init() {
        super.init()
        self.backgroundColor = UIColor(rgb: 0x000000)
    }

    override func didLoad() {
        super.didLoad()

        scrollView.alwaysBounceVertical = true
        self.view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 1
        scrollView.addSubview(stackView)

        // Token cell
        tokenCell.configure(
            icon: "key.fill",
            title: "Access Token",
            subtitle: currentTokenLabel()
        )
        tokenCell.onTap = { [weak self] in
            self?.onItemSelected?(.accessToken)
        }
        stackView.addArrangedSubview(tokenCell)

        // Logs cell
        let logsCount = DivoRequestLogger.shared.getEntries().count
        logsCell.configure(
            icon: "list.bullet.rectangle",
            title: "Request Logs",
            subtitle: "\(logsCount) entries"
        )
        logsCell.onTap = { [weak self] in
            self?.onItemSelected?(.requestLogs)
        }
        stackView.addArrangedSubview(logsCell)

        // Spacer
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stackView.addArrangedSubview(spacer)

        // Info section
        infoSection.configure()
        stackView.addArrangedSubview(infoSection)
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        let bounds = CGRect(origin: .zero, size: layout.size)
        scrollView.frame = CGRect(x: 0, y: navigationBarHeight, width: bounds.width, height: bounds.height - navigationBarHeight)

        let insets = layout.safeInsets
        let width = bounds.width
        stackView.frame = CGRect(x: 0, y: 0, width: width, height: 10000)
        stackView.layoutIfNeeded()
        let contentHeight = stackView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        stackView.frame = CGRect(x: 0, y: 0, width: width, height: contentHeight)
        scrollView.contentSize = CGSize(width: width, height: contentHeight + insets.bottom + 20)
    }

    private func currentTokenLabel() -> String {
        let token = DivoConfig.accessToken
        if token == DivoConfig.agencyToken {
            return "Agency"
        } else if token == DivoConfig.modelToken {
            return "Model"
        } else {
            return "Custom"
        }
    }
}

// MARK: - Menu Cell

private final class DebugMenuCell: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevron = UIImageView()

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = UIColor(rgb: 0x1C1C1E)

        iconView.tintColor = UIColor(rgb: 0xBF7A54)
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 17, weight: .regular)
        titleLabel.textColor = .white
        addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = UIColor(white: 0.5, alpha: 1)
        addSubview(subtitleLabel)

        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = UIColor(white: 0.4, alpha: 1)
        chevron.contentMode = .scaleAspectFit
        addSubview(chevron)

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)

        heightAnchor.constraint(equalToConstant: 56).isActive = true
    }

    func configure(icon: String, title: String, subtitle: String) {
        iconView.image = UIImage(systemName: icon)
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        let pad: CGFloat = 16
        iconView.frame = CGRect(x: pad, y: (h - 24) / 2, width: 24, height: 24)
        chevron.frame = CGRect(x: bounds.width - pad - 12, y: (h - 16) / 2, width: 12, height: 16)
        subtitleLabel.sizeToFit()
        let subW = subtitleLabel.frame.width
        subtitleLabel.frame = CGRect(x: chevron.frame.minX - subW - 8, y: (h - 20) / 2, width: subW, height: 20)
        let textX = iconView.frame.maxX + 12
        titleLabel.frame = CGRect(x: textX, y: (h - 22) / 2, width: subtitleLabel.frame.minX - textX - 8, height: 22)
    }

    @objc private func tapped() {
        UIView.animate(withDuration: 0.1, animations: {
            self.alpha = 0.5
        }) { _ in
            UIView.animate(withDuration: 0.15) { self.alpha = 1 }
        }
        onTap?()
    }
}

// MARK: - Info Section

private final class DebugInfoSection: UIView {
    private let headerLabel = UILabel()
    private let infoStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .clear

        headerLabel.font = .systemFont(ofSize: 13, weight: .regular)
        headerLabel.textColor = UIColor(white: 0.45, alpha: 1)
        headerLabel.text = "APP INFO"
        addSubview(headerLabel)

        infoStack.axis = .vertical
        infoStack.spacing = 0
        infoStack.backgroundColor = UIColor(rgb: 0x1C1C1E)
        infoStack.layer.cornerRadius = 10
        infoStack.clipsToBounds = true
        addSubview(infoStack)
    }

    func configure() {
        let items: [(String, String)] = [
            ("Base URL", DivoConfig.baseURL.absoluteString),
            ("Version", DivoConfig.appVersion),
            ("Platform", DivoConfig.appPlatform),
            ("Bundle ID", Bundle.main.bundleIdentifier ?? "—"),
            ("Device", deviceName()),
            ("iOS", UIDevice.current.systemVersion),
        ]

        for (i, item) in items.enumerated() {
            let row = makeInfoRow(label: item.0, value: item.1)
            infoStack.addArrangedSubview(row)
            if i < items.count - 1 {
                let sep = UIView()
                sep.backgroundColor = UIColor(white: 0.25, alpha: 1)
                sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                infoStack.addArrangedSubview(sep)
            }
        }

        setNeedsLayout()
    }

    private func makeInfoRow(label: String, value: String) -> UIView {
        let row = UIView()
        row.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let labelView = UILabel()
        labelView.font = .systemFont(ofSize: 15, weight: .regular)
        labelView.textColor = .white
        labelView.text = label
        row.addSubview(labelView)

        let valueView = UILabel()
        valueView.font = .systemFont(ofSize: 15, weight: .regular)
        valueView.textColor = UIColor(white: 0.5, alpha: 1)
        valueView.text = value
        valueView.textAlignment = .right
        row.addSubview(valueView)

        labelView.translatesAutoresizingMaskIntoConstraints = false
        valueView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            labelView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            labelView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueView.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            valueView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueView.leadingAnchor.constraint(greaterThanOrEqualTo: labelView.trailingAnchor, constant: 8),
        ])

        return row
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let pad: CGFloat = 16
        headerLabel.frame = CGRect(x: pad + 4, y: 0, width: bounds.width - pad * 2, height: 30)
        infoStack.frame = CGRect(x: pad, y: 30, width: bounds.width - pad * 2, height: infoStack.systemLayoutSizeFitting(
            CGSize(width: bounds.width - pad * 2, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height)
    }

    override var intrinsicContentSize: CGSize {
        let pad: CGFloat = 16
        let stackHeight = infoStack.systemLayoutSizeFitting(
            CGSize(width: UIScreen.main.bounds.width - pad * 2, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        return CGSize(width: UIView.noIntrinsicMetric, height: 30 + stackHeight + 16)
    }

    private func deviceName() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        return String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters) ?? UIDevice.current.model
    }
}

