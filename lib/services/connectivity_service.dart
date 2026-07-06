import 'package:connectivity_plus/connectivity_plus.dart';

/// Checks device connectivity before attempting to load remote (WebView)
/// content. The core game never depends on this — it is only used to
/// gate the optional Privacy Policy / Support pages.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Future<bool> hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
