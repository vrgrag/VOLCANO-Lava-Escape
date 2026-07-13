import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'magma_button.dart';

// ============================================================
// MAGMA OFFLINE — no-connectivity screen
// ============================================================
// Uses the project's dedicated no-wifi artwork (portrait + landscape).
// A single Reconnect action rebuilds whatever screen the caller wants
// to retry.
//
// Landscape button width is capped at 35 % of screen width so it never
// covers the artwork's centerpiece (see pitfalls §18). Portrait width
// is 68 % with a ceiling / floor so it stays readable on tablets.
// ============================================================

class MagmaOffline extends StatefulWidget {
  const MagmaOffline({
    super.key,
    required this.rebuildOnRetry,
    this.portraitAsset =
        'assets/Vertical_Nowifi_Screen.webp',
    this.landscapeAsset =
        'assets/Horizontal_Nowifi_Screen.webp',
  });

  final WidgetBuilder rebuildOnRetry;
  final String portraitAsset;
  final String landscapeAsset;

  @override
  State<MagmaOffline> createState() => _MagmaOfflineState();
}

class _MagmaOfflineState extends State<MagmaOffline>
    with WidgetsBindingObserver {
  bool _reconnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hideHud();
  }

  // Immersive-sticky removes the top/bottom system strips so the
  // "no wifi" artwork fills the full display, matching the WebView shell.
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

  Future<void> _reconnect() async {
    if (_reconnecting) return;
    setState(() => _reconnecting = true);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.rebuildOnRetry),
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
          )
        : EdgeInsets.zero;

    final double buttonWidth = landscape
        ? (size.width * 0.35).clamp(220.0, 380.0)
        : (size.width * 0.68).clamp(220.0, 380.0);

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
          Padding(
            padding: safe,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: landscape ? size.height * 0.10 : size.height * 0.09,
                  child: Center(
                    child: _reconnecting
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF8B2C),
                              ),
                            ),
                          )
                        : MagmaButton(
                            label: 'RECONNECT',
                            width: buttonWidth,
                            height: 54,
                            onTap: _reconnect,
                          ),
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
