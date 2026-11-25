(function () {
    "use strict";

    const css = [
        "#onetrust-banner-sdk",
        "#onetrust-consent-sdk",
        ".onetrust-pc-dark",
        "#CybotCookiebotDialog",
        "#CybotCookiebotDialogBodyUnderlay",
        ".cc-window",
        ".cc-banner",
        ".qc-cmp2-container",
        ".qc-cmp-cleanslate",
        '[id*="cookie-banner" i]',
        '[id*="cookieBanner"]',
        '[class*="cookie-banner" i]',
        '[class*="CookieBanner"]',
        '[id*="cookie-consent" i]',
        '[class*="cookie-consent" i]',
        "#cookie-law-info-bar",
        ".cli-modal-backdrop",
        ".fc-consent-root",
        ".fc-dialog-overlay",
        "#didomi-host",
        ".didomi-popup-container",
        '[id^="sp_message_container"]',
        ".osano-cm-window",
        ".osano-cm-dialog",
        "#iubenda-cs-banner",
        ".iubenda-cs-overlay",
        ".cky-overlay",
        ".cky-consent-container",
        "#usercentrics-root",
        ".truste_overlay",
        ".truste_box_overlay",
        "#gdpr-banner",
        ".gdpr-banner",
        '[aria-label*="cookie" i][role="dialog"]',
        "iframe[src*='doubleclick']",
        "iframe[src*='googlesyndication']",
        "iframe[src*='adservice']",
        "iframe[src*='cookiebot']",
        "iframe[src*='onetrust']",
        "[id*='google_ads']",
        ".adsbygoogle",
        "ins.adsbygoogle",
        "div[data-ad]",
        ".advertisement"
    ].join(",") + "{display:none!important;visibility:hidden!important;pointer-events:none!important;height:0!important;max-height:0!important;overflow:hidden!important;}";

    const decline = [
        "reject all",
        "reject",
        "decline all",
        "decline",
        "deny",
        "refuse",
        "essential only",
        "necessary only",
        "necessary cookies",
        "only necessary",
        "only essential",
        "required cookies only",
        "use necessary",
        "continue without accepting",
        "ablehnen alle",
        "alle ablehnen",
        "ablehnen",
        "nur notwendige",
        "nur essenzielle",
        "nur erforderliche",
        "nur erforderliche cookies",
        "ablehnen und schließen",
        "refuser tout",
        "tout refuser",
        "refuser"
    ];
    const accept = [
        "accept all",
        "accept",
        "allow all",
        "allow",
        "i agree",
        "agree",
        "got it",
        "alle akzeptieren",
        "akzeptieren",
        "zustimmen",
        "einverstanden",
        "alle zulassen",
        "zulassen",
        "tout accepter",
        "accepter"
    ];

    let clicks = 0;
    const seen = new WeakSet();

    function injectCss() {
        if (document.getElementById("modern-provider-filter"))
            return;
        const el = document.createElement("style");
        el.id = "modern-provider-filter";
        el.textContent = css;
        const parent = document.documentElement || document.head || document.body;
        if (parent)
            parent.appendChild(el);
    }

    function norm(s) {
        return String(s || "").toLowerCase().replace(/\s+/g, " ").trim();
    }

    function visible(el) {
        if (!el || el.disabled)
            return false;
        const st = window.getComputedStyle(el);
        if (st.display === "none" || st.visibility === "hidden" || st.opacity === "0")
            return false;
        const r = el.getBoundingClientRect();
        return r.width > 8 && r.height > 8;
    }

    function labelOf(el) {
        return norm(
            el.getAttribute("aria-label") ||
            el.value ||
            el.textContent ||
            ""
        );
    }

    function hasPhrase(t, p) {
        const esc = p.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        return new RegExp("(^|\\s)" + esc + "(\\s|$)", "i").test(t);
    }

    function isAccept(t) {
        return accept.some((p) => hasPhrase(t, p));
    }

    function isDecline(t) {
        if (!t || isAccept(t))
            return false;
        return decline.some((p) => hasPhrase(t, p));
    }

    function clickDeclines() {
        if (clicks >= 8)
            return;
        const nodes = document.querySelectorAll("button, [role='button'], a, input[type='button'], input[type='submit']");
        for (let i = 0; i < nodes.length; i++) {
            const el = nodes[i];
            if (seen.has(el) || !visible(el))
                continue;
            if (!isDecline(labelOf(el)))
                continue;
            seen.add(el);
            clicks += 1;
            try {
                el.click();
            } catch (e) {
            }
            if (clicks >= 8)
                return;
        }
    }

    function run() {
        injectCss();
        clickDeclines();
    }

    let scheduled = 0;
    function schedule() {
        if (scheduled)
            return;
        scheduled = 1;
        setTimeout(function () {
            scheduled = 0;
            run();
        }, 50);
    }

    injectCss();
    run();
    const obs = new MutationObserver(schedule);
    obs.observe(document.documentElement || document, {
        childList: true,
        subtree: true
    });
    document.addEventListener("DOMContentLoaded", run);
})();
