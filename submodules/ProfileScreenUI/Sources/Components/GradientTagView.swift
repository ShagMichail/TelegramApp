//
//  GradientTagView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 26.02.2026.
//

import UIKit

class GradientTagView: UIView {
    
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }
    
    private var gradientLayer: CAGradientLayer {
        return layer as! CAGradientLayer
    }
    
    enum Style {
        case bronzeGradient
        case plainWhite
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        layer.cornerRadius = 14
        layer.masksToBounds = true
        layer.borderWidth = 1
        
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
    }
    
    func apply(style: Style) {
        switch style {
        case .bronzeGradient:
            gradientLayer.colors = [
                UIColor(hex: "BB7148").cgColor,
                UIColor(hex: "D5B187").cgColor,
                UIColor(hex: "A46B4C").cgColor,
                UIColor(hex: "89503B").cgColor,
                UIColor(hex: "823F36").cgColor,
                UIColor(hex: "BB7148").cgColor
            ]
            gradientLayer.locations = [0.0, 0.22, 0.36, 0.66, 0.80, 1.0]
            
            self.backgroundColor = .clear
            self.layer.borderColor = UIColor.white.cgColor
            
        case .plainWhite:
            gradientLayer.colors = nil
            gradientLayer.locations = nil
            
            self.backgroundColor = .white
            self.layer.borderColor = UIColor.clear.cgColor
        }
    }
}

// Надо будет куда-нибудь перенести
extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
