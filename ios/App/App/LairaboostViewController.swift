import UIKit
import Capacitor
import WebKit
import Network

class LairaboostViewController: CAPBridgeViewController {

    // MARK: - UI Elements
    private var navToolbar: UIView!
    private var tabButtons: [UIButton] = []
    private var offlineOverlay: UIView!
    private var refreshControl: UIRefreshControl!

    // MARK: - Network
    private var pathMonitor: NWPathMonitor?
    private var isOnline = true

    // MARK: - Constants
    private let toolbarHeight: CGFloat = 64
    private let tabBarBg = UIColor(red: 18/255.0, green: 20/255.0, blue: 28/255.0, alpha: 0.97)
    private let accentGreen = UIColor(red: 16/255.0, green: 185/255.0, blue: 129/255.0, alpha: 1)
    private let defaultGray = UIColor(red: 140/255.0, green: 140/255.0, blue: 155/255.0, alpha: 1)
    private let dimGray = UIColor(red: 60/255.0, green: 60/255.0, blue: 70/255.0, alpha: 1)

    // Tab config: (SF Symbol name, label)
    private let tabs: [(icon: String, filledIcon: String, label: String)] = [
        ("chevron.backward", "chevron.backward", "Back"),
        ("house", "house.fill", "Home"),
        ("square.grid.2x2", "square.grid.2x2.fill", "Services"),
        ("square.and.arrow.up", "square.and.arrow.up.fill", "Share"),
        ("arrow.clockwise", "arrow.clockwise", "Reload"),
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        webView?.scrollView.bounces = true
        setupTabBar()
        setupPullToRefresh()
        setupOfflineView()
        startNetworkMonitoring()
        enableSwipeNavigation()
        observeNavigation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollInsets()
    }

    // MARK: - Tab Bar

    private func setupTabBar() {
        navToolbar = UIView()
        navToolbar.backgroundColor = tabBarBg
        navToolbar.translatesAutoresizingMaskIntoConstraints = false

        // Top border
        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        sep.translatesAutoresizingMaskIntoConstraints = false
        navToolbar.addSubview(sep)

        // Build tab buttons
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (index, tab) in tabs.enumerated() {
            let btn = createTabButton(index: index, iconName: tab.icon, label: tab.label)
            tabButtons.append(btn)
            stack.addArrangedSubview(btn)
        }

        navToolbar.addSubview(stack)
        view.addSubview(navToolbar)

        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: navToolbar.topAnchor),
            sep.leadingAnchor.constraint(equalTo: navToolbar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: navToolbar.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),

            stack.topAnchor.constraint(equalTo: navToolbar.topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: navToolbar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: navToolbar.trailingAnchor),
            stack.heightAnchor.constraint(equalToConstant: toolbarHeight - 6),

            navToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navToolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            navToolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -toolbarHeight)
        ])

        highlightTab(1) // Home active by default
    }

    private func createTabButton(index: Int, iconName: String, label: String) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.tag = index

        // Icon image view
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        let iconView = UIImageView(image: UIImage(systemName: iconName, withConfiguration: iconConfig))
        iconView.tintColor = defaultGray
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tag = 100

        // Label
        let lbl = UILabel()
        lbl.text = label
        lbl.font = .systemFont(ofSize: 10, weight: .medium)
        lbl.textColor = defaultGray
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.tag = 200

        let vStack = UIStackView(arrangedSubviews: [iconView, lbl])
        vStack.axis = .vertical
        vStack.alignment = .center
        vStack.spacing = 4
        vStack.isUserInteractionEnabled = false
        vStack.translatesAutoresizingMaskIntoConstraints = false

        btn.addSubview(vStack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            vStack.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            vStack.centerYAnchor.constraint(equalTo: btn.centerYAnchor, constant: -2)
        ])

        btn.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func highlightTab(_ activeIndex: Int) {
        for (i, btn) in tabButtons.enumerated() {
            let isActive = (i == activeIndex)
            let tab = tabs[i]
            let color = isActive ? accentGreen : defaultGray

            // Handle Back button dimming
            if i == 0 {
                let canBack = webView?.canGoBack ?? false
                let c = canBack ? defaultGray : dimGray
                if let iv = btn.viewWithTag(100) as? UIImageView {
                    iv.tintColor = c
                }
                if let lbl = btn.viewWithTag(200) as? UILabel {
                    lbl.textColor = c
                }
                btn.isEnabled = canBack
                btn.alpha = canBack ? 1.0 : 0.6
                continue
            }

            if let iconView = btn.viewWithTag(100) as? UIImageView {
                let iconName = isActive ? tab.filledIcon : tab.icon
                let config = UIImage.SymbolConfiguration(pointSize: 24, weight: isActive ? .semibold : .regular)
                iconView.image = UIImage(systemName: iconName, withConfiguration: config)
                iconView.tintColor = color
            }
            if let lbl = btn.viewWithTag(200) as? UILabel {
                lbl.textColor = color
                lbl.font = .systemFont(ofSize: 10, weight: isActive ? .semibold : .medium)
            }
        }
    }

    @objc private func tabTapped(_ sender: UIButton) {
        let index = sender.tag

        switch index {
        case 0: // Back
            webView?.goBack()
        case 1: // Home
            if let url = URL(string: "https://lairaboost.com") {
                webView?.load(URLRequest(url: url))
            }
            highlightTab(1)
        case 2: // Services
            if let url = URL(string: "https://lairaboost.com/services") {
                webView?.load(URLRequest(url: url))
            }
            highlightTab(2)
        case 3: // Share
            guard let url = webView?.url else { return }
            let ac = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let popover = ac.popoverPresentationController {
                popover.sourceView = sender
                popover.sourceRect = sender.bounds
            }
            present(ac, animated: true)
        case 4: // Reload
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            webView?.reload()
        default:
            break
        }
    }

    // MARK: - Pull to Refresh

    private func setupPullToRefresh() {
        guard let scrollView = webView?.scrollView else { return }
        refreshControl = UIRefreshControl()
        refreshControl.tintColor = accentGreen
        refreshControl.addTarget(self, action: #selector(handlePullRefresh), for: .valueChanged)
        scrollView.refreshControl = refreshControl
    }

    @objc private func handlePullRefresh() {
        webView?.reload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.refreshControl?.endRefreshing()
        }
    }

    // MARK: - Offline View

    private func setupOfflineView() {
        offlineOverlay = UIView()
        offlineOverlay.backgroundColor = UIColor(red: 18/255.0, green: 20/255.0, blue: 28/255.0, alpha: 1)
        offlineOverlay.isHidden = true
        offlineOverlay.translatesAutoresizingMaskIntoConstraints = false

        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = 16
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 50, weight: .light)
        let icon = UIImageView(image: UIImage(systemName: "wifi.slash", withConfiguration: iconConfig))
        icon.tintColor = UIColor.white.withAlphaComponent(0.7)
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.text = "No Internet Connection"
        title.textColor = .white
        title.font = .systemFont(ofSize: 22, weight: .semibold)

        let subtitle = UILabel()
        subtitle.text = "Please check your connection and try again"
        subtitle.textColor = UIColor.white.withAlphaComponent(0.5)
        subtitle.font = .systemFont(ofSize: 15)
        subtitle.textAlignment = .center

        let retryBtn = UIButton(type: .system)
        retryBtn.setTitle("Retry", for: .normal)
        retryBtn.setTitleColor(.white, for: .normal)
        retryBtn.backgroundColor = accentGreen
        retryBtn.layer.cornerRadius = 24
        retryBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        retryBtn.contentEdgeInsets = UIEdgeInsets(top: 14, left: 48, bottom: 14, right: 48)
        retryBtn.addTarget(self, action: #selector(tapRetry), for: .touchUpInside)

        container.addArrangedSubview(icon)
        container.addArrangedSubview(title)
        container.addArrangedSubview(subtitle)
        container.addArrangedSubview(retryBtn)
        container.setCustomSpacing(28, after: subtitle)

        offlineOverlay.addSubview(container)
        view.addSubview(offlineOverlay)

        NSLayoutConstraint.activate([
            offlineOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            offlineOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            offlineOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.centerXAnchor.constraint(equalTo: offlineOverlay.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: offlineOverlay.centerYAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: offlineOverlay.leadingAnchor, constant: 32),
            container.trailingAnchor.constraint(lessThanOrEqualTo: offlineOverlay.trailingAnchor, constant: -32)
        ])
    }

    @objc private func tapRetry() {
        if isOnline {
            offlineOverlay.isHidden = true
            webView?.reload()
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied
                if path.status == .satisfied {
                    self?.offlineOverlay.isHidden = true
                    if wasOffline { self?.webView?.reload() }
                } else {
                    self?.offlineOverlay.isHidden = false
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.lairaboost.networkmonitor"))
        self.pathMonitor = monitor
    }

    // MARK: - Swipe Navigation

    private func enableSwipeNavigation() {
        webView?.allowsBackForwardNavigationGestures = true
    }

    // MARK: - Navigation Observation

    private func observeNavigation() {
        webView?.addObserver(self, forKeyPath: "canGoBack", options: .new, context: nil)
        webView?.addObserver(self, forKeyPath: "URL", options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "canGoBack" || keyPath == "URL" {
            updateTabState()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    private func updateTabState() {
        // Detect which tab is active based on URL
        if let urlStr = webView?.url?.absoluteString {
            if urlStr.contains("/services") {
                highlightTab(2)
            } else {
                highlightTab(1)
            }
        } else {
            highlightTab(1)
        }
    }

    // MARK: - Scroll Insets

    private func updateScrollInsets() {
        guard let toolbar = navToolbar else { return }
        let totalToolbarHeight = view.bounds.height - toolbar.frame.origin.y
        webView?.scrollView.contentInset.bottom = totalToolbarHeight
        webView?.scrollView.verticalScrollIndicatorInsets.bottom = totalToolbarHeight
    }

    // MARK: - Cleanup

    deinit {
        webView?.removeObserver(self, forKeyPath: "canGoBack")
        webView?.removeObserver(self, forKeyPath: "URL")
        pathMonitor?.cancel()
    }
}
