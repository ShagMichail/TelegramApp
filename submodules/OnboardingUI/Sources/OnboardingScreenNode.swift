//
//  OnboardingScreenNode.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 28.02.2026.
//

import UIKit

struct OnboardingPage {
    let imageName: String
    let title: String
}

class OnboardingScreenNode: UIViewController {

    private let backgroundImageView = UIImageView()
    private let gradientLayer = CAGradientLayer()
    
    init(page: OnboardingPage) {
        super.init(nibName: nil, bundle: nil)
        backgroundImageView.image = UIImage(bundleImageName: page.imageName)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupGradient()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }
    
    private func setupBackground() {
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupGradient() {
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.1).cgColor,
            UIColor.black.withAlphaComponent(0.6).cgColor,
            UIColor.black.withAlphaComponent(0.9).cgColor
        ]
        gradientLayer.locations = [0.0, 0.7, 1.0]
        view.layer.insertSublayer(gradientLayer, at: 1)
    }
}
