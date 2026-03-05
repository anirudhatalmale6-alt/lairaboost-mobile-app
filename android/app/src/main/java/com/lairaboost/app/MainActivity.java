package com.lairaboost.app;

import android.content.Intent;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebView;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.coordinatorlayout.widget.CoordinatorLayout;
import androidx.core.content.ContextCompat;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {

    private static final int BRAND_BG = Color.parseColor("#12141C");
    private static final int TAB_BAR_BG = Color.parseColor("#12141C");
    private static final int ACCENT_GREEN = Color.parseColor("#10B981");
    private static final int DEFAULT_GRAY = Color.parseColor("#8C8C9B");
    private static final int DIM_GRAY = Color.parseColor("#3C3C46");
    private static final int TOOLBAR_HEIGHT_DP = 64;

    // Tab items
    private LinearLayout[] tabItems = new LinearLayout[5];
    private ImageView[] tabIcons = new ImageView[5];
    private TextView[] tabLabels = new TextView[5];
    private int activeTab = 1; // Home

    private View offlineOverlay;
    private SwipeRefreshLayout swipeRefresh;
    private WebView webView;
    private boolean isOnline = true;

    // Tab config: iconRes, iconActiveRes, label
    private static final int[][] TAB_ICONS = {
        {R.drawable.ic_nav_back, R.drawable.ic_nav_back},
        {R.drawable.ic_nav_home, R.drawable.ic_nav_home_filled},
        {R.drawable.ic_nav_services, R.drawable.ic_nav_services_filled},
        {R.drawable.ic_nav_share, R.drawable.ic_nav_share},
        {R.drawable.ic_nav_refresh, R.drawable.ic_nav_refresh},
    };
    private static final String[] TAB_LABELS = {"Back", "Home", "Services", "Share", "Reload"};

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getBridge().getWebView().post(() -> {
            webView = getBridge().getWebView();
            setupTabBar();
            setupPullToRefresh();
            setupOfflineView();
            setupNetworkMonitoring();
            setupAdSenseInjection();
        });
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    // ─── Modern Tab Bar ─────────────────────────────────────────

    private void setupTabBar() {
        int toolbarPx = dpToPx(TOOLBAR_HEIGHT_DP);

        ViewGroup contentView = findViewById(android.R.id.content);
        ViewGroup rootLayout = (ViewGroup) contentView.getChildAt(0);

        LinearLayout tabBar = new LinearLayout(this);
        tabBar.setOrientation(LinearLayout.HORIZONTAL);
        tabBar.setBackgroundColor(TAB_BAR_BG);
        tabBar.setElevation(dpToPx(12));

        for (int i = 0; i < 5; i++) {
            tabItems[i] = createTabItem(i, TAB_ICONS[i][0], TAB_LABELS[i]);
            LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f);
            tabBar.addView(tabItems[i], p);
        }

        // Wrapper: separator + tab bar
        LinearLayout wrapper = new LinearLayout(this);
        wrapper.setOrientation(LinearLayout.VERTICAL);

        View sep = new View(this);
        sep.setBackgroundColor(Color.argb(15, 255, 255, 255));
        wrapper.addView(sep, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1));
        wrapper.addView(tabBar, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toolbarPx));

        CoordinatorLayout.LayoutParams params = new CoordinatorLayout.LayoutParams(
                CoordinatorLayout.LayoutParams.MATCH_PARENT,
                CoordinatorLayout.LayoutParams.WRAP_CONTENT
        );
        params.gravity = Gravity.BOTTOM;
        rootLayout.addView(wrapper, params);

        // WebView margin
        ViewGroup.MarginLayoutParams webParams = (ViewGroup.MarginLayoutParams) webView.getLayoutParams();
        webParams.bottomMargin = toolbarPx + 1;
        webView.setLayoutParams(webParams);

        // Set initial state
        setActiveTab(1);
    }

    private LinearLayout createTabItem(int index, int iconRes, String label) {
        LinearLayout item = new LinearLayout(this);
        item.setOrientation(LinearLayout.VERTICAL);
        item.setGravity(Gravity.CENTER);
        item.setPadding(0, dpToPx(8), 0, dpToPx(8));

        // Ripple
        RippleDrawable ripple = new RippleDrawable(
                ColorStateList.valueOf(Color.argb(20, 255, 255, 255)),
                null, new ColorDrawable(Color.WHITE)
        );
        item.setBackground(ripple);
        item.setClickable(true);
        item.setFocusable(true);

        // Icon
        ImageView icon = new ImageView(this);
        icon.setImageDrawable(ContextCompat.getDrawable(this, iconRes));
        icon.setColorFilter(DEFAULT_GRAY);
        tabIcons[index] = icon;

        LinearLayout.LayoutParams iconP = new LinearLayout.LayoutParams(dpToPx(26), dpToPx(26));
        iconP.gravity = Gravity.CENTER;

        // Label
        TextView lbl = new TextView(this);
        lbl.setText(label);
        lbl.setTextColor(DEFAULT_GRAY);
        lbl.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10);
        lbl.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        lbl.setGravity(Gravity.CENTER);
        tabLabels[index] = lbl;

        LinearLayout.LayoutParams lblP = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT
        );
        lblP.topMargin = dpToPx(4);
        lblP.gravity = Gravity.CENTER;

        item.addView(icon, iconP);
        item.addView(lbl, lblP);

        final int idx = index;
        item.setOnClickListener(v -> onTabClick(idx));

        return item;
    }

    private void onTabClick(int index) {
        switch (index) {
            case 0: // Back
                if (webView.canGoBack()) webView.goBack();
                updateBackButton();
                break;
            case 1: // Home
                webView.loadUrl("https://lairaboost.com");
                setActiveTab(1);
                webView.postDelayed(() -> injectAdSense(), 3000);
                break;
            case 2: // Services
                webView.loadUrl("https://lairaboost.com/services");
                setActiveTab(2);
                webView.postDelayed(() -> injectAdSense(), 3000);
                break;
            case 3: // Share
                String url = webView.getUrl();
                if (url != null) {
                    Intent shareIntent = new Intent(Intent.ACTION_SEND);
                    shareIntent.setType("text/plain");
                    shareIntent.putExtra(Intent.EXTRA_TEXT, url);
                    startActivity(Intent.createChooser(shareIntent, "Share via"));
                }
                break;
            case 4: // Reload
                webView.reload();
                break;
        }
    }

    private void setActiveTab(int index) {
        activeTab = index;
        for (int i = 0; i < 5; i++) {
            boolean isActive = (i == index);

            if (i == 0) {
                updateBackButton();
                continue;
            }

            int iconRes = isActive ? TAB_ICONS[i][1] : TAB_ICONS[i][0];
            int color = isActive ? ACCENT_GREEN : DEFAULT_GRAY;

            tabIcons[i].setImageDrawable(ContextCompat.getDrawable(this, iconRes));
            tabIcons[i].setColorFilter(color);
            tabLabels[i].setTextColor(color);
            tabLabels[i].setTypeface(Typeface.create(
                    isActive ? "sans-serif-bold" : "sans-serif-medium", Typeface.NORMAL
            ));
        }
    }

    private void updateBackButton() {
        boolean canBack = webView != null && webView.canGoBack();
        int color = canBack ? DEFAULT_GRAY : DIM_GRAY;
        tabIcons[0].setColorFilter(color);
        tabLabels[0].setTextColor(color);
        tabItems[0].setAlpha(canBack ? 1.0f : 0.6f);
    }

    // ─── Pull to Refresh ────────────────────────────────────────

    private void setupPullToRefresh() {
        ViewGroup parent = (ViewGroup) webView.getParent();
        int index = parent.indexOfChild(webView);
        ViewGroup.LayoutParams webParams = webView.getLayoutParams();

        parent.removeView(webView);

        swipeRefresh = new SwipeRefreshLayout(this);
        swipeRefresh.addView(webView, new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
        ));
        swipeRefresh.setColorSchemeColors(ACCENT_GREEN);
        swipeRefresh.setProgressBackgroundColorSchemeColor(TAB_BAR_BG);
        swipeRefresh.setOnRefreshListener(() -> {
            webView.reload();
            webView.postDelayed(() -> swipeRefresh.setRefreshing(false), 2000);
        });

        parent.addView(swipeRefresh, index, webParams);
    }

    // ─── Offline View ───────────────────────────────────────────

    private void setupOfflineView() {
        FrameLayout overlay = new FrameLayout(this);
        overlay.setBackgroundColor(BRAND_BG);
        overlay.setVisibility(View.GONE);

        LinearLayout container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);
        container.setGravity(Gravity.CENTER);
        container.setPadding(dpToPx(32), 0, dpToPx(32), 0);

        TextView title = new TextView(this);
        title.setText("No Internet Connection");
        title.setTextColor(Color.WHITE);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        title.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        title.setGravity(Gravity.CENTER);
        title.setPadding(0, dpToPx(24), 0, dpToPx(8));

        TextView subtitle = new TextView(this);
        subtitle.setText("Check your connection and try again");
        subtitle.setTextColor(Color.argb(128, 255, 255, 255));
        subtitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        subtitle.setGravity(Gravity.CENTER);

        TextView retryBtn = new TextView(this);
        retryBtn.setText("Retry");
        retryBtn.setTextColor(Color.WHITE);
        retryBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        retryBtn.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        retryBtn.setGravity(Gravity.CENTER);
        retryBtn.setPadding(dpToPx(48), dpToPx(14), dpToPx(48), dpToPx(14));

        GradientDrawable retryBg = new GradientDrawable();
        retryBg.setColor(ACCENT_GREEN);
        retryBg.setCornerRadius(dpToPx(24));
        retryBtn.setBackground(retryBg);

        LinearLayout.LayoutParams retryP = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT
        );
        retryP.topMargin = dpToPx(28);
        retryP.gravity = Gravity.CENTER;

        container.addView(title);
        container.addView(subtitle);
        container.addView(retryBtn, retryP);

        overlay.addView(container, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER
        ));

        ViewGroup contentView = findViewById(android.R.id.content);
        ViewGroup rootLayout = (ViewGroup) contentView.getChildAt(0);
        rootLayout.addView(overlay, new CoordinatorLayout.LayoutParams(
                CoordinatorLayout.LayoutParams.MATCH_PARENT,
                CoordinatorLayout.LayoutParams.MATCH_PARENT
        ));

        this.offlineOverlay = overlay;

        retryBtn.setOnClickListener(v -> {
            if (isOnline) {
                overlay.setVisibility(View.GONE);
                webView.reload();
            }
        });
    }

    // ─── Network Monitoring ─────────────────────────────────────

    private void setupNetworkMonitoring() {
        ConnectivityManager cm = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
        if (cm == null) return;

        NetworkRequest request = new NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build();

        cm.registerNetworkCallback(request, new ConnectivityManager.NetworkCallback() {
            @Override
            public void onAvailable(@NonNull Network network) {
                runOnUiThread(() -> {
                    boolean wasOffline = !isOnline;
                    isOnline = true;
                    if (offlineOverlay != null) offlineOverlay.setVisibility(View.GONE);
                    if (wasOffline && webView != null) webView.reload();
                });
            }

            @Override
            public void onLost(@NonNull Network network) {
                runOnUiThread(() -> {
                    isOnline = false;
                    if (offlineOverlay != null) offlineOverlay.setVisibility(View.VISIBLE);
                });
            }
        });
    }

    // ─── AdSense Injection ──────────────────────────────────────

    private static final String ADSENSE_JS =
        "(function(){" +
        "if(!document.querySelector('meta[name=\"google-adsense-account\"]')){" +
        "var m=document.createElement('meta');" +
        "m.name='google-adsense-account';" +
        "m.content='ca-pub-7279544766670377';" +
        "document.head.appendChild(m);}" +
        "if(!document.querySelector('script[src*=\"adsbygoogle\"]')){" +
        "var s=document.createElement('script');" +
        "s.async=true;" +
        "s.src='https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-7279544766670377';" +
        "s.crossOrigin='anonymous';" +
        "document.head.appendChild(s);}" +
        "})();";

    private void setupAdSenseInjection() {
        // Inject on initial page load (with delay for page to finish)
        webView.postDelayed(() -> injectAdSense(), 3000);
    }

    private void injectAdSense() {
        if (webView != null) {
            webView.evaluateJavascript(ADSENSE_JS, null);
        }
    }

    // ─── Helpers ────────────────────────────────────────────────

    private int dpToPx(int dp) {
        return (int) (dp * getResources().getDisplayMetrics().density);
    }
}
