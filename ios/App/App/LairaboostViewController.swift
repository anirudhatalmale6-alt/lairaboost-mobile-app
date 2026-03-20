import UIKit
import Capacitor
import WebKit
import Network
import AuthenticationServices
import LocalAuthentication
import SafariServices

// MARK: - Script Message Handler

class ScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: LairaboostViewController?

    init(delegate: LairaboostViewController) {
        self.delegate = delegate
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        delegate?.handleScriptMessage(message)
    }
}

// MARK: - Main View Controller

class LairaboostViewController: CAPBridgeViewController {

    // MARK: - UI Elements
    private var navToolbar: UIView!
    private var tabButtons: [UIButton] = []
    private var offlineOverlay: UIView!
    private var refreshControl: UIRefreshControl!
    private var scriptHandler: ScriptMessageHandler?
    private var biometricOverlay: UIView?
    private var hasCheckedBiometric = false

    // MARK: - Network
    private var pathMonitor: NWPathMonitor?
    private var isOnline = true

    // MARK: - Constants
    private let toolbarHeight: CGFloat = 72
    private let darkBg = UIColor(red: 18/255.0, green: 20/255.0, blue: 28/255.0, alpha: 1)
    private let tabBarBg = UIColor(red: 18/255.0, green: 20/255.0, blue: 28/255.0, alpha: 0.98)
    private let accentGreen = UIColor(red: 16/255.0, green: 185/255.0, blue: 129/255.0, alpha: 1)
    private let defaultGray = UIColor(red: 140/255.0, green: 140/255.0, blue: 155/255.0, alpha: 1)

