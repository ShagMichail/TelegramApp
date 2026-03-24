import UIKit
import AsyncDisplayKit
import Display

final class DropdownNode: ASDisplayNode {
    
    private let backgroundNode: ASDisplayNode
    private let apperTitleNode: ASTextNode
    private let titleNode: ASTextNode
    private let arrowNode: ASImageNode
    
    var options: [String]
    private let placeholder: String
    private let title: String
    
    var onSelect: ((String) -> Void)?
    var selectedValue: String? {
        didSet {
            updateTitleText()
        }
    }
    
    init(title: String, placeholder: String, options: [String]) {
        self.title = title
        self.placeholder = placeholder
        self.options = options
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.borderWidth = 1.0
        self.backgroundNode.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        self.backgroundNode.cornerRadius = 10.0
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 1
        
        self.arrowNode = ASImageNode()
        self.arrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextDownArrow"), color: .white)
        self.arrowNode.contentMode = .center
        
        self.apperTitleNode = ASTextNode()
        self.apperTitleNode.maximumNumberOfLines = 1
        self.apperTitleNode.attributedText = NSAttributedString(string: title, font: Font.regular(14.0), textColor: .white.withAlphaComponent(0.6))
        
        super.init()
        
        self.addSubnode(apperTitleNode)
        self.addSubnode(backgroundNode)
        self.addSubnode(titleNode)
        self.addSubnode(arrowNode)
        
        updateTitleText()
    }
    
    override func didLoad() {
        super.didLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        self.view.addGestureRecognizer(tap)
        self.isUserInteractionEnabled = true
    }
    
    private func updateTitleText() {
        let text = selectedValue ?? placeholder
        let color: UIColor = selectedValue == nil ? UIColor.white.withAlphaComponent(0.4) : .white
        titleNode.attributedText = NSAttributedString(string: text, font: Font.regular(16.0), textColor: color)
        setNeedsLayout()
    }
    
    @objc private func tapped() {
        guard !options.isEmpty else { return }
        guard let viewController = findViewController() else { return }
        
        let sheet = DropdownListSheetController(
            title: title,
            options: options,
            selectedValue: selectedValue
        ) { [weak self] selected in
            self?.selectedValue = selected
            self?.onSelect?(selected)
        }
        viewController.present(sheet, animated: true)
    }
    
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self.view
        while let next = responder?.next {
            if let vc = next as? UIViewController {
                return vc
            }
            responder = next
        }
        return nil
    }
    
    override func layout() {
        super.layout()
        backgroundNode.frame = bounds
        
        let arrowSize = CGSize(width: 20, height: 20)
        arrowNode.frame = CGRect(x: bounds.width - 16 - arrowSize.width,
                                 y: (bounds.height - arrowSize.height) / 2.0,
                                 width: arrowSize.width,
                                 height: arrowSize.height)
        
        let titleSize = titleNode.measure(CGSize(width: bounds.width - 32 - arrowSize.width - 10, height: .greatestFiniteMagnitude))
        titleNode.frame = CGRect(x: 16,
                                 y: (bounds.height - titleSize.height) / 2.0,
                                 width: titleSize.width,
                                 height: titleSize.height)
        
        let apperTitleSize = apperTitleNode.measure(CGSize(width: bounds.width - 32 - arrowSize.width - 10, height: .greatestFiniteMagnitude))
        apperTitleNode.frame = CGRect(x: bounds.width - 16 - arrowSize.width - apperTitleSize.width,
                                 y: (bounds.height - apperTitleSize.height) / 2.0,
                                 width: apperTitleSize.width,
                                 height: apperTitleSize.height)
    }
}


// MARK: - Sheet Controller

private final class DropdownListSheetController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let options: [String]
    private let selectedValue: String?
    private let onSelect: (String) -> Void
    private let sheetTitle: String
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let titleLabel = UILabel()
    private let handleView = UIView()
    
    private let cellReuseId = "OptionCell"
    private let accentColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
    
    init(title: String, options: [String], selectedValue: String?, onSelect: @escaping (String) -> Void) {
        self.sheetTitle = title
        self.options = options
        self.selectedValue = selectedValue
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
        
        modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *), let sheet = sheetPresentationController {
            let rowHeight: CGFloat = 52
            let headerHeight: CGFloat = 56
            let bottomPadding: CGFloat = 34
            let totalHeight = headerHeight + rowHeight * CGFloat(min(options.count, 8)) + bottomPadding
            
            if #available(iOS 16.0, *) {
                sheet.detents = [.custom { _ in totalHeight }]
            } else {
                sheet.detents = [.medium()]
            }
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 20
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)
        
        handleView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        handleView.layer.cornerRadius = 2.5
        handleView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(handleView)
        
        titleLabel.text = sheetTitle
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseId)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.bounces = options.count > 8
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            handleView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            handleView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handleView.widthAnchor.constraint(equalToConstant: 36),
            handleView.heightAnchor.constraint(equalToConstant: 5),
            
            titleLabel.topAnchor.constraint(equalTo: handleView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - UITableView
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 52
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId, for: indexPath)
        let option = options[indexPath.row]
        let isSelected = option == selectedValue
        
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        
        cell.textLabel?.text = option
        cell.textLabel?.font = .systemFont(ofSize: 17, weight: isSelected ? .semibold : .regular)
        cell.textLabel?.textColor = isSelected ? accentColor : .white
        
        cell.accessoryType = isSelected ? .checkmark : .none
        cell.tintColor = accentColor
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelect(options[indexPath.row])
        dismiss(animated: true)
    }
}
