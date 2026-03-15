import UIKit
import Display

final class InteractionUserCell: UITableViewCell {
    static let reuseIdentifier = "InteractionUserCell"

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 30
        iv.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = UIColor(hexString: "222222")
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let premiumBadge: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(bundleImageName: "Profile/CrownPremium")
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(14)
        label.textColor = UIColor(hexString: "222222")?.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(premiumBadge)
        contentView.addSubview(roleLabel)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 60),
            avatarImageView.heightAnchor.constraint(equalToConstant: 60),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor),

            premiumBadge.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 6),
            premiumBadge.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            premiumBadge.widthAnchor.constraint(equalToConstant: 16),
            premiumBadge.heightAnchor.constraint(equalToConstant: 16),

            roleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            roleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2)
        ])
    }

    func configure(with user: InteractionUser) {
        nameLabel.text = user.name
        roleLabel.text = user.role
        premiumBadge.isHidden = !user.isPremium

        avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarImageView.tintColor = .lightGray
    }
}

