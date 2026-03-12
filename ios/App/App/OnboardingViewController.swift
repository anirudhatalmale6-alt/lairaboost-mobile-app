import UIKit

class OnboardingViewController: UIViewController {

    var onComplete: (() -> Void)?

    // MARK: - Properties
    private var scrollView: UIScrollView!
    private var pageControl: UIPageControl!
    private var nextButton: UIButton!
    private var skipButton: UIButton!
    private var currentPage = 0

    private let accentGreen = UIColor(red: 16/255.0, green: 185/255.0, blue: 129/255.0, alpha: 1)
    private let darkBg = UIColor(red: 18/255.0, green: 20/255.0, blue: 28/255.0, alpha: 1)

    private let pages: [(icon: String, title: String, subtitle: String)] = [
        ("chart.line.uptrend.xyaxis", "Grow Your Audience", "Professional marketing tools to expand your reach across Instagram, TikTok, YouTube, and more."),
        ("person.crop.circle.fill", "Your Account Dashboard", "Track your balance, monitor campaigns, and manage everything from your native account screen."),
        ("bell.fill", "Real-Time Alerts", "Get instant notifications on campaign progress. Enable Face ID for secure, private access."),
        ("shield.fill", "Trusted & Secure", "Protected by industry-standard encryption. Trusted by thousands of marketers worldwide."),
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = darkBg
        setupUI()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Skip button
        skipButton = UIButton(type: .system)
        skipButton.setTitle("Skip", for: .normal)
        skipButton.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
        skipButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        view.addSubview(skipButton)

        // Scroll view
        scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Page control
        pageControl = UIPageControl()
        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.currentPageIndicatorTintColor = accentGreen
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.2)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageControl)

        // Next/Get Started button
        nextButton = UIButton(type: .system)
        nextButton.setTitle("Next", for: .normal)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.backgroundColor = accentGreen
        nextButton.layer.cornerRadius = 28
        nextButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        view.addSubview(nextButton)

        NSLayoutConstraint.activate([
            skipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            skipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: skipButton.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -30),

            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -30),

            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            nextButton.widthAnchor.constraint(equalToConstant: 220),
            nextButton.heightAnchor.constraint(equalToConstant: 56),
        ])

        // Build pages
        buildPages()
    }

    private func buildPages() {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, multiplier: CGFloat(pages.count)),
        ])

        for (index, page) in pages.enumerated() {
            let pageView = createPageView(icon: page.icon, title: page.title, subtitle: page.subtitle)
            pageView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(pageView)

            NSLayoutConstraint.activate([
                pageView.topAnchor.constraint(equalTo: contentView.topAnchor),
                pageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                pageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
                pageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor,
                    constant: CGFloat(index) * UIScreen.main.bounds.width),
            ])
        }
    }

    private func createPageView(icon: String, title: String, subtitle: String) -> UIView {
        let container = UIView()

        // Icon circle background
        let iconBg = UIView()
        iconBg.backgroundColor = accentGreen.withAlphaComponent(0.12)
        iconBg.layer.cornerRadius = 60
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = accentGreen
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconBg)
        iconBg.addSubview(iconView)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            iconBg.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconBg.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -80),
            iconBg.widthAnchor.constraint(equalToConstant: 120),
            iconBg.heightAnchor.constraint(equalToConstant: 120),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconBg.bottomAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40),
        ])

        return container
    }

    // MARK: - Actions

    @objc private func nextTapped() {
        if currentPage < pages.count - 1 {
            currentPage += 1
            let offset = CGFloat(currentPage) * scrollView.bounds.width
            scrollView.setContentOffset(CGPoint(x: offset, y: 0), animated: true)
            updateUI()
        } else {
            completeOnboarding()
        }
    }

    @objc private func skipTapped() {
        completeOnboarding()
    }

    private func completeOnboarding() {
        onComplete?()
        dismiss(animated: true)
    }

    private func updateUI() {
        pageControl.currentPage = currentPage
        if currentPage == pages.count - 1 {
            nextButton.setTitle("Get Started", for: .normal)
            skipButton.isHidden = true
        } else {
            nextButton.setTitle("Next", for: .normal)
            skipButton.isHidden = false
        }
    }
}

// MARK: - UIScrollViewDelegate

extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        currentPage = page
        updateUI()
    }
}
