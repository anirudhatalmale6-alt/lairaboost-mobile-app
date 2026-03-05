package com.lairaboost.app;

import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.content.res.ColorStateList;
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

    private static final int BRAND_COLOR = Color.parseColor("#1a1c24");
    private static final int BRAND_SURFACE = Color.parseColor("#242630");
    private static final int ACCENT_GREEN = Color.parseColor("#10B981");
    private static final int ACCENT_BLUE = Color.parseColor("#3B82F6");
    private static final int ICON_DEFAULT = Color.parseColor("#BFBFBF");
    private static final int ICON_INACTIVE = Color.parseColor("#595959");
    private static final int TOOLBAR_HEIGHT_DP = 60;

    private LinearLayout backItem, forwardItem, homeItem, shareItem, refreshItem;
    private ImageView backIcon, forwardIcon, homeIcon, shareIcon, refreshIcon;
    private View offlineOverlay;
    private SwipeRefreshLayout swipeRefresh;
    private WebView webView;
    private boolean isOnline = true;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getBridge().getWebView().post(() -> {
            webView = getBridge().getWebView();
            setupToolbar();
            setupPullToRefresh();
            setupOfflineView();
            setupNetworkMonitoring();
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

    // ─── Modern Bottom Navigation Bar ────────────────────────────

    private void setupToolbar() {
        int toolbarPx = dpToPx(TOOLBAR_HEIGHT_DP);

        ViewGroup contentView = findViewById(android.R.id.content);
        ViewGroup rootLayout = (ViewGroup) contentView.getChildAt(0);

        // Main toolbar container
        LinearLayout toolbar = new LinearLayout(this);
        toolbar.setOrientation(LinearLayout.HORIZONTAL);
        toolbar.setBackgroundColor(BRAND_SURFACE);
        toolbar.setGravity(Gravity.CENTER_VERTICAL);
        toolbar.setElevation(dpToPx(8));

        // Build nav items: Back, Forward, Home, Share, Reload
        backItem = makeNavItem(R.drawable.ic_nav_back, "Back");
        forwardItem = makeNavItem(R.drawable.ic_nav_forward, "Forward");
        homeItem = makeNavItem(R.drawable.ic_nav_home, "Home");
        shareItem = makeNavItem(R.drawable.ic_nav_share, "Share");
        refreshItem = makeNavItem(R.drawable.ic_nav_refresh, "Reload");

        // Get icon refs (tag 100)
        backIcon = (ImageView) backItem.findViewWithTag("icon");
        forwardIcon = (ImageView) forwardItem.findViewWithTag("icon");
        homeIcon = (ImageView) homeItem.findViewWithTag("icon");
        shareIcon = (ImageView) shareItem.findViewWithTag("icon");
        refreshIcon = (ImageView) refreshItem.findViewWithTag("icon");

        LinearLayout.LayoutParams itemParams = new LinearLayout.LayoutParams(
                0, LinearLayout.LayoutParams.MATCH_PARENT, 1f
        );

        toolbar.addView(backItem, itemParams);
        toolbar.addView(forwardItem, itemParams);
        toolbar.addView(homeItem, itemParams);
        toolbar.addView(shareItem, itemParams);
        toolbar.addView(refreshItem, itemParams);

        // Wrapper: thin separator line + toolbar
        LinearLayout wrapper = new LinearLayout(this);
        wrapper.setOrientation(LinearLayout.VERTICAL);

        View sep = new View(this);
        sep.setBackgroundColor(Color.argb(20, 255, 255, 255));
        wrapper.addView(sep, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 1
        ));
        wrapper.addView(toolbar, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, toolbarPx
        ));

        CoordinatorLayout.LayoutParams params = new CoordinatorLayout.LayoutParams(
                CoordinatorLayout.LayoutParams.MATCH_PARENT,
                CoordinatorLayout.LayoutParams.WRAP_CONTENT
        );
        params.gravity = Gravity.BOTTOM;
        rootLayout.addView(wrapper, params);

        // Adjust WebView margin
        ViewGroup.MarginLayoutParams webParams =
                (ViewGroup.MarginLayoutParams) webView.getLayoutParams();
        webParams.bottomMargin = toolbarPx + 1;
        webView.setLayoutParams(webParams);

        // Actions
        backItem.setOnClickListener(v -> {
            if (webView.canGoBack()) webView.goBack();
            updateNavButtons();
        });
        forwardItem.setOnClickListener(v -> {
            if (webView.canGoForward()) webView.goForward();
            updateNavButtons();
        });
        homeItem.setOnClickListener(v -> webView.loadUrl("https://lairaboost.com"));
        shareItem.setOnClickListener(v -> {
            String url = webView.getUrl();
            if (url != null) {
                Intent shareIntent = new Intent(Intent.ACTION_SEND);
                shareIntent.setType("text/plain");
                shareIntent.putExtra(Intent.EXTRA_TEXT, url);
                startActivity(Intent.createChooser(shareIntent, "Share via"));
            }
        });
        refreshItem.setOnClickListener(v -> webView.reload());

        // Home is highlighted
        homeIcon.setColorFilter(ACCENT_GREEN);
        TextView homeLbl = (TextView) homeItem.findViewWithTag("label");
        if (homeLbl != null) homeLbl.setTextColor(ACCENT_GREEN);

        updateNavButtons();
    }

    private LinearLayout makeNavItem(int drawableRes, String label) {
        LinearLayout item = new LinearLayout(this);
        item.setOrientation(LinearLayout.VERTICAL);
        item.setGravity(Gravity.CENTER);
        item.setPadding(0, dpToPx(6), 0, dpToPx(6));

        // Ripple effect
        RippleDrawable ripple = new RippleDrawable(
                ColorStateList.valueOf(Color.argb(30, 255, 255, 255)),
                null, new ColorDrawable(Color.WHITE)
        );
        item.setBackground(ripple);
        item.setClickable(true);
        item.setFocusable(true);

        // Icon
        ImageView icon = new ImageView(this);
        icon.setImageDrawable(ContextCompat.getDrawable(this, drawableRes));
        icon.setColorFilter(ICON_DEFAULT);
        icon.setTag("icon");

        LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(
                dpToPx(22), dpToPx(22)
        );
        iconParams.gravity = Gravity.CENTER;

        // Label
        TextView lbl = new TextView(this);
        lbl.setText(label);
        lbl.setTextColor(ICON_DEFAULT);
        lbl.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10);
        lbl.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        lbl.setGravity(Gravity.CENTER);
        lbl.setTag("label");

        LinearLayout.LayoutParams lblParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
        );
        lblParams.topMargin = dpToPx(2);
        lblParams.gravity = Gravity.CENTER;

        item.addView(icon, iconParams);
        item.addView(lbl, lblParams);

        return item;
    }

    private void updateNavButtons() {
        if (webView == null || backIcon == null) return;

        boolean canBack = webView.canGoBack();
        boolean canFwd = webView.canGoForward();

        backIcon.setColorFilter(canBack ? ICON_DEFAULT : ICON_INACTIVE);
        forwardIcon.setColorFilter(canFwd ? ICON_DEFAULT : ICON_INACTIVE);
        backItem.setAlpha(canBack ? 1.0f : 0.5f);
        forwardItem.setAlpha(canFwd ? 1.0f : 0.5f);

        TextView backLbl = (TextView) backItem.findViewWithTag("label");
        TextView fwdLbl = (TextView) forwardItem.findViewWithTag("label");
        if (backLbl != null) backLbl.setTextColor(canBack ? ICON_DEFAULT : ICON_INACTIVE);
        if (fwdLbl != null) fwdLbl.setTextColor(canFwd ? ICON_DEFAULT : ICON_INACTIVE);
    }

    // ─── Pull to Refresh ────────────────────────────────────────

    private void setupPullToRefresh() {
        ViewGroup parent = (ViewGroup) webView.getParent();
        int index = parent.indexOfChild(webView);
        ViewGroup.LayoutParams webParams = webView.getLayoutParams();

        parent.removeView(webView);

        swipeRefresh = new SwipeRefreshLayout(this);
        swipeRefresh.addView(webView, new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        ));
        swipeRefresh.setColorSchemeColors(ACCENT_GREEN);
        swipeRefresh.setProgressBackgroundColorSchemeColor(BRAND_SURFACE);
        swipeRefresh.setOnRefreshListener(() -> {
            webView.reload();
            webView.postDelayed(() -> swipeRefresh.setRefreshing(false), 2000);
        });

        parent.addView(swipeRefresh, index, webParams);
    }

    // ─── Offline View ───────────────────────────────────────────

    private void setupOfflineView() {
        FrameLayout overlay = new FrameLayout(this);
        overlay.setBackgroundColor(BRAND_COLOR);
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
        retryBtn.setPadding(dpToPx(40), dpToPx(12), dpToPx(40), dpToPx(12));

        GradientDrawable retryBg = new GradientDrawable();
        retryBg.setColor(ACCENT_GREEN);
        retryBg.setCornerRadius(dpToPx(22));
        retryBtn.setBackground(retryBg);

        LinearLayout.LayoutParams retryParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
        );
        retryParams.topMargin = dpToPx(24);
        retryParams.gravity = Gravity.CENTER;

        container.addView(title);
        container.addView(subtitle);
        container.addView(retryBtn, retryParams);

        FrameLayout.LayoutParams centerParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
        );
        overlay.addView(container, centerParams);

        ViewGroup contentView = findViewById(android.R.id.content);
        ViewGroup rootLayout = (ViewGroup) contentView.getChildAt(0);
        CoordinatorLayout.LayoutParams overlayParams = new CoordinatorLayout.LayoutParams(
                CoordinatorLayout.LayoutParams.MATCH_PARENT,
                CoordinatorLayout.LayoutParams.MATCH_PARENT
        );
        rootLayout.addView(overlay, overlayParams);

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

    // ─── Helpers ────────────────────────────────────────────────

    private int dpToPx(int dp) {
        return (int) (dp * getResources().getDisplayMetrics().density);
    }
}
