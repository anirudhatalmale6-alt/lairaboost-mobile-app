import UIKit
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register for push notifications
        UNUserNotificationCenter.current().delegate = self

        // Setup Quick Actions (3D Touch / Long Press shortcuts)
        setupQuickActions(for: application)

        return true
    }

    // MARK: - Quick Actions

    private func setupQuickActions(for application: UIApplication) {
        let homeAction = UIApplicationShortcutItem(
            type: "com.lairaboost.home",
            localizedTitle: "Home",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "house.fill"),
            userInfo: nil
        )
        let servicesAction = UIApplicationShortcutItem(
            type: "com.lairaboost.services",
            localizedTitle: "Services",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "square.grid.2x2.fill"),
            userInfo: nil
        )
        let ordersAction = UIApplicationShortcutItem(
            type: "com.lairaboost.orders",
            localizedTitle: "My Orders",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "list.clipboard.fill"),
            userInfo: nil
        )
        let addFundsAction = UIApplicationShortcutItem(
            type: "com.lairaboost.addfunds",
            localizedTitle: "Add Funds",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "plus.circle.fill"),
            userInfo: nil
        )

        application.shortcutItems = [homeAction, servicesAction, ordersAction, addFundsAction]
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcutItem(shortcutItem)
        completionHandler(true)
    }

    private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        guard let rootVC = window?.rootViewController as? LairaboostViewController else { return }
        var urlString = "https://lairaboost.com"

        switch shortcutItem.type {
        case "com.lairaboost.services":
            urlString = "https://lairaboost.com/services"
        case "com.lairaboost.orders":
            urlString = "https://lairaboost.com/orders"
        case "com.lairaboost.addfunds":
            urlString = "https://lairaboost.com/addfunds"
        default:
            break
        }

        if let url = URL(string: urlString) {
            // Small delay to ensure view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                rootVC.webView?.load(URLRequest(url: url))
            }
        }
    }

    // MARK: - Lifecycle

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

    // MARK: - URL Handling

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

    // MARK: - Push Notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Store notification for native inbox
        storeNotification(notification)
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        storeNotification(response.notification)
        completionHandler()
    }

    private func storeNotification(_ notification: UNNotification) {
        let content = notification.request.content
        let entry: [String: Any] = [
            "title": content.title,
            "body": content.body,
            "date": ISO8601DateFormatter().string(from: notification.date),
            "id": notification.request.identifier
        ]

        var stored = UserDefaults.standard.array(forKey: "com.lairaboost.notifications") as? [[String: Any]] ?? []

        // Don't duplicate
        if stored.contains(where: { ($0["id"] as? String) == notification.request.identifier }) {
            return
        }

        stored.insert(entry, at: 0)
        // Keep last 50 notifications
        if stored.count > 50 { stored = Array(stored.prefix(50)) }
        UserDefaults.standard.set(stored, forKey: "com.lairaboost.notifications")
    }
}
