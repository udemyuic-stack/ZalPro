import 'package:flutter/foundation.dart';

class UpgradeInfo {
  const UpgradeInfo({required this.downloadUrl});

  final String downloadUrl;
}

const upgradeRequiredCode = 'upgrade_required';
const appVersionHeader = 'X-App-Version';

final ValueNotifier<UpgradeInfo?> upgradeRequired = ValueNotifier<UpgradeInfo?>(null);