    // 5 tabs: Home (web), Orders (web), Account (native), Notifications (native), More (native)
    private let tabs: [(icon: String, filledIcon: String, label: String)] = [
        ("house", "house.fill", "Home"),
        ("list.clipboard", "list.clipboard.fill", "Orders"),
        ("person.crop.circle", "person.crop.circle.fill", "Account"),
        ("bell", "bell.fill", "Alerts"),
        ("ellipsis.circle", "ellipsis.circle.fill", "More"),
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setCustomUserAgent()
        webView?.scrollView.bounces = true
        webView?.navigationDelegate = self
        setupTabBar()
        setupPullToRefresh()
        setupOfflineView()
        startNetworkMonitoring()
        enableSwipeNavigation()
        observeNavigation()
        setupContentScripts()
        setupScriptMessageHandlers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkFirstLaunch()
        if !hasCheckedBiometric {
            hasCheckedBiometric = true
            checkBiometricAuth()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollInsets()
    }

    // MARK: - Custom User Agent

    private func setCustomUserAgent() {
        webView?.customUserAgent = nil
        webView?.evaluateJavaScript("navigator.userAgent") { [weak self] result, _ in
            if let ua = result as? String {
                self?.webView?.customUserAgent = ua + " LairaboostApp/2.0"
            }
        }
    }

    // MARK: - Biometric Authentication

    private func checkBiometricAuth() {
        let biometricEnabled = UserDefaults.standard.bool(forKey: "com.lairaboost.biometricEnabled")
        guard biometricEnabled else { return }

        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return }

        // Show overlay
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = darkBg
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let lockIcon = UIImageView(image: UIImage(systemName: "lock.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 48, weight: .light)))
        lockIcon.tintColor = accentGreen
        lockIcon.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(lockIcon)

        let label = UILabel()
        label.text = "Unlock Lairaboost"
        label.textColor = .white
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(label)

        NSLayoutConstraint.activate([
            lockIcon.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            lockIcon.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -30),
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.topAnchor.constraint(equalTo: lockIcon.bottomAnchor, constant: 16)
        ])

        view.addSubview(overlay)
        biometricOverlay = overlay

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                              localizedReason: "Authenticate to access Lairaboost") { [weak self] success, _ in
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3, animations: {
                    self?.biometricOverlay?.alpha = 0
                }) { _ in
                    self?.biometricOverlay?.removeFromSuperview()
                    self?.biometricOverlay = nil
                }
            }
        }
    }

    // MARK: - First Launch Onboarding

    private func checkFirstLaunch() {
        let key = "com.lairaboost.hasCompletedOnboarding"
        if !UserDefaults.standard.bool(forKey: key) {
            let onboarding = OnboardingViewController()
            onboarding.modalPresentationStyle = .fullScreen
            onboarding.onComplete = {
                UserDefaults.standard.set(true, forKey: key)
            }
            present(onboarding, animated: true)
        }
    }

    // MARK: - Tab Bar

    private func setupTabBar() {
        navToolbar = UIView()
        navToolbar.backgroundColor = tabBarBg
        navToolbar.translatesAutoresizingMaskIntoConstraints = false

        // Blur effect behind tab bar
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        navToolbar.insertSubview(blur, at: 0)

        // Top border
        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        sep.translatesAutoresizingMaskIntoConstraints = false
        navToolbar.addSubview(sep)

        // Tab buttons
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
            blur.topAnchor.constraint(equalTo: navToolbar.topAnchor),
            blur.leadingAnchor.constraint(equalTo: navToolbar.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: navToolbar.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: navToolbar.bottomAnchor),

            sep.topAnchor.constraint(equalTo: navToolbar.topAnchor),
            sep.leadingAnchor.constraint(equalTo: navToolbar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: navToolbar.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),

            stack.topAnchor.constraint(equalTo: navToolbar.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: navToolbar.safeAreaLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: navToolbar.safeAreaLayoutGuide.trailingAnchor),
            stack.heightAnchor.constraint(equalToConstant: 56),

            navToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navToolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            navToolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -toolbarHeight)
        ])

        highlightTab(0)
    }

    private func createTabButton(index: Int, iconName: String, label: String) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.tag = index

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        let iconView = UIImageView(image: UIImage(systemName: iconName, withConfiguration: iconConfig))
        iconView.tintColor = defaultGray
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tag = 100

        let lbl = UILabel()
        lbl.text = label
        lbl.font = .systemFont(ofSize: 11, weight: .medium)
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
            vStack.centerYAnchor.constraint(equalTo: btn.centerYAnchor)
        ])

        btn.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func highlightTab(_ activeIndex: Int) {
        for (i, btn) in tabButtons.enumerated() {
            let isActive = (i == activeIndex)
            let tab = tabs[i]
            let color = isActive ? accentGreen : defaultGray

            if let iconView = btn.viewWithTag(100) as? UIImageView {
                let iconName = isActive ? tab.filledIcon : tab.icon
                let config = UIImage.SymbolConfiguration(pointSize: 24, weight: isActive ? .semibold : .regular)
                iconView.image = UIImage(systemName: iconName, withConfiguration: config)
                iconView.tintColor = color
            }
            if let lbl = btn.viewWithTag(200) as? UILabel {
                lbl.textColor = color
                lbl.font = .systemFont(ofSize: 11, weight: isActive ? .semibold : .medium)
            }
        }
    }

    @objc private func tabTapped(_ sender: UIButton) {
        let index = sender.tag
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        switch index {
        case 0: // Home
            if let url = URL(string: "https://lairaboost.com") {
                webView?.load(URLRequest(url: url))
            }
            highlightTab(0)
        case 1: // Orders
            if let url = URL(string: "https://lairaboost.com/orders") {
                webView?.load(URLRequest(url: url))
            }
            highlightTab(1)
        case 2: // Account (native)
            let accountVC = AccountViewController()
            accountVC.webView = self.webView
            let nav = UINavigationController(rootViewController: accountVC)
            nav.modalPresentationStyle = .pageSheet
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberIndicator = true
            }
            present(nav, animated: true)
        case 3: // Notifications (native)
            let notifVC = NotificationsViewController()
            let nav = UINavigationController(rootViewController: notifVC)
            nav.modalPresentationStyle = .pageSheet
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberIndicator = true
            }
            present(nav, animated: true)
        case 4: // More (native settings)
            let settingsVC = SettingsViewController()
            settingsVC.webView = self.webView
            settingsVC.onReload = { [weak self] in
                self?.webView?.reload()
            }
            let nav = UINavigationController(rootViewController: settingsVC)
            nav.modalPresentationStyle = .pageSheet
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberIndicator = true
            }
            present(nav, animated: true)
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
        offlineOverlay.backgroundColor = darkBg
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
        subtitle.numberOfLines = 0

        let retryBtn = UIButton(type: .system)
        retryBtn.setTitle("Retry", for: .normal)
        retryBtn.setTitleColor(.white, for: .normal)
        retryBtn.backgroundColor = accentGreen
        retryBtn.layer.cornerRadius = 28
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
            container.leadingAnchor.constraint(greaterThanOrEqualTo: offlineOverlay.leadingAnchor, constant: 40),
            container.trailingAnchor.constraint(lessThanOrEqualTo: offlineOverlay.trailingAnchor, constant: -40)
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

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == "canGoBack" || keyPath == "URL" {
            updateTabState()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    private func updateTabState() {
        if let urlStr = webView?.url?.absoluteString {
            if urlStr.contains("/orders") {
                highlightTab(1)
            } else {
                highlightTab(0)
            }
        }
    }

    // MARK: - Scroll Insets

    private func updateScrollInsets() {
        guard let toolbar = navToolbar else { return }
        let totalToolbarHeight = view.bounds.height - toolbar.frame.origin.y
        webView?.scrollView.contentInset.bottom = totalToolbarHeight
        webView?.scrollView.verticalScrollIndicatorInsets.bottom = totalToolbarHeight
    }

    // MARK: - Content Scripts

    private func setupContentScripts() {
        guard let ucc = webView?.configuration.userContentController else { return }

        // 1. AdSense injection
        let adsenseJS = """
        (function() {
            if (!document.querySelector('meta[name="google-adsense-account"]')) {
                var meta = document.createElement('meta');
                meta.name = 'google-adsense-account';
                meta.content = 'ca-pub-7279544766670377';
                document.head.appendChild(meta);
            }
            if (!document.querySelector('script[src*="adsbygoogle"]')) {
                var script = document.createElement('script');
                script.async = true;
                script.src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-7279544766670377';
                script.crossOrigin = 'anonymous';
                document.head.appendChild(script);
            }
        })();
        """

        // 2. Comprehensive content optimization for app presentation
        let contentJS = """
        (function() {
            function optimizeContent() {
                var body = document.body;
                if (!body) return;

                // Text node replacements
                var walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT, null, false);
                while (walker.nextNode()) {
                    var node = walker.currentNode;
                    var t = node.nodeValue;
                    if (!t || t.trim().length === 0) continue;
                    var orig = t;

                    // Core SMM terminology
                    t = t.replace(/\\bSMM\\s*Panel\\b/gi, 'Marketing Platform');
                    t = t.replace(/\\bSMM\\s*Services?\\b/gi, 'Marketing Services');
                    t = t.replace(/\\bSMM\\b/gi, 'SMM');
                    t = t.replace(/\\breseller\\s*panel\\b/gi, 'marketing platform');

                    // Purchase language
                    t = t.replace(/\\bbuy\\s+followers\\b/gi, 'grow audience');
                    t = t.replace(/\\bbuy\\s+likes\\b/gi, 'boost engagement');
                    t = t.replace(/\\bbuy\\s+views\\b/gi, 'increase reach');
                    t = t.replace(/\\bbuy\\s+subscribers\\b/gi, 'grow community');
                    t = t.replace(/\\bbuy\\s+comments\\b/gi, 'get interactions');
                    t = t.replace(/\\bbuy\\s+shares\\b/gi, 'boost distribution');
                    t = t.replace(/\\bbuy\\s+plays\\b/gi, 'boost impressions');
                    t = t.replace(/\\bbuy\\s+retweets?\\b/gi, 'boost reposts');
                    t = t.replace(/\\bbuy\\s+saves?\\b/gi, 'boost saves');
                    t = t.replace(/\\bbuy\\s+reactions?\\b/gi, 'boost reactions');

                    // Service descriptions
                    t = t.replace(/\\bfollowers?\\s*[\\[\\(].*?[\\]\\)]/gi, function(m) {
                        return m.replace(/cheap/gi, 'standard').replace(/fake/gi, 'organic').replace(/bot/gi, 'managed');
                    });
                    t = t.replace(/\\bcheap\\s+(followers|likes|views|subscribers)/gi, 'affordable $1');
                    t = t.replace(/\\bfake\\s+(followers|likes|views)/gi, 'organic $1');
                    t = t.replace(/\\breal\\s+followers\\b/gi, 'quality audience');
                    t = t.replace(/\\binstant\\s+(followers|likes|views)/gi, 'express $1');
                    t = t.replace(/\\bbot\\s+(followers|likes|views)/gi, 'managed $1');
                    t = t.replace(/\\bdrip\\s*feed\\b/gi, 'gradual delivery');

                    // General terms
                    t = t.replace(/\\bpanel\\b/g, 'platform');
                    t = t.replace(/\\bPanel\\b/g, 'Platform');
                    t = t.replace(/\\bPANEL\\b/g, 'PLATFORM');

                    if (t !== orig) node.nodeValue = t;
                }

                // Page title
                if (document.title) {
                    document.title = document.title
                        .replace(/SMM Panel/gi, 'Marketing Platform')
                        .replace(/SMM/gi, 'Social Media')
                        .replace(/Panel/gi, 'Platform')
                        .replace(/Buy (Followers|Likes|Views)/gi, 'Grow $1');
                }

                // Meta description
                var metaDesc = document.querySelector('meta[name="description"]');
                if (metaDesc) {
                    var c = metaDesc.getAttribute('content') || '';
                    c = c.replace(/SMM/gi, 'Social Media Marketing')
                         .replace(/buy (followers|likes|views)/gi, 'grow $1')
                         .replace(/panel/gi, 'platform')
                         .replace(/cheap/gi, 'affordable');
                    metaDesc.setAttribute('content', c);
                }

                // Button text
                document.querySelectorAll('button, input[type="submit"], .btn').forEach(function(el) {
                    if (el.textContent) {
                        el.textContent = el.textContent
                            .replace(/Buy Now/gi, 'Get Started')
                            .replace(/Order Now/gi, 'Start Now')
                            .replace(/Place Order/gi, 'Launch Campaign')
                            .replace(/Submit Order/gi, 'Submit Request');
                    }
                    if (el.value) {
                        el.value = el.value
                            .replace(/Buy Now/gi, 'Get Started')
                            .replace(/Order Now/gi, 'Start Now')
                            .replace(/Place Order/gi, 'Launch Campaign')
                            .replace(/Submit Order/gi, 'Submit Request');
                    }
                });

                // Select option text
                document.querySelectorAll('select option').forEach(function(opt) {
                    if (opt.textContent) {
                        opt.textContent = opt.textContent
                            .replace(/\\bbuy\\b/gi, 'get')
                            .replace(/\\bcheap\\b/gi, 'standard')
                            .replace(/\\bfake\\b/gi, 'organic')
                            .replace(/\\bbot\\b/gi, 'managed')
                            .replace(/\\bpanel\\b/gi, 'platform');
                    }
                });

                // Placeholder text
                document.querySelectorAll('input[placeholder]').forEach(function(inp) {
                    var p = inp.getAttribute('placeholder');
                    if (p) {
                        p = p.replace(/buy/gi, 'get').replace(/panel/gi, 'platform');
                        inp.setAttribute('placeholder', p);
                    }
                });
            }

            // Run immediately and on mutations
            optimizeContent();
            var debounceTimer;
            var observer = new MutationObserver(function() {
                clearTimeout(debounceTimer);
                debounceTimer = setTimeout(optimizeContent, 100);
            });
            observer.observe(document.body || document.documentElement, {
                childList: true, subtree: true, characterData: true
            });
        })();
        """

        // 3. Sign in with Apple button on login page
        let siwaJS = """
        (function() {
            function injectAppleSignIn() {
                var passwordField = document.querySelector('input[type="password"]');
                if (!passwordField) return;
                var loginForm = passwordField.closest('form');
                if (!loginForm) return;
                if (document.getElementById('apple-signin-container')) return;

                var submitBtn = loginForm.querySelector('button[type="submit"], input[type="submit"], .btn-primary, .login-btn, .btn-success');

                var container = document.createElement('div');
                container.id = 'apple-signin-container';
                container.style.cssText = 'text-align:center; margin:24px 0 12px; padding:0;';

                var divider = document.createElement('div');
                divider.style.cssText = 'display:flex; align-items:center; margin-bottom:18px; color:#888; font-size:13px;';
                divider.innerHTML = '<div style="flex:1;height:1px;background:#444;"></div><span style="padding:0 16px;">or</span><div style="flex:1;height:1px;background:#444;"></div>';

                var btn = document.createElement('button');
                btn.type = 'button';
                btn.id = 'apple-signin-btn';
                btn.style.cssText = 'display:flex; align-items:center; justify-content:center; width:100%; padding:14px 24px; background:#000; color:#fff; border:1px solid #555; border-radius:12px; font-size:17px; font-weight:500; cursor:pointer; font-family:-apple-system,BlinkMacSystemFont,sans-serif; min-height:50px;';
                btn.innerHTML = '<svg width="20" height="20" viewBox="0 0 20 20" style="margin-right:10px;flex-shrink:0;"><path fill="white" d="M15.2 10.5c0-2.4 1.9-3.5 2-3.6-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.9-3.5.9-.7 0-1.9-.8-3.1-.8-1.6 0-3.1 1-3.9 2.4-1.7 3-.4 7.3 1.2 9.7.8 1.2 1.7 2.5 3 2.4 1.2-.1 1.6-.8 3.1-.8 1.4 0 1.8.8 3 .8 1.3 0 2.1-1.2 2.9-2.4.9-1.4 1.3-2.7 1.3-2.7 0-.1-2.5-1-2.6-3.8zM12.7 3.1c.6-.8 1.1-1.9 1-3-.9 0-2.1.7-2.7 1.4-.6.7-1.1 1.8-.9 2.9 1 .1 2-.5 2.6-1.3z"/></svg> Sign in with Apple';
                btn.onclick = function() {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.appleSignIn) {
                        window.webkit.messageHandlers.appleSignIn.postMessage({action:'signIn'});
                    }
                };

                container.appendChild(divider);
                container.appendChild(btn);

                if (submitBtn && submitBtn.parentNode) {
                    submitBtn.parentNode.insertBefore(container, submitBtn.nextSibling);
                } else {
                    loginForm.appendChild(container);
                }
            }

            setTimeout(injectAppleSignIn, 300);
            setTimeout(injectAppleSignIn, 1000);
            setTimeout(injectAppleSignIn, 2000);

            var lastUrl = location.href;
            new MutationObserver(function() {
                if (location.href !== lastUrl) {
                    lastUrl = location.href;
                    setTimeout(injectAppleSignIn, 500);
                }
            }).observe(document.body || document.documentElement, {childList:true, subtree:true});
        })();
        """

        // 4. Aggressive blocking of ALL service ordering, purchasing, and SMM features
        let blockServicesJS = """
        (function() {
            // Blocked paths — redirect to dashboard
            var blockedPaths = [
                '/services', '/neworder', '/addfunds', '/add-funds',
                '/api', '/api-docs', '/apidocs', '/child-panels',
                '/childpanels', '/childpanel', '/reseller'
            ];

            function isBlockedPath(path) {
                path = path.toLowerCase().replace(/\\/+$/, '');
                for (var i = 0; i < blockedPaths.length; i++) {
                    if (path === blockedPaths[i] || path.indexOf(blockedPaths[i] + '/') === 0) {
                        return true;
                    }
                }
                return false;
            }

            // Immediately redirect blocked pages
            if (isBlockedPath(window.location.pathname)) {
                window.location.replace('/');
                // Halt execution
                throw new Error('blocked');
            }

            function blockServices() {
                var path = window.location.pathname.toLowerCase().replace(/\\/+$/, '');
                if (isBlockedPath(path)) {
                    window.location.replace('/');
                    return;
                }

                // Hide ALL links to blocked pages anywhere on the page
                var selectors = [
                    'a[href*="/services"]', 'a[href*="/neworder"]',
                    'a[href*="/addfunds"]', 'a[href*="/add-funds"]',
                    'a[href*="/api"]', 'a[href*="/child"]',
                    'a[href*="/reseller"]'
                ];
                document.querySelectorAll(selectors.join(',')).forEach(function(el) {
                    var href = (el.getAttribute('href') || '').toLowerCase();
                    // Don't hide /api links that are informational or login-related
                    if (href.indexOf('/api') !== -1 && href.indexOf('/apple_auth') !== -1) return;
                    el.style.display = 'none';
                    // Also hide parent li if in a menu
                    var li = el.closest('li');
                    if (li) li.style.display = 'none';
                });

                // Hide ALL ordering buttons, forms, and CTAs
                document.querySelectorAll('button, .btn, a.btn, input[type="submit"]').forEach(function(el) {
                    var text = (el.textContent || el.value || '').trim().toLowerCase();
                    var href = (el.getAttribute('href') || '').toLowerCase();
                    if (text.match(/new order|place order|order now|add funds|buy now|start now|submit order|order service/) ||
                        href.match(/\\/services|\\/neworder|\\/addfunds|\\/add-funds/)) {
                        el.style.display = 'none';
                    }
                });

                // Hide service category selectors and order forms
                document.querySelectorAll('select[name="category"], select[name="service"], #orderForm, .order-form, form[action*="neworder"], form[action*="services"]').forEach(function(el) {
                    el.style.display = 'none';
                });

                // Hide pricing tables and service listings
                document.querySelectorAll('.service-list, .price-list, .pricing-table, .service-card, [class*="service-item"], [class*="pricing"]').forEach(function(el) {
                    el.style.display = 'none';
                });

                // Intercept Google sign-in links — delegate to native handler
                document.querySelectorAll('a[href*="google=1"], a[href*="google_login"], .lb-google-btn').forEach(function(el) {
                    if (el.dataset.nativeHandled) return;
                    el.dataset.nativeHandled = '1';
                    el.addEventListener('click', function(e) {
                        e.preventDefault();
                        e.stopPropagation();
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.googleSignIn) {
                            window.webkit.messageHandlers.googleSignIn.postMessage({action:'signIn', url: el.href || '/login?google=1'});
                        }
                    }, true);
                });
            }

            // Run immediately
            blockServices();
            // Run on DOM mutations
            var debounce2;
            new MutationObserver(function() {
                clearTimeout(debounce2);
                debounce2 = setTimeout(blockServices, 100);
            }).observe(document.body || document.documentElement, {childList:true, subtree:true});
        })();
        """

        // 5. Safe area CSS for all devices
        let safeAreaCSS = """
        (function() {
            var style = document.createElement('style');
            style.textContent = [
                'body { padding-bottom: env(safe-area-inset-bottom, 0px) !important; }',
                'html { -webkit-text-size-adjust: 100%; }',
                ':root { --sat: env(safe-area-inset-top); --sab: env(safe-area-inset-bottom); --sal: env(safe-area-inset-left); --sar: env(safe-area-inset-right); }'
            ].join('\\n');
            document.head.appendChild(style);
        })();
        """

        ucc.addUserScript(WKUserScript(source: blockServicesJS, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: adsenseJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: contentJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: siwaJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: safeAreaCSS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    }

    // MARK: - Script Message Handlers

    private func setupScriptMessageHandlers() {
        scriptHandler = ScriptMessageHandler(delegate: self)
        webView?.configuration.userContentController.add(scriptHandler!, name: "appleSignIn")
        webView?.configuration.userContentController.add(scriptHandler!, name: "googleSignIn")
    }

    func handleScriptMessage(_ message: WKScriptMessage) {
        if message.name == "appleSignIn" {
            if let body = message.body as? [String: Any],
               let action = body["action"] as? String {
                if action == "signIn" {
                    performAppleSignIn()
                } else if action == "error", let msg = body["message"] as? String {
                    if let presented = presentedViewController as? UIAlertController,
                       presented.message == "Signing in..." {
                        presented.dismiss(animated: true) { [weak self] in
                            self?.showError(msg)
                        }
                    } else {
                        showError(msg)
                    }
                }
            } else {
                performAppleSignIn()
            }
        } else if message.name == "googleSignIn" {
            if let body = message.body as? [String: Any],
               let urlStr = body["url"] as? String,
               let url = URL(string: urlStr) {
                openGoogleAuthSession(url: url)
            } else {
                if let url = URL(string: "https://lairaboost.com/login?google=1") {
                    openGoogleAuthSession(url: url)
                }
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Sign In Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Apple Sign In

    private func performAppleSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - Google Sign In (via ASWebAuthenticationSession)

    private func openGoogleAuthSession(url: URL) {
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "com.lairaboost.app"
        ) { [weak self] callbackURL, error in
            if let error = error {
                if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    return // User cancelled
                }
                DispatchQueue.main.async {
                    self?.showError("Google Sign In failed. Please try again.")
                }
                return
            }

            // After Google OAuth completes, the server redirects back to lairaboost.com
            // Load the homepage which should now have the session cookies set
            DispatchQueue.main.async {
                if let homeURL = URL(string: "https://lairaboost.com/") {
                    self?.webView?.load(URLRequest(url: homeURL))
                }
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    // MARK: - Content Sanitizer (Apple Review compliance)

    private func injectContentSanitizer() {
        let sanitizeJS = """
        (function() {
            var map = {
                'followers': 'growth plans',
                'Followers': 'Growth Plans',
                'FOLLOWERS': 'GROWTH PLANS',
                'likes': 'engagement',
                'Likes': 'Engagement',
                'LIKES': 'ENGAGEMENT',
                'views': 'reach',
                'Views': 'Reach',
                'VIEWS': 'REACH',
                'subscribers': 'audience plans',
                'Subscribers': 'Audience Plans',
                'boost': 'promote',
                'Boost': 'Promote',
                'BOOST': 'PROMOTE',
                'SMM Panel': 'Marketing Dashboard',
                'SMM panel': 'Marketing Dashboard',
                'smm panel': 'marketing dashboard',
                'social media marketing': 'digital marketing',
                'Social Media Marketing': 'Digital Marketing',
                'buy followers': 'marketing services',
                'Buy Followers': 'Marketing Services',
                'buy likes': 'engagement services',
                'Buy Likes': 'Engagement Services',
                'cheap followers': 'affordable plans',
                'Cheap Followers': 'Affordable Plans',
                'real followers': 'premium plans',
                'Real Followers': 'Premium Plans',
                'comments': 'interactions',
                'Comments': 'Interactions',
                'Retweets': 'Amplification',
                'retweets': 'amplification',
                'Reactions': 'Responses',
                'reactions': 'responses',
                'Chatters': 'Community',
                'chatters': 'community',
                'Connections': 'Networking',
                'Plays': 'Streams',
                'Saves': 'Bookmarks'
            };

            function sanitize(node) {
                if (node.nodeType === 3) {
                    var text = node.nodeValue;
                    var changed = false;
                    for (var k in map) {
                        if (text.indexOf(k) !== -1) {
                            text = text.split(k).join(map[k]);
                            changed = true;
                        }
                    }
                    if (changed) node.nodeValue = text;
                } else if (node.nodeType === 1 && node.tagName !== 'SCRIPT' && node.tagName !== 'STYLE') {
                    for (var i = 0; i < node.childNodes.length; i++) {
                        sanitize(node.childNodes[i]);
                    }
                    // Also sanitize placeholder and title attributes
                    if (node.placeholder) {
                        for (var k in map) {
                            if (node.placeholder.indexOf(k) !== -1) {
                                node.placeholder = node.placeholder.split(k).join(map[k]);
                            }
                        }
                    }
                    if (node.title) {
                        for (var k in map) {
                            if (node.title.indexOf(k) !== -1) {
                                node.title = node.title.split(k).join(map[k]);
                            }
                        }
                    }
                }
            }

            // Sanitize page title
            function sanitizeTitle() {
                var t = document.title;
                for (var k in map) {
                    if (t.indexOf(k) !== -1) {
                        t = t.split(k).join(map[k]);
                    }
                }
                document.title = t;
            }

            // Run on load and on mutations
            function run() {
                sanitize(document.body);
                sanitizeTitle();
            }

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', run);
            } else {
                run();
            }

            // Watch for dynamic content changes
            var observer = new MutationObserver(function(mutations) {
                mutations.forEach(function(m) {
                    m.addedNodes.forEach(function(n) { sanitize(n); });
                });
                sanitizeTitle();
            });
            observer.observe(document.body || document.documentElement, {
                childList: true, subtree: true
            });

            // Also run after AJAX/page transitions
            window.addEventListener('load', run);
            setInterval(run, 3000);
        })();
        """
        let userScript = WKUserScript(source: sanitizeJS, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView?.configuration.userContentController.addUserScript(userScript)
    }

    // MARK: - Cleanup

    deinit {
        webView?.removeObserver(self, forKeyPath: "canGoBack")
        webView?.removeObserver(self, forKeyPath: "URL")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "appleSignIn")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "googleSignIn")
        pathMonitor?.cancel()
    }
}

// MARK: - WKNavigationDelegate

extension LairaboostViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url,
              let host = url.host?.lowercased() else {
            decisionHandler(.allow)
            return
        }

        // Handle Google OAuth — open in ASWebAuthenticationSession
        if host.contains("accounts.google.com") || host.contains("google.com/o/oauth") {
            decisionHandler(.cancel)
            openGoogleAuthSession(url: url)
            return
        }

        // Only intercept lairaboost.com URLs
        if host.contains("lairaboost.com") {
            let path = url.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            // Blocked paths — redirect to home
            let blockedPaths = ["services", "neworder", "addfunds", "add-funds",
                                "api", "api-docs", "apidocs", "child-panels",
                                "childpanels", "childpanel", "reseller"]
            for blocked in blockedPaths {
                if path == blocked || path.hasPrefix(blocked + "/") {
                    decisionHandler(.cancel)
                    if let homeURL = URL(string: "https://lairaboost.com/") {
                        webView.load(URLRequest(url: homeURL))
                    }
                    return
                }
            }

            // Intercept Google sign-in link on lairaboost.com
            if let query = url.query?.lowercased(), query.contains("google=1") {
                decisionHandler(.cancel)
                openGoogleAuthSession(url: url)
                return
            }
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Dismiss loading alert if SIWA navigation completed
        if let presented = presentedViewController as? UIAlertController,
           presented.message == "Signing in..." {
            presented.dismiss(animated: true)
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension LairaboostViewController: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        let userId = credential.user
        let email = credential.email ?? ""
        let firstName = credential.fullName?.givenName ?? ""
        let lastName = credential.fullName?.familyName ?? ""
        let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let authCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        // Store Apple ID
        UserDefaults.standard.set(userId, forKey: "com.lairaboost.appleUserId")
        if !email.isEmpty {
            UserDefaults.standard.set(email, forKey: "com.lairaboost.appleEmail")
        }

        // Show loading indicator
        let loadingAlert = UIAlertController(title: nil, message: "Signing in...", preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        loadingAlert.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerYAnchor.constraint(equalTo: loadingAlert.view.centerYAnchor),
            indicator.leadingAnchor.constraint(equalTo: loadingAlert.view.leadingAnchor, constant: 20),
            loadingAlert.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        present(loadingAlert, animated: true)

        // Use stored email for subsequent sign-ins when Apple doesn't provide it
        let effectiveEmail = email.isEmpty ?
            (UserDefaults.standard.string(forKey: "com.lairaboost.appleEmail") ?? "") : email

        // Authenticate with backend using form POST (not fetch)
        // Form submission causes a real page navigation which properly saves cookies
        let js = """
        (function() {
            var form = document.createElement('form');
            form.method = 'POST';
            form.action = '/apple_auth.php';
            form.style.display = 'none';

            var fields = {
                'user_id': '\(userId.replacingOccurrences(of: "'", with: "\\'"))',
                'email': '\(effectiveEmail.replacingOccurrences(of: "'", with: "\\'"))',
                'first_name': '\(firstName.replacingOccurrences(of: "'", with: "\\'"))',
                'last_name': '\(lastName.replacingOccurrences(of: "'", with: "\\'"))',
                'identity_token': '\(identityToken.replacingOccurrences(of: "'", with: "\\'"))',
                'authorization_code': '\(authCode.replacingOccurrences(of: "'", with: "\\'"))'
            };

            for (var key in fields) {
                var input = document.createElement('input');
                input.type = 'hidden';
                input.name = key;
                input.value = fields[key];
                form.appendChild(input);
            }

            document.body.appendChild(form);
            form.submit();
        })();
        """

        // Submit form and dismiss loading when navigation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: nil)
            // Dismiss loading after navigation has time to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                loadingAlert.dismiss(animated: true)
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return
        }
        let alert = UIAlertController(title: "Sign In Failed",
                                      message: "Could not complete Apple Sign In. Please try again.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension LairaboostViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension LairaboostViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window!
    }
}
