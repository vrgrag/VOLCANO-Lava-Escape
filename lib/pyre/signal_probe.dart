import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

// ============================================================
// SIGNAL PROBE — connectivity + DNS reachability
// ============================================================
// The default connectivity_plus adapter check reports "wifi" long before
// the network is actually usable (VPN handshake, captive portals, DNS
// throttling). The probe layers a real DNS lookup on top so the shell
// makes routing decisions on genuine reachability.
//
// VPN is treated as connectivity — otherwise the No-Wi-Fi screen flashes
// when the tunnel comes up. Timeout is a generous 7s so slow DNS through
// a real tunnel is not misdiagnosed as offline (see
// `.cursor/rules/gray_part_pitfalls.md` §3).
// ============================================================

class SignalProbe {
  SignalProbe({Connectivity? adapter, this.probeHost = 'one.one.one.one'})
      : _adapter = adapter ?? Connectivity();

  /// Hosts that count as "we have a working transport" for the adapter
  /// state check. Anything else routes to offline.
  static const Set<ConnectivityResult> _live = <ConnectivityResult>{
    ConnectivityResult.wifi,
    ConnectivityResult.mobile,
    ConnectivityResult.ethernet,
    ConnectivityResult.vpn,
    ConnectivityResult.bluetooth,
    ConnectivityResult.other,
  };

  final Connectivity _adapter;
  final String probeHost;

  /// Returns true when the OS reports at least one live transport AND a
  /// DNS lookup for [probeHost] resolves inside the 7s budget.
  Future<bool> reachable() async {
    final List<ConnectivityResult> transports =
        await _adapter.checkConnectivity();
    if (!transports.any(_live.contains)) return false;

    try {
      final List<InternetAddress> answer = await InternetAddress
          .lookup(probeHost)
          .timeout(const Duration(seconds: 7));
      return answer.isNotEmpty && answer.first.rawAddress.isNotEmpty;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get transportChanges =>
      _adapter.onConnectivityChanged;
}
