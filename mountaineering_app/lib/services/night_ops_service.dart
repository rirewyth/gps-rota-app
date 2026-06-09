import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NightOpsService extends ChangeNotifier {
  static final NightOpsService _instance = NightOpsService._internal();
  factory NightOpsService() => _instance;
  NightOpsService._internal() {
    _loadState();
  }

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('night_ops_active') ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isEnabled = !_isEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('night_ops_active', _isEnabled);
    notifyListeners();
  }

  // Tactical Red Filter for Night Vision
  // Consists of a deep red overlay that preserves peripheral vision
  Widget applyNightFilter(Widget child) {
    if (!_isEnabled) return child;
    
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.8, 0, 0, 0, 50, // Red
        0, 0.1, 0, 0, 0,  // Green (minimal)
        0, 0, 0.1, 0, 0,  // Blue (minimal)
        0, 0, 0, 1, 0,    // Alpha
      ]),
      child: child,
    );
  }
}
