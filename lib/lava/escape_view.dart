import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../pyre/agent_forge.dart';
import '../pyre/beacon_hub.dart';
import '../pyre/caverns_vault.dart';
import '../pyre/signal_probe.dart';
import 'magma_offline.dart';

// ============================================================
// ESCAPE VIEW — full-screen WebView (gray content)
// ============================================================
// Hosts the destination URL with every partner-required capability
// wired up:
//   • forged device UA (identical to the HTTP client),
//   • all four screen orientations, immersive system UI,
//   • external-scheme handoff (tel:, mailto:, intent:, whatsapp:, tg:),
//   • redirect-loop recovery (up to 3 automatic retries),
//   • live connectivity guard (VPN-friendly, DNS-agnostic on drop),
//   • warm push URL loading via [BeaconHub.liveLinkSink],
//   • native file chooser via a MethodChannel (no file_picker),
//   • third-party cookies, inline autoplay, DRM permission grants,
//   • JS keyboard-scroll fix (single pass, behavior:'auto') and
//     safe-area CSS neutralisation that respects the site's own
//     horizontal gutters (per `.cursor/rules/webview_safe_area_injection`).
// ============================================================

// [FINGERPRINT] Method channel name MUST match the value used in
// MainActivity.kt. Any rename must happen atomically in both places.
const String _kUploadChannel = 'lavaEscape/attach';

class EscapeView extends StatefulWidget {
  const EscapeView({
    super.key,
    required this.entryUrl,
    required this.vault,
    required this.beacon,
    required this.signal,
  });

  final String entryUrl;
  final CavernsVault vault;
  final BeaconHub beacon;
  final SignalProbe signal;

  @override
  State<EscapeView> createState() => _EscapeViewState();
}

