import '../crypto/veil_cipher.dart';

// ============================================================
// SECRET VAULT — masked endpoints & credentials
// ============================================================
// Every constant below is a base64 string produced by
// `dart run scripts/pack_secrets.dart` (see that file for the packer).
// Plaintext MUST NEVER appear as a literal here — that would defeat the
// entire purpose of the veil cipher.
//
// ─────────────────────────────────────────────────────────────
// TEMPLATE STATE — first-time setup
// ─────────────────────────────────────────────────────────────
// On a fresh checkout every masked string may be empty (`''`). An empty
// mask unwraps to `""`, which triggers a graceful gate-fail path so the
// build compiles and runs without any credentials — the shell simply
// falls back to the native game.
//
// To populate:
//   1. Edit `scripts/pack_secrets.dart` — paste real plaintext into the
//      six constants inside `main()`.
//   2. `dart run scripts/pack_secrets.dart` — copy the printed base64
//      strings below.
//   3. Verify the resulting build reaches the gate; if the offline path
//      is reached even on a live network, the masked strings are
//      misaligned with the cipher's current phrase / ribbon length.
//   4. Wipe plaintext from `scripts/pack_secrets.dart` before committing.
//
// Rotate the cipher phrase + ribbon length (see veil_cipher.dart) on any
// new project spawned from a gray-part template — see
// `.cursor/rules/gray_part_pitfalls.md`.
// ============================================================

// [FINGERPRINT] Populated per-project via the packer. Do not check
// non-empty values in without also confirming the cipher phrase in
// veil_cipher.dart matches.
const String _configEndpointMasked = 'qEo1HSCiIeu6Rlfk4b5qcTQyO91GnKgS8IMbGmbB8fHJyw==';
const String _gcdBaseMasked = 'qEo1HSCiIeuFREn24IaxdyMyDRV/gqCvy7cYE6zfMfLV2t9K99pO1bB2pJ4+z0c=';
const String _chromeVersionMasked = 'cQr+W2WeKeT2eh+LPA==';
const String _webkitVersionMasked = 'dQvwW2Cm';

const String _attributionKeyMasked = 'p0g/QyfLNSeFbz778Yl7cc0/DAUkRw==';
const String _messagingProjectMasked = 'cRbwXWOZJ+H2dh2LPQ==';

String unlockConfigEndpoint() => unmask(_configEndpointMasked);

String unlockAttributionKey() => unmask(_attributionKeyMasked);

String unlockMessagingProject() => unmask(_messagingProjectMasked);

String unlockChromeFragment() => unmask(_chromeVersionMasked);

String unlockWebkitFragment() => unmask(_webkitVersionMasked);

/// Assembles the GCD attribution-refresh URL for the given identifiers.
/// An empty base yields "" so callers can treat the retry as unavailable
/// without special-casing every crash / timeout path.
String buildGcdUrl(String appId, String deviceId) {
  final String base = unmask(_gcdBaseMasked);
  if (base.isEmpty) return '';
  return '$base$appId?devkey=${unlockAttributionKey()}&device_id=$deviceId';
}
