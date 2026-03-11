import UIKit
import Capacitor
import WebKit
import Network
import AuthenticationServices

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

    // MARK: - Network
    private var pathMonitor: NWPathMonitor?
    private var isOnline = true

    // MARK: - Constants
    private let toolbarHeight: CGFloat = 64
    private let tabBarBg = UIColor(red: 18/255.0, green: 20/255.0, blue: 28/255.0, alpha: 0.97)
    private let accentGreen = UIColor(red: 16/255.0, green: 185/255.0, blue: 129/255.0, alpha: 1)
    private let defaultGray = UIColor(red: 140/255.0, green: 140/255.0, blue: 155/255.0, alpha: 1)
    private let dimGray = UIColor(red: 60/255.0, green: 60/255.0, blue: 70/255.0, alpha: 1)

    // Tab config: (SF Symbol name, filled variant, label)
    private let tabs: [(icon: String, filledIcon: String, label: String)] = [
        ("chevron.backward", "chevron.backward", "Back"),
        ("house", "house.fill", "Home"),
        ("square.grid.2x2", "square.grid.2x2.fill", "Services"),
        ("square.and.arrow.up", "square.and.arrow.up.fill", "Share"),
        ("gearshape", "gearshape.fill", "More"),
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
        setupContentScripts()
        setupScriptMessageHandlers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkFirstLaunch()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollInsets()
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
            navToolbar.heightAnchor.constraint(equalToConstant: toolbarHeight + view.safeAreaInsets.bottom),
            navToolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -toolbarHeight)
        ])

        highlightTab(1) // Home active by default
    }

    private func createTabButton(index: Int, iconName: String, label: String) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.tag = index

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let iconView = UIImageView(image: UIImage(systemName: iconName, withConfiguration: iconConfig))
        iconView.tintColor = defaultGray
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tag = 100

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
        vStack.spacing = 3
        vStack.isUserInteractionEnabled = false
        vStack.translatesAutoresizingMaskIntoConstraints = false

        btn.addSubview(vStack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 26),
            iconView.heightAnchor.constraint(equalToConstant: 26),
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
                let config = UIImage.SymbolConfiguration(pointSize: 22, weight: isActive ? .semibold : .regular)
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

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

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
        case 4: // More (Settings)
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
        subtitle.numberOfLines = 0

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

        // 2. App-optimized content presentation
        let contentJS = """
        (function() {
            function optimizeContent() {
                var body = document.body;
                if (!body) return;
                var walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT, null, false);
                while (walker.nextNode()) {
                    var node = walker.currentNode;
                    var t = node.nodeValue;
                    if (!t || t.trim().length === 0) continue;
                    var orig = t;
                    t = t.replace(/\\bSMM\\s*Panel\\b/gi, 'Marketing Platform');
                    t = t.replace(/\\bSMM\\b/gi, 'Social Media Marketing');
                    t = t.replace(/\\bbuy\\s+followers\\b/gi, 'grow followers');
                    t = t.replace(/\\bbuy\\s+likes\\b/gi, 'boost likes');
                    t = t.replace(/\\bbuy\\s+views\\b/gi, 'boost views');
                    t = t.replace(/\\bbuy\\s+subscribers\\b/gi, 'grow subscribers');
                    t = t.replace(/\\bbuy\\s+comments\\b/gi, 'get comments');
                    t = t.replace(/\\bbuy\\s+shares\\b/gi, 'boost shares');
                    t = t.replace(/\\bbuy\\s+plays\\b/gi, 'boost plays');
                    t = t.replace(/\\bcheap\\s+followers\\b/gi, 'affordable growth');
                    t = t.replace(/\\bcheap\\s+likes\\b/gi, 'affordable engagement');
                    t = t.replace(/\\bfake\\s+followers\\b/gi, 'real growth');
                    t = t.replace(/\\breseller\\s*panel\\b/gi, 'marketing platform');
                    t = t.replace(/\\bpanel\\b/gi, 'platform');
                    if (t !== orig) node.nodeValue = t;
                }
                if (document.title) {
                    document.title = document.title
                        .replace(/SMM Panel/gi, 'Marketing Platform')
                        .replace(/SMM/gi, 'Social Media Marketing')
                        .replace(/Panel/gi, 'Platform');
                }
                // Also sanitize meta description
                var metaDesc = document.querySelector('meta[name="description"]');
                if (metaDesc) {
                    var c = metaDesc.getAttribute('content') || '';
                    c = c.replace(/SMM/gi, 'Social Media Marketing')
                         .replace(/buy followers/gi, 'grow followers')
                         .replace(/panel/gi, 'platform');
                    metaDesc.setAttribute('content', c);
                }
            }
            optimizeContent();
            var observer = new MutationObserver(function() { optimizeContent(); });
            observer.observe(document.body || document.documentElement, {
                childList: true, subtree: true
            });
        })();
        """

        // 3. Sign in with Apple button injection on login page
        let siwaJS = """
        (function() {
            function injectAppleSignIn() {
                // Detect login page
                var loginForm = document.querySelector('form[action*="login"], form[action*="signin"], .login-form, #loginForm, form[method="post"]');
                var passwordField = document.querySelector('input[type="password"]');
                if (!passwordField && !loginForm) return;
                if (!loginForm && passwordField) loginForm = passwordField.closest('form');
                if (!loginForm) return;

                // Don't inject twice
                if (document.getElementById('apple-signin-container')) return;

                // Find submit button or form end
                var submitBtn = loginForm.querySelector('button[type="submit"], input[type="submit"], .btn-primary, .login-btn');

                var container = document.createElement('div');
                container.id = 'apple-signin-container';
                container.style.cssText = 'text-align:center; margin:20px 0 10px; padding:0;';

                var divider = document.createElement('div');
                divider.style.cssText = 'display:flex; align-items:center; margin-bottom:16px; color:#666; font-size:13px;';
                divider.innerHTML = '<div style="flex:1;height:1px;background:#333;"></div><span style="padding:0 14px;">or</span><div style="flex:1;height:1px;background:#333;"></div>';

                var btn = document.createElement('button');
                btn.type = 'button';
                btn.style.cssText = 'display:flex; align-items:center; justify-content:center; width:100%; padding:13px 20px; background:#000; color:#fff; border:1px solid #444; border-radius:10px; font-size:16px; font-weight:500; cursor:pointer; font-family:-apple-system,BlinkMacSystemFont,sans-serif; transition:background 0.2s;';
                btn.innerHTML = '<svg width="18" height="18" viewBox="0 0 18 18" style="margin-right:8px;"><path fill="white" d="M13.7 9.6c0-2.2 1.8-3.3 1.9-3.4-1-1.5-2.6-1.7-3.2-1.7-1.3-.1-2.6.8-3.3.8-.7 0-1.8-.8-3-.7-1.5 0-2.9.9-3.7 2.3-1.6 2.8-.4 6.8 1.1 9.1.7 1.1 1.6 2.3 2.8 2.3 1.1-.1 1.5-.7 2.9-.7 1.3 0 1.7.7 2.9.7 1.2 0 2-1.1 2.7-2.2.9-1.3 1.2-2.5 1.2-2.5 0-.1-2.3-.9-2.3-3.6zM11.4 3c.6-.7 1-1.8.9-2.8-.8 0-1.9.6-2.5 1.3-.5.6-1 1.7-.9 2.7 1 .1 1.9-.5 2.5-1.2z"/></svg> Sign in with Apple';
                btn.onmouseover = function() { this.style.background = '#1a1a1a'; };
                btn.onmouseout = function() { this.style.background = '#000'; };
                btn.onclick = function() {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.appleSignIn) {
                        window.webkit.messageHandlers.appleSignIn.postMessage({action:'signIn'});
                    }
                };

                container.appendChild(divider);
                container.appendChild(btn);

                // Insert after submit button or at end of form
                if (submitBtn && submitBtn.parentNode) {
                    submitBtn.parentNode.insertBefore(container, submitBtn.nextSibling);
                } else {
                    loginForm.appendChild(container);
                }
            }

            // Run after a short delay to ensure page is rendered
            setTimeout(injectAppleSignIn, 500);
            setTimeout(injectAppleSignIn, 1500);

            // Watch for SPA navigation
            var lastUrl = location.href;
            new MutationObserver(function() {
                if (location.href !== lastUrl) {
                    lastUrl = location.href;
                    setTimeout(injectAppleSignIn, 500);
                }
            }).observe(document.body || document.documentElement, {childList:true, subtree:true});
        })();
        """

        // 4. Safe area CSS injection for proper display on all devices
        let safeAreaCSS = """
        (function() {
            var style = document.createElement('style');
            style.textContent = 'body { padding-bottom: env(safe-area-inset-bottom, 0px) !important; }';
            document.head.appendChild(style);
        })();
        """

        ucc.addUserScript(WKUserScript(source: adsenseJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: contentJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: siwaJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: safeAreaCSS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    }

    // MARK: - Script Message Handlers

    private func setupScriptMessageHandlers() {
        scriptHandler = ScriptMessageHandler(delegate: self)
        webView?.configuration.userContentController.add(scriptHandler!, name: "appleSignIn")
    }

    func handleScriptMessage(_ message: WKScriptMessage) {
        if message.name == "appleSignIn" {
            performAppleSignIn()
        }
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

    // MARK: - Cleanup

    deinit {
        webView?.removeObserver(self, forKeyPath: "canGoBack")
        webView?.removeObserver(self, forKeyPath: "URL")
        if let handler = scriptHandler {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "appleSignIn")
        }
        pathMonitor?.cancel()
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

        // Store Apple ID for future credential state checks
        UserDefaults.standard.set(userId, forKey: "com.lairaboost.appleUserId")

        // Attempt to authenticate with the backend
        let js = """
        (function() {
            var data = {
                user_id: '\(userId.replacingOccurrences(of: "'", with: "\\'"))',
                email: '\(email.replacingOccurrences(of: "'", with: "\\'"))',
                first_name: '\(firstName.replacingOccurrences(of: "'", with: "\\'"))',
                last_name: '\(lastName.replacingOccurrences(of: "'", with: "\\'"))',
                identity_token: '\(identityToken.replacingOccurrences(of: "'", with: "\\'"))',
                authorization_code: '\(authCode.replacingOccurrences(of: "'", with: "\\'"))'
            };

            fetch('/api/auth/apple', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(data)
            })
            .then(function(r) { return r.json(); })
            .then(function(d) {
                if (d.success || d.redirect) {
                    window.location.href = d.redirect || '/';
                } else {
                    // Fallback: auto-fill registration form
                    var emailField = document.querySelector('input[name="email"], input[type="email"]');
                    var nameField = document.querySelector('input[name="first_name"], input[name="name"], input[name="fullname"]');
                    if (emailField && data.email) emailField.value = data.email;
                    if (nameField) nameField.value = (data.first_name + ' ' + data.last_name).trim();
                    alert('Welcome! Please complete your registration to continue.');
                }
            })
            .catch(function() {
                var emailField = document.querySelector('input[name="email"], input[type="email"]');
                var nameField = document.querySelector('input[name="first_name"], input[name="name"], input[name="fullname"]');
                if (emailField && data.email) emailField.value = data.email;
                if (nameField) nameField.value = (data.first_name + ' ' + data.last_name).trim();
                alert('Welcome! Please complete your registration to continue.');
            });
        })();
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        // User cancelled - no action needed
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return
        }
        // Show error for other cases
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
