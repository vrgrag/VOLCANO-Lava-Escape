import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'agent_forge.dart';
import 'caverns_vault.dart';

// ============================================================
// BEACON HUB — Firebase Messaging + local notification display
// ============================================================
// The channel id below MUST match the value of
// `com.google.firebase.messaging.default_notification_channel_id`
// meta-data in `android/app/src/main/AndroidManifest.xml`.
//
// The small icon references `res/drawable/ic_notification.xml` — a
// monochrome FLAME (see `.cursor/rules/gray_part_pitfalls.md` §15).
// Never point this at the launcher icon.
//
// Cold tap (app killed): the URL is parked in the vault and consumed on
// the next launch via `claimPushLink()`.
// Warm tap (app in background / foreground): the URL is delivered live
// via [liveLinkSink] — never persisted (push links are one-shot).
// ============================================================

// [FINGERPRINT] Both constants below are project-unique. Do not port to
// any other project — do the atomic manifest + Dart rename each time.
const String kBeaconChannelId = 'lava_escape_alerts';
const String kBeaconChannelName = 'Lava Alerts';
const String _iconRes = '@drawable/ic_notification';

@pragma('vm:entry-point')
Future<void> _backdropHandler(RemoteMessage message) async {
  // Background notifications render themselves; the tap goes through
  // `onMessageOpenedApp` (warm) or `getInitialMessage()` (cold).
}

class BeaconHub {
  BeaconHub(this._vault);

  final CavernsVault _vault;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fm;
  String? _token;
  // Split the "wire" idempotency into TWO flags:
  //   • [_channelReady] — local notif channel + native listeners; safe to
  //     do once for the process lifetime.
  //   • [_tokenReady]   — we hold a non-null FCM token AND have posted at
  //     least one token to the on-fresh listeners. If getToken() failed
  //     (offline / Play Services stalled), we keep retrying on every
  //     subsequent wire() so the app self-heals after the user reconnects.
  bool _channelReady = false;
  bool _tokenReady = false;
  // In-flight guards. Multiple callers (BootRouter + EscapeView + resume
  // handler) can hit wire()/nudgeToken() simultaneously; without these
  // we would re-register FCM listeners twice, which throws on Firebase
  // 15.x and silently stalls the rest of startup.
  Future<void>? _wireInFlight;
  Future<void>? _pullInFlight;

  /// Warm-tap sink. When the user taps a notification while the app is
  /// alive, the URL is delivered here — the WebView loads it live.
  void Function(String url)? liveLinkSink;

  /// Fires when the FCM token rotates. The router re-POSTs the config
  /// request so the backend can target the fresh token.
  void Function(String token)? onFreshToken;

  String? get token => _token;

  Future<void> wire() {
    return _wireInFlight ??= _runWire().whenComplete(() {
      _wireInFlight = null;
    });
  }

  Future<void> _runWire() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fm ??= FirebaseMessaging.instance;

      if (!_channelReady) {
        FirebaseMessaging.onBackgroundMessage(_backdropHandler);
        await _bootLocal();

        _fm!.onTokenRefresh.listen((String t) {
          _token = t;
          _tokenReady = true;
          onFreshToken?.call(t);
        });
        FirebaseMessaging.onMessage.listen(_onForeground);
        FirebaseMessaging.onMessageOpenedApp.listen(_onWarmOpen);

        final RemoteMessage? cold = await _fm!.getInitialMessage();
        if (cold != null) _onColdOpen(cold);

        _channelReady = true;
      }

      // Always attempt a token refresh when wire() is invoked — this is
      // how the WebView / retry path recovers from an initial offline
      // wire() where getToken() returned null.
      if (!_tokenReady) await _pullToken();
    } catch (_) {
      // Firebase not configured yet — push subsystem stays dormant and
      // the shell keeps working. Next wire() call will retry.
    }
  }

  Future<void> _pullToken() {
    return _pullInFlight ??= _runPullToken().whenComplete(() {
      _pullInFlight = null;
    });
  }

  Future<void> _runPullToken() async {
    if (_fm == null) return;
    try {
      // Cap `getToken()` — Play Services can stall it for minutes when
      // the device just came online or is behind a captive portal. A
      // null here is fine: retry on the next `wire()` / `nudgeToken()`.
      final String? fresh = await _fm!.getToken().timeout(
            const Duration(seconds: 6),
            onTimeout: () => null,
          );
      if (fresh == null || fresh.isEmpty) return;
      final bool changed = fresh != _token;
      _token = fresh;
      _tokenReady = true;
      if (changed) onFreshToken?.call(fresh);
    } catch (_) {}
  }

  /// Public opportunistic re-fetch. Called from screens that resume
  /// (WebView, offline retry) so the backend eventually sees the token
  /// even if the very first `wire()` happened before the device had a
  /// working data path to FCM.
  Future<void> nudgeToken() => _pullToken();

  Future<void> _bootLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_iconRes);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? blob = r.payload;
        if (blob == null || blob.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(blob) as Map<String, dynamic>;
          final String? link = data['url'] as String?;
          if (link != null && link.isNotEmpty) liveLinkSink?.call(link);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android = _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          kBeaconChannelId,
          kBeaconChannelName,
          description: 'Updates and offers from Lava Escape.',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Asks the OS for notification permission. Records whether the OS
  /// definitively denied so the invite screen never re-appears (Android
  /// will silently ignore future permission requests after a deny).
  Future<bool> askPermission() async {
    if (_fm == null) return false;
    final NotificationSettings settings = await _fm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = settings.authorizationStatus;
    final bool allowed = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    await _vault.recordPushGrant(allowed: allowed);
    if (status == AuthorizationStatus.denied) {
      await _vault.flagPushBlockedByOs();
    }
    return allowed;
  }

  void _onForeground(RemoteMessage message) async {
    final RemoteNotification? note = message.notification;
    if (note == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? imageUrl = note.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _grabImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kBeaconChannelId,
          kBeaconChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _iconRes,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      kBeaconChannelId,
      kBeaconChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _iconRes,
    );

    await _local.show(
      note.hashCode,
      note.title,
      note.body,
      NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onColdOpen(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      _vault.parkPushLink(url);
    }
  }

  void _onWarmOpen(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      liveLinkSink?.call(url);
    }
  }

  Future<Uint8List?> _grabImage(String url) async {
    try {
      final res = await lavaAgent.fetch(
        Uri.parse(url),
        timeLimit: const Duration(seconds: 10),
      );
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }
}
