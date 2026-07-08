import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../wire/route_mode.dart';

// ============================================================
// CAVERNS VAULT — persistence for the shell
// ============================================================
// Plain flags live in SharedPreferences (cheap, fast). Sensitive URLs
// (cached content link, one-time push link) live in encrypted secure
// storage. Keys are intentionally opaque so a `prefs` dump doesn't
// reveal intent.
//
// The class does not initialise itself in the constructor — call
// `mount()` once during startup before reading anything.
// ============================================================

class CavernsVault {
  CavernsVault({FlutterSecureStorage? sealedStore})
      : _sealed = sealedStore ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const String _slotRoute = 'rt.mode.v2';
  static const String _slotCached = 'lv.dst';
  static const String _slotTtl = 'lv.ttl';
  static const String _slotInviteUntil = 'nf.invite.until';
  static const String _slotPushGrant = 'nf.grant';
  static const String _slotOsBlocked = 'nf.os.blocked';
  static const String _slotPendingLink = 'lv.push.pending';

  late final SharedPreferences _flat;
  final FlutterSecureStorage _sealed;

  Future<void> mount() async {
    _flat = await SharedPreferences.getInstance();
  }

  // ── Route mode ──
  RouteMode currentMode() => RouteMode.restore(_flat.getString(_slotRoute));

  Future<void> lockMode(RouteMode mode) =>
      _flat.setString(_slotRoute, mode.persistTag());

  // ── Cached content URL (secure) ──
  Future<String?> cachedDestination() => _sealed.read(key: _slotCached);

  Future<void> keepDestination(String url) =>
      _sealed.write(key: _slotCached, value: url);

  // ── Content TTL ──
  int? destinationExpiry() => _flat.getInt(_slotTtl);

  Future<void> keepDestinationExpiry(int unixSeconds) =>
      _flat.setInt(_slotTtl, unixSeconds);

  bool destinationStale() {
    final int? until = destinationExpiry();
    if (until == null) return true;
    return _clockSeconds() >= until;
  }

  // ── Push permission state ──
  bool pushAllowed() => _flat.getBool(_slotPushGrant) ?? false;

  Future<void> recordPushGrant({required bool allowed}) =>
      _flat.setBool(_slotPushGrant, allowed);

  bool pushBlockedByOs() => _flat.getBool(_slotOsBlocked) ?? false;

  Future<void> flagPushBlockedByOs() =>
      _flat.setBool(_slotOsBlocked, true);

  int? inviteCooldownUntil() => _flat.getInt(_slotInviteUntil);

  Future<void> stashInviteCooldown(int unixSeconds) =>
      _flat.setInt(_slotInviteUntil, unixSeconds);

  /// True → invite screen should be offered before the WebView.
  bool shouldOfferInvite() {
    if (pushAllowed()) return false;
    if (pushBlockedByOs()) return false;
    final int? until = inviteCooldownUntil();
    if (until == null) return true;
    return _clockSeconds() >= until;
  }

  // ── One-time push link ──
  Future<void> parkPushLink(String? link) async {
    if (link == null || link.isEmpty) {
      await _sealed.delete(key: _slotPendingLink);
    } else {
      await _sealed.write(key: _slotPendingLink, value: link);
    }
  }

  Future<String?> claimPushLink() async {
    final String? link = await _sealed.read(key: _slotPendingLink);
    if (link != null) await _sealed.delete(key: _slotPendingLink);
    return link;
  }

  static int _clockSeconds() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
