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
    html.youtube-window-player,
    html.youtube-window-player body {overflow:hidden !important}
    html.youtube-window-player #masthead-container,
    html.youtube-window-player ytd-watch-flexy > :not(#full-bleed-container) {
      display:none !important;
    }
    html.youtube-window-player #full-bleed-container,
    html.youtube-window-player #player-full-bleed-container {
      overflow:visible !important;
    }
    html.youtube-window-player #player-container {
      position:fixed !important; inset:0 !important;
      width:100vw !important; height:100vh !important;
      z-index:2147483647 !important;
      background:#000 !important;
    }
    html.youtube-window-player ytd-player#ytd-player,
    html.youtube-window-player ytd-player#ytd-player > #container,
    html.youtube-window-player #movie_player,
    html.youtube-window-player #movie_player .html5-video-container {
      position:absolute !important; inset:0 !important;
      width:100% !important; height:100% !important;
      max-width:none !important; max-height:none !important;
      border-radius:0 !important;
    }
    html.youtube-window-player #movie_player {background:#000 !important}
    html.youtube-window-player #movie_player video.html5-main-video {
      position:absolute !important; inset:0 !important;
      width:100% !important; height:100% !important;
      object-fit:contain !important;
    }
    /* hide scrollbars, keep scrolling */
    ::-webkit-scrollbar {display:none !important}
    html {scrollbar-width:none !important}
    /* let main content take the freed width */
    ytd-app[mini-guide-visible] ytd-page-manager.ytd-app {margin-left:0 !important}
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
      const w = el.closest('ytd-topbar-menu-button-renderer, ytd-button-renderer, yt-icon-button, button') || el;
      w.style.display = 'none';
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

  function updateMasthead() {
    hideButtons();
    ensureLogoHitTarget();
  }

  function touchesMasthead(node) {
    return node.nodeType === Node.ELEMENT_NODE &&
      (node.matches?.('ytd-masthead') ||
       node.closest?.('ytd-masthead') ||
       node.querySelector?.('ytd-masthead'));
  }

  updateMasthead();
  new MutationObserver(records => {
    if (records.some(record =>
      touchesMasthead(record.target) ||
      Array.from(record.addedNodes).some(touchesMasthead))) {
      updateMasthead();
    }
  }).observe(document.body, {childList: true, subtree: true});

  const windowPlayerClass = 'youtube-window-player';
  function setWindowPlayer(active) {
    document.documentElement.classList.toggle(windowPlayerClass, active);
    document.querySelectorAll('.ytp-fullscreen-button').forEach(button => {
      const label = active ? 'Exit full window' : 'Full window';
      button.setAttribute('aria-label', `${label} (f)`);
      button.setAttribute('data-title-no-tooltip', label);
    });
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

class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private static let dragMessageName = "drag"

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

    // target=_blank links open in the same view instead of dying
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { webView.load(URLRequest(url: url)) }
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
