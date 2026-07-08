import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/orientation.dart';
import '../lava/escape_view.dart';
import '../lava/magma_offline.dart';
import '../lava/notify_prompt.dart';
import '../pyre/attribution_scout.dart';
import '../pyre/beacon_hub.dart';
import '../pyre/caverns_vault.dart';
import '../pyre/signal_probe.dart';
import '../pyre/verdict_channel.dart';
import '../screens/main_menu_screen.dart';
import '../wire/route_mode.dart';
import '../wire/verdict_reply.dart';

// ============================================================
// BOOT ROUTER — loading screen + gray/native routing engine
// ============================================================
// This is the direct implementation of the state machine documented in
// `.cursor/rules/android_gray_guide.md` §"Gray Flow State Machine".
// Do not re-order branches without re-reading that section.
//
// FIRST-LAUNCH UX INVARIANT (per TZ + rules):
//   If the device is offline at first launch AND we have no committed
//   verdict, the router MUST route to MagmaOffline BEFORE calling
//   AttributionScout.lightUp(). Otherwise the AppsFlyer init call can
//   hang for tens of seconds while the user stares at the OS launch
//   background. AppMode stays `unresolved` — never commits to offline
//   on a mere connectivity failure.
// ============================================================

class BootRouter extends StatefulWidget {
  const BootRouter({
    super.key,
    required this.vault,
    required this.signal,
    required this.scout,
    required this.verdict,
    required this.beacon,
  });

  final CavernsVault vault;
  final SignalProbe signal;
  final AttributionScout scout;
  final VerdictChannel verdict;
  final BeaconHub beacon;

  @override
  State<BootRouter> createState() => _BootRouterState();
}

