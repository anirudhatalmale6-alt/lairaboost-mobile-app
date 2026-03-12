import UIKit
import UserNotifications

class NotificationsViewController: UITableViewController {

    // MARK: - Properties
    private let darkBg = UIColor(red: 18/255.0, green: 20/255.0, blue: 28/255.0, alpha: 1)
    private let cardBg = UIColor(red: 28/255.0, green: 30/255.0, blue: 40/255.0, alpha: 1)
    private let accentGreen = UIColor(red: 16/255.0, green: 185/255.0, blue: 129/255.0, alpha: 1)

    private var notifications: [[String: Any]] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notifications"
        view.backgroundColor = darkBg
        tableView.backgroundColor = darkBg
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.06)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = darkBg
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = accentGreen

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(dismissView))

        if !notifications.isEmpty {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Clear All", style: .plain, target: self, action: #selector(clearAll))
            navigationItem.leftBarButtonItem?.tintColor = .systemRed
        }

        tableView.register(NotificationCell.self, forCellReuseIdentifier: "notifCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80

        loadNotifications()
    }

    @objc private func dismissView() {
        dismiss(animated: true)
    }

    @objc private func clearAll() {
        notifications.removeAll()
        UserDefaults.standard.removeObject(forKey: "com.lairaboost.notifications")
        tableView.reloadData()
        navigationItem.leftBarButtonItem = nil
    }

    // MARK: - Data

    private func loadNotifications() {
        // Load stored notifications
        if let stored = UserDefaults.standard.array(forKey: "com.lairaboost.notifications") as? [[String: Any]] {
            notifications = stored
        }

        // Also fetch delivered notifications from notification center
        UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] delivered in
            var combined = self?.notifications ?? []
            for notif in delivered {
                let entry: [String: Any] = [
                    "title": notif.request.content.title,
                    "body": notif.request.content.body,
                    "date": ISO8601DateFormatter().string(from: notif.date),
                    "id": notif.request.identifier
                ]
                // Don't add duplicates
                let exists = combined.contains { ($0["id"] as? String) == notif.request.identifier }
                if !exists {
                    combined.insert(entry, at: 0)
                }
            }

            DispatchQueue.main.async {
                self?.notifications = combined
                // Save combined list
                UserDefaults.standard.set(combined, forKey: "com.lairaboost.notifications")
                self?.tableView.reloadData()

                if !combined.isEmpty {
                    self?.navigationItem.leftBarButtonItem = UIBarButtonItem(
                        title: "Clear All", style: .plain, target: self, action: #selector(self?.clearAll))
                    self?.navigationItem.leftBarButtonItem?.tintColor = .systemRed
                }
            }
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if notifications.isEmpty {
            showEmptyState()
            return 0
        }
        tableView.backgroundView = nil
        return notifications.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "notifCell", for: indexPath) as! NotificationCell
        let notif = notifications[indexPath.row]
        cell.configure(
            title: notif["title"] as? String ?? "Notification",
            body: notif["body"] as? String ?? "",
            dateStr: notif["date"] as? String ?? ""
        )
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            notifications.remove(at: indexPath.row)
            UserDefaults.standard.set(notifications, forKey: "com.lairaboost.notifications")
            tableView.deleteRows(at: [indexPath], with: .fade)
            if notifications.isEmpty {
                navigationItem.leftBarButtonItem = nil
                tableView.reloadData()
            }
        }
    }

    // MARK: - Empty State

    private func showEmptyState() {
        let container = UIView()
        container.backgroundColor = .clear

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 50, weight: .light)
        let icon = UIImageView(image: UIImage(systemName: "bell.slash", withConfiguration: iconConfig))
        icon.tintColor = UIColor.white.withAlphaComponent(0.3)

        let title = UILabel()
        title.text = "No Notifications"
        title.textColor = UIColor.white.withAlphaComponent(0.6)
        title.font = .systemFont(ofSize: 20, weight: .semibold)

        let subtitle = UILabel()
        subtitle.text = "You'll see order updates and alerts here"
        subtitle.textColor = UIColor.white.withAlphaComponent(0.3)
        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        let enableBtn = UIButton(type: .system)
        enableBtn.setTitle("Enable Push Notifications", for: .normal)
        enableBtn.setTitleColor(.white, for: .normal)
        enableBtn.backgroundColor = accentGreen
        enableBtn.layer.cornerRadius = 24
        enableBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        enableBtn.contentEdgeInsets = UIEdgeInsets(top: 12, left: 28, bottom: 12, right: 28)
        enableBtn.addTarget(self, action: #selector(enableNotifications), for: .touchUpInside)

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(enableBtn)
        stack.setCustomSpacing(24, after: subtitle)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -40)
        ])

        tableView.backgroundView = container

        // Hide enable button if already authorized
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                enableBtn.isHidden = settings.authorizationStatus == .authorized
            }
        }
    }

    @objc private func enableNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    self.tableView.reloadData()
                } else {
                    let alert = UIAlertController(
                        title: "Notifications Disabled",
                        message: "Enable notifications in Settings to receive order updates.",
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    })
                    alert.addAction(UIAlertAction(title: "Later", style: .cancel))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

// MARK: - Notification Cell

class NotificationCell: UITableViewCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let dateLabel = UILabel()

    private let accentGreen = UIColor(red: 16/255.0, green: 185/255.0, blue: 129/255.0, alpha: 1)
    private let cardBg = UIColor(red: 28/255.0, green: 30/255.0, blue: 40/255.0, alpha: 1)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCell() {
        backgroundColor = UIColor(red: 18/255.0, green: 20/255.0, blue: 28/255.0, alpha: 1)
        selectionStyle = .none

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image = UIImage(systemName: "bell.fill", withConfiguration: config)
        iconView.tintColor = accentGreen
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit

        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.numberOfLines = 1

        bodyLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        bodyLabel.font = .systemFont(ofSize: 14)
        bodyLabel.numberOfLines = 3

        dateLabel.textColor = UIColor.white.withAlphaComponent(0.35)
        dateLabel.font = .systemFont(ofSize: 12)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, dateLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconView)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    func configure(title: String, body: String, dateStr: String) {
        titleLabel.text = title
        bodyLabel.text = body

        if let date = ISO8601DateFormatter().date(from: dateStr) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            dateLabel.text = formatter.localizedString(for: date, relativeTo: Date())
        } else {
            dateLabel.text = dateStr
        }
    }
}
