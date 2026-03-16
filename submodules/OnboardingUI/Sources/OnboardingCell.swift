//
//  OnboardingCell.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 28.02.2026.
//

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle

class OnboardingCell: UICollectionViewCell {
    
    static let reuseIdentifier = "OnboardingCell"
    
    private let backgroundImageView = UIImageView()
    private let gradientLayer = CAGradientLayer()
    private let textContainer = UIView()
    
    private let categoryImageView: UIImageView = {
        let label = UIImageView()
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(34)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    func configure(imageName: String, title: String) {
        backgroundImageView.image = UIImage(named: imageName)
        
        categoryImageView.image = UIImage(bundleImageName: "Onboarding/logo")
        titleLabel.text = title
    }
    
    private func setupUI() {
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        contentView.addSubview(backgroundImageView)
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.1).cgColor,
            UIColor.black.withAlphaComponent(0.6).cgColor,
            UIColor.black.withAlphaComponent(0.9).cgColor
        ]
        gradientLayer.locations = [0.0, 0.6, 1.0]
        contentView.layer.insertSublayer(gradientLayer, at: 1)
        
        contentView.addSubview(categoryImageView)
        contentView.addSubview(titleLabel)
        
        categoryImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -175),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            categoryImageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -20),
            categoryImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            categoryImageView.heightAnchor.constraint(equalToConstant: 26),
            categoryImageView.widthAnchor.constraint(equalToConstant: 68),
        ])
    }
}
