import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../services/api/json_helpers.dart';
import '../theme.dart';

enum ScanStatus { arrived, alreadyPresent, expired, none }

class ScanResult {
  final String userId;
  final String name;
  final String day;
  final bool alreadyPresent;
  final DateTime? subscriptionExpiresAt;
  final int? daysLeft;
  final String subscription;

  const ScanResult({
    required this.userId,
    required this.name,
    required this.day,
    required this.alreadyPresent,
    required this.subscriptionExpiresAt,
    required this.daysLeft,
    required this.subscription,
  });

  factory ScanResult.fromJson(Map<String, dynamic> j) {
    final left = j['days_left'];
    return ScanResult(
      userId: jsonString(j['user_id']),
      name: jsonString(j['name']),
      day: jsonString(j['day']),
      alreadyPresent: jsonBool(j['already_present']),
      subscriptionExpiresAt: jsonDate(j['subscription_expires_at']),
      daysLeft: left is num ? left.toInt() : null,
      subscription: jsonString(j['subscription'], 'none'),
    );
  }
}

class ScanOutcome {
  final ScanStatus status;
  final String message;
  final String? note;
  final Color Function() color;
  final IconData icon;

  const ScanOutcome({
    required this.status,
    required this.message,
    required this.color,
    required this.icon,
    this.note,
  });
}

ScanOutcome scanOutcome(ScanResult r) {
  if (r.subscription == 'expired') {
    return ScanOutcome(
      status: ScanStatus.expired,
      message: trf('{0}: obuna tugagan', [r.name]),
      note: tr('Davomat belgilandi'),
      color: () => AppColors.danger,
      icon: Icons.warning_amber_rounded,
    );
  }
  if (r.subscription != 'active') {
    return ScanOutcome(
      status: ScanStatus.none,
      message: trf("{0}: obuna yo'q", [r.name]),
      note: tr('Davomat belgilandi'),
      color: () => AppColors.danger,
      icon: Icons.warning_amber_rounded,
    );
  }
  if (r.alreadyPresent) {
    return ScanOutcome(
      status: ScanStatus.alreadyPresent,
      message: trf('Bugun allaqachon belgilangan: {0}', [r.name]),
      color: () => AppColors.warning,
      icon: Icons.info_outline,
    );
  }
  final left = r.daysLeft ?? 0;
  return ScanOutcome(
    status: ScanStatus.arrived,
    message: left <= 0
        ? trf('Keldi: {0}, bugun tugaydi', [r.name])
        : trf('Keldi: {0}, {1} kun qoldi', [r.name, left]),
    color: () => AppColors.success,
    icon: Icons.check_circle_outline,
  );
}