class _EscapeViewState extends State<EscapeView>
    with WidgetsBindingObserver {
  late final WebViewController _panel;
  bool _busy = true;
  bool _offlineShown = false;
  String? _lastMainFrame;
  int _redirectAttempts = 0;
  StreamSubscription<List<ConnectivityResult>>? _tx;
  Timer? _dropDebounce;
  static const MethodChannel _bridge = MethodChannel(_kUploadChannel);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The WebView must be able to rotate freely — the shell (splash /
    // offline / invite) has already unlocked all four orientations.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _dive();
    _panel = _makeController();
    _panel.loadRequest(Uri.parse(widget.entryUrl));

    widget.beacon.liveLinkSink = (String url) {
      if (mounted) _panel.loadRequest(Uri.parse(url));
    };

    _tx = widget.signal.transportChanges.listen(_onTransportChange);
  }

  void _dive() {
    // Full immersive — hides both status bar and nav bar. Keyboard is
    // handled by the JS scroll fix, so we do NOT need `adjustResize`
    // to physically shrink the window.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _dive();
  }

  void _onTransportChange(List<ConnectivityResult> tx) {
    // Only route to offline when EVERY reported transport is `none`.
    // Debounce 700 ms — VPN handshakes flip through `none` briefly.
    final bool allDown = tx.isNotEmpty &&
        tx.every((ConnectivityResult r) => r == ConnectivityResult.none);
    _dropDebounce?.cancel();
    if (!allDown) return;
    _dropDebounce = Timer(const Duration(milliseconds: 700), () {
      _openOffline();
    });
  }

  WebViewController _makeController() {
    final WebViewController panel = WebViewController();
    panel
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(lavaAgent.agent)
      ..setBackgroundColor(const Color(0xFF0D0806))
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _busy = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _busy = false);
            _redirectAttempts = 0;
            _neutraliseSafeArea();
            _wireKeyboardScroll();
          },
          onWebResourceError: (WebResourceError err) {
            if (err.isForMainFrame != true) return;

            final String desc = err.description.toLowerCase();
            final bool loop = desc.contains('too_many_redirects') ||
                desc.contains('too many redirects') ||
                err.errorCode == -9 ||
                err.errorCode == -1007;
            if (loop &&
                _lastMainFrame != null &&
                _redirectAttempts < 3) {
              _redirectAttempts++;
              _panel.loadRequest(Uri.parse(_lastMainFrame!));
              return;
            }

            // Cover the native "black-robot" error page immediately —
            // never let it be seen by the user (pitfalls §4).
            if (mounted) setState(() => _busy = true);

            final bool dnsish = desc.contains('name_not_resolved') ||
                desc.contains('err_name_not_resolved') ||
                desc.contains('internet_disconnected') ||
                desc.contains('network_changed') ||
                err.errorCode == -105 ||
                err.errorCode == -106 ||
                err.errorCode == -21;

            if (dnsish) {
              _openOffline();
            } else {
              _guardOffline();
            }
          },
          onNavigationRequest: (NavigationRequest req) {
            final Uri? uri = Uri.tryParse(req.url);
            if (uri == null) return NavigationDecision.prevent;
            const Set<String> inline = <String>{
              'http',
              'https',
              'about',
              'data',
              'blob',
            };
            if (inline.contains(uri.scheme)) {
              if (req.isMainFrame) _lastMainFrame = req.url;
              return NavigationDecision.navigate;
            }
            _handoffExternal(uri);
            return NavigationDecision.prevent;
          },
        ),
      );

    _tuneAndroid(panel);
    return panel;
  }

  void _tuneAndroid(WebViewController panel) {
    if (!Platform.isAndroid) return;
    if (panel.platform is! AndroidWebViewController) return;
    final AndroidWebViewController android =
        panel.platform as AndroidWebViewController;

    // Inline autoplay video without tap-to-start.
    android.setMediaPlaybackRequiresUserGesture(false);

    // Auto-grant DRM (protected media) + camera / mic permission
    // requests so partner streams and forms work without pop-ups.
    android.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest req) => req.grant(),
    );

    // Wire <input type="file"> to the native chooser via MethodChannel.
    // No `file_picker` dependency — pitfalls §1.
    android.setOnShowFileSelector(_delegateFilePick);

    // Third-party cookies for OAuth / payment redirects.
    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(android, true);
  }

  Future<List<String>> _delegateFilePick(FileSelectorParams params) async {
    try {
      final List<Object?>? picked =
          await _bridge.invokeMethod<List<Object?>>('chooseFiles', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes':
            params.acceptTypes.where((String t) => t.trim().isNotEmpty).toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _handoffExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // Probe-then-show: for transient WebView load errors that might be
  // network flaps rather than real disconnects.
  Future<void> _guardOffline() async {
    if (_offlineShown) return;
    final bool online = await widget.signal.reachable();
    if (online) return;
    _openOffline();
  }

  void _openOffline() {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    final String current = _lastMainFrame ?? widget.entryUrl;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MagmaOffline(
          rebuildOnRetry: (_) => EscapeView(
            entryUrl: current,
            vault: widget.vault,
            beacon: widget.beacon,
            signal: widget.signal,
          ),
        ),
      ),
    );
  }

  Future<void> _returnOnePage() async {
    if (await _panel.canGoBack()) {
      await _panel.goBack();
    }
  }

  // ── JS payloads ──

  // Keyboard scroll fix — one delayed pass, `behavior: 'auto'`, guarded
  // against re-execution. See pitfalls §3 for the rationale.
  void _wireKeyboardScroll() {
    _panel.runJavaScript(r'''
(function(){
  if (window.__lavaKbFix) return; window.__lavaKbFix = true;
  function isEditable(el){
    if(!el) return false;
    return el.tagName==='INPUT' || el.tagName==='TEXTAREA' || el.isContentEditable;
  }
  function lift(){
    var el = document.activeElement;
    if(!isEditable(el)) return;
    var vp = window.visualViewport;
    if(vp){
      var box = el.getBoundingClientRect();
      var bottom = vp.offsetTop + vp.height;
      if(box.bottom > bottom - 20 || box.top < vp.offsetTop){
        el.scrollIntoView({behavior:'auto', block:'nearest'});
      }
    } else {
      el.scrollIntoView({behavior:'auto', block:'nearest'});
    }
  }
  document.addEventListener('focusin', function(e){
    if(isEditable(e.target)) setTimeout(lift, 350);
  });
  if(window.visualViewport){
    var prev = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function(){
      var h = window.visualViewport.height;
      if(h < prev) setTimeout(lift, 120);
      prev = h;
    });
  }
})();
''');
  }

  // Safe-area neutralisation — narrow class list only. NEVER touches
  // `html/body/#app/#root` padding-left/right (that would squash the
  // partner site's designed gutters — see the safe-area-injection rule).
  void _neutraliseSafeArea() {
    _panel.runJavaScript(r'''
(function(){
  if(window.__lavaSaFix) return; window.__lavaSaFix = true;
  var TAG = '__lava_sa_style';
  var CSS =
    ':root{'
      +'--safe-area-inset-top:0px !important;'
      +'--safe-area-inset-right:0px !important;'
      +'--safe-area-inset-bottom:0px !important;'
      +'--safe-area-inset-left:0px !important;'
      +'--sat:0px !important; --sar:0px !important;'
      +'--sab:0px !important; --sal:0px !important;'
      +'--safe-top:0px !important; --safe-bottom:0px !important;'
      +'--safe-left:0px !important; --safe-right:0px !important;'
    +'}'
    +'.gameview-mobile-header,.app-header,.js-safe-top,.mobile-topbar-safe{'
      +'padding-top:0 !important;'
      +'margin-top:0 !important;'
    +'}';
  function kbUp(){
    var vp = window.visualViewport;
    if(!vp) return false;
    return vp.height < window.innerHeight * 0.75;
  }
  function fit(){
    if(kbUp()) return; // never patch during keyboard animation
    var head = document.head || document.documentElement;
    if(!head) return;
    var vpMeta = document.querySelector('meta[name="viewport"]');
    if(vpMeta && !/viewport-fit\s*=\s*contain/i.test(vpMeta.getAttribute('content')||'')){
      var current = (vpMeta.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      vpMeta.setAttribute('content', current + (current ? ', ' : '') + 'viewport-fit=contain');
    }
    var style = document.getElementById(TAG);
    if(!style){ style = document.createElement('style'); style.id = TAG; head.appendChild(style); }
    if(style.textContent !== CSS) style.textContent = CSS;
  }
  fit();
  ['pushState','replaceState'].forEach(function(fn){
    var orig = history[fn];
    history[fn] = function(){
      var r = orig.apply(this, arguments);
      setTimeout(fit, 80);
      setTimeout(fit, 400);
      return r;
    };
  });
  window.addEventListener('popstate', function(){ setTimeout(fit, 80); });
  setInterval(fit, 2500);
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tx?.cancel();
    _dropDebounce?.cancel();
    widget.beacon.liveLinkSink = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final Orientation ori = mq.orientation;

    // Landscape: keep the cutout inset on BOTH long edges (some devices
    // put the camera on the left, some on the right; rotate 180° and the
    // notch flips). Portrait: only the top safe inset matters.
    final EdgeInsets safe = ori == Orientation.landscape
        ? EdgeInsets.only(
            left: mq.viewPadding.left,
            right: mq.viewPadding.right,
            top: mq.viewPadding.top,
          )
        : EdgeInsets.only(top: mq.viewPadding.top);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _returnOnePage();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0806),
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              padding: safe,
              child: WebViewWidget(controller: _panel),
            ),
            if (_busy)
              const ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFF8B2C)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
