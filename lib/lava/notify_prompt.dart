import 'package:flutter/material.dart';

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

class NotifyPrompt extends StatelessWidget {
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

  Future<void> _onAccept(BuildContext context) async {
    final bool granted = await beacon.askPermission();
    if (!granted) {
      await vault.stashInviteCooldown(_cooldownUntil());
    }
    if (context.mounted) _forwardToView(context);
  }

  Future<void> _onSkip(BuildContext context) async {
    await vault.stashInviteCooldown(_cooldownUntil());
    if (context.mounted) _forwardToView(context);
  }

  int _cooldownUntil() =>
      (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
      EscapeIdentity.inviteCooldownSeconds;

  void _forwardToView(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => EscapeView(
          entryUrl: contentUrl,
          vault: vault,
          beacon: beacon,
          signal: signal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final Size size = mq.size;
    final bool landscape = mq.orientation == Orientation.landscape;
    final EdgeInsets safe = landscape
        ? EdgeInsets.only(
            left: mq.viewPadding.left,
            right: mq.viewPadding.right,
            top: mq.viewPadding.top,
          )
        : EdgeInsets.only(top: mq.viewPadding.top);

    final double primaryWidth = landscape
        ? size.width * 0.34
        : (size.width * 0.66).clamp(220.0, 380.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0806),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            landscape ? landscapeAsset : portraitAsset,
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0xAA000000)],
              ),
            ),
          ),
          Padding(
            padding: safe,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: landscape
                      ? size.height * 0.07
                      : size.height * 0.08,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      MagmaButton(
                        label: 'ACCEPT',
                        width: primaryWidth,
                        height: landscape ? 48 : 56,
                        onTap: () => _onAccept(context),
                      ),
                      SizedBox(height: landscape ? 12 : 16),
                      MagmaButton(
                        label: 'SKIP',
                        tone: MagmaTone.secondary,
                        width: primaryWidth,
                        height: landscape ? 44 : 50,
                        onTap: () => _onSkip(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
