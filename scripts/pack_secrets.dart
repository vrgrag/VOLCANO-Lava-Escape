// ignore_for_file: avoid_print
// ============================================================
// SECRET PACKER — encodes plaintext secrets into masked base64 strings
// ============================================================
// Mirrors lib/crypto/veil_cipher.dart byte-for-byte. Run with:
//   dart run scripts/pack_secrets.dart
// then paste the printed String constants into
//   lib/rift/secret_vault.dart
//
// ⚠️ Always execute with `dart run` — NEVER port to PowerShell. Native
// 64-bit dart ints keep the bitmath safe; PowerShell would truncate at
// 32 bits and corrupt every byte silently.
//
// Keep `_secretPhrase`, `_ribbonLen`, and `_twist` here in perfect sync
// with veil_cipher.dart.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

const String _secretPhrase = 'MagmaGusher_v2_lavaEsc';
const int _ribbonLen = 33;
const int _twist = 0x1B;

Uint8List _expandRibbon() {
  final List<int> phrase = _secretPhrase.codeUnits;

  int h1 = 0xDEAD10CC;
  int h2 = 0xBEEFCAFE;
  for (final int c in phrase) {
    h1 = ((h1 ^ c) * 0x5BD1E995) & 0xFFFFFFFF;
    h1 ^= (h1 >> 15);
    h2 = ((h2 + c) * 0x27D4EB2F) & 0xFFFFFFFF;
    h2 ^= (h2 >> 13);
  }
  h1 = (h1 ^ (h2 << 3)) & 0xFFFFFFFF;
  h2 = (h2 ^ (h1 >> 2)) & 0xFFFFFFFF;

  final Uint8List ribbon = Uint8List(_ribbonLen);
  int state = (h1 == 0 && h2 == 0) ? 0x1F83D9AB : (h1 ^ h2);
  for (int i = 0; i < _ribbonLen; i++) {
    state = ((state * 1664525) + 1013904223) & 0xFFFFFFFF;
    ribbon[i] = (state >> 24) & 0xFF;
  }
  return ribbon;
}

final Uint8List _ribbon = _expandRibbon();

String mask(String plain) {
  if (plain.isEmpty) return '';
  final Uint8List bytes = Uint8List.fromList(utf8.encode(plain));
  final Uint8List out = Uint8List(bytes.length);
  for (int i = 0; i < bytes.length; i++) {
    final int shifted = (bytes[i] + _ribbon[i % _ribbonLen]) & 0xFF;
    out[i] = shifted ^ ((i * _twist) & 0xFF);
  }
  return base64Encode(out);
}

void emit(String label, String plain) {
  if (plain.isEmpty) {
    print("// $label — (empty, populate later)");
    print("const String $label = '';");
    print('');
    return;
  }
  final String masked = mask(plain);
  print("// $label  <= \"$plain\"");
  print("const String $label = '$masked';");
  print('');
}

void main() {
  // ── Populate these before running the packer ──
  //
  // ⚠️ NEVER commit non-empty plaintext values into this file. Fill,
  // run the packer, copy the printed masked strings into
  // `lib/rift/secret_vault.dart`, then wipe the plaintext back to
  // empty strings before committing.
  //
  // Leaving a field empty is fine — the corresponding mask output is
  // simply `''`, which the veil cipher unwraps to an empty string.
  const String configEndpoint = '';
  const String gcdBase = '';
  const String chromeVersion = '';
  const String webkitVersion = '';
  const String attributionKey = '';
  const String messagingProject = '';

  print('=== lava_escape secret packer ===');
  print('');
  emit('_configEndpointMasked', configEndpoint);
  emit('_gcdBaseMasked', gcdBase);
  emit('_chromeVersionMasked', chromeVersion);
  emit('_webkitVersionMasked', webkitVersion);
  emit('_attributionKeyMasked', attributionKey);
  emit('_messagingProjectMasked', messagingProject);
}
