import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import TelegramBaseController

public final class DebugRequestLogsController: TelegramBaseController {
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

        self.title = "Request Logs"

        let clearButton = UIBarButtonItem(
            title: "Clear",
            style: .plain,
            target: self,
            action: #selector(clearLogs)
        )
        clearButton.setTitleTextAttributes([.foregroundColor: UIColor(rgb: 0xBF7A54)], for: .normal)
        self.navigationItem.rightBarButtonItem = clearButton
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let node = DebugRequestLogsNode()
        node.onEntrySelected = { [weak self] entry in
            guard let self = self else { return }
            let detail = DebugRequestDetailController(context: self.context, entry: entry)
            self.push(detail)
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (self.displayNode as? DebugRequestLogsNode)?.reload()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        (self.displayNode as? DebugRequestLogsNode)?.containerLayoutUpdated(layout, navigationBarHeight: navHeight)
    }

    @objc private func clearLogs() {
        DivoRequestLogger.shared.clear()
        (self.displayNode as? DebugRequestLogsNode)?.reload()
    }
}

// MARK: - Logs List Node

private final class DebugRequestLogsNode: ASDisplayNode {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var entries: [DivoRequestLogEntry] = []

    var onEntrySelected: ((DivoRequestLogEntry) -> Void)?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    override init() {
        super.init()
        self.backgroundColor = UIColor(rgb: 0x000000)
    }

    override func didLoad() {
        super.didLoad()

        tableView.backgroundColor = UIColor(rgb: 0x000000)
        tableView.separatorColor = UIColor(white: 0.2, alpha: 1)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(LogEntryCell.self, forCellReuseIdentifier: "LogEntry")
        self.view.addSubview(tableView)

        reload()
    }

    func reload() {
        entries = DivoRequestLogger.shared.getEntries()
        tableView.reloadData()
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        let bounds = CGRect(origin: .zero, size: layout.size)
        tableView.frame = CGRect(x: 0, y: navigationBarHeight, width: bounds.width, height: bounds.height - navigationBarHeight)
    }
}

extension DebugRequestLogsNode: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogEntry", for: indexPath) as! LogEntryCell
        let entry = entries[indexPath.row]
        cell.configure(with: entry, timeFormatter: DebugRequestLogsNode.timeFormatter)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onEntrySelected?(entries[indexPath.row])
    }
}

// MARK: - Log Entry Cell

private final class LogEntryCell: UITableViewCell {
    private let methodLabel = UILabel()
    private let pathLabel = UILabel()
    private let statusLabel = UILabel()
    private let timeLabel = UILabel()
    private let durationLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = UIColor(rgb: 0x1C1C1E)
        let selectedBg = UIView()
        selectedBg.backgroundColor = UIColor(white: 0.15, alpha: 1)
        selectedBackgroundView = selectedBg

        methodLabel.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        contentView.addSubview(methodLabel)

        pathLabel.font = .systemFont(ofSize: 15, weight: .regular)
        pathLabel.textColor = .white
        pathLabel.lineBreakMode = .byTruncatingMiddle
        contentView.addSubview(pathLabel)

        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        statusLabel.textAlignment = .right
        contentView.addSubview(statusLabel)

        timeLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = UIColor(white: 0.4, alpha: 1)
        contentView.addSubview(timeLabel)

        durationLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        durationLabel.textColor = UIColor(white: 0.4, alpha: 1)
        durationLabel.textAlignment = .right
        contentView.addSubview(durationLabel)
    }

    func configure(with entry: DivoRequestLogEntry, timeFormatter: DateFormatter) {
        methodLabel.text = entry.method
        methodLabel.textColor = colorForMethod(entry.method)

        pathLabel.text = entry.path

        if let code = entry.statusCode {
            statusLabel.text = "\(code)"
            statusLabel.textColor = entry.isSuccess ? UIColor(rgb: 0x34C759) : UIColor(rgb: 0xFF3B30)
        } else if entry.error != nil {
            statusLabel.text = "ERR"
            statusLabel.textColor = UIColor(rgb: 0xFF3B30)
        } else {
            statusLabel.text = "—"
            statusLabel.textColor = UIColor(white: 0.4, alpha: 1)
        }

        timeLabel.text = timeFormatter.string(from: entry.timestamp)
        durationLabel.text = String(format: "%.0fms", entry.duration * 1000)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = contentView.bounds.height
        let w = contentView.bounds.width
        let pad: CGFloat = 16

        methodLabel.frame = CGRect(x: pad, y: 8, width: 60, height: 16)
        statusLabel.frame = CGRect(x: w - pad - 40, y: 8, width: 40, height: 16)
        pathLabel.frame = CGRect(x: pad + 64, y: 6, width: w - pad * 2 - 64 - 48, height: 20)
        timeLabel.frame = CGRect(x: pad, y: h - 22, width: 100, height: 16)
        durationLabel.frame = CGRect(x: w - pad - 60, y: h - 22, width: 60, height: 16)
    }

    private func colorForMethod(_ method: String) -> UIColor {
        switch method.uppercased() {
        case "GET": return UIColor(rgb: 0x34C759)
        case "POST": return UIColor(rgb: 0x5AC8FA)
        case "PUT", "PATCH": return UIColor(rgb: 0xFF9500)
        case "DELETE": return UIColor(rgb: 0xFF3B30)
        default: return UIColor(white: 0.6, alpha: 1)
        }
    }
}

// MARK: - Request Detail Controller

final class DebugRequestDetailController: TelegramBaseController {
    private let entry: DivoRequestLogEntry

    init(context: AccountContext, entry: DivoRequestLogEntry) {
        self.entry = entry
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

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
                strings: NavigationBarStrings(presentationStrings: presentationData.strings)
            )
        )

        self.title = "\(entry.method) \(entry.path)"
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        let node = DebugRequestDetailNode(entry: entry)
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        (self.displayNode as? DebugRequestDetailNode)?.containerLayoutUpdated(layout, navigationBarHeight: navHeight)
    }
}

// MARK: - Request Detail Node

private final class DebugRequestDetailNode: ASDisplayNode {
    private let scrollView = UIScrollView()
    private let textView = UITextView()
    private let entry: DivoRequestLogEntry

    private static let detailTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    init(entry: DivoRequestLogEntry) {
        self.entry = entry
        super.init()
        self.backgroundColor = UIColor(rgb: 0x000000)
    }

    override func didLoad() {
        super.didLoad()

        textView.isEditable = false
        textView.backgroundColor = UIColor(rgb: 0x000000)
        textView.textColor = .white
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        var text = ""
        text += "Method:   \(entry.method)\n"
        text += "Path:     \(entry.path)\n"
        text += "Status:   \(entry.statusCode.map { "\($0)" } ?? "N/A")\n"
        text += "Duration: \(String(format: "%.1fms", entry.duration * 1000))\n"
        text += "Time:     \(DebugRequestDetailNode.detailTimeFormatter.string(from: entry.timestamp))\n"

        if let error = entry.error {
            text += "\n--- ERROR ---\n\(error)\n"
        }

        if let reqBody = entry.requestBody {
            text += "\n--- REQUEST BODY ---\n"
            text += prettyJSON(reqBody)
            text += "\n"
        }

        if let resBody = entry.responseBody {
            text += "\n--- RESPONSE BODY ---\n"
            text += prettyJSON(resBody)
            text += "\n"
        }

        textView.text = text
        self.view.addSubview(textView)
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        let bounds = CGRect(origin: .zero, size: layout.size)
        textView.frame = CGRect(x: 0, y: navigationBarHeight, width: bounds.width, height: bounds.height - navigationBarHeight)
    }

    private func prettyJSON(_ string: String) -> String {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: pretty, encoding: .utf8)
        else {
            return string
        }
        return result
    }
}

