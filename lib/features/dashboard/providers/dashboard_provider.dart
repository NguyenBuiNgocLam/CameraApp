import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/dashboard_stats.dart';
import '../services/dashboard_service.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({required DashboardService dashboardService})
    : _dashboardService = dashboardService;

  final DashboardService _dashboardService;

  bool isLoading = false;
  String? errorMessage;
  DashboardStats stats = DashboardStats.empty();

  Future<void> loadDashboard() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      stats = DashboardStats.empty();
      errorMessage = null;
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      stats = await _dashboardService.getDashboardStats(uid);
      await _dashboardService.updateDashboardSummary(uid);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshDashboard() => loadDashboard();
}
