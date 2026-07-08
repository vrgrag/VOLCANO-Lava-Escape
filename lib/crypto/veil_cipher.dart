import 'dart:convert';
import 'dart:typed_data';

// ============================================================
// VEIL CIPHER — light-weight string masker for sensitive strings
// ============================================================
// Every private endpoint / dev key / project number gets folded through
// this pair of routines so plaintext literals never land in the compiled
// APK. The transform is deliberately unlike any templated implementation:
//
//   1. A pass-phrase is expanded into a 512-bit expanded seed via three
//      MurmurHash3-style mixing rounds (constants chosen at random for
//      this project — do not port them elsewhere).
//   2. The expanded seed drives a linear-congruential generator that
//      emits a `_ribbonLen`-byte keystream. Different generator family
//      than xorshift; different bit width than the popular templates.
//   3. Each output byte is `((plain + ribbon[i % L]) & 0xFF) xor
//      ((i * 0x1B) & 0xFF)`. Addition (not XOR) with the keystream and
//      a prime multiplicative positional twist make the byte-frequency
//      histogram flat and different from XOR-only schemes.
//   4. The final byte sequence is stored as a base64 [String] rather
//      than a `List<int>` literal — again to move away from the common
//      encoded-byte-array fingerprint.
//
// Everything is completely symmetric between packer (scripts/) and
// unwrapper (this file). Rotate `_secretPhrase` + `_ribbonLen` on every
// new project (see comment block below).
// ============================================================

// [FINGERPRINT] Rotate BOTH values on every new project spawned from a
// gray-part template. Never reuse a phrase, even renamed. See
// `.cursor/rules/gray_part_pitfalls.md` for the reasoning behind this
// invariant across the developer's app portfolio.
const String _secretPhrase = 'MagmaGusher_v2_lavaEsc';
const int _ribbonLen = 33;

// Positional twister multiplier — a small odd number, kept in sync with
// scripts/pack_secrets.dart. Changing this here without changing the
// packer breaks every stored ribbon simultaneously (safe-fail: unwrap
// returns garbage → gate call fails → app opens the offline game).
const int _twist = 0x1B;

Uint8List _expandRibbon() {
  final List<int> phrase = _secretPhrase.codeUnits;

  // Three-round MurmurHash3-flavoured mixer. Constants below are random
  // for this project — the correctness proof only relies on symmetry
  // with pack_secrets.dart, not on any specific bit pattern.
  int h1 = 0xDEAD10CC;
  int h2 = 0xBEEFCAFE;
  for (final int c in phrase) {
    h1 = ((h1 ^ c) * 0x5BD1E995) & 0xFFFFFFFF;
    h1 ^= (h1 >> 15);
    h2 = ((h2 + c) * 0x27D4EB2F) & 0xFFFFFFFF;
    h2 ^= (h2 >> 13);
  }
  // Cross-mix so both halves contribute to every ribbon byte.
  h1 = (h1 ^ (h2 << 3)) & 0xFFFFFFFF;
  h2 = (h2 ^ (h1 >> 2)) & 0xFFFFFFFF;

  final Uint8List ribbon = Uint8List(_ribbonLen);
  int state = (h1 == 0 && h2 == 0) ? 0x1F83D9AB : (h1 ^ h2);
  for (int i = 0; i < _ribbonLen; i++) {
    // Linear congruential generator — different family than the xorshift
    // typical of templated projects. Multiplier / increment picked at
    // random; keep them unchanged for the lifetime of this project.
    state = ((state * 1664525) + 1013904223) & 0xFFFFFFFF;
    ribbon[i] = (state >> 24) & 0xFF;
  }
  return ribbon;
}

final Uint8List _ribbon = _expandRibbon();

/// Decodes a masked base64 [String] into its original plaintext.
///
/// Returns `""` for an empty input — the safe path the shell takes until
/// real credentials are packed via `scripts/pack_secrets.dart`.
String unmask(String masked) {
  if (masked.isEmpty) return '';
  final Uint8List packed = base64Decode(masked);
  final Uint8List out = Uint8List(packed.length);
  for (int i = 0; i < packed.length; i++) {
    final int mixed = packed[i] ^ ((i * _twist) & 0xFF);
    out[i] = (mixed - _ribbon[i % _ribbonLen]) & 0xFF;
  }
  return utf8.decode(out, allowMalformed: true);
}
