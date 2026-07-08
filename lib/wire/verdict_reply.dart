// ============================================================
// VERDICT REPLY — parsed response from the config endpoint
// ============================================================
// Wire format from the backend: `{ ok, url, expires, message }`.
// Fields are renamed here for clarity; the JSON keys are mapped 1:1 so
// the backend contract stays intact.
// ============================================================

class VerdictReply {
  const VerdictReply._({
    required this.approved,
    this.destination,
    this.note,
    this.expiresAt,
    this.failureCause,
  });

  /// Backend `ok`. True → open the WebView with [destination].
  final bool approved;

  /// Backend `url`. The remote page to display.
  final String? destination;

  /// Backend `message`. Diagnostic note (e.g. "organic").
  final String? note;

  /// Backend `expires`. Unix seconds after which [destination] is stale.
  final int? expiresAt;

  /// Populated only when the reply was synthesised locally on a failed
  /// request — captures the transport/parse error so tests can assert
  /// against it. Never set on genuine backend replies.
  final String? failureCause;

  factory VerdictReply.fromWire(Map<String, dynamic> map) {
    return VerdictReply._(
      approved: (map['ok'] as bool?) ?? false,
      destination: map['url'] as String?,
      note: map['message'] as String?,
      expiresAt: (map['expires'] as num?)?.toInt(),
    );
  }

  factory VerdictReply.local(String cause) => VerdictReply._(
        approved: false,
        failureCause: cause,
      );

  bool get hasDestination =>
      destination != null && destination!.trim().isNotEmpty;
}
