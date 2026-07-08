import 'civic_urls.dart';
import 'secret_vault.dart';

// ============================================================
// ESCAPE IDENTITY — single source of app-wide constants
// ============================================================
// Plain identity fields (bundle, market, display name) sit as string
// literals; credentials and endpoint URLs resolve lazily through the
// veil cipher so plaintext never lands in the compiled binary.
//
// [FINGERPRINT] These fields MUST differ between every project spawned
// from a gray-part template. Do not port them elsewhere and do not
// rename them "close enough" — reuse patterns are what store scanners
// index. See `.cursor/rules/gray_part_pitfalls.md`.
// ============================================================

class EscapeIdentity {
  EscapeIdentity._();

  // ── Identity ──
  //
  // Android applicationId + namespace must match `bundle` exactly:
  //   • android/app/build.gradle.kts → applicationId
  //   • android/app/build.gradle.kts → namespace
  //   • android/app/src/main/kotlin/**/MainActivity.kt package
  //   • android/app/google-services.json → package_name
  static const String bundle = 'com.lavaescap.lavaescape';

  // Sent to the config endpoint as `store_id`. On Android the value is
  // identical to `bundle` (only iOS prefixes a numeric App Store id
  // with the literal `id`).
  static const String marketPlace = 'com.lavaescap.lavaescape';

  // Human-readable name as it appears in the Play Console listing and
  // in `android:label` inside AndroidManifest.xml. Keep in perfect sync.
  static const String presentedName = 'Lava Escape';

  // iOS App Store numeric id — unused on the Android-only build. Kept
  // as an empty literal so cross-platform code can reference it without
  // conditionals.
  static const String appleStoreId = '';

  // ── Resolved credentials ──
  //
  // These come from `secret_vault.dart` which is populated by
  // `scripts/pack_secrets.dart`. On a fresh checkout the masked strings
  // may be empty → these getters return `""` → the gate call fails
  // gracefully and the app opens the offline game.
  static String get configUrl => unlockConfigEndpoint();

  static String get attributionKey => unlockAttributionKey();

  static String get messagingProject => unlockMessagingProject();

  // ── Public URLs ──
  //
  // Plain strings — see civic_urls.dart for why these are NOT masked.
  static const String siteHome = kSiteHome;
  static const String privacyUrl = kPrivacyUrl;
  static const String supportUrl = kSupportUrl;

  // ── Timing knobs ──
  //
  // How long to keep the push invite hidden after a Skip, in seconds.
  // Per TZ §"Push permission" — 3 days, do not shorten without approval.
  static const int inviteCooldownSeconds = 3 * 24 * 3600;

  // How many seconds to wait before re-querying GCD when the initial
  // AppsFlyer callback reports `af_status == "Organic"` for what may
  // actually be a paid install (SDK first-run false-positive).
  static const int organicRepeatDelaySeconds = 5;
}
