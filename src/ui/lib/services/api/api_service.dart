import 'api_client.dart';
import 'poll_stream.dart';

abstract class ApiService {
  ApiService(this.client, {ChangeBus? bus, PollActivity? activity})
      : bus = bus ?? changeBus,
        activity = activity ?? pollActivity;

  final ApiClient client;
  final ChangeBus bus;
  final PollActivity activity;

  Stream<T> poll<T>(Future<T> Function() fetch, Duration every, Set<String> tags) =>
      pollStream<T>(fetch, every: every, tags: tags, bus: bus, activity: activity);

  Future<void> write(String method, String path, Object? body, Iterable<String> tags) =>
      bus.after(client.request<void>(method, path, data: body), tags);
}
