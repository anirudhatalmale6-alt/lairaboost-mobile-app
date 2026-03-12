import UIKit
import WebKit
import UserNotifications
import LocalAuthentication

class SettingsViewController: UITableViewController {

    // MARK: - Properties
    weak var webView: WKWebView?
    var onReload: (() -> Void)?

    private let darkBg = UIColor(red: 18/255.0, green: 20/255.0, blue: 28/255.0, alpha: 1)
    private let cellBg = UIColor(red: 28/255.0, green: 30/255.0, blue: 40/255.0, alpha: 1)
    private let accentGreen = UIColor(red: 16/255.0, green: 185/255.0, blue: 129/255.0, alpha: 1)

    private struct SettingsItem {
        let title: String
        let icon: String
        let iconColor: UIColor
        let type: ItemType
        let action: (() -> Void)?

        enum ItemType {
            case action
            case toggle
            case info
            case destructive
        }

        init(title: String, icon: String, iconColor: UIColor = .white, type: ItemType = .action, action: (() -> Void)? = nil) {
            self.title = title
            self.icon = icon
            self.iconColor = iconColor
            self.type = type
            self.action = action
        }
    }

    private var sections: [(title: String, items: [SettingsItem])] = []
    private var notificationsEnabled = false
    private var biometricEnabled = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "More"
        view.backgroundColor = darkBg
        tableView.backgroundColor = darkBg
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.08)

        // Navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = darkBg
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = accentGreen
        navigationItem.largeTitleDisplayMode = .never

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissSettings)
        )

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "toggleCell")

        checkNotificationStatus()
        biometricEnabled = UserDefaults.standard.bool(forKey: "com.lairaboost.biometricEnabled")
        buildSections()
    }

    // MARK: - Build Sections

    private func buildSections() {
        sections = [
            (title: "Quick Actions", items: [
                SettingsItem(title: "Reload Page", icon: "arrow.clockwise", iconColor: accentGreen) { [weak self] in
                    self?.dismiss(animated: true) {
                        self?.onReload?()
                    }
                },
                SettingsItem(title: "Go to Home", icon: "house.fill", iconColor: .systemBlue) { [weak self] in
                    self?.dismiss(animated: true) {
                        if let url = URL(string: "https://lairaboost.com") {
                            self?.webView?.load(URLRequest(url: url))
                        }
                    }
                },
            ]),
            (title: "Quick Actions", items: [
                SettingsItem(title: "Share App", icon: "square.and.arrow.up", iconColor: .systemBlue) { [weak self] in
                    self?.shareApp()
                },
            ]),
            (title: "Preferences", items: [
                SettingsItem(title: "Push Notifications", icon: "bell.fill", iconColor: .systemOrange, type: .toggle),
                SettingsItem(title: "Face ID / Touch ID Lock", icon: "faceid", iconColor: .systemGreen, type: .toggle),
                SettingsItem(title: "Clear Cache", icon: "trash.fill", iconColor: .systemRed, type: .destructive) { [weak self] in
                    self?.clearCache()
                },
            ]),
            (title: "Information", items: [
                SettingsItem(title: "Privacy Policy", icon: "lock.shield.fill", iconColor: .systemBlue) { [weak self] in
                    self?.openInWebView("https://lairaboost.com/terms")
                },
                SettingsItem(title: "Terms of Service", icon: "doc.text.fill", iconColor: .systemGray) { [weak self] in
                    self?.openInWebView("https://lairaboost.com/terms")
                },
                SettingsItem(title: "Rate App", icon: "star.fill", iconColor: .systemYellow) { [weak self] in
                    self?.rateApp()
                },
                SettingsItem(title: "Contact Support", icon: "envelope.fill", iconColor: accentGreen) { [weak self] in
                    self?.openInWebView("https://lairaboost.com/tickets")
                },
            ]),
            (title: "About", items: [
                SettingsItem(title: "Version", icon: "info.circle.fill", iconColor: .systemGray, type: .info),
            ]),
        ]
    }

    // MARK: - Actions

    @objc private func dismissSettings() {
        dismiss(animated: true)
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationsEnabled = settings.authorizationStatus == .authorized
                self?.tableView.reloadData()
            }
        }
    }

    private func clearCache() {
        let alert = UIAlertController(
            title: "Clear Cache",
            message: "This will clear all cached data. You may need to log in again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            let dataStore = WKWebsiteDataStore.default()
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            dataStore.fetchDataRecords(ofTypes: types) { records in
                dataStore.removeData(ofTypes: types, for: records) {
                    DispatchQueue.main.async {
                        let done = UIAlertController(title: "Done", message: "Cache cleared successfully.", preferredStyle: .alert)
                        done.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(done, animated: true)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func rateApp() {
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(Bundle.main.infoDictionary?["APP_STORE_ID"] as? String ?? "")") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    private func openInWebView(_ urlString: String) {
        dismiss(animated: true) { [weak self] in
            if let url = URL(string: urlString) {
                self?.webView?.load(URLRequest(url: url))
            }
        }
    }

    @objc private func notificationToggleChanged(_ sender: UISwitch) {
        if sender.isOn {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.notificationsEnabled = granted
                    sender.isOn = granted
                    if granted {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        } else {
            // Can't programmatically disable - direct user to Settings
            let alert = UIAlertController(
                title: "Disable Notifications",
                message: "To disable notifications, go to Settings > Lairaboost > Notifications.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                sender.isOn = true
            })
            present(alert, animated: true)
        }
    }

    @objc private func biometricToggleChanged(_ sender: UISwitch) {
        if sender.isOn {
            let context = LAContext()
            var error: NSError?
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                      localizedReason: "Enable biometric lock for Lairaboost") { [weak self] success, _ in
                    DispatchQueue.main.async {
                        if success {
                            self?.biometricEnabled = true
                            UserDefaults.standard.set(true, forKey: "com.lairaboost.biometricEnabled")
                        } else {
                            sender.isOn = false
                        }
                    }
                }
            } else {
                sender.isOn = false
                let alert = UIAlertController(title: "Not Available",
                    message: "Biometric authentication is not available on this device.",
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        } else {
            biometricEnabled = false
            UserDefaults.standard.set(false, forKey: "com.lairaboost.biometricEnabled")
        }
    }

    private func shareApp() {
        guard let url = webView?.url ?? URL(string: "https://lairaboost.com") else { return }
        let ac = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = ac.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(ac, animated: true)
    }

    // MARK: - Table View Data Source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = UIColor.white.withAlphaComponent(0.5)
            header.textLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section].items[indexPath.row]

        if item.type == .toggle {
            let cell = tableView.dequeueReusableCell(withIdentifier: "toggleCell", for: indexPath)
            cell.textLabel?.text = item.title
            cell.textLabel?.textColor = .white
            cell.backgroundColor = cellBg
            cell.selectionStyle = .none

            let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            cell.imageView?.image = UIImage(systemName: item.icon, withConfiguration: iconConfig)
            cell.imageView?.tintColor = item.iconColor

            let toggle = UISwitch()
            toggle.onTintColor = accentGreen

            if item.title.contains("Face ID") || item.title.contains("Touch ID") {
                toggle.isOn = biometricEnabled
                toggle.tag = 200
                toggle.addTarget(self, action: #selector(biometricToggleChanged(_:)), for: .valueChanged)
            } else {
                toggle.isOn = notificationsEnabled
                toggle.tag = 100
                toggle.addTarget(self, action: #selector(notificationToggleChanged(_:)), for: .valueChanged)
            }

            cell.accessoryView = toggle
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = item.title
        cell.textLabel?.textColor = item.type == .destructive ? .systemRed : .white
        cell.backgroundColor = cellBg
        cell.selectionStyle = item.type == .info ? .none : .default

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        cell.imageView?.image = UIImage(systemName: item.icon, withConfiguration: iconConfig)
        cell.imageView?.tintColor = item.iconColor

        if item.type == .info {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            let versionLabel = UILabel()
            versionLabel.text = "v\(version) (\(build))"
            versionLabel.textColor = UIColor.white.withAlphaComponent(0.4)
            versionLabel.font = .systemFont(ofSize: 14)
            versionLabel.sizeToFit()
            cell.accessoryView = versionLabel
        } else if item.type != .destructive {
            cell.accessoryType = .disclosureIndicator
        }

        // Fix disclosure indicator color
        let selectedBg = UIView()
        selectedBg.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        cell.selectedBackgroundView = selectedBg

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section].items[indexPath.row]
        item.action?()
    }
}
