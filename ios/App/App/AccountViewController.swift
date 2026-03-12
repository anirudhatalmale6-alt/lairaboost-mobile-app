import UIKit
import WebKit

class AccountViewController: UIViewController {

    // MARK: - Properties
    weak var webView: WKWebView?

    private let darkBg = UIColor(red: 18/255.0, green: 20/255.0, blue: 28/255.0, alpha: 1)
    private let cardBg = UIColor(red: 28/255.0, green: 30/255.0, blue: 40/255.0, alpha: 1)
    private let accentGreen = UIColor(red: 16/255.0, green: 185/255.0, blue: 129/255.0, alpha: 1)

    private var scrollView: UIScrollView!
    private var contentStack: UIStackView!
    private var loadingIndicator: UIActivityIndicatorView!

    // User data
    private var userData: [String: Any]?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Account"
        view.backgroundColor = darkBg

        // Navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = darkBg
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = accentGreen

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(dismissView))

        setupUI()
        loadUserData()
    }

    @objc private func dismissView() {
        dismiss(animated: true)
    }

    // MARK: - UI Setup

    private func setupUI() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = accentGreen
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Load Data

    private func loadUserData() {
        let js = """
        fetch('/user_info.php', {credentials: 'same-origin'})
            .then(function(r) { return r.text(); })
            .then(function(t) { return t; })
        """
        webView?.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }

            self.loadingIndicator.stopAnimating()
            self.loadingIndicator.isHidden = true

            if let jsonStr = result as? String,
               let data = jsonStr.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["authenticated"] as? Bool == true {
                self.userData = json
                self.buildAccountUI()
            } else {
                self.buildNotLoggedInUI()
            }
        }
    }

    // MARK: - Build UI

    private func buildAccountUI() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let data = userData else { return }

        let firstName = data["first_name"] as? String ?? ""
        let lastName = data["last_name"] as? String ?? ""
        let email = data["email"] as? String ?? ""
        let username = data["username"] as? String ?? ""
        let balance = data["balance"] as? Double ?? 0
        let spent = data["spent"] as? Double ?? 0
        let totalOrders = data["total_orders"] as? Int ?? 0
        let memberSince = data["member_since"] as? String ?? ""
        let currency = data["currency"] as? String ?? "$"
        let status = data["status"] as? String ?? "active"

        let initials = String((firstName.first ?? "?")) + String((lastName.first ?? ""))

        // Profile header
        let profileCard = createCard()
        let avatarContainer = UIView()
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false

        let avatar = UILabel()
        avatar.text = initials.uppercased()
        avatar.textColor = .white
        avatar.font = .systemFont(ofSize: 28, weight: .bold)
        avatar.textAlignment = .center
        avatar.backgroundColor = accentGreen
        avatar.layer.cornerRadius = 40
        avatar.clipsToBounds = true
        avatar.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        nameLabel.textColor = .white
        nameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        nameLabel.textAlignment = .center

        let emailLabel = UILabel()
        emailLabel.text = email
        emailLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        emailLabel.font = .systemFont(ofSize: 14)
        emailLabel.textAlignment = .center

        let usernameLabel = UILabel()
        usernameLabel.text = "@\(username)"
        usernameLabel.textColor = accentGreen
        usernameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        usernameLabel.textAlignment = .center

        let statusBadge = UILabel()
        statusBadge.text = "  \(status.uppercased())  "
        statusBadge.textColor = .white
        statusBadge.font = .systemFont(ofSize: 11, weight: .bold)
        statusBadge.backgroundColor = status == "active" ? accentGreen : .systemRed
        statusBadge.layer.cornerRadius = 10
        statusBadge.clipsToBounds = true
        statusBadge.textAlignment = .center

        let statusContainer = UIStackView(arrangedSubviews: [statusBadge])
        statusContainer.alignment = .center

        avatarContainer.addSubview(avatar)
        NSLayoutConstraint.activate([
            avatar.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatar.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatar.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 80),
            avatar.heightAnchor.constraint(equalToConstant: 80)
        ])

        let profileStack = UIStackView(arrangedSubviews: [avatarContainer, nameLabel, usernameLabel, emailLabel, statusContainer])
        profileStack.axis = .vertical
        profileStack.spacing = 8
        profileStack.alignment = .center
        profileStack.setCustomSpacing(16, after: avatarContainer)

        profileCard.addArrangedSubview(profileStack)
        contentStack.addArrangedSubview(profileCard)

        // Stats cards
        let statsRow = UIStackView()
        statsRow.axis = .horizontal
        statsRow.spacing = 12
        statsRow.distribution = .fillEqually

        statsRow.addArrangedSubview(createStatCard(
            value: "\(currency)\(String(format: "%.2f", balance))",
            label: "Balance",
            icon: "wallet.pass.fill",
            color: accentGreen))

        statsRow.addArrangedSubview(createStatCard(
            value: "\(currency)\(String(format: "%.2f", spent))",
            label: "Total Spent",
            icon: "chart.line.uptrend.xyaxis",
            color: .systemBlue))

        statsRow.addArrangedSubview(createStatCard(
            value: "\(totalOrders)",
            label: "Orders",
            icon: "list.clipboard.fill",
            color: .systemOrange))

        contentStack.addArrangedSubview(statsRow)

        // Member since
        let memberCard = createCard()
        let memberRow = createInfoRow(icon: "calendar", title: "Member Since", value: formatDate(memberSince))
        memberCard.addArrangedSubview(memberRow)
        contentStack.addArrangedSubview(memberCard)

        // Quick actions
        let actionsCard = createCard()
        actionsCard.spacing = 0

        let addFundsBtn = createActionRow(icon: "plus.circle.fill", title: "Add Funds", color: accentGreen)
        addFundsBtn.addTarget(self, action: #selector(openAddFunds), for: .touchUpInside)
        actionsCard.addArrangedSubview(addFundsBtn)

        let divider1 = createDivider()
        actionsCard.addArrangedSubview(divider1)

        let ordersBtn = createActionRow(icon: "list.bullet.rectangle", title: "View Orders", color: .systemBlue)
        ordersBtn.addTarget(self, action: #selector(openOrders), for: .touchUpInside)
        actionsCard.addArrangedSubview(ordersBtn)

        let divider2 = createDivider()
        actionsCard.addArrangedSubview(divider2)

        let supportBtn = createActionRow(icon: "questionmark.circle.fill", title: "Support", color: .systemOrange)
        supportBtn.addTarget(self, action: #selector(openSupport), for: .touchUpInside)
        actionsCard.addArrangedSubview(supportBtn)

        contentStack.addArrangedSubview(actionsCard)

        // Sign out
        let signOutBtn = UIButton(type: .system)
        signOutBtn.setTitle("Sign Out", for: .normal)
        signOutBtn.setTitleColor(.systemRed, for: .normal)
        signOutBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        signOutBtn.backgroundColor = cardBg
        signOutBtn.layer.cornerRadius = 14
        signOutBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        signOutBtn.addTarget(self, action: #selector(signOut), for: .touchUpInside)
        contentStack.addArrangedSubview(signOutBtn)
    }

    private func buildNotLoggedInUI() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
        let icon = UIImageView(image: UIImage(systemName: "person.crop.circle.badge.questionmark", withConfiguration: iconConfig))
        icon.tintColor = UIColor.white.withAlphaComponent(0.4)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.heightAnchor.constraint(equalToConstant: 80).isActive = true

        let title = UILabel()
        title.text = "Not Signed In"
        title.textColor = .white
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.textAlignment = .center

        let subtitle = UILabel()
        subtitle.text = "Sign in to view your account details, balance, and order history."
        subtitle.textColor = UIColor.white.withAlphaComponent(0.5)
        subtitle.font = .systemFont(ofSize: 15)
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        let signInBtn = UIButton(type: .system)
        signInBtn.setTitle("Sign In", for: .normal)
        signInBtn.setTitleColor(.white, for: .normal)
        signInBtn.backgroundColor = accentGreen
        signInBtn.layer.cornerRadius = 26
        signInBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        signInBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        signInBtn.addTarget(self, action: #selector(goToLogin), for: .touchUpInside)

        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 40).isActive = true

        contentStack.addArrangedSubview(spacer)
        contentStack.addArrangedSubview(icon)
        contentStack.addArrangedSubview(title)
        contentStack.addArrangedSubview(subtitle)
        contentStack.addArrangedSubview(signInBtn)
        contentStack.setCustomSpacing(24, after: subtitle)
    }

    // MARK: - UI Helpers

    private func createCard() -> UIStackView {
        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 12
        card.backgroundColor = cardBg
        card.layer.cornerRadius = 16
        card.isLayoutMarginsRelativeArrangement = true
        card.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        return card
    }

    private func createStatCard(value: String, label: String, icon: String, color: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor = cardBg
        card.layer.cornerRadius = 14

        let iconView = UIImageView(image: UIImage(systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)))
        iconView.tintColor = color
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.textColor = .white
        valueLabel.font = .systemFont(ofSize: 18, weight: .bold)
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconView)
        card.addSubview(valueLabel)
        card.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 90),
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            valueLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            valueLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            valueLabel.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -2),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            titleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])

        return card
    }

    private func createInfoRow(icon: String, title: String, value: String) -> UIView {
        let row = UIView()
        let iconView = UIImageView(image: UIImage(systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)))
        iconView.tintColor = accentGreen
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        titleLabel.font = .systemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.textColor = .white
        valueLabel.font = .systemFont(ofSize: 14, weight: .medium)
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(iconView)
        row.addSubview(titleLabel)
        row.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 28),
            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    private func createActionRow(icon: String, title: String, color: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        let iconView = UIImageView(image: UIImage(systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)))
        iconView.tintColor = color
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isUserInteractionEnabled = false

        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)))
        chevron.tintColor = UIColor.white.withAlphaComponent(0.3)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.isUserInteractionEnabled = false

        btn.addSubview(iconView)
        btn.addSubview(label)
        btn.addSubview(chevron)

        NSLayoutConstraint.activate([
            btn.heightAnchor.constraint(equalToConstant: 52),
            iconView.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: btn.centerYAnchor)
        ])

        return btn
    }

    private func createDivider() -> UIView {
        let d = UIView()
        d.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        d.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return d
    }

    private func formatDate(_ dateStr: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = fmt.date(from: dateStr) {
            fmt.dateFormat = "MMM d, yyyy"
            return fmt.string(from: date)
        }
        return dateStr.isEmpty ? "N/A" : dateStr
    }

    // MARK: - Actions

    @objc private func openAddFunds() {
        dismiss(animated: true) { [weak self] in
            if let url = URL(string: "https://lairaboost.com/addfunds") {
                self?.webView?.load(URLRequest(url: url))
            }
        }
    }

    @objc private func openOrders() {
        dismiss(animated: true) { [weak self] in
            if let url = URL(string: "https://lairaboost.com/orders") {
                self?.webView?.load(URLRequest(url: url))
            }
        }
    }

    @objc private func openSupport() {
        dismiss(animated: true) { [weak self] in
            if let url = URL(string: "https://lairaboost.com/tickets") {
                self?.webView?.load(URLRequest(url: url))
            }
        }
    }

    @objc private func goToLogin() {
        dismiss(animated: true) { [weak self] in
            if let url = URL(string: "https://lairaboost.com/auth") {
                self?.webView?.load(URLRequest(url: url))
            }
        }
    }

    @objc private func signOut() {
        let alert = UIAlertController(title: "Sign Out", message: "Are you sure you want to sign out?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { [weak self] _ in
            self?.dismiss(animated: true) {
                if let url = URL(string: "https://lairaboost.com/logout") {
                    self?.webView?.load(URLRequest(url: url))
                }
            }
        })
        present(alert, animated: true)
    }
}
