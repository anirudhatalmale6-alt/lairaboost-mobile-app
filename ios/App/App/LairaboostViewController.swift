import UIKit
import Capacitor
import WebKit
import Network

class LairaboostViewController: CAPBridgeViewController {

    // MARK: - UI Elements
    private var navToolbar: UIVisualEffectView!
    private var backBtn: UIButton!
    private var forwardBtn: UIButton!
    private var shareBtn: UIButton!
    private var refreshBtn: UIButton!
    private var homeBtn: UIButton!
    private var offlineOverlay: UIView!
    private var refreshControl: UIRefreshControl!

    // MARK: - Network
    private var pathMonitor: NWPathMonitor?
    private var isOnline = true

    // MARK: - Constants
    private let toolbarHeight: CGFloat = 56
    private let brandBg = UIColor(red: 26/255.0, green: 28/255.0, blue: 36/255.0, alpha: 1)
    private let accentGreen = UIColor(red: 16/255.0, green: 185/255.0, blue: 129/255.0, alpha: 1)
    private let accentBlue = UIColor(red: 59/255.0, green: 130/255.0, blue: 246/255.0, alpha: 1)
    private let iconColor = UIColor(white: 0.75, alpha: 1)
    private let iconActiveColor = UIColor.white

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        webView?.scrollView.bounces = true
        setupBottomToolbar()
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

    // MARK: - Modern Bottom Toolbar

    private func setupBottomToolbar() {
        // Frosted glass blur effect
        let blur = UIBlurEffect(style: .systemChromeMaterialDark)
        navToolbar = UIVisualEffectView(effect: blur)
        navToolbar.translatesAutoresizingMaskIntoConstraints = false

        // Top hairline separator
        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        sep.translatesAutoresizingMaskIntoConstraints = false
        navToolbar.contentView.addSubview(sep)

        // Create buttons with labels
        backBtn = makeNavButton(iconName: "chevron.left", label: "Back", action: #selector(tapBack))
        forwardBtn = makeNavButton(iconName: "chevron.right", label: "Forward", action: #selector(tapForward))
        homeBtn = makeNavButton(iconName: "house.fill", label: "Home", action: #selector(tapHome))
        shareBtn = makeNavButton(iconName: "square.and.arrow.up", label: "Share", action: #selector(tapShare))
        refreshBtn = makeNavButton(iconName: "arrow.clockwise", label: "Reload", action: #selector(tapRefresh))

        let stack = UIStackView(arrangedSubviews: [backBtn, forwardBtn, homeBtn, shareBtn, refreshBtn])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        navToolbar.contentView.addSubview(stack)

        view.addSubview(navToolbar)

        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: navToolbar.topAnchor),
            sep.leadingAnchor.constraint(equalTo: navToolbar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: navToolbar.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.33),

            stack.topAnchor.constraint(equalTo: navToolbar.contentView.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: navToolbar.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: navToolbar.contentView.trailingAnchor),
            stack.heightAnchor.constraint(equalToConstant: toolbarHeight - 4),

            navToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navToolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            navToolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -toolbarHeight)
        ])

        updateNavButtons()
    }

    private func makeNavButton(iconName: String, label: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .custom)

        // Icon
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: iconName, withConfiguration: iconConfig))
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tag = 100

        // Label
        let lbl = UILabel()
        lbl.text = label
        lbl.font = .systemFont(ofSize: 10, weight: .medium)
        lbl.textColor = iconColor
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.tag = 200

        let stack = UIStackView(arrangedSubviews: [iconView, lbl])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 3
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        btn.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.heightAnchor.constraint(equalToConstant: 22),
            stack.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: btn.centerYAnchor)
        ])

        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    private func updateNavButtons() {
        let canBack = webView?.canGoBack ?? false
        let canFwd = webView?.canGoForward ?? false
        backBtn?.isEnabled = canBack
        forwardBtn?.isEnabled = canFwd
        setButtonAppearance(backBtn, active: canBack)
        setButtonAppearance(forwardBtn, active: canFwd)
        setButtonAppearance(homeBtn, active: true, highlight: true)
        setButtonAppearance(shareBtn, active: true)
        setButtonAppearance(refreshBtn, active: true)
    }

    private func setButtonAppearance(_ btn: UIButton?, active: Bool, highlight: Bool = false) {
        guard let btn = btn else { return }
        let color = highlight ? accentGreen : (active ? iconActiveColor : UIColor(white: 0.35, alpha: 1))
        if let iconView = btn.viewWithTag(100) as? UIImageView {
            iconView.tintColor = color
        }
        if let lbl = btn.viewWithTag(200) as? UILabel {
            lbl.textColor = color
        }
    }

    // MARK: - Toolbar Actions

    @objc private func tapBack() {
        webView?.goBack()
    }

    @objc private func tapForward() {
        webView?.goForward()
    }

    @objc private func tapHome() {
        if let url = URL(string: "https://lairaboost.com") {
            webView?.load(URLRequest(url: url))
        }
    }

    @objc private func tapShare() {
        guard let url = webView?.url else { return }
        let items: [Any] = [url]
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = ac.popoverPresentationController {
            popover.sourceView = shareBtn
            popover.sourceRect = shareBtn.bounds
        }
        present(ac, animated: true)
    }

    @objc private func tapRefresh() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        webView?.reload()
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
        offlineOverlay.backgroundColor = brandBg
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
        retryBtn.layer.cornerRadius = 22
        retryBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        retryBtn.contentEdgeInsets = UIEdgeInsets(top: 12, left: 40, bottom: 12, right: 40)
        retryBtn.addTarget(self, action: #selector(tapRetry), for: .touchUpInside)

        container.addArrangedSubview(icon)
        container.addArrangedSubview(title)
        container.addArrangedSubview(subtitle)
        container.addArrangedSubview(retryBtn)
        container.setCustomSpacing(24, after: subtitle)

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
                    if wasOffline {
                        self?.webView?.reload()
                    }
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

    // MARK: - Navigation Observation (KVO)

    private func observeNavigation() {
        webView?.addObserver(self, forKeyPath: "canGoBack", options: .new, context: nil)
        webView?.addObserver(self, forKeyPath: "canGoForward", options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "canGoBack" || keyPath == "canGoForward" {
            updateNavButtons()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
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
        webView?.removeObserver(self, forKeyPath: "canGoForward")
        pathMonitor?.cancel()
    }
}
