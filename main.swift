import Cocoa
import WebKit

// ponytail: single-file app, no Xcode project — add one if you ever need entitlements/App Store

// Customize YouTube and bridge masthead drags to the native window.
let pageScript = """
(function () {
  const css = document.createElement('style');
  css.textContent = `
    /* hide sidebar (expanded + collapsed) and the hamburger toggle */
    #guide, tp-yt-app-drawer, ytd-mini-guide-renderer, #guide-button,
    ytd-masthead #guide-button, yt-icon-button#guide-button {display:none !important}
    /* place the YouTube logo at the left edge, cropped to the play glyph */
    ytd-masthead ytd-topbar-logo-renderer {
      position:absolute !important; left:10px !important; z-index:1;
      width:48px !important; overflow:hidden !important;
      pointer-events:none !important;
    }
    ytd-masthead #youtube-logo-hit-target {
      position:absolute !important; top:0 !important; bottom:0 !important;
      left:10px !important; width:48px !important; z-index:3 !important;
      display:block !important; cursor:pointer !important;
    }
    /* left-align the search bar */
    ytd-masthead #container.ytd-masthead {position:relative !important}
    ytd-masthead #center.ytd-masthead {
      position:absolute !important; left:12px !important; z-index:2 !important;
      max-width:640px !important; width:40vw !important;
    }
    ytd-masthead ytd-searchbox #container.ytd-searchbox,
    ytd-masthead yt-searchbox .ytSearchboxComponentInputBox {
      background:transparent !important;
      border:none !important; box-shadow:none !important;
    }
    /* Keep YouTube's re-rendered masthead extras hidden. */
    ytd-masthead button[aria-label="Ask YouTube"],
    ytd-masthead yt-searchbox button[aria-label="Search"],
    ytd-masthead #search-button-narrow,
    ytd-masthead #voice-search-button,
    ytd-masthead #ai-companion-button,
    ytd-masthead #end ytd-button-renderer:has([aria-label="Upload"]),
    ytd-masthead #end [aria-label="Upload"] {display:none !important}
    ytd-masthead #youtube-history-button {
      position:relative !important;
      width:40px !important; height:40px !important;
      margin:0 4px !important; padding:0 !important;
      border-radius:50% !important;
      border:0 !important; background:transparent !important;
      cursor:pointer !important;
    }
    ytd-masthead #youtube-history-button:hover,
    ytd-masthead #youtube-history-button:focus-visible {
      background:rgba(0, 0, 0, .1) !important;
    }
    html[dark] ytd-masthead #youtube-history-button:hover,
    html[dark] ytd-masthead #youtube-history-button:focus-visible {
      background:rgba(255, 255, 255, .1) !important;
    }
    ytd-masthead #youtube-history-button::before {
      content:"" !important;
      position:absolute !important; inset:0 !important;
      background-color:#0f0f0f !important;
      -webkit-mask:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E%3Cpath d='M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18Zm0 2a7 7 0 1 1 0 14 7 7 0 0 1 0-14Zm-1 2v6l5 3 .99-1.65L13 12V7h-2Z'/%3E%3C/svg%3E") center / 26.667px 26.667px no-repeat !important;
      pointer-events:none !important;
    }
    html[dark] ytd-masthead #youtube-history-button::before {
      background-color:#fff !important;
    }
    html.youtube-window-player,
    html.youtube-window-player body {overflow:hidden !important}
    html.youtube-window-player #masthead-container {display:none !important}
    /* Hide the whole watch page but keep the player painted, wherever YouTube
       hosts it. Using visibility (not display:none) means the player stays
       visible even inside a hidden branch, and hidden branches never paint
       over it. */
    html.youtube-window-player ytd-watch-flexy {visibility:hidden !important}
    html.youtube-window-player #movie_player {visibility:visible !important}
    /* Neutralize ancestor transforms and height caps so the pinned player
       anchors to the window and can't be collapsed at large window sizes. */
    html.youtube-window-player ytd-watch-flexy,
    html.youtube-window-player #full-bleed-container,
    html.youtube-window-player #player-full-bleed-container,
    html.youtube-window-player #columns,
    html.youtube-window-player #primary,
    html.youtube-window-player #primary-inner,
    html.youtube-window-player #player,
    html.youtube-window-player #player-container-outer,
    html.youtube-window-player #player-container,
    html.youtube-window-player ytd-player#ytd-player,
    html.youtube-window-player ytd-player#ytd-player > #container {
      transform:none !important;
      overflow:visible !important;
      max-height:none !important;
    }
    /* Pin the player itself to the window, independent of which container
       YouTube hosts it in or how it caps player height for a given size. */
    html.youtube-window-player #movie_player {
      position:fixed !important; inset:0 !important;
      width:100vw !important; height:100vh !important;
      max-width:none !important; max-height:none !important;
      z-index:2147483647 !important;
      background:#000 !important;
      border-radius:0 !important;
    }
    html.youtube-window-player #movie_player .html5-video-container,
    html.youtube-window-player #movie_player video.html5-main-video {
      position:absolute !important; inset:0 !important;
      width:100% !important; height:100% !important;
      max-width:none !important; max-height:none !important;
      transform:none !important;
      border-radius:0 !important;
    }
    html.youtube-window-player #movie_player video.html5-main-video {
      object-fit:contain !important;
    }
    /* hide scrollbars, keep scrolling */
    ::-webkit-scrollbar {display:none !important}
    html {scrollbar-width:none !important}
    /* let main content take the freed width */
    ytd-page-manager.ytd-app {margin-left:0 !important}
  `;
  document.documentElement.appendChild(css);

  // Hide upload/create button only: find the labeled element itself, hide its
  // nearest renderer wrapper (not a shared ancestor like CSS :has did).
  function hideButtons() {
    document.querySelectorAll(
      'ytd-masthead #end [aria-label*="Upload" i], ytd-masthead #end [aria-label*="Create" i], ytd-masthead #end a[href^="/upload"],' +
      'ytd-masthead [aria-label*="Search with your voice" i], ytd-masthead [title*="Search with your voice" i],' +
      'ytd-masthead [aria-label*="Ask" i], ytd-masthead [title*="Ask" i],' +
      'ytd-masthead #search-icon-legacy, ytd-masthead yt-searchbox button[aria-label*="Search" i], ytd-masthead yt-searchbox .ytSearchboxComponentSearchIcon'
    ).forEach(el => {
      const w = el.closest(
        'ytd-topbar-menu-button-renderer, ytd-button-renderer, yt-button-view-model, button-view-model, yt-icon-button, button'
      ) || el;
      w.style.setProperty('display', 'none', 'important');
    });
  }

  function ensureLogoHitTarget() {
    const masthead = document.querySelector('ytd-masthead #container.ytd-masthead');
    const logo = document.querySelector('ytd-masthead ytd-topbar-logo-renderer');
    if (!masthead || !logo || masthead.querySelector('#youtube-logo-hit-target')) return;
    const hitTarget = document.createElement('a');
    hitTarget.id = 'youtube-logo-hit-target';
    hitTarget.href = '/';
    hitTarget.setAttribute('aria-label', 'YouTube Home');
    hitTarget.addEventListener('click', event => {
      event.preventDefault();
      event.stopImmediatePropagation();
      const link = logo.querySelector('a[href="/"], a');
      if (link) link.click();
      else location.assign('https://www.youtube.com/');
    });
    masthead.appendChild(hitTarget);
  }

  function ensureHistoryButton() {
    const buttons = document.querySelector('ytd-masthead #buttons');
    if (!buttons || buttons.querySelector('#youtube-history-button')) return;
    const button = document.createElement('button');
    button.id = 'youtube-history-button';
    button.type = 'button';
    button.title = 'History';
    button.setAttribute('aria-label', 'History');
    button.addEventListener('click', () => location.assign('/feed/history'));
    const profile = buttons.querySelector('ytd-topbar-menu-button-renderer:has(#avatar-btn)');
    buttons.insertBefore(button, profile || null);
  }

  function updateMasthead() {
    hideButtons();
    ensureLogoHitTarget();
    ensureHistoryButton();
  }

  function touchesMasthead(node) {
    return node.nodeType === Node.ELEMENT_NODE &&
      (node.matches?.('ytd-masthead') ||
       node.closest?.('ytd-masthead') ||
       node.querySelector?.('ytd-masthead'));
  }

  // Coalesce YouTube's heavy DOM churn: once an update is queued for this
  // frame, skip re-inspecting further mutations until it runs.
  let mastheadUpdateQueued = false;
  function queueMastheadUpdate() {
    if (mastheadUpdateQueued) return;
    mastheadUpdateQueued = true;
    requestAnimationFrame(() => {
      mastheadUpdateQueued = false;
      updateMasthead();
    });
  }

  updateMasthead();
  new MutationObserver(records => {
    if (mastheadUpdateQueued) return;
    if (records.some(record =>
      touchesMasthead(record.target) ||
      Array.from(record.addedNodes).some(touchesMasthead))) {
      queueMastheadUpdate();
    }
  }).observe(document.body, {
    childList: true,
    attributes: true,
    attributeFilter: ['aria-label', 'title', 'href'],
    subtree: true
  });

  const windowPlayerClass = 'youtube-window-player';
  function setWindowPlayer(active) {
    const root = document.documentElement;
    if (root.classList.contains(windowPlayerClass) === active) return; // no change
    root.classList.toggle(windowPlayerClass, active);
    document.querySelectorAll('.ytp-fullscreen-button').forEach(button => {
      const label = active ? 'Exit full window' : 'Full window';
      button.setAttribute('aria-label', `${label} (f)`);
      button.setAttribute('data-title-no-tooltip', label);
    });
    // The class flip resizes the player via CSS without notifying YouTube, so
    // its control bar keeps the old width. Nudge a resize once layout settles
    // so the player recomputes chrome sizing for the new dimensions.
    requestAnimationFrame(() => window.dispatchEvent(new Event('resize')));
  }
  document.addEventListener('click', event => {
    const button = event.target.closest?.('.ytp-fullscreen-button');
    if (!button) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    setWindowPlayer(!document.documentElement.classList.contains(windowPlayerClass));
  }, true);
  document.addEventListener('keydown', event => {
    if (event.key !== 'Escape' || !document.documentElement.classList.contains(windowPlayerClass)) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    setWindowPlayer(false);
  }, true);
  document.addEventListener('yt-navigate-start', () => setWindowPlayer(false));

  let sx = 0, sy = 0, armed = false;
  addEventListener('mousedown', e => {
    if (e.button !== 0) return;
    if (!e.target.closest('#masthead-container, ytd-masthead')) return;
    if (e.target.closest('a, button, input, textarea, select, [contenteditable], [role="button"], [role="textbox"]')) return;
    armed = true; sx = e.screenX; sy = e.screenY;
  }, true);
  addEventListener('mousemove', e => {
    if (!armed) return;
    if ((e.buttons & 1) === 0) {
      armed = false;
      return;
    }
    if (Math.abs(e.screenX - sx) > 4 || Math.abs(e.screenY - sy) > 4) {
      armed = false;
      webkit.messageHandlers.drag.postMessage(0);
    }
  }, true);
  addEventListener('mouseup', () => { armed = false; }, true);
  addEventListener('blur', () => { armed = false; });
})();
"""

