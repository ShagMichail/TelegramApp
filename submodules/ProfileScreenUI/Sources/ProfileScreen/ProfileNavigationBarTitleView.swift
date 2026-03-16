//
//  ProfileNavigationBarTitleView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 08.03.2026.
//

import UIKit
import Display

final class ProfileNavigationBarTitleView: UIView {
    
    private lazy var containerStack: UIStackView = {
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.alignment = .center
        infoStack.spacing = 4
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        return infoStack
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(12)
        label.textColor = .white
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(10)
        label.textColor = .white
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    private func setupViews() {
        addSubview(containerStack)
        containerStack.addArrangedSubview(nameLabel)
        containerStack.addArrangedSubview(infoLabel)
        
        NSLayoutConstraint.activate([
            containerStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
        
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(name: String, info: String? = nil) {
        nameLabel.text = name.uppercased()
        if let info = info {
            infoLabel.text = info
        } else {
            infoLabel.removeFromSuperview()
        }
    }
}
