import 'dart:convert';

import '../rift/identity.dart';
import '../wire/verdict_reply.dart';
import 'agent_forge.dart';
import 'caverns_vault.dart';

// ============================================================
// VERDICT CHANNEL — POSTs the attribution body, parses the answer
// ============================================================
// A missing endpoint or any transport error yields a local failure
// reply, which routes the user to the offline game. On an approved
// answer the destination URL + ttl are cached so a later launch can
// fall back to it if the network fails.
// ============================================================

class VerdictChannel {
  VerdictChannel(this._vault);

  final CavernsVault _vault;

  Future<VerdictReply> query(Map<String, dynamic> body) async {
    final String endpoint = EscapeIdentity.configUrl;
    if (endpoint.isEmpty) {
      return VerdictReply.local('no-endpoint');
    }

    try {
      final response = await lavaAgent.submit(
        Uri.parse(endpoint),
        body,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        timeLimit: const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        return VerdictReply.local('http-${response.statusCode}');
      }

      final Map<String, dynamic> parsed =
          jsonDecode(response.body) as Map<String, dynamic>;
      final VerdictReply reply = VerdictReply.fromWire(parsed);

      if (reply.approved && reply.hasDestination) {
        await _vault.keepDestination(reply.destination!);
        final int? ttl = reply.expiresAt;
        if (ttl != null) {
          await _vault.keepDestinationExpiry(ttl);
        }
      }
      return reply;
    } catch (err) {
      return VerdictReply.local(err.toString());
    }
  }
}
