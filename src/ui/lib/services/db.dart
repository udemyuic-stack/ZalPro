import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/announcement.dart';
import '../models/game.dart';
import '../models/leaderboard.dart';
import '../models/member_analytics.dart';
import '../models/shop_analytics.dart';
import '../models/gym.dart';
import '../models/exercise_set.dart';
import '../models/exercises.dart';
import '../models/models.dart';
import '../models/payment.dart';
import '../models/shop.dart';
import '../models/stats.dart';
import '../models/photo.dart';
import '../models/scan_result.dart';
import '../models/subscription.dart';
import 'api/analytics_api.dart';
import 'api/announcements_api.dart';
import 'api/exercise_set_api.dart';
import 'api/game_api.dart';
import 'api/leaderboard_api.dart';
import 'api/api_instance.dart';
import 'api/billing_api.dart';
import 'api/body_api.dart';
import 'api/catalog_api.dart';
import 'api/chat_api.dart';
import 'api/checkin_api.dart';
import 'api/day_api.dart';
import 'api/poll_stream.dart';
import 'api/shop_api.dart';
import 'api/stats_api.dart';
import 'api/users_api.dart';
import 'notifications.dart';

String todayKey([DateTime? d]) => DateFormat('yyyy-MM-dd').format(d ?? DateTime.now());

String normalizePhone(String input) {
  final d = input.replaceAll(RegExp(r'\D'), '');
  return d.length == 9 ? '998$d' : d;
}

class AuthService {
  static Stream<String?> changes() async* {
    yield apiClient.userId;
    yield* apiClient.userChanges;
  }

  static Future<void> signIn(String phone, String pass) =>
      apiClient.login(normalizePhone(phone), pass);

  static Future<void> register(String name, String phone, String pass) =>
      apiClient.register(name.trim(), normalizePhone(phone), pass);

  static Future<void> signOut() async {
    await apiClient.logout();
    unawaited(_cancelNotifications());
  }

  static Future<void> _cancelNotifications() async {
    try {
      await Notifications.cancelAll().timeout(const Duration(seconds: 1));
    } catch (_) {}
  }

  static Future<void> changePassword(String current, String next) async {
    final me = await apiClient.getJson('/v1/users/me');
    await apiClient.request<void>('POST', '/v1/auth/change-password',
        data: {'current_password': current, 'new_password': next});
    await apiClient.login('${me['phone']}', next);
  }
}

class Db {
  static final _users = UsersApi(apiClient);
  static final _catalog = CatalogApi(apiClient);
  static final _days = DayApi(apiClient);
  static final _shop = ShopApi(apiClient);
  static final _billing = BillingApi(apiClient);
  static final _chat = ChatApi(apiClient);
  static final _body = BodyApi(apiClient);
  static final _stats = StatsApi(apiClient);
  static final _checkin = CheckinApi(apiClient);
  static final _announcements = AnnouncementsApi(apiClient);
  static final _leaderboard = LeaderboardApi(apiClient);
  static final _game = GameApi(apiClient);
  static final _exerciseSets = ExerciseSetApi(apiClient);
  static final _analytics = AnalyticsApi(apiClient);
  static final _plans = <String, SharedStream<Plan?>>{};

  // ---------- users ----------
  static Stream<AppUser?> me(String uid) => _users.me(uid);

  static Stream<AppUser?> user(String uid) {
    return _users.user(uid);
  }

  /// Hamma shogirdlar — faqat bosh admin uchun (qoidalar trenerga bu so'rovni bermaydi)
  static Stream<List<AppUser>> clients() {
    return _users.clients();
  }

  /// Trenerga biriktirilgan shogirdlar — trener faqat shularni ko'radi
  static Stream<List<AppUser>> clientsOf(String trainerId) {
    return _users.clientsOf(trainerId);
  }

  /// Trenerlar va bosh admin — "Xodimlar" bo'limi uchun.
  /// `whereIn` bitta so'rovda ikkala rolni oladi.
  static Stream<List<AppUser>> staff() {
    return _users.staff();
  }

  /// Faqat trenerlar (bosh admin emas) — shogirdga trener biriktirish ro'yxati uchun
  static Stream<List<AppUser>> trainers() {
    return _users.trainers();
  }

