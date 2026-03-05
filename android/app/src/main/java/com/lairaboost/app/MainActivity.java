package com.lairaboost.app;

import android.content.Intent;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
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
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.coordinatorlayout.widget.CoordinatorLayout;
import androidx.core.content.ContextCompat;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {

    private static final int BRAND_COLOR = Color.parseColor("#1a1c24");
    private static final int ACCENT_COLOR = Color.parseColor("#3B82F6");
    private static final int TOOLBAR_HEIGHT_DP = 50;

    private ImageButton backBtn, forwardBtn, shareBtn, refreshBtn;
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

    // ─── Bottom Toolbar ─────────────────────────────────────────

    private void setupToolbar() {
        int toolbarHeightPx = dpToPx(TOOLBAR_HEIGHT_DP);

        ViewGroup contentView = findViewById(android.R.id.content);
        ViewGroup rootLayout = (ViewGroup) contentView.getChildAt(0);

        // Create toolbar
        LinearLayout toolbar = new LinearLayout(this);
        toolbar.setOrientation(LinearLayout.HORIZONTAL);
        toolbar.setBackgroundColor(BRAND_COLOR);
        toolbar.setGravity(Gravity.CENTER_VERTICAL);

        // Create navigation buttons with vector drawables
        backBtn = makeToolbarButton(R.drawable.ic_nav_back);
        forwardBtn = makeToolbarButton(R.drawable.ic_nav_forward);
        shareBtn = makeToolbarButton(R.drawable.ic_nav_share);
        refreshBtn = makeToolbarButton(R.drawable.ic_nav_refresh);

        LinearLayout.LayoutParams btnParams = new LinearLayout.LayoutParams(
                0, LinearLayout.LayoutParams.MATCH_PARENT, 1f
        );

        toolbar.addView(backBtn, btnParams);
        toolbar.addView(forwardBtn, btnParams);
        toolbar.addView(shareBtn, btnParams);
        toolbar.addView(refreshBtn, btnParams);

        // Wrapper with top border
        LinearLayout wrapper = new LinearLayout(this);
        wrapper.setOrientation(LinearLayout.VERTICAL);
        wrapper.setBackgroundColor(BRAND_COLOR);

        View topBorder = new View(this);
        topBorder.setBackgroundColor(Color.argb(40, 255, 255, 255));
        wrapper.addView(topBorder, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpToPx(1)
        ));
        wrapper.addView(toolbar, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, toolbarHeightPx
        ));

        // Add to root at bottom
        CoordinatorLayout.LayoutParams params = new CoordinatorLayout.LayoutParams(
                CoordinatorLayout.LayoutParams.MATCH_PARENT,
                CoordinatorLayout.LayoutParams.WRAP_CONTENT
        );
        params.gravity = Gravity.BOTTOM;
        rootLayout.addView(wrapper, params);

        // Add bottom margin to WebView
        ViewGroup.MarginLayoutParams webParams =
                (ViewGroup.MarginLayoutParams) webView.getLayoutParams();
        webParams.bottomMargin = toolbarHeightPx + dpToPx(1);
        webView.setLayoutParams(webParams);

        // Set actions
        backBtn.setOnClickListener(v -> {
            if (webView.canGoBack()) webView.goBack();
            updateNavButtons();
        });
        forwardBtn.setOnClickListener(v -> {
            if (webView.canGoForward()) webView.goForward();
            updateNavButtons();
        });
        shareBtn.setOnClickListener(v -> {
            String url = webView.getUrl();
            if (url != null) {
                Intent shareIntent = new Intent(Intent.ACTION_SEND);
                shareIntent.setType("text/plain");
                shareIntent.putExtra(Intent.EXTRA_TEXT, url);
                startActivity(Intent.createChooser(shareIntent, "Share via"));
            }
        });
        refreshBtn.setOnClickListener(v -> webView.reload());

        updateNavButtons();
    }

    private ImageButton makeToolbarButton(int drawableRes) {
        ImageButton btn = new ImageButton(this);
        btn.setBackgroundColor(Color.TRANSPARENT);
        btn.setImageDrawable(ContextCompat.getDrawable(this, drawableRes));
        btn.setScaleType(ImageButton.ScaleType.CENTER);
        btn.setPadding(dpToPx(12), dpToPx(12), dpToPx(12), dpToPx(12));
        return btn;
    }

    private void updateNavButtons() {
        if (webView != null && backBtn != null) {
            backBtn.setAlpha(webView.canGoBack() ? 1.0f : 0.35f);
            forwardBtn.setAlpha(webView.canGoForward() ? 1.0f : 0.35f);
        }
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
        swipeRefresh.setColorSchemeColors(ACCENT_COLOR);
        swipeRefresh.setProgressBackgroundColorSchemeColor(BRAND_COLOR);
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

        // Title
        TextView title = new TextView(this);
        title.setText("No Internet Connection");
        title.setTextColor(Color.WHITE);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        title.setGravity(Gravity.CENTER);
        title.setPadding(0, dpToPx(24), 0, dpToPx(8));

        // Subtitle
        TextView subtitle = new TextView(this);
        subtitle.setText("Check your connection and try again");
        subtitle.setTextColor(Color.argb(128, 255, 255, 255));
        subtitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        subtitle.setGravity(Gravity.CENTER);

        // Retry button
        TextView retryBtn = new TextView(this);
        retryBtn.setText("Retry");
        retryBtn.setTextColor(Color.WHITE);
        retryBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        retryBtn.setGravity(Gravity.CENTER);
        retryBtn.setPadding(dpToPx(40), dpToPx(12), dpToPx(40), dpToPx(12));

        GradientDrawable retryBg = new GradientDrawable();
        retryBg.setColor(ACCENT_COLOR);
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
