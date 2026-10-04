import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Central reactive connectivity service for NextClass (Flow 9 / Phase 11).
/// Listens to network connectivity state changes and provides reactive state
/// across Home, Week, Quizzes, and Upload screens.
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity;
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast(sync: true);

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOffline = false;
  bool _isInitialized = false;

  ConnectivityService._internal({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// Visible for testing constructor allowing custom initial state and mock
  @visibleForTesting
  ConnectivityService.test({Connectivity? connectivity, bool initialOffline = false})
      : _connectivity = connectivity ?? Connectivity(),
        _isOffline = initialOffline;

  // --- Getters ---

  bool get isOffline => _isOffline;
  bool get isOnline => !_isOffline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Initializes the connectivity listener
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);

      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        _updateStatus(results);
      });

      _isInitialized = true;
    } catch (_) {
      // Default to online in headless/test environments
      _isOffline = false;
      notifyListeners();
    }
  }

  /// Manually checks and updates network connectivity state
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
      return _isOffline;
    } catch (_) {
      return _isOffline;
    }
  }

  /// Sets offline status directly (for unit/widget tests)
  void setOffline(bool offline) {
    if (_isOffline != offline) {
      _isOffline = offline;
      _controller.add(_isOffline);
      notifyListeners();
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // If results contains only 'none' or is empty, we are offline
    final offline = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);

    if (_isOffline != offline) {
      _isOffline = offline;
      _controller.add(_isOffline);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
    super.dispose();
  }
}
