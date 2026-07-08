// ============================================================
// ROUTE MODE — which experience the shell resolved to
// ============================================================
// Persisted across launches so the shell never re-runs attribution once
// a definitive verdict has been recorded. A returning `RouteMode.escape`
// user goes straight to the WebView; `RouteMode.native` opens the game.
// `RouteMode.unresolved` means "first run, no verdict yet".
// ============================================================

enum RouteMode {
  /// Returning user, previously routed into the WebView (gray flow).
  escape,

  /// Returning user, previously routed into the offline game (white flow).
  native,

  /// First run — verdict has not been committed yet.
  unresolved;

  static RouteMode restore(String? raw) {
    switch (raw) {
      case 'escape':
        return RouteMode.escape;
      case 'native':
        return RouteMode.native;
      default:
        return RouteMode.unresolved;
    }
  }

  String persistTag() => name;
}
