import '../../models/models.dart';
import '../../models/payment.dart';
import '../../models/streak.dart';
import '../../models/subscription.dart';
import 'api_error.dart';
import 'api_service.dart';
import 'json_helpers.dart';
import 'poll_stream.dart';

class BillingApi extends ApiService {
  BillingApi(super.client, {super.bus, super.activity, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const _subs = Duration(seconds: 60);
  static const _memberships = Duration(seconds: 60);
  static const _attendance = Duration(seconds: 30);
  static const _reminders = Duration(seconds: 60);
  static const _windowDays = 400;
  static const _minDaysLeft = -3650;
  static const _maxDaysLeft = 31;

  final DateTime Function() _now;
  final _marks = <String, SharedStream<bool>>{};
  final _ranges = <String, SharedStream<Set<String>>>{};

  String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Stream<List<Subscription>> subscriptions(String uid) => poll(() async {
        final rows = await client.getList('/v1/users/$uid/subscriptions');
        return jsonMaps(rows).map(Subscription.fromJson).toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));
      }, _subs, {'subscriptions', 'subscriptions:$uid'}, key: 'subscriptions:$uid');

  Stream<List<(String, Subscription)>> allSubscriptions() => poll(() async {
        final rows = await client.getList('/v1/subscriptions');
        return [
          for (final row in jsonMaps(rows))
            (jsonString(row['user_id']), Subscription.fromJson(row)),
        ];
      }, _subs, {'subscriptions'}, key: 'allSubscriptions');

  Future<void> addSubscription(AppUser client, Subscription s) async {
    await write(
      'POST',
      '/v1/users/${client.id}/subscriptions',
      s.toJson(),
      ['subscriptions', 'subscriptions:${client.id}', 'memberships', 'users', 'user:${client.id}'],
    );
  }

  Future<PaymentOptions> paymentOptions() async =>
      PaymentOptions.fromJson(await client.getJson('/v1/payments/options'));

  /// Server narxni o'zi hisoblaydi — faqat muddat (oy) va to'lov tizimi yuboriladi.
  Future<PaymentOrder> createPaymentOrder(int months, String provider) async {
    final row = await client.request<Map<String, dynamic>>(
      'POST',
      '/v1/payments/orders',
      data: {'months': months, 'provider': provider},
    );
    return PaymentOrder.fromJson(row ?? const {});
  }

  Future<PaymentOrder> paymentOrder(String id) async =>
      PaymentOrder.fromJson(await client.getJson('/v1/payments/orders/$id'));

  /// To'lov holatini [every] da so'raydi; `paid`/`canceled` bo'lganda yoki [timeout] dan keyin
  /// tugaydi. Tarmoq uzilishlari o'tkazib yuboriladi (to'lov sahifasida internet bo'lmasligi mumkin).
  /// To'langanda abonement va profil oqimlari yangilanadi.
  Stream<PaymentOrder> watchPaymentOrder(
    String uid,
    String id, {
    Duration every = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 15),
  }) async* {
    final clock = Stopwatch()..start();
    while (clock.elapsed < timeout) {
      try {
        final order = await paymentOrder(id);
        yield order;
        if (order.isFinal) {
          if (order.isPaid) refreshAfterPayment(uid);
          return;
        }
      } on ApiException catch (e) {
        if (!e.isNetwork) rethrow;
      }
      await Future<void>.delayed(every);
    }
  }

  void refreshAfterPayment(String uid) => bus.touchAll(
      ['subscriptions', 'subscriptions:$uid', 'memberships', 'users', 'user:$uid']);

  Stream<List<Membership>> memberships(AppUser me) {
    if (!me.isOwner && (me.gymId ?? '').isEmpty) return Stream.value(const <Membership>[]);
    return poll(() async {
      final rows = await client.getList('/v1/memberships');
      return jsonMaps(rows).map(Membership.fromJson).toList();
    }, _memberships, {'memberships'}, key: 'memberships');
  }

  SharedStream<bool> _mark(String uid, String day) {
    return _marks.putIfAbsent(
      '$uid|$day',
      () => SharedStream(
        () => poll(() async {
          final row = await client.getJson('/v1/users/$uid/attendance/$day');
          return jsonBool(row['present']);
        }, _attendance, {'attendance:$uid:$day'}),
      ),
    );
  }

  Stream<bool> attendance(String uid, String day) => _mark(uid, day).stream;

  SharedStream<Set<String>> _range(String uid) {
    return _ranges.putIfAbsent(uid, () {
      final today = _now();
      final from = historyFromKey(_day(today));
      final start = DateTime.parse(from);
      final tags = <String>{'attendance:$uid'};
      for (var d = start;
          !d.isAfter(DateTime(today.year, today.month, today.day + 2));
          d = DateTime(d.year, d.month, d.day + 1)) {
        tags.add('attendance:$uid:${_day(d)}');
      }
      return SharedStream(
        () => poll(() async {
          final now = _now();
          final rows = await client.getList('/v1/users/$uid/attendance', query: {
            'from': historyFromKey(_day(now)),
            'to': _day(now),
          });
          return {
            for (final row in jsonMaps(rows))
              if (jsonBool(row['present'])) jsonString(row['day']),
          };
        }, _attendance, tags),
      );
    });
  }

  Stream<Set<String>> attendanceRange(String uid) => _range(uid).stream;

  Future<void> markAttendance(String uid, String day, bool present) async {
    final row = await client.request<Map<String, dynamic>>(
      'PUT',
      '/v1/users/$uid/attendance/$day',
      data: {'present': present},
    );
    _mark(uid, day).push(row == null ? present : jsonBool(row['present']));
    bus.touchAll(['attendance:$uid:$day', 'attendance:$uid']);
  }

  Stream<List<Reminder>> _remindersWhere(bool owner, bool Function(Reminder) keep) {
    return poll(() async {
      final query = <String, dynamic>{};
      if (!owner) {
        final today = _now();
        final to = DateTime(today.year, today.month, today.day + 1);
        final from = DateTime(to.year, to.month, to.day - (_windowDays - 1));
        query['from'] = _day(from);
        query['to'] = _day(to);
      }
      final rows = await client.getList('/v1/reminders', query: query);
      return jsonMaps(rows).map(Reminder.fromJson).toList();
    }, _reminders, {'reminders'}, key: owner ? 'reminders:all' : 'reminders:window')
        .map((rows) => rows.where(keep).toList());
  }

  Stream<List<Reminder>> remindersOf(String trainerId) =>
      _remindersWhere(false, (r) => r.trainerId == trainerId);

  Stream<List<Reminder>> allReminders() => _remindersWhere(true, (_) => true);

  Future<void> sendSubscriptionReminder(AppUser client, int daysLeft) => write(
        'POST',
        '/v1/reminders',
        {
          'client_id': client.id,
          'days_left': daysLeft.clamp(_minDaysLeft, _maxDaysLeft),
        },
        ['reminders'],
      );
}
