import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pyre/beacon_hub.dart';
import '../pyre/caverns_vault.dart';
import '../pyre/signal_probe.dart';
import '../rift/identity.dart';
import 'escape_view.dart';
import 'magma_button.dart';

// ============================================================
// NOTIFY PROMPT — push permission opt-in screen
// ============================================================
// Shown once before the WebView (gray flow). Accept fires the OS
// permission dialog; Skip arms a cooldown so the screen doesn't
// re-appear for the next 3 days.
//
// Per §12 of the pitfalls file, BOTH buttons render as full gradient
// magma buttons — never a subdued text link. `Skip` uses the ghost
// variant (dark bevel + orange outline) so its visual weight is clearly
// lower than `Accept` while remaining fully legible on any backdrop.
// Requested layout: Accept + Skip labels, buttons only (no captions
// baked in — the artwork carries all the copy).
// ============================================================

class NotifyPrompt extends StatefulWidget {
  const NotifyPrompt({
    super.key,
    required this.vault,
    required this.beacon,
    required this.signal,
    required this.contentUrl,
    this.portraitAsset =
        'assets/Vertical_Notification_Screen.webp',
    this.landscapeAsset =
        'assets/Horizontal_Notification_Screen.webp',
  });

  final CavernsVault vault;
  final BeaconHub beacon;
  final SignalProbe signal;
  final String contentUrl;
  final String portraitAsset;
  final String landscapeAsset;

  @override
  State<NotifyPrompt> createState() => _NotifyPromptState();
}

class _NotifyPromptState extends State<NotifyPrompt>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hideHud();
  }

  // Immersive-sticky matches the WebView shell: no status/nav strips
  // frame the artwork, so the volcano background reaches every edge.
  void _hideHud() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _hideHud();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _onAccept() async {
    final bool granted = await widget.beacon.askPermission();
    if (!granted) {
      await widget.vault.stashInviteCooldown(_cooldownUntil());
    }
    if (mounted) _forwardToView();
  }

  Future<void> _onSkip() async {
    await widget.vault.stashInviteCooldown(_cooldownUntil());
    if (mounted) _forwardToView();
  }

  int _cooldownUntil() =>
      (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
      EscapeIdentity.inviteCooldownSeconds;

  void _forwardToView() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => EscapeView(
          entryUrl: widget.contentUrl,
          vault: widget.vault,
          beacon: widget.beacon,
          signal: widget.signal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final Size size = mq.size;
    final bool landscape = mq.orientation == Orientation.landscape;

    final double primaryWidth = landscape
        ? (size.width * 0.34).clamp(200.0, 360.0)
        : (size.width * 0.66).clamp(220.0, 380.0);

    // Pin the button pair to the bottom of the visible area, centered
    // horizontally, so they sit UNDER the banner artwork on every
    // aspect ratio rather than overlapping the "Stay tuned…" caption.
    // Landscape has less vertical room, so the bottom offset shrinks.
    final double bottomOffset = landscape
        ? size.height * 0.05
        : size.height * 0.08;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0806),
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            landscape ? widget.landscapeAsset : widget.portraitAsset,
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x66000000)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
                padding: EdgeInsets.only(bottom: bottomOffset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    MagmaButton(
                      label: 'ACCEPT',
                      width: primaryWidth,
                      height: landscape ? 48 : 56,
                      onTap: _onAccept,
                    ),
                    SizedBox(height: landscape ? 10 : 14),
                    MagmaButton(
                      label: 'SKIP',
                      tone: MagmaTone.secondary,
                      width: primaryWidth,
                      height: landscape ? 42 : 50,
                      onTap: _onSkip,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
