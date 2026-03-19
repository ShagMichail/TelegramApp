import UIKit
import AsyncDisplayKit
import Display

final class DropdownNode: ASDisplayNode, UIPickerViewDelegate, UIPickerViewDataSource {
    
    private let backgroundNode: ASDisplayNode
    private let apperTitleNode: ASTextNode
    private let titleNode: ASTextNode
    private let arrowNode: ASImageNode
    
    private let hiddenTextField = UITextField()
    private let pickerView = UIPickerView()
    
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
        
        self.view.addSubview(hiddenTextField)
        hiddenTextField.isHidden = true
        
        pickerView.delegate = self
        pickerView.dataSource = self
        
        pickerView.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.barTintColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        toolbar.isTranslucent = false
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(donePicker))
        
        doneButton.tintColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        toolbar.setItems([flexSpace, doneButton], animated: false)
        
        hiddenTextField.inputView = pickerView
        hiddenTextField.inputAccessoryView = toolbar
        
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
        hiddenTextField.becomeFirstResponder()
    }
    
    @objc private func donePicker() {
        hiddenTextField.resignFirstResponder()
        
        if selectedValue == nil && !options.isEmpty {
            let selectedRow = pickerView.selectedRow(inComponent: 0)
            selectedValue = options[selectedRow]
            onSelect?(options[selectedRow])
        }
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
    
    
    // MARK: - UIPickerView Methods
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { return options.count }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        return NSAttributedString(string: options[row], attributes: [NSAttributedString.Key.foregroundColor: UIColor.white])
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedValue = options[row]
        onSelect?(options[row])
    }
}