  // ---------- zallar (filiallar) ----------
  /// Zallar ro'yxati — nomi bo'yicha tartiblangan
  static Stream<List<Gym>> gyms() {
    return _users.gyms();
  }

  /// Zal qo'shish yoki nomini o'zgartirish; id qaytadi
  static Future<String> saveGym(Gym g) async {
    return _users.saveGym(g);
  }

  /// Zalni o'chirish — undagi trenerlar zalsiz qoladi
  static Future<void> deleteGym(String id) async {
    return _users.deleteGym(id);
  }

  /// Trenerni zalga biriktirish (null — zaldan chiqarish). Faqat bosh admin.
  static Future<void> setUserGym(String uid, String? gymId) async {
    return _users.setUserGym(uid, gymId);
  }

  /// Yangi trener akkaunti — bosh admin yaratadi.
  static Future<String> createStaff({
    required String name,
    required String phone,
    required String password,
    String role = 'admin',
    String? gymId,
  }) async {
    return _users.createStaff(
      name: name,
      phone: normalizePhone(phone),
      password: password,
      role: role,
      gymId: gymId,
    );
  }

  static Future<void> updateUser(AppUser u, {AppUser? before}) {
    return _users.updateUser(u, before: before);
  }

  /// Reja biriktirilgan vaqt ham saqlanadi — reytingda rioya shu kundan hisoblanadi
  static Future<void> assignPlan(String uid, String? planId) {
    return _users.assignPlan(uid, planId);
  }

  /// Shogird maqsadini trener belgilaydi ('lose' / 'gain')
  static Future<void> setGoal(String uid, String goal) {
    return _users.setGoal(uid, goal);
  }

  /// Shogirdni trenerga biriktirish (null — biriktirishni bekor qilish)
  static Future<void> assignTrainer(String uid, String? trainerId) {
    return _users.assignTrainer(uid, trainerId);
  }

  /// Trenerlar katalogi — shogird anketada tanlaydi (qabul qilayotganlar)
  static Stream<List<TrainerInfo>> trainerDirectory() {
    return _users.trainerDirectory();
  }

  /// Trenerning katalogdagi o'z yozuvi (trener boshqaradi)
  static Stream<TrainerInfo?> trainerProfile(String uid) {
    return _users.trainerProfile(uid);
  }

  /// Zal har doim trenerning o'z hujjatidan olinadi — bosh admin zalni almashtirgan
  /// bo'lsa ham eski qiymat yozilib qolmaydi.
  static Future<void> saveTrainerProfile(TrainerInfo t) async {
    return _users.saveTrainerProfile(t);
  }

  /// Shogird trenerini o'zi tanlaydi yoki almashtiradi (qoidalar: faqat katalogda shogird
  /// qabul qilayotgan trener)
  static Future<void> chooseTrainer(String uid, String trainerId) {
    return _users.assignTrainer(uid, trainerId);
  }

  // ---------- zal ----------
  /// Shogird o'z mashg'ulot kunlarini tanlaydi (aynan 3 ta)
  static Future<void> setGymDays(String uid, List<int> days) {
    return _users.setGymDays(uid, days);
  }

  /// Trener: bugun uyda mashq (null — bekor qilish)
  static Future<void> setHomeWorkout(String uid, String? day) {
    return _users.setHomeWorkout(uid, day);
  }

  // ---------- bosh admin baholari ----------
  static Stream<Map<String, TrainerRating>> ratings() {
    return _users.ratings();
  }

  static Future<void> saveRating(String trainerId, int stars, String comment) {
    return _users.saveRating(trainerId, stars, comment);
  }

  /// Rolni o'zgartirish — faqat bosh admin (qoidalar bilan himoyalangan).
  /// Trenerlikdan olinganda unga biriktirilgan shogirdlar bo'shatiladi.
  /// Trenerlar katalogi ham yangilanadi (katalogda faqat `admin` roli).
  static Future<void> setRole(String uid, String role) async {
    return _users.setRole(uid, role);
  }

  /// Akkauntni o'chirish — faqat bosh admin.
  /// Firestore hujjati o'chadi; kirish akkaunti (Auth) mijoz tomonidan
  /// o'chirilmaydi, shuning uchun AuthGate hujjatsiz kirishni to'sadi.
  static Future<void> deleteUser(String uid) async {
    return _users.deleteUser(uid);
  }