class _BootRouterState extends State<BootRouter>
    with SingleTickerProviderStateMixin {
  static const String _kPortraitBg =
      'assets/Vertical_Loading_Screen.webp';
  static const String _kLandscapeBg =
      'assets/Horizontal_Loading_Screen.webp';

  double _flame = 0.05;
  bool _handedOff = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    widget.beacon.onFreshToken = _rePostOnTokenRotation;
    WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
  }

  @override
  void dispose() {
    widget.beacon.onFreshToken = null;
    _pulse.dispose();
    super.dispose();
  }

  void _tick(double value) {
    if (!mounted) return;
    setState(() => _flame = value);
  }

  // ── State machine ──

  Future<void> _drive() async {
    final RouteMode mode = widget.vault.currentMode();

    // FIRST-FRAME CONNECTIVITY GATE — must happen BEFORE beacon.wire().
    //
    // BeaconHub.wire() calls FirebaseMessaging.getToken(), which without
    // network can stall for tens of seconds waiting on Play Services.
    // Running the reachability probe first lets us skip straight to the
    // offline screen on frame ≈ 1 (per TZ + first-launch UX contract).
    //
    // The native game path is offline-safe, so we do NOT gate it — a
    // returning `native` user with no network still gets the game.
    if (mode != RouteMode.native) {
      if (!await widget.signal.reachable()) {
        _routeOffline();
        return;
      }
    }
    _tick(0.12);

    await widget.beacon.wire();
    _tick(0.22);

    switch (mode) {
      case RouteMode.native:
        await _routeNative(from: 0.35);
        return;
      case RouteMode.escape:
        await _resumeEscape();
        return;
      case RouteMode.unresolved:
        await _cold();
        return;
    }
  }

  Future<void> _cold() async {
    if (!await widget.signal.reachable()) {
      _routeOffline();
      return;
    }
    _tick(0.35);

    await widget.scout.lightUp();
    await Future.wait<void>(<Future<void>>[
      widget.scout.waitForInstall(),
      widget.scout.waitForDeepLink(),
    ]);
    _tick(0.75);

    final VerdictReply reply = await _consult();
    if (reply.approved && reply.hasDestination) {
      await widget.vault.lockMode(RouteMode.escape);
      _tick(1.0);
      await _breathe();
      _routeEscape(reply.destination!);
    } else {
      await widget.vault.lockMode(RouteMode.native);
      await _routeNative(from: 0.85);
    }
  }

  Future<void> _resumeEscape() async {
    if (!await widget.signal.reachable()) {
      _tick(1.0);
      _routeOffline();
      return;
    }
    _tick(0.4);

    // Cold-start push URL wins over everything.
    final String? pushed = await widget.vault.claimPushLink();
    if (pushed != null && pushed.isNotEmpty) {
      _tick(1.0);
      await _breathe();
      _routeEscape(pushed);
      return;
    }

    final String? cached = await widget.vault.cachedDestination();

    // If we still have a valid cached destination, prefer it — but keep
    // running attribution in the background so a token refresh from
    // BeaconHub eventually re-POSTs with the current install data.
    if (cached != null && !widget.vault.destinationStale()) {
      _tick(1.0);
      await _breathe();
      _routeEscape(cached);
      // Fire-and-forget scout warm-up so the SDK is ready for later
      // token rotations. Any failure is ignored.
      unawaited(widget.scout.lightUp());
      return;
    }

    await widget.scout.lightUp();
    await Future.wait<void>(<Future<void>>[
      widget.scout.waitForInstall(seconds: 10),
      widget.scout.waitForDeepLink(),
    ]);
    _tick(0.75);

    final VerdictReply reply = await _consult();
    _tick(1.0);
    await _breathe();

    if (reply.approved && reply.hasDestination) {
      _routeEscape(reply.destination!);
    } else if (cached != null) {
      _routeEscape(cached);
    } else {
      _routeOffline();
    }
  }

  Future<VerdictReply> _consult() async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.scout.composeGateBody(
      locale: locale,
      pushToken: widget.beacon.token,
    );
    return widget.verdict.query(body);
  }

  void _rePostOnTokenRotation(String token) async {
    if (widget.vault.currentMode() != RouteMode.escape) return;
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.scout.composeGateBody(
      locale: locale,
      pushToken: token,
    );
    await widget.verdict.query(body);
  }

  Future<void> _breathe() =>
      Future<void>.delayed(const Duration(milliseconds: 320));

  // ── Routing ──

  Future<void> _routeNative({required double from}) async {
    _tick(from);
    // The native game is portrait-only.
    await lockPortraitOrientation();
    _tick(1.0);
    await _breathe();
    if (_handedOff || !mounted) return;
    _handedOff = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainMenuScreen()),
    );
  }

  void _routeEscape(String destination) {
    if (_handedOff || !mounted) return;
    _handedOff = true;
    // Unlock every orientation for the WebView flow — even the invite
    // screen needs landscape support.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    if (widget.vault.shouldOfferInvite()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => NotifyPrompt(
            vault: widget.vault,
            beacon: widget.beacon,
            signal: widget.signal,
            contentUrl: destination,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => EscapeView(
            entryUrl: destination,
            vault: widget.vault,
            beacon: widget.beacon,
            signal: widget.signal,
          ),
        ),
      );
    }
  }

  void _routeOffline() {
    if (_handedOff || !mounted) return;
    _handedOff = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MagmaOffline(
          rebuildOnRetry: (_) => BootRouter(
            vault: widget.vault,
            signal: widget.signal,
            scout: widget.scout,
            verdict: widget.verdict,
            beacon: widget.beacon,
          ),
        ),
      ),
    );
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;
    final String bg = landscape ? _kLandscapeBg : _kPortraitBg;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.obsidian,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(bg, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Color(0xAA000000),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  landscape ? 80 : 36,
                  0,
                  landscape ? 80 : 36,
                  landscape ? 26 : 42,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (BuildContext context, _) {
                        final int step = (_pulse.value * 4).floor() % 4;
                        return Text(
                          'Loading${'.' * step}',
                          style: AppTextStyles.heading.copyWith(
                            letterSpacing: 1.4,
                            shadows: const <Shadow>[
                              Shadow(
                                color: Colors.black87,
                                offset: Offset(0, 2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _FlameProgress(value: _flame),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress bar shaped as a flame trail — obsidian bevel + lava fill.
/// Deliberately distinct from the game's `LavaProgressBar` widget so the
/// two never share painter code; keeps the shell and the game visually
/// independent.
class _FlameProgress extends StatelessWidget {
  const _FlameProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return Container(
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xCC120A08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFFC96B).withValues(alpha: 0.7),
              width: 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFFF8B2C).withValues(alpha: 0.35),
                blurRadius: 14,
              ),
            ],
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: c.maxWidth * value.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xFFFFC96B),
                    Color(0xFFFF8B2C),
                    Color(0xFFE23B1F),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small utility to avoid pulling in dart:async just for a single call.
void unawaited(Future<void> f) {
  // Deliberately empty — the caller wanted fire-and-forget semantics.
}
