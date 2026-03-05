import UIKit
import Capacitor
import WebKit
import Network

class LairaboostViewController: CAPBridgeViewController {

    // MARK: - UI Elements
    private var navToolbar: UIView!
    private var backBtn: UIButton!
    private var forwardBtn: UIButton!
    private var shareBtn: UIButton!
    private var refreshBtn: UIButton!
    private var offlineOverlay: UIView!
    private var refreshControl: UIRefreshControl!

    // MARK: - Network
    private var pathMonitor: NWPathMonitor?
    private var isOnline = true

    // MARK: - Constants
    private let toolbarHeight: CGFloat = 50
    private let brandBg = UIColor(red: 26/255.0, green: 28/255.0, blue: 36/255.0, alpha: 1)
    private let accentBlue = UIColor(red: 59/255.0, green: 130/255.0, blue: 246/255.0, alpha: 1)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // webView is ready after super.viewDidLoad()
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

    // MARK: - Bottom Toolbar

    private func setupBottomToolbar() {
        navToolbar = UIView()
        navToolbar.backgroundColor = brandBg
        navToolbar.translatesAutoresizingMaskIntoConstraints = false

        // Top separator line
        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        sep.translatesAutoresizingMaskIntoConstraints = false
        navToolbar.addSubview(sep)

        // Create buttons
        backBtn = makeNavButton(systemName: "chevron.left", action: #selector(tapBack))
        forwardBtn = makeNavButton(systemName: "chevron.right", action: #selector(tapForward))
        shareBtn = makeNavButton(systemName: "square.and.arrow.up", action: #selector(tapShare))
        refreshBtn = makeNavButton(systemName: "arrow.clockwise", action: #selector(tapRefresh))

        let stack = UIStackView(arrangedSubviews: [backBtn, forwardBtn, shareBtn, refreshBtn])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        navToolbar.addSubview(stack)

        view.addSubview(navToolbar)

        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: navToolbar.topAnchor),
            sep.leadingAnchor.constraint(equalTo: navToolbar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: navToolbar.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),

            stack.topAnchor.constraint(equalTo: navToolbar.topAnchor),
            stack.leadingAnchor.constraint(equalTo: navToolbar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: navToolbar.trailingAnchor),
            stack.heightAnchor.constraint(equalToConstant: toolbarHeight),

            navToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navToolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            navToolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -toolbarHeight)
        ])

        updateNavButtons()
    }

    private func makeNavButton(systemName: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        btn.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    private func updateNavButtons() {
        let canBack = webView?.canGoBack ?? false
        let canFwd = webView?.canGoForward ?? false
        backBtn?.isEnabled = canBack
        forwardBtn?.isEnabled = canFwd
        backBtn?.alpha = canBack ? 1.0 : 0.35
        forwardBtn?.alpha = canFwd ? 1.0 : 0.35
    }

    // MARK: - Toolbar Actions

    @objc private func tapBack() {
        webView?.goBack()
    }

    @objc private func tapForward() {
        webView?.goForward()
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
        webView?.reload()
    }

    // MARK: - Pull to Refresh

    private func setupPullToRefresh() {
        guard let scrollView = webView?.scrollView else { return }
        refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
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
        retryBtn.backgroundColor = accentBlue
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