func hideTrafficLights(_ window: NSWindow) {
    for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        guard let button = window.standardWindowButton(type) else { continue }
        button.isEnabled = false
        button.isHidden = true
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    private static let dragMessageName = "drag"

    // Hosts kept inside the app: YouTube itself plus the Google domains its
    // sign-in, account, media, and asset flows rely on. Everything else is an
    // external link and opens in the system browser.
    private static let internalHostSuffixes = [
        "youtube.com", "youtu.be", "youtubekids.com", "ytimg.com",
        "google.com", "googleusercontent.com", "googlevideo.com",
        "ggpht.com", "gstatic.com", "googleapis.com",
    ]

    private func isInternalHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return Self.internalHostSuffixes.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    var window: NSWindow!
    var webView: WKWebView!
    private var mouseMonitor: Any?

    func applicationDidFinishLaunching(_ note: Notification) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // persistent cookies -> stay logged in
        config.userContentController.addUserScript(WKUserScript(
            source: pageScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController.add(self, name: Self.dragMessageName)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "YouTube"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentView = webView

        window.setFrameAutosaveName("YouTubeMainWindow")
        window.center()
        hideTrafficLights(window)
        window.makeKeyAndOrderFront(nil)

        // Hardware back/forward mouse buttons (buttons 4/5 -> buttonNumber 3/4)
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseUp) { [weak self] e in
            guard let self else { return e }
            switch e.buttonNumber {
            case 3 where self.webView.canGoBack:
                self.webView.goBack()
                return nil
            case 4 where self.webView.canGoForward:
                self.webView.goForward()
                return nil
            default: return e
            }
        }

        webView.load(URLRequest(url: URL(string: "https://www.youtube.com")!))
        NSApp.activate(ignoringOtherApps: true)
    }

    // Route top-level navigations: keep YouTube/Google in-app, send external
    // links to the system browser.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.allow) }
        switch url.scheme?.lowercased() {
        case "http", "https":
            // Only hijack main-frame link targets; let subframes and new-window
            // actions (handled in createWebViewWith) proceed normally.
            if navigationAction.targetFrame?.isMainFrame == true, !isInternalHost(url.host) {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        case "blob", "data", "about", "javascript", nil:
            decisionHandler(.allow)
        default:
            // mailto:, tel:, and other app schemes -> hand off to the OS.
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    // target=_blank: YouTube/Google open in the same view; external -> browser.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if isInternalHost(url.host) {
                webView.load(URLRequest(url: url))
            } else {
                NSWorkspace.shared.open(url)
            }
        }
        return nil
    }

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.dragMessageName,
              message.frameInfo.isMainFrame,
              message.body is NSNumber,
              let host = message.frameInfo.request.url?.host?.lowercased(),
              host == "youtube.com" || host.hasSuffix(".youtube.com"),
              NSEvent.pressedMouseButtons & 1 != 0,
              let event = NSApp.currentEvent else { return }
        window.performDrag(with: event)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Self.dragMessageName)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}

// Minimal menu bar so Cmd+Q/C/V/A etc. work
func buildMenu() -> NSMenu {
    let main = NSMenu()

    let appItem = NSMenuItem(); main.addItem(appItem)
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Quit YouTube", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appItem.submenu = appMenu

    let editItem = NSMenuItem(); main.addItem(editItem)
    let edit = NSMenu(title: "Edit")
    edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    edit.addItem(.separator())
    edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editItem.submenu = edit

    return main
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.mainMenu = buildMenu()
let delegate = AppDelegate()
app.delegate = delegate
app.run()
