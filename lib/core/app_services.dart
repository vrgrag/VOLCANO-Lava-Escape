import 'package:flutter/widgets.dart';

import '../services/connectivity_service.dart';
import '../services/storage_service.dart';

/// Bundles the small set of long-lived services and exposes them to the
/// whole widget tree without pulling in a state-management dependency.
class AppServices {
  AppServices({required this.storage}) : connectivity = ConnectivityService();

  final StorageService storage;
  final ConnectivityService connectivity;
}

class AppServicesScope extends InheritedWidget {
  const AppServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppServicesScope>();
    assert(scope != null, 'AppServicesScope not found in context');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) =>
      services != oldWidget.services;
}