  // ---------- foods ----------
  static Stream<List<Food>> foods() {
    return _catalog.foods();
  }

  static Future<void> saveFood(Food f) {
    return _catalog.saveFood(f);
  }

  static Future<void> deleteFood(String id) {
    return _catalog.deleteFood(id);
  }

  static Future<Food> uploadFoodImage(
    String id,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
    void Function(int sent, int total)? onProgress,
  }) {
    return _catalog.uploadFoodImage(id, bytes, contentType: contentType, onProgress: onProgress);
  }

  static Future<void> deleteFoodImage(String id) {
    return _catalog.deleteFoodImage(id);
  }

  // ---------- exercises (trener qo'shgan mashqlar) ----------
  static Stream<List<Exercise>> customExercises() {
    return _catalog.customExercises();
  }

  static Future<String> saveExercise(Exercise e) {
    return _catalog.saveExercise(e);
  }

  static Future<void> deleteExercise(String id) {
    return _catalog.deleteExercise(id);
  }

  static Future<void> uploadExerciseVideo(
    String id, {
    required int size,
    required String contentType,
    Uint8List? bytes,
    Stream<List<int>> Function()? open,
    void Function(int sent, int total)? onProgress,
  }) {
    return _catalog.uploadExerciseVideo(
      id,
      size: size,
      contentType: contentType,
      bytes: bytes,
      open: open,
      onProgress: onProgress,
    );
  }

  static Future<String> waitVideoReady(String id, {bool Function()? cancelled}) {
    return _catalog.waitVideoReady(id, cancelled: cancelled);
  }

  static Future<String> exerciseVideoUrl(String id) {
    return _catalog.exerciseVideoUrl(id);
  }

  static Future<void> deleteExerciseVideo(String id) {
    return _catalog.deleteExerciseVideo(id);
  }

  /// Trener shogirdga [muscle] uchun mashqlar tanlaydi; bo'sh ro'yxat — standartga qaytish
  static Future<void> setProgram(String uid, String muscle, List<String> keys) {
    return _catalog.setProgram(uid, muscle, keys);
  }

  // ---------- plans ----------
  static Stream<List<Plan>> plans() {
    return _catalog.plans();
  }

  static Stream<Plan?> plan(String id) {
    return _plans.putIfAbsent(id, () => SharedStream(() => _catalog.plan(id))).stream;
  }

  /// Rejani saqlaydi va uning id sini qaytaradi (yangi reja bo'lsa — yaratilgan id)
  static Future<String> savePlan(Plan p) async {
    return _catalog.savePlan(p);
  }

  static Future<void> deletePlan(String id) {
    return _catalog.deletePlan(id);
  }

  // ---------- do'kon: tovarlar (`shop`) ----------
  /// Hamma tovarlar — bo'lim tartibi bo'yicha, ichida nomi bo'yicha.
  /// (Sotuvda yo'qlarini ekranning o'zi ajratadi: trener ko'radi, shogird ko'rmaydi.)
  static Stream<List<Product>> products() {
    return _shop.products();
  }

  static Future<void> saveProduct(Product p) {
    return _shop.saveProduct(p);
  }

  static Future<void> deleteProduct(String id) {
    return _shop.deleteProduct(id);
  }

  static Future<String> uploadProductImage(
    String id,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
    void Function(int sent, int total)? onProgress,
  }) {
    return _shop.uploadProductImage(id, bytes, contentType: contentType, onProgress: onProgress);
  }

  static Future<Product> setProductImages(String id, List<String> keys) {
    return _shop.setProductImages(id, keys);
  }

  // ---------- do'kon: buyurtmalar (`orders`) ----------
  /// Shogirdning o'z buyurtmalari
  static Stream<List<ShopOrder>> myOrders(String uid) {
    return _shop.myOrders(uid);
  }

  /// Trenerga tushgan buyurtmalar (o'z shogirdlariniki)
  static Stream<List<ShopOrder>> ordersOf(String trainerId) {
    return _shop.ordersOf(trainerId);
  }

  /// Hamma buyurtmalar — faqat bosh admin uchun
  /// (qoidalar trener va barmenga bu so'rovni bermaydi)
  static Stream<List<ShopOrder>> allOrders() {
    return _shop.allOrders();
  }

  /// Barmen: faqat o'z zalining buyurtmalari. Zalga biriktirilmagan barmen hech narsa ko'rmaydi.
  static Stream<List<ShopOrder>> gymOrders(String? gymId) {
    return _shop.gymOrders(gymId);
  }

  /// Kim qaysi buyurtmalarni ko'radi: bosh admin — hammasi, barmen — o'z zali,
  /// trener — o'z shogirdlariniki
  static Stream<List<ShopOrder>> ordersFor(AppUser u) => u.isOwner
      ? allOrders()
      : u.isBarmen
          ? gymOrders(u.gymId)
          : ordersOf(u.id);

  /// Shogird buyurtma beradi. Yozuv bilan birga chatga xabar ketadi —
  /// trener buyurtmani bildirishnoma sifatida ham ko'radi.
  static Future<void> createOrder(AppUser client, Product p, int qty,
      {String size = '', String color = ''}) async {
    return _shop.createOrder(p.id, qty, size: size, color: color);
  }

  /// Trener holatni belgilaydi. 'Topshirildi' — zaldagi qoldiqdan ayiriladi.
  /// Shogird chatda javob xabarini ko'radi.
  static Future<void> setOrderStatus(ShopOrder o, String status, String byId) async {
    return _shop.setOrderStatus(o.id, status);
  }

  /// Shogird o'z buyurtmasini bekor qiladi (faqat hali berilmagan bo'lsa)
  static Future<void> cancelOrder(String id) {
    return _shop.setOrderStatus(id, orderCanceled);
  }

  // ---------- meal logs ----------
  static Stream<Set<int>> doneMeals(String uid, String day) {
    return _days.doneMeals(uid, day);
  }

  static Future<void> toggleMeal(String uid, String day, int index, bool done) {
    return _days.toggleMeal(uid, day, index, done);
  }

  /// Rejadan tashqari yeyilgan ovqatlar — qo'shilgan tartibda
  static Stream<List<ExtraFood>> extras(String uid, String day) {
    return _days.extras(uid, day);
  }

  static Future<void> addExtra(String uid, String day, ExtraFood e) {
    return _days.addExtra(uid, day, e);
  }

  static Future<void> removeExtra(String uid, String day, ExtraFood e) {
    return _days.removeExtra(uid, day, e);
  }

  /// Bugungi zal mashg'uloti: boshlanganmi va qaysi mashqlar bajarilgan
  static Stream<WorkoutProgress> workout(String uid, String day) {
    return _days.workout(uid, day);
  }

  static Future<void> startWorkout(String uid, String day) {
    return _days.startWorkout(uid, day);
  }

  static Future<void> toggleExercise(String uid, String day, String key, bool done) {
    return _days.toggleExercise(uid, day, key, done);
  }

  static Future<void> setWorkoutFeedback(String uid, String day, int rating) {
    return _days.setFeedback(uid, day, rating);
  }

  static Stream<Map<String, int>> workoutFeedbackWeek(String uid) {
    return _days.feedbackWeek(uid);
  }

  static Stream<Map<String, Set<String>>> workoutDoneWeek(String uid) {
    return _days.doneWeek(uid);
  }

  static Stream<int> water(String uid, String day) {
    return _days.water(uid, day);
  }

  static Future<void> setWater(String uid, String day, int glasses) {
    return _days.setWater(uid, day, glasses);
  }

  // ---------- weights ----------
  static Stream<List<WeightLog>> weights(String uid) {
    return _body.weights(uid);
  }

  /// Vazn kiritish — o'lchov yozuvi va profildagi vazn BITTA batch'da.
  /// `lastWeighIn` server vaqti bilan yoziladi: qoidalar shu orqali haftada 1 martadan
  /// ko'p kiritishga ruxsat bermaydi (ilovani chetlab o'tganda ham).
  static Future<void> addWeight(String uid, double w) async {
    return _body.addWeight(uid, w);
  }

  // ---------- "oldin / keyin" rasmlari ----------
  /// Eskisi birinchi — "oldin" chapda, "keyin" o'ngda
  static Stream<List<ProgressPhoto>> photos(String uid) {
    return _body.photos(uid);
  }

  /// Rasm hujjatning o'zida saqlanadi (siqilgan, [ProgressPhoto.maxBytes] gacha)
  static Future<void> addPhoto(String uid, Uint8List bytes, double weight) async {
    return _body.addPhoto(uid, bytes, weight);
  }

  static Future<void> deletePhoto(String uid, String id) async {
    return _body.deletePhoto(uid, id);
  }

  // ---------- abonement ----------
  static Stream<List<Subscription>> subscriptions(String uid) {
    return _billing.subscriptions(uid);
  }

  /// Hamma shogirdlarning abonementlari (shogird uid bilan) — faqat bosh admin, oylik hisobot uchun.
  /// Qoidalar trener va barmenga bu so'rovni bermaydi.
  static Stream<List<(String, Subscription)>> allSubscriptions() {
    return _billing.allSubscriptions();
  }

  /// Abonement qo'shish — yozuv va profildagi tugash sanasi BITTA batch'da (`addWeight` kabi).
  /// Shu batch'da `memberships/{uid}` ko'zgusi ham yoziladi — zalning boshqa xodimlari to'lovni
  /// shundan ko'radi. Zal — mijoz trenerining zali (qoidalar ham shuni tekshiradi).
  static Future<void> addSubscription(AppUser client, Subscription s) async {
    return _billing.addSubscription(client, s);
  }

  // ---------- onlayn to'lov (Payme / Click) ----------
  static Future<PaymentOptions> paymentOptions() => _billing.paymentOptions();

  static Future<PaymentOrder> createPaymentOrder(int months, String provider) {
    return _billing.createPaymentOrder(months, provider);
  }

  static Future<PaymentOrder> paymentOrder(String id) => _billing.paymentOrder(id);

  /// To'lov holati oqimi: to'langanda yoki bekor bo'lganda tugaydi.
  static Stream<PaymentOrder> watchPaymentOrder(String uid, String id) {
    return _billing.watchPaymentOrder(uid, id);
  }

  static void refreshAfterPayment(String uid) => _billing.refreshAfterPayment(uid);

  /// Zal mijozlarining oxirgi to'lovlari: bosh admin — hammasi, trener va barmen — o'z zali
  /// (zalsiz xodim — bo'sh; qoidalar boshqa zalni bermaydi).
  static Stream<List<Membership>> memberships(AppUser me) {
    return _billing.memberships(me);
  }

  // ---------- davomat ----------
  static Stream<bool> attendance(String uid, String day) {
    return _billing.attendance(uid, day);
  }

  static Stream<Set<String>> attendanceRange(String uid) {
    return _billing.attendanceRange(uid);
  }

  static Future<List<ExerciseSet>> exerciseSets(String uid, String day, String key) =>
      _exerciseSets.sets(uid, day, key);

  static Future<List<ExerciseSet>> previousExerciseSets(String uid, String key, String before) =>
      _exerciseSets.previous(uid, key, before);

  static Future<void> saveExerciseSets(
          String uid, String day, String key, List<ExerciseSet> sets) =>
      _exerciseSets.save(uid, day, key, sets);

  static Stream<Set<String>> streakFreezes(String uid) => _billing.streakFreezes(uid);

  static Future<void> freezeWeek(String uid, String weekStart) =>
      _billing.freezeWeek(uid, weekStart);

  static Future<void> markAttendance(String uid, String day, bool present, String byId) {
    return _billing.markAttendance(uid, day, present);
  }

  static Stream<List<Announcement>> announcements() => _announcements.announcements();

  static Future<void> addAnnouncement({
    required String title,
    required String body,
    required AnnouncementAudience audience,
    int? expiresInDays,
  }) =>
      _announcements.add(
        title: title,
        body: body,
        audience: audience,
        expiresInDays: expiresInDays,
      );

  static Future<void> removeAnnouncement(String id) => _announcements.remove(id);

  static Stream<Leaderboard> leaderboard() => _leaderboard.leaderboard();

  static Future<GameCatalog> gameCatalog() => _game.catalog();

  static Stream<GameMe> gameMe() => _game.me();

  static Stream<GameChallenges> gameChallenges() => _game.challenges();

  static Stream<GameLeaderboard> gameLeaderboard({String period = 'week', String? exercise}) =>
      _game.leaderboard(period: period, exercise: exercise);

  static Future<GameSessionResult> submitGameSession(GameSessionDraft draft) => _game.submit(draft);

  static Future<List<ChallengeStepAdmin>> challengeSteps() => _game.challengeSteps();

  static Future<void> addChallengeStep({
    required String exercise,
    required int target,
    required int coins,
    required String muscle,
  }) =>
      _game.addChallengeStep(exercise: exercise, target: target, coins: coins, muscle: muscle);

  static Future<void> updateChallengeStep(
    String id, {
    required String exercise,
    required int target,
    required int coins,
    required String muscle,
  }) =>
      _game.updateChallengeStep(
        id,
        exercise: exercise,
        target: target,
        coins: coins,
        muscle: muscle,
      );

  static Future<void> removeChallengeStep(String id) => _game.removeChallengeStep(id);

  static Future<ShopAnalytics> shopAnalytics(DateTime from, DateTime to) =>
      _analytics.shop(from, to);

  static Future<ChurnReport> churn() => _analytics.churn();

  static Future<Retention> retention(DateTime from, DateTime to) => _analytics.retention(from, to);

  static Future<TrainerStats> trainerAnalytics(DateTime from, DateTime to) =>
      _analytics.trainers(from, to);

  static Future<void> setLeaderboardVisible(String uid, bool visible) =>
      _users.setLeaderboardVisible(uid, visible);

  static Future<void> setGameEnabled(String uid, bool enabled) =>
      _users.setGameEnabled(uid, enabled);

  static Future<String> checkinToken() => _checkin.checkinToken();

  static Future<ScanResult> scanCheckin(String token) => _checkin.scanCheckin(token);

  // ---------- eslatmalar (abonement tugashi haqida jo'natilgan jurnal) ----------
  static Stream<List<Reminder>> remindersOf(String trainerId) {
    return _billing.remindersOf(trainerId);
  }

  static Stream<List<Reminder>> allReminders() {
    return _billing.allReminders();
  }

  /// Abonement tugashi haqida eslatma: jurnalga yoziladi va shogirdga chatga xabar boradi.
  static Future<void> sendSubscriptionReminder(AppUser client, int daysLeft, String byId) async {
    return _billing.sendSubscriptionReminder(client, daysLeft);
  }

  // ---------- trenerlar reytingi (faqat bosh admin) ----------

  /// Har xodim va unga biriktirilgan shogirdlar bo'yicha so'nggi [statsDays] kun
  /// ko'rsatkichlari. Bir martalik yuklash — ekranda "yangilash" bilan qayta chaqiriladi.
  static Future<List<TrainerStat>> trainerStats() async {
    return _stats.trainerStats(await trainers().first);
  }

  // ---------- chat (har bir user uchun bitta chat: chats/{uid}) ----------
  static Stream<List<ChatMessage>> messages(String chatUid, {bool live = true}) {
    return _chat.messages(chatUid, live: live);
  }

  /// Bildirishnomalar uchun: oxirgi xabarlar hujjat id si bilan (takror bildirmaslik uchun)
  static Stream<List<(String, ChatMessage)>> messageEvents(String chatUid) {
    return _chat.messageEvents(chatUid);
  }

  static Future<void> send(String chatUid, String senderId, String text) {
    return _chat.send(chatUid, text);
  }

  static Future<String> uploadChatMedia(
    String chatUid, {
    required String kind,
    required String contentType,
    required int size,
    Uint8List? bytes,
    Stream<List<int>> Function()? open,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) {
    return _chat.uploadChatMedia(
      chatUid,
      kind: kind,
      contentType: contentType,
      size: size,
      bytes: bytes,
      open: open,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  static Future<void> sendMessage(
    String chatUid, {
    String text = '',
    String? mediaKey,
    String? mediaKind,
    int? durationMs,
  }) {
    return _chat.sendMessage(
      chatUid,
      text: text,
      mediaKey: mediaKey,
      mediaKind: mediaKind,
      durationMs: durationMs,
    );
  }
}

// ---------- providers ----------
final authProvider = StreamProvider<String?>((ref) => AuthService.changes());

/// Trenerlar katalogi — anketa va AuthGate uchun (kirmagan bo'lsa bo'sh)
final trainerDirectoryProvider = StreamProvider<List<TrainerInfo>>((ref) {
  final uid = ref.watch(authProvider).value;
  if (uid == null) return Stream.value(const []);
  return Db.trainerDirectory();
});

final meProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authProvider).value;
  if (uid == null) return Stream.value(null);
  return Db.me(uid);
});
