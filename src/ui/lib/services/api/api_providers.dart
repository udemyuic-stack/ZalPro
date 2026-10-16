import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'api_instance.dart';
import 'poll_stream.dart';

final apiClientProvider = Provider<ApiClient>((ref) => apiClient);

final changeBusProvider = Provider<ChangeBus>((ref) => changeBus);

final pollActivityProvider = Provider<PollActivity>((ref) => pollActivity);
