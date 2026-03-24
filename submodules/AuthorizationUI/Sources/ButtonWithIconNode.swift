import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import Markdown
import SolidRoundedButtonNode
import AuthorizationUtils

class AgeSliderNode: ASDisplayNode {
    private let titleNode: ASTextNode
    private let valueNode: ASTextNode
    public let slider: UISlider

    private let minAgeNode: ASTextNode
    private let maxAgeNode: ASTextNode
    private let type: String

    init(title: String, type: String, defaultValue: Int, minimumValue: Int, maximumValue: Int) {
        self.type = type
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.regular(16), textColor: .white)
        self.titleNode.displaysAsynchronously = false

        self.valueNode = ASTextNode()
        self.valueNode.attributedText = NSAttributedString(string: String(defaultValue) + " " + type, font: Font.bold(16), textColor: .white)
        self.valueNode.displaysAsynchronously = false

        self.slider = UISlider()
        self.slider.minimumValue = Float(minimumValue)
        self.slider.maximumValue = Float(maximumValue)
        self.slider.value = Float(defaultValue)
        self.slider.tintColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)

        // Кастомизация ползунка: меньший размер с цветным border
        let thumbSize: CGFloat = 16.0
        let borderColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        let thumbImage = generateImage(CGSize(width: thumbSize, height: thumbSize), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            // Рисуем круг с border
            let borderRect = CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
            let path = UIBezierPath(ovalIn: borderRect)
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(2.0)
            context.addPath(path.cgPath)
            context.strokePath()
            // Белая середина (без просвета)
            let innerRect = CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4)
            let innerPath = UIBezierPath(ovalIn: innerRect)
            context.setFillColor(UIColor.white.cgColor)
            context.addPath(innerPath.cgPath)
            context.fillPath()
        })
        self.slider.setThumbImage(thumbImage, for: .normal)
        self.slider.setThumbImage(thumbImage, for: .highlighted)

        self.minAgeNode = ASTextNode()
        self.minAgeNode.attributedText = NSAttributedString(string: String(minimumValue), font: Font.regular(14), textColor: .white.withAlphaComponent(0.8))
        self.minAgeNode.displaysAsynchronously = false

        self.maxAgeNode = ASTextNode()
        self.maxAgeNode.attributedText = NSAttributedString(string: String(maximumValue), font: Font.regular(14), textColor: .white.withAlphaComponent(0.8))
        self.maxAgeNode.displaysAsynchronously = false

        super.init()

        self.slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        self.addSubnode(titleNode)
        self.addSubnode(valueNode)
        self.view.addSubview(self.slider)

        self.addSubnode(self.minAgeNode)
        self.addSubnode(self.maxAgeNode)
    }
    
    override func layout() {
        super.layout()

        let sideInset: CGFloat = 16.0
        let maximumWidth: CGFloat = self.bounds.width
//        let maxHeight: CGFloat = self.bounds.height

        let titleSize = self.titleNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(x: sideInset, y: 0, width: titleSize.width, height: titleSize.height)

        let valueSize = self.valueNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.valueNode.frame = CGRect(x: maximumWidth - sideInset - valueSize.width, y: 0, width: valueSize.width, height: valueSize.height)

        let sliderWidth = maximumWidth - sideInset * 2.0
        let sliderHeight: CGFloat = 30.0 // Фиксированная высота для слайдера
        let sliderY = titleSize.height
        self.slider.frame = CGRect(x: sideInset, y: sliderY, width: sliderWidth, height: sliderHeight)

        let minSize = self.minAgeNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.minAgeNode.frame = CGRect(x: sideInset, y: sliderY + sliderHeight, width: minSize.width, height: minSize.height)

        let maxSize = self.maxAgeNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.maxAgeNode.frame = CGRect(x: maximumWidth - sideInset - maxSize.width, y: sliderY + sliderHeight, width: maxSize.width, height: maxSize.height)
    }
    
    @objc private func sliderValueChanged() {
        let roundedValue = Int(self.slider.value.rounded())
        self.valueNode.attributedText = NSAttributedString(string: "\(roundedValue) " + type, font: Font.bold(16), textColor: .white)
        self.setNeedsLayout()
    }
}

class CheckboxNode: ASButtonNode {
    private let checkboxSize: CGSize
    
    init(size: CGSize = CGSize(width: 20, height: 20)) {
        self.checkboxSize = size
        super.init()
        self.updateAppearance()
    }
    
    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }
    
    private func updateAppearance() {
        let normalImage = UIImage(bundleImageName: "Models/Checkbox")
        let selectedImage = UIImage(bundleImageName: "Models/CheckboxSelected")
        
        self.setImage(normalImage, for: .normal)
        self.setImage(selectedImage, for: .selected)
        self.setImage(selectedImage, for: .highlighted)
    }
}



final class ButtonWithIconNode: ASControlNode {
    private let textNode: ASTextNode
    private let iconNode: ASImageNode
    private let spacing: CGFloat
    private let imageSize: CGSize
    
    init(title: String, icon: UIImage?, theme: PresentationTheme, spacing: CGFloat, imageSize: CGSize) {
        self.spacing = spacing
        self.imageSize = imageSize
        
        self.textNode = ASTextNode()
        self.textNode.attributedText = NSAttributedString(string: title, font: Font.bold(20.0), textColor: .white)
        
        self.iconNode = ASImageNode()
        self.iconNode.image = icon
        self.iconNode.contentMode = .scaleAspectFit
        
        super.init()
        
        self.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.cornerRadius = 6
//        self.layer.borderColor = UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.14).cgColor
//        self.layer.borderWidth = 1
        
        if icon != nil {
            self.addSubnode(self.iconNode)
        }
        self.addSubnode(self.textNode)
    }
    
    override func layout() {
        super.layout()
        
        let textSize = self.textNode.measure(self.bounds.size)
        
        if self.iconNode.image != nil {
            // Layout with icon
            let contentWidth = self.imageSize.width + self.spacing + textSize.width
            let contentOriginX = (self.bounds.width - contentWidth) / 2.0
            
            self.iconNode.frame = CGRect(x: contentOriginX,
                                         y: (self.bounds.height - self.imageSize.height) / 2.0,
                                         width: self.imageSize.width,
                                         height: self.imageSize.height)
            
            self.textNode.frame = CGRect(x: contentOriginX + self.imageSize.width + self.spacing,
                                         y: (self.bounds.height - textSize.height) / 2.0,
                                         width: textSize.width,
                                         height: textSize.height)
        } else {
            // Layout without icon (center the text)
            self.textNode.frame = CGRect(x: (self.bounds.width - textSize.width) / 2.0,
                                         y: (self.bounds.height - textSize.height) / 2.0,
                                         width: textSize.width,
                                         height: textSize.height)
        }
    }
}
