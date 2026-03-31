import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import TelegramBaseController

public final class DebugUserInfoController: TelegramBaseController {
    private let context: AccountContext
    private var presentationData: PresentationData

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(
            context: context,
            navigationBarPresentationData: NavigationBarPresentationData(
                theme: DebugTheme.navTheme(),
                strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)
            )
        )

        self.title = "Пользователь"
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let node = DebugUserInfoNode()
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (self.displayNode as? DebugUserInfoNode)?.loadUserInfo()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        (self.displayNode as? DebugUserInfoNode)?.containerLayoutUpdated(layout, navigationBarHeight: navHeight)
    }
}

// MARK: - Node

private final class DebugUserInfoNode: ASDisplayNode, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var rows: [(String, String)] = []
    private var rawJSON: String?

    override init() {
        super.init()
        self.backgroundColor = DebugTheme.background
    }

    override func didLoad() {
        super.didLoad()

        tableView.backgroundColor = DebugTheme.background
        tableView.separatorColor = DebugTheme.separator
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.view.addSubview(tableView)

        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = DebugTheme.accent
        self.view.addSubview(activityIndicator)
    }

    func loadUserInfo() {
        rows = []
        rawJSON = nil
        tableView.reloadData()
        activityIndicator.startAnimating()

        Task { @MainActor in
            do {
                let data: Data = try await DivoAPIClient.shared.requestRawData(
                    path: "/user/info",
                    method: "GET",
                    body: Optional<String>.none
                )

                self.rawJSON = String(data: data, encoding: .utf8)

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataObj = json["data"] as? [String: Any] {
                    self.parseUserInfo(dataObj)
                } else {
                    self.rows = [("Ошибка", "Не удалось распарсить ответ")]
                }
            } catch {
                self.rows = [("Ошибка", error.localizedDescription)]
            }
            self.activityIndicator.stopAnimating()
            self.tableView.reloadData()
        }
    }

    private func parseUserInfo(_ data: [String: Any]) {
        var result: [(String, String)] = []

        if let id = data["id"] { result.append(("ID", "\(id)")) }
        if let name = data["fullName"] as? String { result.append(("Имя", name)) }
        if let phone = data["phone"] as? String { result.append(("Телефон", phone)) }
        if let email = data["email"] as? String { result.append(("Email", email)) }
        if let role = data["role"] as? [String: Any], let title = role["title"] as? String {
            result.append(("Роль", title))
        }
        if let gender = data["gender"] as? String { result.append(("Пол", gender)) }
        if let city = data["city"] as? [String: Any], let title = city["title"] as? String {
            result.append(("Город", title))
        }
        if let country = data["country"] as? [String: Any], let title = country["title"] as? String {
            result.append(("Страна", title))
        }
        if let birthday = data["birthday"] as? String { result.append(("Дата рождения", birthday)) }

        if let params = data["params"] as? [String: Any] {
            if let height = params["height"] { result.append(("Рост", "\(height)")) }
            if let weight = params["weight"] { result.append(("Вес", "\(weight)")) }
            if let bust = params["bust"] { result.append(("Грудь", "\(bust)")) }
            if let waist = params["waist"] { result.append(("Талия", "\(waist)")) }
            if let hips = params["hips"] { result.append(("Бёдра", "\(hips)")) }
            if let shoes = params["shoes"] { result.append(("Обувь", "\(shoes)")) }
        }

        rows = result
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        let bounds = CGRect(origin: .zero, size: layout.size)
        tableView.frame = CGRect(x: 0, y: navigationBarHeight, width: bounds.width, height: bounds.height - navigationBarHeight)
        activityIndicator.center = CGPoint(x: bounds.midX, y: navigationBarHeight + 60)
    }

    // MARK: - UITableView

    func numberOfSections(in tableView: UITableView) -> Int {
        return rows.isEmpty ? 0 : 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return rows.count }
        return rawJSON != nil ? 1 : 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return "ДАННЫЕ ПОЛЬЗОВАТЕЛЯ" }
        return "RAW JSON"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.backgroundColor = DebugTheme.cellBackground
            let row = rows[indexPath.row]
            cell.textLabel?.text = row.0
            cell.textLabel?.textColor = DebugTheme.primaryText
            cell.textLabel?.font = .systemFont(ofSize: 15)
            cell.detailTextLabel?.text = row.1
            cell.detailTextLabel?.textColor = DebugTheme.secondaryText
            cell.detailTextLabel?.font = .systemFont(ofSize: 15)
            cell.selectionStyle = .none
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.backgroundColor = DebugTheme.cellBackground
            cell.textLabel?.text = "Скопировать JSON"
            cell.textLabel?.textColor = DebugTheme.accent
            cell.textLabel?.textAlignment = .center
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1, let json = rawJSON {
            UIPasteboard.general.string = json
            if let cell = tableView.cellForRow(at: indexPath) {
                let original = cell.textLabel?.text
                cell.textLabel?.text = "Скопировано!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    cell.textLabel?.text = original
                }
            }
        }
    }
}
