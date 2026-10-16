import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/l10n/tr.dart';
import 'package:kotta_qani_diet/models/exercises.dart';
import 'package:kotta_qani_diet/models/feed.dart';
import 'package:kotta_qani_diet/models/finance.dart';
import 'package:kotta_qani_diet/screens/user/muscles_screen.dart';
import 'package:kotta_qani_diet/models/gym.dart';
import 'package:kotta_qani_diet/models/hudud.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/models/shop.dart';
import 'package:kotta_qani_diet/models/stats.dart';
import 'package:kotta_qani_diet/models/subscription.dart';
import 'package:kotta_qani_diet/models/video_link.dart';
import 'package:kotta_qani_diet/screens/admin/exercises_admin_screen.dart';
import 'package:kotta_qani_diet/screens/admin/plans_screen.dart';
import 'package:kotta_qani_diet/screens/notifications_screen.dart';
import 'package:kotta_qani_diet/services/db.dart';
import 'package:kotta_qani_diet/services/reminders.dart';
import 'package:kotta_qani_diet/widgets/change_password.dart';
import 'package:kotta_qani_diet/widgets/body_map.dart';
import 'package:kotta_qani_diet/widgets/food_image.dart';
import 'package:kotta_qani_diet/widgets/lazy_stack.dart';
import 'package:kotta_qani_diet/widgets/ui.dart';

void main() {
  group('AppUser.targetKcal', () {
    test('trener formulasi: erkak, sekin metabolizm — 85 kg × 33, ozishda −20%', () {
      final u = AppUser(
          id: '1', name: 'a', email: 'a', age: 30, height: 175, weight: 85, metabolism: 'slow');
      expect(u.kcalPerKg, 33);
      expect(u.targetKcal, (85 * 33 * 0.8).round()); // 2244
    });

    test('trener koeffitsiyentlari: ayol 31/33, erkak 33/35', () {
      AppUser w(String g, String m) =>
          AppUser(id: 'k', name: 'k', email: '', gender: g, metabolism: m);
      expect(w('female', 'slow').kcalPerKg, 31);
      expect(w('female', 'fast').kcalPerKg, 33);
      expect(w('male', 'slow').kcalPerKg, 33);
      expect(w('male', 'fast').kcalPerKg, 35);
      // tanlanmagan — sekin deb olinadi
      expect(w('male', '').kcalPerKg, 33);
    });

    test("normal vaznli ayol, tez metabolizm — defitsitsiz vazn × 33", () {
      final u = AppUser(
          id: '6',
          name: 'f',
          email: '',
          gender: 'female',
          age: 25,
          height: 165,
          weight: 60,
          metabolism: 'fast');
      expect(u.targetKcal, 1980);
    });

    test('ayol uchun 1200 kkal dan past tushmaydi', () {
      final u = AppUser(
          id: '2',
          name: 'b',
          email: 'b',
          gender: 'female',
          age: 60,
          height: 150,
          weight: 36,
          metabolism: 'slow');
      expect(u.targetKcal, 1200); // 36 × 31 = 1116 → minimum 1200
    });

    test("massa nabor uchun +10% (defitsit yo'q)", () {
      final u = AppUser(
          id: '4',
          name: 'd',
          email: 'd',
          age: 30,
          height: 175,
          weight: 85,
          metabolism: 'slow',
          goal: 'gain');
      // 85 × 33 = 2805 → +10%
      expect(u.targetKcal, 3086);
      expect(u.goalLabel, 'Massa nabor');
    });

    test('maqsad saqlanadi va shablon kategoriyasiga mos', () {
      final u = AppUser(id: '5', name: 'e', email: 'e', goal: 'lose');
      expect(u.toMap()['goal'], 'lose');
      expect(u.copyWith(goal: 'gain').goal, 'gain');
      expect(planCategories, containsAll([u.goalLabel, u.copyWith(goal: 'gain').goalLabel]));
    });

    test("reja faqat o'z maqsadidagi shogirdga mos (boshqasi bloklanadi)", () {
      final ozish = Plan(title: 'Ozish • 80-90 kg', meals: []);
      final massa = Plan(title: 'Massa nabor • 1-versiya', meals: []);
      final eski = Plan(title: 'Mening rejam', meals: []);
      final gain = AppUser(id: 'g', name: 'g', email: '', goal: 'gain');
      final none = AppUser(id: 'n', name: 'n', email: '');
      expect(gain.fitsPlan(massa), isTrue);
      expect(gain.fitsPlan(ozish), isFalse);
      expect(gain.copyWith(goal: 'lose').fitsPlan(ozish), isTrue);
      expect(none.fitsPlan(ozish), isFalse, reason: 'maqsad tanlanmagan');
      expect(none.fitsPlan(eski), isTrue, reason: 'kategoriyasiz eski reja');
    });

    test('norma formulasi foydalanuvchiga tushunarli yoziladi', () {
      final u = AppUser(
          id: 'f', name: 'f', email: '', age: 25, height: 175, weight: 80, metabolism: 'slow');
      expect(u.kcalFormula, '80 kg × 33 − 20%');
      expect(u.targetKcal, 2112);
      expect(u.copyWith(goal: 'gain').kcalFormula, '80 kg × 33 + 10%');
      final normal = u.copyWith(weight: 60); // BMI 19,6 — defitsit yo'q
      expect(normal.kcalFormula, '60 kg × 33');
    });

    test("vazn kam (BMI < 18,5) — ozish mumkin emas", () {
      final thin = AppUser(id: 'b', name: 'b', email: '', age: 19, height: 175, weight: 56);
      expect(thin.bmi, lessThan(18.5));
      expect(thin.canLose, isFalse);
      expect(AppUser(id: 'c', name: 'c', email: '', height: 175, weight: 70).canLose, isTrue);
      expect(AppUser(id: 'd', name: 'd', email: '').canLose, isTrue); // anketa yo'q
    });

    test('anketa to\'ldirilmagan bo\'lsa 0', () {
      expect(AppUser(id: '3', name: 'c', email: 'c').targetKcal, 0);
    });
  });

  group('Diamond shabloni', () {
    final plan = diamondTemplate();

    test('5 mahal: 07:00, 10:30, 13:00, 15:00, 18:00', () {
      expect(plan.meals.map((m) => m.time), ['07:00', '10:30', '13:00', '15:00', '18:00']);
    });

    test("poldnikda 50 g yong'oq", () {
      expect(plan.meals[3].items.single.grams, 50);
    });

    test('shakar, non, shirin mevalar taqiqlangan', () {
      expect(plan.forbidden, containsAll(['Shakar', 'Non', 'Shirin mevalar']));
    });

    test('kunlik kaloriya xavfsiz oraliqda (1200+)', () {
      expect(plan.kcal, inInclusiveRange(1400, 1500));
    });
  });

  group('Ozish 2-versiya (60/65/75 kg)', () {
    final plan = ozish60to75Template();

    test('ovqat vaqtlari: 07:00, 10:30, 12:30, 16:00, 17:30, 19:00', () {
      expect(plan.meals.map((m) => m.time), ['07:00', '10:30', '12:30', '16:00', '17:30', '19:00']);
    });

    test("tushlikda 150 g go'sht, kechki ovqatda 150 g baliq", () {
      expect(plan.meals[2].items[1].grams, 150);
      expect(plan.meals[5].items[1].grams, 150);
    });

    test('kunlik kaloriya xavfsiz oraliqda (1200+)', () {
      expect(plan.kcal, inInclusiveRange(1200, 1800));
    });
  });

  group('Shablon kategoriyalari', () {
    test('2 ta ozish va 3 ta massa nabor', () {
      final cats = planTemplates().map((p) => p.category).toList();
      expect(cats.where((c) => c == 'Ozish'), hasLength(2));
      expect(cats.where((c) => c == 'Massa nabor'), hasLength(3));
    });

    test('massa nabor 3-versiya: rasmlardagi matn to\'liq', () {
      final note = massaNabor3Template().note;
      for (final part in [
        '31',
        '33',
        '35',
        'metabolizm',
        '374 kkal',
        'gainer',
        'testosteron',
        '78,9 g',
        '69,2 g',
        '67,8 g',
        '60,2 g',
        '52–62 g',
        '368 kkal',
      ]) {
        expect(note, contains(part));
      }
    });

    test('ozish 2-versiya izohida trener matni to\'liq', () {
      final note = ozish60to75Template().note;
      for (final part in [
        '75 kg, 65 kg va 60 kg',
        'soya yog',
        'sarig',
        '10:30',
        '12:30',
        '150 g norma',
        '4 ta tuxum oqi',
        '16:00',
        'kefir',
        'zarari yo',
        '19:00',
        'bolgar',
        'vitamin',
      ]) {
        expect(note, contains(part));
      }
    });

    test('massa nabor 1-versiya: 4 mahal, ~2540 kkal', () {
      final p = massaNabor1Template();
      expect(p.meals.map((m) => m.time), ['07:30', '13:00', '18:00', '21:00']);
      expect(p.kcal, inInclusiveRange(2450, 2650));
    });

    test('massa nabor 2-versiya: 6 mahal, ~2700 kkal, oqsil me\'yorida (≤ 230 g)', () {
      final p = massaNabor2Template();
      expect(p.meals, hasLength(6));
      expect(p.kcal, inInclusiveRange(2600, 2950));
      expect(p.protein, inInclusiveRange(170, 230));
    });

    test("massa nabor 3-versiya: mahallar to'ldirilgan, gainer mashg'ulot atrofida", () {
      final p = massaNabor3Template();
      expect(p.meals, hasLength(6));
      expect(p.kcal, inInclusiveRange(2550, 2950));
      expect(p.meals.where((m) => m.title.contains("Mashg'ulot")), hasLength(2));
    });
  });

  group('Mahsulot rasmi nom bo\'yicha', () {
    String? img(String name) => foodAsset(name)?.split('/').last.replaceAll('.jpg', '');

    test('shablonlardagi har bir mahsulotning rasmi bor', () {
      final missing = [
        for (final p in planTemplates())
          for (final m in p.meals)
            for (final i in m.items)
              if (img(i.name) == null) i.name,
      ];
      expect(missing, isEmpty);
    });

    test('nomdagi birinchi mahsulot tanlanadi', () {
      expect(img("Yong'oq (yoki hammasi o'rniga 1 porsiya protein)"), 'walnut');
      expect(img('Olma yoki qulupnay (yoki ozgina mayiz)'), 'apple');
      expect(img("Tovuq ko'kragi (grill) / bifshteks / mol go'shti / baliq"), 'chicken');
      expect(img("Protein, 1 porsiya (mashg'ulot bo'lsa: 50 g grechka + kefir)"), 'protein');
      expect(img('Tuxum oqi (4 dona)'), 'egg_white');
    });

    test('yangi rasmlar', () {
      expect(img('Banan (1 dona)'), 'banana');
      expect(img('Sut (250 ml)'), 'milk');
      expect(img('Pishloq (sir)'), 'cheese');
      expect(img('Iliq suv + yarimta limon'), 'lemon');
      expect(img('Brokkoli yoki gulkaram'), 'broccoli');
      expect(img("Qaynatilgan: guruch / grechka / kartoshka"), 'rice');
    });

    test("so'z ichidagi harflar adashtirmaydi", () {
      expect(img('Sutka'), isNull);
      expect(img('Osh'), 'rice');
      expect(img('Oshqozon'), isNull);
      expect(img('Suzma'), 'cottage_cheese');
    });
  });

  group("Parolni o'zgartirish", () {
    test('tekshiruvlar', () {
      expect(validateNewPassword('', 'yangi123', 'yangi123'), isNotNull);
      expect(validateNewPassword('eski12', '1234567', '1234567'), contains('8 belgi'));
      expect(validateNewPassword('eski1234', 'eski1234', 'eski1234'), contains('farq'));
      expect(validateNewPassword('eski1234', 'yangi123', 'yangi124'), contains('bir xil emas'));
      expect(validateNewPassword('eski1234', 'yangi123', 'yangi123'), isNull);
    });
  });

  group('Zal', () {
    test('Se/Pay/Sha: 1) ko\'krak+biceps, 2) qanot+oyoq, 3) yelka+triceps', () {
      expect(workoutFor(evenDays, DateTime.tuesday), workoutGroups[0]);
      expect(workoutFor(evenDays, DateTime.thursday), workoutGroups[1]);
      expect(workoutFor(evenDays, DateTime.saturday), workoutGroups[2]);
      expect(workoutFor(evenDays, DateTime.monday), isNull);
    });

    test('faqat ikki variant qabul qilinadi', () {
      expect(validGymDays([2, 4, 6]), isTrue);
      expect(validGymDays([5, 3, 1]), isTrue);
      expect(validGymDays([1, 4, 6]), isFalse);
      expect(validGymDays([]), isFalse);
    });

    test('keyingi mashg\'ulot', () {
      // yakshanba → dushanba (Du/Chor/Ju variant)
      expect(nextWorkout(oddDays, DateTime.sunday), (DateTime.monday, workoutGroups[0]));
      expect(nextWorkout(evenDays, DateTime.saturday), (DateTime.tuesday, workoutGroups[0]));
    });

    test('chatda kela olmasligini yozgani aniqlanadi', () {
      expect(saysCantCome('Bugun kelolmayman'), isTrue);
      expect(saysCantCome("bugun zalga bora olmayman"), isTrue);
      expect(saysCantCome('borolmiman trener'), isTrue);
      expect(saysCantCome('bugun boromiman'), isTrue);
      expect(saysCantCome('Kelomiman bugun'), isTrue);
      expect(saysCantCome('bugun kelaman'), isFalse);
      expect(saysCantCome('zalga boraman'), isFalse);
    });
  });

  group('Eslatmalar vaqti', () {
    test('rejadagi vaqt matni', () {
      expect(parseMealTime('07:30'), (7, 30));
      expect(parseMealTime('7:05'), (7, 5));
      expect(parseMealTime('25:00'), isNull);
      expect(parseMealTime('nonushta'), isNull);
    });

    test("ovqat eslatmasi: vaqt o'tmagan bo'lsa bugun, o'tgan bo'lsa ertaga", () {
      final now = DateTime(2026, 9, 15, 10, 0);
      expect(nextDailyAt(now, 13, 0), DateTime(2026, 9, 15, 13, 0));
      expect(nextDailyAt(now, 7, 30), DateTime(2026, 9, 16, 7, 30));
    });

    test("vazn eslatmasi: oxirgi o'lchovdan 7 kun keyin 08:00", () {
      final now = DateTime(2026, 9, 15, 10, 0);
      expect(weighInReminderAt(DateTime(2026, 9, 14, 21), now), DateTime(2026, 9, 21, 8));
      // muddat o'tib ketgan — eng yaqin 08:00 (ertaga)
      expect(weighInReminderAt(DateTime(2026, 9, 1), now), DateTime(2026, 9, 16, 8));
      expect(weighInReminderAt(null, DateTime(2026, 9, 15, 6)), DateTime(2026, 9, 15, 8));
    });

    test('eslatma matni', () {
      final (title, body) = mealReminderText(Meal(time: '07:30', title: 'Nonushta', items: [
        MealItem(name: "Suli bo'tqasi (quruq)", grams: 50, kcal: 185),
        MealItem(name: 'Tvorog', grams: 150, kcal: 180),
      ]));
      expect(title, 'Nonushta vaqti · 07:30');
      expect(body, "Suli bo'tqasi, Tvorog");
    });
  });

  group('Vazn haftada 1 marta', () {
    final monday = DateTime(2026, 9, 14, 21, 0); // dushanba kechqurun

    test('birinchi o\'lchov doim mumkin', () {
      expect(WeightLog.canAdd(null), isTrue);
    });

    test('ertasi kuni ham, 6 kundan keyin ham kiritib bo\'lmaydi', () {
      final last = WeightLog(monday, 80);
      expect(WeightLog.canAdd(last, DateTime(2026, 9, 15, 8)), isFalse);
      expect(WeightLog.daysLeft(last, DateTime(2026, 9, 15, 8)), 6);
      expect(WeightLog.canAdd(last, DateTime(2026, 9, 20, 23)), isFalse);
    });

    test('keyingi dushanba ertalab kiritsa bo\'ladi (soatga qaralmaydi)', () {
      final last = WeightLog(monday, 80);
      expect(WeightLog.canAdd(last, DateTime(2026, 9, 21, 7)), isTrue);
      expect(WeightLog.daysLeft(last, DateTime(2026, 9, 21, 7)), 0);
    });
  });

  group('Trenerlar reytingi', () {
    final now = DateTime(2026, 9, 14, 12);
    final trainer = AppUser(id: 't', name: 'Trener', email: '', role: 'admin');

    ClientStat client({
      String id = 'c',
      String? planId = 'p',
      String goal = 'lose',
      int done = 35,
      List<double> weights = const [80, 78],
      List<ChatMessage> messages = const [],
    }) =>
        ClientStat(
          client: AppUser(
              id: id,
              name: id,
              email: '',
              age: 30,
              height: 175,
              weight: 80,
              goal: goal,
              planId: planId,
              trainerId: 't'),
          mealsPerDay: planId == null ? 0 : 5,
          mealsDone: done,
          weights: [
            for (var i = 0; i < weights.length; i++)
              WeightLog(now.subtract(Duration(days: 7 * (weights.length - 1 - i))), weights[i]),
          ],
          messages: messages,
          now: now,
        );

    test("hammasi a'lo bo'lsa 100 ball, 5 yulduz", () {
      final s = TrainerStat(trainer: trainer, clients: [
        client(messages: [ChatMessage('t', 'javob', now), ChatMessage('c', 'savol', now)]),
      ]);
      expect(s.score, 100);
      expect(s.stars, 5);
      expect(s.needAttention, isEmpty);
      expect(s.messagesSent, 1);
    });

    test("reja yo'q, javobsiz chat — ball past va e'tibor kerak", () {
      final bad = client(
        id: 'b',
        planId: null,
        weights: const [80, 81],
        messages: [ChatMessage('b', 'savol', now.subtract(const Duration(days: 2)))],
      );
      final s = TrainerStat(trainer: trainer, clients: [bad]);
      expect(s.score, 0);
      expect(bad.attention, containsAll(["Reja berilmagan", 'Javob kutmoqda: 2 kun']));
    });

    test("massa naborda vazn oshsa — natija yaxshi", () {
      expect(client(goal: 'gain', weights: const [70, 72]).progressing, isTrue);
      expect(client(goal: 'gain', weights: const [72, 70]).progressing, isFalse);
    });

    test("ma'lumoti yo'q qism ballga ta'sir qilmaydi", () {
      // chat yo'q, vazn bir marta — faqat reja (30) va rioya (25) hisoblanadi
      final s = TrainerStat(trainer: trainer, clients: [
        client(done: 0, weights: const [80])
      ]);
      expect(s.replyRate, isNull);
      expect(s.progressRate, isNull);
      expect(s.score, ((1 * 30 + 0 * 25) / 55 * 100).round());
    });

    test("kecha berilgan reja 7 kunga emas, 2 kunga bo'linadi", () {
      final c = ClientStat(
        client: AppUser(
            id: 'n',
            name: 'n',
            email: '',
            planId: 'p',
            trainerId: 't',
            goal: 'gain',
            planAssignedAt: now.subtract(const Duration(days: 1))),
        mealsPerDay: 5,
        mealsDone: 5, // bugun 0, kecha 5 ta mahal
        weights: const [],
        messages: const [],
        now: now,
      );
      expect(c.trackedDays, 2);
      expect(c.adherence, 0.5);
      // berilgan vaqti noma'lum eski hujjat — to'liq 7 kun
      expect(ClientStat.trackedDaysFor(null, now), 7);
      expect(ClientStat.trackedDaysFor(now.subtract(const Duration(days: 30)), now), 7);
    });

    test("shogirdi yo'q trenerga baho qo'yilmaydi", () {
      expect(TrainerStat(trainer: trainer, clients: []).score, isNull);
    });
  });

  group('Telefon raqam bilan kirish', () {
    test("9 xonali raqamga 998 qo'shiladi", () {
      expect(normalizePhone('90 123 45 67'), '998901234567');
    });

    test('+998 va belgilar bilan yozilgan raqam', () {
      expect(normalizePhone('+998 (90) 123-45-67'), '998901234567');
    });

    test("chiroyli ko'rinish", () {
      expect(fmtPhone('998901234567'), '+998 90 123 45 67');
    });
  });

  group('Rollar', () {
    AppUser withRole(String role) => AppUser(id: 'x', name: 'Test', email: '', role: role);

    test('bosh admin trener paneliga kiradi', () {
      final owner = withRole('owner');
      expect(owner.isOwner, isTrue);
      expect(owner.isAdmin, isTrue, reason: 'bosh admin trener panelini ko’radi');
      expect(owner.isTrainer, isFalse, reason: 'u oddiy trener emas');
    });

    test('trener bosh admin emas', () {
      final trainer = withRole('admin');
      expect(trainer.isAdmin, isTrue);
      expect(trainer.isTrainer, isTrue);
      expect(trainer.isOwner, isFalse, reason: 'trener rol tayinlay olmaydi');
    });

    test('oddiy foydalanuvchida panel yo’q', () {
      final user = withRole('user');
      expect(user.isAdmin, isFalse);
      expect(user.isOwner, isFalse);
      expect(user.isTrainer, isFalse);
    });

    test('noma’lum rol foydalanuvchi sifatida qaraladi', () {
      final weird = withRole('superuser');
      expect(weird.isAdmin, isFalse, reason: 'faqat admin/owner panelga kiradi');
      expect(weird.isOwner, isFalse);
    });

    test('trainerId saqlanadi va o’zgartiriladi', () {
      final u = AppUser(id: 'x', name: 'A', email: '', trainerId: 't1');
      expect(u.trainerId, 't1');
      expect(u.toMap()['trainerId'], 't1');
      expect(u.copyWith(trainerId: 't2').trainerId, 't2');
    });
  });

  group("Do'kon", () {
    test('narx probel bilan yoziladi: 450000 -> 450 000', () {
      expect(fmtSum(450000), '450 000');
      expect(fmtSum(1200), '1 200');
      expect(fmtSum(950), '950');
      expect(fmtSum(0), '0');
      expect(fmtSum(12500000), '12 500 000');
    });

    test('sotuvda: faol, qoldig-i va narxi bor tovar', () {
      const p = Product(category: 'Forma', name: 'Mayka', price: 120000, stock: 4);
      expect(p.onSale, isTrue);
      expect(const Product(category: 'Forma', name: 'a', price: 1000, stock: 0).onSale, isFalse,
          reason: 'qoldiq tugagan');
      expect(
          const Product(category: 'Forma', name: 'a', price: 1000, stock: 2, active: false).onSale,
          isFalse,
          reason: 'trener sotuvdan olgan');
      expect(const Product(category: 'Forma', name: 'a', price: 0, stock: 2).onSale, isFalse,
          reason: 'narxi kiritilmagan');
    });

    test('bo-limlar: forma, anjomlar, protein, gainer, kreatin, dobavkalar', () {
      expect(shopCategories.length, 9);
      expect(shopGroups, ['Forma', 'Suv idishlari', 'Anjomlar', 'Dobavkalar']);
      // dobavkalar ichidagi kichik bo'limlar
      for (final c in ['Protein', 'Gainer', 'Kreatin', 'L-Karnitin', 'L-Arginin', 'Boshqa']) {
        expect(shopCategories, contains(c));
        expect(shopGroupOf(c), 'Dobavkalar');
      }
      expect(shopGroupOf('Forma'), 'Forma');
      expect(shopGroupOf('Suv idishlari'), 'Suv idishlari');
      expect(shopGroupOf('Anjomlar'), 'Anjomlar');
    });

    ShopOrder order({int qty = 1, int price = 450000, String status = orderNew, DateTime? at}) =>
        ShopOrder(
          clientId: 'u1',
          productId: 'p1',
          productName: 'Protein 900 g',
          price: price,
          qty: qty,
          status: status,
          createdAt: at,
        );

    test('buyurtma summasi = narx × soni', () {
      expect(order(qty: 3).total, 1350000);
      expect(order(qty: 1).total, 450000);
    });

    test('holat nomlari', () {
      expect(order().statusLabel, 'Kutilmoqda');
      expect(order(status: orderGiven).statusLabel, 'Berildi');
      expect(order(status: orderCanceled).statusLabel, 'Bekor qilindi');
      expect(order(status: orderGiven).isGiven, isTrue);
      expect(order(status: orderCanceled).isNew, isFalse);
    });

    test('chatga tushadigan matnda nomi, soni va summasi bor', () {
      final text = order(qty: 2).chatText;
      expect(text, contains('Protein 900 g'));
      expect(text, contains('2'));
      expect(text, contains('900 000'));
    });

    test('hisobot: faqat BERILGAN buyurtmalar sanaladi', () {
      final now = DateTime(2026, 9, 16);
      final r = SalesReport.of([
        order(status: orderGiven, at: now.subtract(const Duration(days: 1))),
        order(status: orderGiven, qty: 2, at: now.subtract(const Duration(days: 3))),
        order(at: now), // kutilmoqda — sanalmaydi
        order(status: orderCanceled, at: now), // bekor — sanalmaydi
      ], days: 30, now: now);
      expect(r.count, 2);
      expect(r.sum, 450000 + 900000);
    });

    test('hisobot: davrdan tashqaridagi buyurtma kirmaydi', () {
      final now = DateTime(2026, 9, 16);
      final r = SalesReport.of([
        order(status: orderGiven, at: now.subtract(const Duration(days: 40))),
        order(status: orderGiven, at: now.subtract(const Duration(days: 2))),
      ], days: 30, now: now);
      expect(r.count, 1);
      expect(r.sum, 450000);
    });
  });

  group('Haftalik reja', () {
    Meal meal(String time, double kcal, [double protein = 0]) => Meal(
          time: time,
          title: time,
          items: [MealItem(name: 'x', grams: 100, kcal: kcal, protein: protein)],
        );

    test('haftalik bo-lmagan reja har kuni bir xil', () {
      final p = Plan(title: 'Ozish • A', meals: [meal('08:00', 500), meal('13:00', 700)]);
      expect(p.isWeekly, isFalse);
      expect(p.kcal, 1200);
      expect(p.mealsPerDay, 2);
      for (var d = 1; d <= 7; d++) {
        expect(p.mealsFor(d).length, 2);
        expect(p.kcalFor(d), 1200);
      }
      expect(p.toMap().containsKey('week'), isFalse, reason: 'bo-sh hafta saqlanmaydi');
    });

    test('har kunga alohida menyu', () {
      final p = Plan(
        title: 'Ozish • Hafta',
        meals: [meal('08:00', 1000)],
        week: {
          1: [meal('08:00', 1300)],
          2: [meal('08:00', 700), meal('13:00', 800)],
        },
      );
      expect(p.isWeekly, isTrue);
      expect(p.kcalFor(1), 1300);
      expect(p.kcalFor(2), 1500);
      // menyu berilmagan kun — asosiy menyu
      expect(p.kcalFor(5), 1000);
      expect(p.mealsFor(2).length, 2);
    });

    test('kunlar o-rtachasi ro-yxatda ko-rsatiladi', () {
      final week = {
        for (var d = 1; d <= 7; d++) d: [meal('08:00', d == 1 ? 1700 : 1400)]
      };
      final p = Plan(title: 'Ozish • Hafta', meals: week[1]!, week: week);
      expect(p.kcal.round(), ((1700 + 1400 * 6) / 7).round());
      expect(p.mealsPerDay, 1);
    });

    test('saqlashda hafta kunlari matn kalit bilan yoziladi', () {
      final p = Plan(
        title: 'Ozish • Hafta',
        meals: [meal('08:00', 500)],
        week: {
          1: [meal('08:00', 500)],
          7: [meal('09:00', 600)]
        },
      );
      final m = p.toMap();
      final w = m['week'] as Map<String, dynamic>;
      expect(w.keys.toSet(), {'1', '7'});
      expect((w['7'] as List).length, 1);
    });
  });

  group('Zallar', () {
    test('zal nomi, joyi va manzili saqlanadi', () {
      const g = Gym(
        name: 'Kotta Qani zali',
        country: "O'zbekiston",
        region: 'Toshkent shahri',
        district: 'Chilonzor',
        address: 'Bunyodkor 12',
      );
      expect(g.place, 'Chilonzor, Toshkent shahri');
      expect(g.fullAddress, 'Chilonzor, Toshkent shahri · Bunyodkor 12');
      expect(g.toMap()['district'], 'Chilonzor');
    });

    test('joyi tanlanmagan zal ham ishlaydi', () {
      const g = Gym(name: 'Zal');
      expect(g.place, '');
      expect(g.fullAddress, '');
    });

    test('hududlar: viloyatlar va Toshkent tumanlari', () {
      expect(regionNames, contains('Toshkent shahri'));
      expect(regionNames.length, greaterThanOrEqualTo(14));
      expect(districtsOf('Toshkent shahri'), contains('Chilonzor'));
      // har viloyat oxirida qo-lda yozish varianti turadi
      expect(districtsOf('Toshkent shahri').last, otherOption);
      expect(districtsOf('Yo-q viloyat'), [otherOption]);
    });

    test('shogird profilni saqlaganda zal o-zgarmaydi (gymId toMap da yo-q)', () {
      final u = AppUser(id: 'u1', name: 'A', email: '', gymId: 'zal1');
      expect(u.gymId, 'zal1');
      expect(u.toMap().containsKey('gymId'), isFalse, reason: 'zalni faqat bosh admin yozadi');
      expect(u.copyWith(name: 'B').gymId, 'zal1', reason: 'nusxada ham qoladi');
    });

    test('zalsiz trener ham bo-lishi mumkin', () {
      final t = AppUser(id: 't1', name: 'Trener', email: '', role: 'admin');
      expect(t.gymId, isNull);
      expect(t.isTrainer, isTrue);
    });
  });

  group('Bildirishnomalar (Eslatma bo-limi)', () {
    final now = DateTime(2026, 9, 18, 15, 0);

    AppUser student({String? planId, DateTime? assigned}) => AppUser(
          id: 'u1',
          name: 'Shogird',
          email: '',
          age: 30,
          height: 175,
          weight: 80,
          goal: 'lose',
          planId: planId,
          planAssignedAt: assigned,
        );

    test('trener xabari ro-yxatga tushadi, o-zining xabari tushmaydi', () {
      final items = studentFeed(
        user: student(),
        messages: [
          ChatMessage('trener1', 'Salom, bugun kelasizmi?', now.subtract(const Duration(hours: 2))),
          ChatMessage('u1', 'Ha, kelaman', now.subtract(const Duration(hours: 1))),
        ],
        weights: [WeightLog(now.subtract(const Duration(days: 1)), 80)],
        now: now,
      );
      final chat = items.where((i) => i.kind == FeedKind.chat).toList();
      expect(chat, hasLength(1));
      expect(chat.first.body, 'Salom, bugun kelasizmi?');
    });

    test('vazn muddati kelganda amal talab qiladigan eslatma chiqadi', () {
      final items = studentFeed(
        user: student(),
        messages: const [],
        weights: [WeightLog(now.subtract(const Duration(days: 8)), 80)],
        now: now,
      );
      final w = items.where((i) => i.kind == FeedKind.weighIn).toList();
      expect(w, hasLength(1));
      expect(w.first.action, isTrue);
    });

    test('vazn yaqinda kiritilgan bo-lsa eslatma yo-q', () {
      final items = studentFeed(
        user: student(),
        messages: const [],
        weights: [WeightLog(now.subtract(const Duration(days: 2)), 80)],
        now: now,
      );
      expect(items.where((i) => i.kind == FeedKind.weighIn), isEmpty);
    });

    test('vaqti o-tgan va belgilanmagan mahal eslatma beradi', () {
      final plan = Plan(title: 'Ozish • A', meals: [
        Meal(time: '08:00', title: 'Nonushta', items: [
          MealItem(name: 'Tuxum', grams: 100, kcal: 155, protein: 13),
        ]),
        Meal(time: '20:00', title: 'Kechki', items: []),
      ]);
      final items = studentFeed(
        user: student(planId: 'p1', assigned: now.subtract(const Duration(days: 3))),
        messages: const [],
        plan: plan,
        weights: [WeightLog(now.subtract(const Duration(days: 1)), 80)],
        now: now,
      );
      final meals = items.where((i) => i.kind == FeedKind.meal).toList();
      // 08:00 o-tgan (belgilanmagan), 20:00 hali kelmagan
      expect(meals, hasLength(1));
      expect(meals.first.title, contains('Nonushta'));
    });

    test('belgilangan mahal eslatma bermaydi', () {
      final plan = Plan(title: 'Ozish • A', meals: [
        Meal(time: '08:00', title: 'Nonushta', items: []),
      ]);
      final items = studentFeed(
        user: student(planId: 'p1', assigned: now),
        messages: const [],
        plan: plan,
        doneMeals: {0},
        weights: [WeightLog(now.subtract(const Duration(days: 1)), 80)],
        now: now,
      );
      expect(items.where((i) => i.kind == FeedKind.meal), isEmpty);
    });

    test('trenerda: shogird xabari, yangi buyurtma va rejasiz shogird', () {
      final trainer = AppUser(id: 't1', name: 'Trener', email: '', role: 'admin');
      final items = trainerFeed(
        trainer: trainer,
        clients: [
          AppUser(id: 'c1', name: 'Aziz', email: '', gymDays: const [1, 3, 5]),
          AppUser(id: 'c2', name: 'Jasur', email: '', planId: 'p1', gymDays: const [2, 4, 6]),
        ],
        messages: {
          'c1': [
            ChatMessage('c1', 'Bugun kelolmayman', now.subtract(const Duration(minutes: 10))),
            ChatMessage('t1', 'Mayli', now.subtract(const Duration(minutes: 5))),
          ],
        },
        orders: [
          ShopOrder(
            clientId: 'c1',
            clientName: 'Aziz',
            productId: 'p',
            productName: 'Protein',
            price: 450000,
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
        now: now,
      );
      // shogirdning xabari bor, trenerning o-zi yozgani yo-q
      expect(items.where((i) => i.kind == FeedKind.chat), hasLength(1));
      // yangi buyurtma amal talab qiladi
      final order = items.firstWhere((i) => i.kind == FeedKind.order);
      expect(order.action, isTrue);
      // faqat rejasiz shogird (Aziz) uchun eslatma
      final noPlan = items.where((i) => i.kind == FeedKind.attention).toList();
      expect(noPlan, hasLength(1));
      expect(noPlan.first.body, contains('Aziz'));
    });

    test('yangi (ko-rilmagan) soni sanaladi', () {
      final items = [
        FeedItem(kind: FeedKind.chat, title: 'a', body: 'b', at: now),
        FeedItem(
            kind: FeedKind.chat, title: 'a', body: 'b', at: now.subtract(const Duration(hours: 5))),
      ];
      expect(unreadCount(items, null), 2, reason: 'hech qachon ochilmagan');
      expect(unreadCount(items, now.subtract(const Duration(hours: 1))), 1);
      expect(unreadCount(items, now.add(const Duration(minutes: 1))), 0);
    });

    test('vaqt yozuvi: hozir, bugun, kecha', () {
      expect(feedTime(now, now), 'Hozir');
      expect(feedTime(now.subtract(const Duration(minutes: 20)), now), '20 daqiqa oldin');
      expect(feedTime(DateTime(2026, 9, 18, 8, 5), now), 'Bugun 08:05');
      expect(feedTime(DateTime(2026, 9, 17, 8, 5), now), 'Kecha 08:05');
    });
  });

  group('Barmen va sotuv hisoboti', () {
    final now = DateTime(2026, 9, 18, 18, 0);

    ShopOrder order({
      required String product,
      int price = 100000,
      int qty = 1,
      String status = orderGiven,
      String givenBy = 'b1',
      int daysAgo = 0,
      String client = 'Aziz',
    }) =>
        ShopOrder(
          clientId: 'c1',
          clientName: client,
          productId: 'p',
          productName: product,
          price: price,
          qty: qty,
          status: status,
          givenBy: givenBy,
          givenAt: now.subtract(Duration(days: daysAgo)),
          createdAt: now.subtract(Duration(days: daysAgo)),
        );

    test('barmen roli: faqat do-kon xodimi', () {
      final b = AppUser(id: 'b1', name: 'Sardor', email: '', role: 'barmen');
      expect(b.isBarmen, isTrue);
      expect(b.isStaff, isTrue, reason: 'Xodimlar ro-yxatida chiqadi');
      expect(b.isAdmin, isFalse, reason: 'trener paneliga kirmaydi');
      expect(b.isTrainer, isFalse);
      expect(b.isOwner, isFalse);
    });

    test('sotuvchi kesimida hisobot', () {
      final orders = [
        order(product: 'Protein', price: 450000, givenBy: 'b1'),
        order(product: 'Mayka', price: 120000, givenBy: 'b1'),
        order(product: 'Protein', price: 450000, givenBy: 't1'),
        order(product: 'Kreatin', price: 90000, status: orderNew, givenBy: ''),
      ];
      final sellers = SalesReport.bySeller(orders, days: 30, now: now);
      expect(sellers['b1']!.count, 2);
      expect(sellers['b1']!.sum, 570000);
      expect(sellers['t1']!.count, 1);
      expect(sellers.containsKey(''), isFalse, reason: 'berilmagan buyurtma sanalmaydi');
    });

    test('tovar kesimida hisobot: dona soni qo-shiladi', () {
      final orders = [
        order(product: 'Protein', price: 450000, qty: 2),
        order(product: 'Protein', price: 450000, qty: 1),
        order(product: 'Mayka', price: 120000, qty: 1),
      ];
      final byProduct = SalesReport.byProduct(orders, days: 30, now: now);
      expect(byProduct['Protein']!.count, 3, reason: '2 + 1 dona');
      expect(byProduct['Protein']!.sum, 450000 * 2 + 450000);
      expect(byProduct['Mayka']!.count, 1);
    });

    test('davr: 7 kundan eskisi kirmaydi', () {
      final orders = [
        order(product: 'Protein', daysAgo: 2),
        order(product: 'Mayka', daysAgo: 10),
      ];
      expect(SalesReport.of(orders, days: 7, now: now).count, 1);
      expect(SalesReport.of(orders, days: 0, now: now).count, 2, reason: 'hamma vaqt');
    });

    test('berilgan vaqt yo-q bo-lsa buyurtma vaqti olinadi', () {
      final o = ShopOrder(
        clientId: 'c1',
        productId: 'p',
        productName: 'Protein',
        price: 1000,
        status: orderGiven,
        createdAt: now.subtract(const Duration(days: 3)),
      );
      expect(SalesReport.soldAt(o), now.subtract(const Duration(days: 3)));
      expect(SalesReport.of([o], days: 7, now: now).count, 1);
    });

    test('barmen eslatmasi: yangi buyurtma amal talab qiladi', () {
      final items = barmenFeed(orders: [
        order(product: 'Protein', status: orderNew, givenBy: ''),
        order(product: 'Mayka', daysAgo: 1),
      ]);
      expect(items, hasLength(2));
      final yangi = items.firstWhere((i) => i.title == 'Yangi buyurtma');
      expect(yangi.action, isTrue);
      expect(yangi.body, contains('Aziz'));
    });
  });

  group("Tovar rasmlari va o-lchamlari", () {
    test('galereya: asosiy rasm birinchi, takror yo-q', () {
      const p = Product(
        category: 'Forma',
        name: 'Venum',
        image: 'a.jpg',
        images: ['b.jpg', 'a.jpg', '  ', 'c.jpg'],
      );
      expect(p.gallery, ['a.jpg', 'b.jpg', 'c.jpg']);
    });

    test('rasmsiz tovarda galereya bo-sh', () {
      const p = Product(category: 'Forma', name: 'X');
      expect(p.gallery, isEmpty);
    });

    test('o-lchamlar saqlanadi', () {
      const p = Product(
        category: 'Forma',
        name: 'Venum',
        sizes: ['XL', 'XXL', '3XL', '4XL'],
      );
      expect(p.toMap()['sizes'], ['XL', 'XXL', '3XL', '4XL']);
      expect(p.copyWith(stock: 2).sizes, hasLength(4));
    });

    test('buyurtma nomi o-lcham bilan chiqadi', () {
      const o = ShopOrder(
        clientId: 'c',
        productId: 'p',
        productName: 'Venum komplekt',
        size: 'XL',
        price: 450000,
        qty: 2,
      );
      expect(o.title, 'Venum komplekt (XL)');
      expect(o.chatText,
          contains('Venum komplekt (XL) x 2'.replaceAll('x', String.fromCharCode(215))));
    });

    test('o-lchamsiz tovarda nom o-zgarmaydi', () {
      const o = ShopOrder(
        clientId: 'c',
        productId: 'p',
        productName: 'Protein',
        price: 450000,
      );
      expect(o.title, 'Protein');
    });

    test('o-lcham bo-yicha qoldiq: bor tovarda sizeStock yig-indisi', () {
      const p = Product(
        category: 'Forma',
        name: 'Venum',
        price: 450000,
        sizes: ['XL', 'XXL'],
        sizeStock: {'XL': 3, 'XXL': 0},
      );
      expect(p.totalStock, 3);
      expect(p.stockFor('XL'), 3);
      expect(p.stockFor('XXL'), 0);
      expect(p.stockFor(null), 0);
      expect(p.onSale, isTrue);
    });

    test('o-lchamsiz tovarda stockFor flat stock-ni qaytaradi', () {
      const p = Product(category: 'Dobavkalar', name: 'Protein', stock: 5);
      expect(p.totalStock, 5);
      expect(p.stockFor(null), 5);
      expect(p.stockFor('XL'), 5);
    });

    test('tan narx kiritilmagan bo-lsa foyda 0', () {
      const p = Product(category: 'Forma', name: 'Venum', price: 500000);
      expect(p.margin, 0);
    });

    test('tan narx bilan foyda hisoblanadi', () {
      const p = Product(category: 'Forma', name: 'Venum', price: 500000, costPrice: 350000);
      expect(p.margin, 150000);
    });
  });

  group('Abonement', () {
    test('tugash sanasi oy qo-shib hisoblanadi', () {
      expect(Subscription.expiryOf(DateTime(2026, 1, 15), 3), DateTime(2026, 4, 15));
    });

    test('kunlik: faqat shu kuni amal qiladi', () {
      final s = Subscription(startDate: DateTime(2026, 10, 5, 14), months: 0, days: 1);
      expect(s.expiresAt, DateTime(2026, 10, 5));
      expect(s.kindLabel, 'Kunlik');
      expect(Subscription.isActive(s.expiresAt, DateTime(2026, 10, 5, 23)), isTrue);
      expect(Subscription.isActive(s.expiresAt, DateTime(2026, 10, 6, 1)), isFalse);
    });

    test('eski yozuv (days yo-q) oy bo-yicha hisoblanadi', () {
      final s = Subscription(startDate: DateTime(2026, 10, 3), months: 1);
      expect(s.isDaily, isFalse);
      expect(s.expiresAt, DateTime(2026, 11, 3));
      expect(s.kindLabel, 'Oylik');
    });

    test('to-lov ko-zgusi: tur va sana yorlig-i', () {
      const m = Membership(uid: 'u1', name: 'Ali', gymId: 'zal1', days: 1, price: 50000);
      expect(m.kindLabel, 'Kunlik');
      expect(const Membership(uid: 'u2', months: 3).kindLabel, '3 oy');
      expect(fmtDay(DateTime(2026, 10, 3)), '03.10.2026');
      expect(fmtDay(null), '');
    });

    test('belgilangan narx', () {
      expect(Subscription.priceOf(days: 1), 50000);
      expect(Subscription.priceOf(months: 1), 500000);
      expect(Subscription.priceOf(months: 3), 1500000);
    });

    test('qolgan kun va holat', () {
      final exp = DateTime(2026, 10, 10);
      final now = DateTime(2026, 10, 8);
      expect(Subscription.daysLeft(exp, now), 2);
      expect(Subscription.isActive(exp, now), isTrue);
      expect(Subscription.isExpiringSoon(exp, now), isTrue);
      expect(Subscription.isExpired(exp, now), isFalse);
    });

    test('muddati o-tgan abonement', () {
      final exp = DateTime(2026, 10, 1);
      final now = DateTime(2026, 10, 8);
      expect(Subscription.daysLeft(exp, now), -7);
      expect(Subscription.isActive(exp, now), isFalse);
      expect(Subscription.isExpiringSoon(exp, now), isFalse);
      expect(Subscription.isExpired(exp, now), isTrue);
    });

    test('maydon yo-q bo-lsa amal qilmaydi deb hisoblanadi', () {
      expect(Subscription.isActive(null), isFalse);
      expect(Subscription.isExpiringSoon(null), isFalse);
      expect(Subscription.isExpired(null), isFalse);
    });
  });

  group('Eslatma hisoboti', () {
    test('kuni nechta eslatma jo-natilgani sanaladi', () {
      final now = DateTime(2026, 10, 4, 18);
      final list = [
        Reminder(clientId: 'a', sentBy: 't', daysLeft: 2, sentAt: DateTime(2026, 10, 4, 9)),
        Reminder(clientId: 'b', sentBy: 't', daysLeft: 1, sentAt: DateTime(2026, 10, 4, 10)),
        Reminder(clientId: 'c', sentBy: 't', daysLeft: 0, sentAt: DateTime(2026, 10, 2, 9)),
      ];
      final byDay = ReminderReport.byDay(list, days: 7, now: now);
      expect(byDay.length, 7);
      expect(byDay['2026-10-04'], 2);
      expect(byDay['2026-10-02'], 1);
      expect(byDay['2026-10-03'], 0);
    });

    test('bo-sh ro-yxatda hamma kun 0', () {
      final byDay = ReminderReport.byDay(const [], days: 3, now: DateTime(2026, 10, 4));
      expect(byDay.values.every((v) => v == 0), isTrue);
      expect(byDay.length, 3);
    });
  });

  group('Oylik hisobot', () {
    final oct = DateTime(2026, 10);
    ShopOrder given(String pid, int price, int qty, DateTime at, [String cur = 'UZS']) => ShopOrder(
        clientId: 'c',
        productId: pid,
        productName: pid,
        price: price,
        qty: qty,
        currency: cur,
        status: orderGiven,
        givenAt: at);

    test('oy chegarasi: 31-kun 23:59 kiradi, keyingi oyning 1-kuni kirmaydi', () {
      expect(MonthlyReport.inMonth(DateTime(2026, 10, 31, 23, 59), oct), isTrue);
      expect(MonthlyReport.inMonth(DateTime(2026, 11, 1), oct), isFalse);
      expect(MonthlyReport.inMonth(DateTime(2026, 10, 1), oct), isTrue);
      expect(MonthlyReport.inMonth(DateTime(2026, 9, 30, 23, 59), oct), isFalse);
    });

    test('bo-sh oy', () {
      final r = MonthlyReport.build(oct);
      expect(r.subsCount, 0);
      expect(r.ordersCount, 0);
      expect(MonthlyReport.money(r.income), fmtMoney(0));
    });

    test('abonement to-langan sanasi bo-yicha', () {
      final r = MonthlyReport.build(oct, subs: [
        Subscription(
            startDate: DateTime(2026, 9, 20),
            months: 1,
            price: 300000,
            paidDate: DateTime(2026, 10, 2)),
        Subscription(
            startDate: DateTime(2026, 10, 5),
            months: 3,
            price: 800000,
            paidDate: DateTime(2026, 9, 30)),
      ]);
      expect(r.subsCount, 1);
      expect(r.subsSums['UZS'], 300000);
    });

    test('aralash valyuta, foyda va tan narxsiz buyurtma', () {
      final products = {
        'prot':
            const Product(id: 'prot', category: 'Protein', name: 'P', price: 115, costPrice: 100),
        'venum': const Product(
            id: 'venum', category: 'Forma', name: 'V', price: 40, costPrice: 35, currency: 'USD'),
        'eski': const Product(id: 'eski', category: 'Forma', name: 'E', price: 10),
      };
      final r = MonthlyReport.build(oct, products: products, orders: [
        given('prot', 115, 2, DateTime(2026, 10, 3)),
        given('venum', 40, 1, DateTime(2026, 10, 4), 'USD'),
        given('eski', 10, 1, DateTime(2026, 10, 5)),
        given('prot', 115, 1, DateTime(2026, 11, 1)), // keyingi oy
        const ShopOrder(
            clientId: 'c', productId: 'prot', productName: 'P', price: 115), // berilmagan
      ], subs: [
        Subscription(
            startDate: DateTime(2026, 10, 1),
            months: 1,
            price: 300,
            paidDate: DateTime(2026, 10, 1)),
      ]);
      expect(r.ordersCount, 3);
      expect(r.shopSums, {'UZS': 240, 'USD': 40});
      expect(r.profit, {'UZS': 30, 'USD': 5});
      expect(r.noCostOrders, 1);
      expect(r.income, {'UZS': 540, 'USD': 40});
    });
  });

  group('Trener haqi', () {
    final oct = DateTime(2026, 10);
    Subscription sub(int price, DateTime paid, [String cur = 'UZS']) =>
        Subscription(startDate: paid, months: 1, price: price, currency: cur, paidDate: paid);

    test('trenerlar bo-yicha yig-iladi, boshqa oy kirmaydi', () {
      final r = MonthlyReport.byTrainer(oct, clientTrainer: {
        'a': 't1',
        'b': 't1',
        'c': 't2',
        'd': '',
      }, subs: [
        ('a', sub(300000, DateTime(2026, 10, 2))),
        ('b', sub(200000, DateTime(2026, 10, 9))),
        ('c', sub(50, DateTime(2026, 10, 3), 'USD')),
        ('a', sub(300000, DateTime(2026, 9, 2))), // o'tgan oy
        ('d', sub(100000, DateTime(2026, 10, 5))), // trenersiz
      ]);
      expect(r['t1']!.clients, 2);
      expect(r['t1']!.subsCount, 2);
      expect(r['t1']!.sums, {'UZS': 500000});
      expect(r['t1']!.share(40), {'UZS': 200000});
      expect(r['t2']!.share(50), {'USD': 25});
      expect(r['']!.subsCount, 1);
    });

    test('abonement sotmagan trener ham ro-yxatda, ulushi bo-sh', () {
      final r = MonthlyReport.byTrainer(oct, clientTrainer: {'a': 't1'});
      expect(r['t1']!.clients, 1);
      expect(r['t1']!.subsCount, 0);
      expect(r['t1']!.share(40), isEmpty);
    });
  });

  group('Rang tanlash', () {
    test('nomda o-lcham va rang chiqadi', () {
      const o = ShopOrder(
          clientId: 'c',
          productId: 'p',
          productName: 'Venum',
          price: 1,
          size: 'XL',
          color: 'sariq');
      expect(o.title, 'Venum (XL, sariq)');
    });
    test('faqat rang', () {
      const o =
          ShopOrder(clientId: 'c', productId: 'p', productName: 'Shaker', price: 1, color: 'qora');
      expect(o.title, 'Shaker (qora)');
    });
    test('rangsiz va o-lchamsiz nom o-zgarmaydi', () {
      const o = ShopOrder(clientId: 'c', productId: 'p', productName: 'Protein', price: 1);
      expect(o.title, 'Protein');
    });
    test('tovar ranglari saqlanadi', () {
      const p = Product(category: 'Forma', name: 'X', colors: ['sariq', 'yashil']);
      expect(p.toMap()['colors'], ['sariq', 'yashil']);
      expect(p.copyWith(stock: 2).colors, ['sariq', 'yashil']);
    });
  });

  group('Barmen - o-z zali', () {
    test('trener katalogi zal ko-zgusini yozadi', () {
      const t = TrainerInfo('t1', 'Ali', gymId: 'zal1');
      expect(t.toMap()['gymId'], 'zal1');
      expect(const TrainerInfo('t2', 'Vali').toMap()['gymId'], '');
    });

    test('buyurtmada zal bo-lmasa bo-sh qator', () {
      const o = ShopOrder(clientId: 'c', productId: 'p', productName: 'X', price: 1);
      expect(o.gymId, '');
      const g = ShopOrder(clientId: 'c', productId: 'p', productName: 'X', price: 1, gymId: 'zal1');
      expect(g.gymId, 'zal1');
    });
  });

  group('Dangasa bo-limlar', () {
    testWidgets('bo-lim faqat birinchi tanlanganda quriladi va keyin saqlanadi', (t) async {
      final built = <String>[];
      Widget tab(String name) => Builder(builder: (_) {
            built.add(name);
            return Text(name, textDirection: TextDirection.ltr);
          });
      Widget app(int i) => Directionality(
            textDirection: TextDirection.ltr,
            child: LazyIndexedStack(index: i, children: [tab('a'), tab('b'), tab('c')]),
          );
      await t.pumpWidget(app(0));
      expect(built, ['a']);
      await t.pumpWidget(app(2));
      expect(built.contains('c'), isTrue);
      expect(built.contains('b'), isFalse);
      // 'a' daraxtda qoladi (holati saqlanadi), 'b' hali qurilmagan
      expect(find.text('a', skipOffstage: false), findsOneWidget);
      expect(find.text('b', skipOffstage: false), findsNothing);
    });
  });

  group('Tillar', () {
    tearDown(() => appLang.value = 'uz');

    test('tr: uch til va tarjimasi yo-q matn', () {
      expect(tr('Kirish'), 'Kirish');
      appLang.value = 'ru';
      expect(tr('Kirish'), 'Войти');
      expect(tr('Lug-atda yo-q matn'), 'Lug-atda yo-q matn');
      appLang.value = 'en';
      expect(tr('Kirish'), 'Sign in');
    });

    test('trf: o-rinbosarlar va so-z tartibi', () {
      expect(trf('{0} kkal', [2000]), '2000 kkal');
      appLang.value = 'ru';
      expect(trf('{0} kkal', [2000]), '2000 ккал');
      appLang.value = 'en';
      expect(trf('gacha {0}', [5]), 'of 5');
    });

    test('chatdagi tizim xabari tarjima bo-ladi, odam yozgani - yo-q', () {
      const order = "🛒 Buyurtma: Venum (XL) × 2 — 450 000 so'm";
      expect(trChat(order), order);
      appLang.value = 'ru';
      expect(trChat(order), '🛒 Заказ: Venum (XL) × 2 — 450 000 сум');
      expect(trChat('⏰ Abonementingiz 3 kundan keyin tugaydi'),
          '⏰ Ваш абонемент закончится через 3 дн.');
      expect(trChat('Bugun kelolmayman'), 'Bugun kelolmayman');
    });

    test('tovar nomi tilga qarab, tarjimasi yo-q bo-lsa o-zbekcha', () {
      const p = Product(
          category: 'Forma',
          name: 'Mayka (kulrang)',
          note: 'Yengsiz',
          nameRu: 'Майка (серая)',
          noteEn: 'Sleeveless');
      expect(p.displayName, 'Mayka (kulrang)');
      appLang.value = 'ru';
      expect(p.displayName, 'Майка (серая)');
      expect(p.displayNote, 'Yengsiz'); // ruscha izoh yo-q
      appLang.value = 'en';
      expect(p.displayName, 'Mayka (kulrang)'); // inglizcha nom yo-q
      expect(p.displayNote, 'Sleeveless');
      expect(p.toMap()['nameRu'], 'Майка (серая)');
      expect(p.toMap().containsKey('nameEn'), isFalse);
    });

    test('sana tilga qarab yoziladi', () {
      final d = DateTime(2026, 10, 5); // dushanba
      expect(uzDate(d), 'Dushanba, 5-oktyabr');
      appLang.value = 'ru';
      expect(uzDate(d), 'Понедельник, 5 октября');
      appLang.value = 'en';
      expect(uzDate(d), 'Monday, October 5');
    });
  });

  group('Rejadan tashqari yedim', () {
    test('kaloriya va oqsil grammga qarab hisoblanadi', () {
      final osh = Food(name: 'Osh', kcal: 180, protein: 6.5, fat: 8, carbs: 20);
      final e = ExtraFood.of(osh, 250, now: DateTime.fromMillisecondsSinceEpoch(1000));
      expect(e.kcal, 450);
      expect(e.protein, 16.3);
      expect(e.grams, 250);
      expect(e.at, 1000);
    });

    test('yozuv bazaga borib qaytganda o-zgarmaydi; jami', () {
      const a = ExtraFood(name: 'Osh', grams: 250, kcal: 450, protein: 16.3, at: 1);
      const b = ExtraFood(name: 'Non', grams: 50, kcal: 130, protein: 4, at: 2);
      final back = ExtraFood.fromMap(a.toMap());
      expect(back.name, 'Osh');
      expect(back.kcal, 450);
      expect(back.at, 1);
      expect(ExtraFood.totalKcal([a, b]), 580);
      expect(ExtraFood.totalKcal(const []), 0);
    });
  });

  group('Tana xaritasi', () {
    test('har mushak guruhi shaklda bor va kamida 3 ta mashqi bor', () {
      final drawn = {...BodyMap.musclesOn(back: false), ...BodyMap.musclesOn(back: true)};
      for (final m in muscles) {
        expect(drawn.contains(m.id), isTrue, reason: '${m.id} shaklda yo-q');
        expect(exercisesFor(m.id).length, greaterThanOrEqualTo(3), reason: m.id);
      }
    });

    test('mashqlardagi mushak id-lari to-g-ri', () {
      final ids = {for (final m in muscles) m.id};
      for (final e in exercises) {
        expect(ids.contains(e.muscle), isTrue, reason: e.name);
        expect(e.also.every(ids.contains), isTrue, reason: e.name);
      }
    });

    test('bosilgan nuqta mushakni topadi', () {
      expect(BodyMap.hit(back: false, x: 76, y: 108), 'chest');
      expect(BodyMap.hit(back: false, x: 52, y: 126), 'biceps');
      expect(BodyMap.hit(back: true, x: 50, y: 102), 'triceps');
      expect(BodyMap.hit(back: false, x: 66, y: 140), 'abs');
      expect(BodyMap.hit(back: true, x: 86, y: 202), 'glutes');
      expect(BodyMap.hit(back: false, x: 5, y: 5), isNull);
    });
  });

  group('Tana xaritasi — haftalik reja', () {
    test('har mashg-ulot mushaklari to-g-ri va hamma mushak rejada bor', () {
      final ids = {for (final m in muscles) m.id};
      expect(workoutMuscles.length, workoutGroups.length);
      final planned = {for (final w in workoutMuscles) ...w};
      expect(planned, ids, reason: 'har mushak guruhi qaysidir kunda bo-lishi kerak');
      expect(workoutMuscles.expand((w) => w).length, planned.length, reason: 'takror yo-q');
    });

    test('kun bo-yicha mushaklar', () {
      expect(musclesFor(evenDays, DateTime.tuesday), contains('chest'));
      expect(musclesFor(evenDays, DateTime.thursday), contains('quads'));
      expect(musclesFor(evenDays, DateTime.saturday), contains('triceps'));
      expect(musclesFor(evenDays, DateTime.monday), isEmpty, reason: 'dam olish kuni');
      expect(musclesFor(const [], DateTime.tuesday), isEmpty, reason: 'kunlar tanlanmagan');
      expect(weekdayOfMuscle(evenDays, 'back'), DateTime.thursday);
      expect(weekdayOfMuscle(oddDays, 'shoulders'), DateTime.friday);
      expect(weekdayOfMuscle(const [], 'back'), isNull);
    });

    Future<void> open(WidgetTester t,
        {required List<int> days, required int weekday, bool home = false}) async {
      t.view.physicalSize = const Size(420, 6000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        home: MusclesScreen(gymDays: days, weekday: weekday, homeToday: home, onBack: () {}),
      ));
      await t.pump(const Duration(seconds: 3));
    }

    testWidgets('zal kuni — faqat bugungi mushaklar mashqlari', (t) async {
      await open(t, days: evenDays, weekday: DateTime.tuesday);
      expect(find.text('BUGUNGI MASHQLAR'), findsOneWidget);
      expect(find.text('Shtanga bilan yotib siqish'), findsOneWidget, reason: 'ko-krak — bugun');
      expect(find.text(exercisesFor('quads').first.name), findsNothing,
          reason: 'oyoq — boshqa kun');
    });

    testWidgets('mashg-ulotdan tashqari mushak ro-yxatda yo-q, bugungisi tanlanadi', (t) async {
      await open(t, days: evenDays, weekday: DateTime.tuesday);
      expect(find.text(muscleById('quads')!.name), findsNothing, reason: 'oyoq — boshqa kun');
      expect(find.text(muscleById('shoulders')!.name), findsNothing);
      // bugungi mushak tanlansa — faqat o'shaning mashqlari qoladi
      await t.tap(find.text(muscleById('biceps')!.name));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(exercisesFor('biceps').first.name), findsOneWidget);
      expect(find.text('Shtanga bilan yotib siqish'), findsNothing, reason: 'ko-krak tanlanmagan');
    });

    testWidgets('dam olish kuni — keyingi mashg-ulot ko-rsatiladi', (t) async {
      await open(t, days: evenDays, weekday: DateTime.monday);
      expect(find.text("Mashg'ulotni boshlash"), findsNothing,
          reason: 'dam olish kunida boshlab bo-lmaydi');
      expect(find.text('Dam olish kuni'), findsOneWidget);
      expect(find.text("KEYINGI MASHG'ULOT MASHQLARI"), findsOneWidget);
    });

    testWidgets('kunlar tanlanmagan — hamma mushak ochiq', (t) async {
      await open(t, days: const [], weekday: DateTime.tuesday);
      expect(find.text('Zal kunlari tanlanmagan'), findsOneWidget);
      await t.tap(find.text(muscleById('quads')!.name));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(exercisesFor('quads').first.name), findsOneWidget);
    });
  });

  group('Trener mashq qo-shadi', () {
    final now = DateTime(2026, 10, 12, 12);
    Exercise custom({String muscle = 'chest', DateTime? at, String name = 'Trener mashqi'}) =>
        Exercise(name, muscle, '5 × 5', 'Sekin tushiring',
            also: const ['triceps'],
            id: 'e1',
            video: 'https://example.com/v',
            createdAt: at ?? now,
            createdBy: 't1');

    test('bazaga yozilib qaytganda o-zgarmaydi', () {
      final e = Exercise.fromMap('e1', custom().toMap())!;
      expect([
        e.id,
        e.name,
        e.muscle,
        e.sets,
        e.tip,
        e.video,
        e.createdBy
      ], [
        'e1',
        'Trener mashqi',
        'chest',
        '5 × 5',
        'Sekin tushiring',
        'https://example.com/v',
        't1'
      ]);
      expect(e.also, ['triceps']);
      expect(e.createdAt, now);
      expect(e.isCustom, isTrue);
      expect(exercises.first.isCustom, isFalse, reason: 'namunaviy mashq');
    });

    test('daraja bazaga yozilib qaytadi; noma-lum daraja — belgisiz', () {
      final e =
          Exercise('D', 'chest', '', '', id: 'd1', createdAt: now, createdBy: 't1', level: 'pro');
      expect(Exercise.fromMap('d1', e.toMap())!.level, 'pro');
      expect(Exercise.fromMap('d1', {...e.toMap(), 'level': 'chempion'})!.level, '');
      expect(Exercise.fromMap('d1', {'name': 'D', 'muscle': 'chest'})!.level, '',
          reason: 'eski yozuv');
      expect(exercises.every((x) => x.level.isEmpty), isTrue, reason: 'namunaviylar belgisiz');
      expect(levels.keys, ['beginner', 'middle', 'pro']);
    });

    test('noto-g-ri yozuv ro-yxatga tushmaydi', () {
      expect(Exercise.fromMap('x', {'name': 'A', 'muscle': 'bosh'}), isNull,
          reason: 'bunday mushak yo-q');
      expect(Exercise.fromMap('x', {'name': '  ', 'muscle': 'chest'}), isNull, reason: 'nom bo-sh');
      final e = Exercise.fromMap('x', {
        'name': 'A',
        'muscle': 'chest',
        'also': ['chest', 'qosh', 'abs']
      })!;
      expect(e.also, ['abs'], reason: 'asosiy mushak va noma-lum id olib tashlanadi');
    });

    test('yangi belgisi 7 kun turadi', () {
      expect(custom().isNew(now.add(const Duration(days: 6))), isTrue);
      expect(custom().isNew(now.add(const Duration(days: 8))), isFalse);
      expect(exercises.first.isNew(now), isFalse, reason: 'namunaviy — hech qachon yangi emas');
    });

    test('mushak mashqlari: trener qo-shgani tepada, namunaviylar joyida', () {
      final old = custom(at: now.subtract(const Duration(days: 30)), name: 'Eski');
      final list = exercisesFor('chest', [old, custom(), custom(muscle: 'abs', name: 'Boshqa')]);
      expect(list.map((e) => e.name).take(2), ['Trener mashqi', 'Eski']);
      expect(list.length, exercisesFor('chest').length + 2);
      expect(list.any((e) => e.name == 'Boshqa'), isFalse);
    });

    test('takror nom topiladi (harf, tutuq belgisi, bo-shliq farq qilmaydi)', () {
      expect(sameExercise('  shtanga  BILAN yotib siqish ', const [])?.muscle, 'chest');
      expect(sameExercise("Gantelni yonga ko‘tarish", const [])?.muscle, 'shoulders');
      expect(sameExercise('Trener mashqi', [custom()])?.id, 'e1');
      expect(sameExercise('Trener mashqi', [custom()], exceptId: 'e1'), isNull,
          reason: 'o-zini tahrirlash');
      expect(sameExercise('Butunlay yangi mashq', [custom()]), isNull);
    });

    test('namunaviy mashqqa video: o-rniga chiqadi, kaliti va tartibi saqlanadi', () {
      final first = exercisesFor('chest').first;
      final over = Exercise(first.name, first.muscle, first.sets, first.tip,
          also: first.also,
          id: 'o1',
          video: 'https://example.com/v',
          createdAt: now,
          createdBy: 't1',
          base: first.name);
      final back = Exercise.fromMap('o1', over.toMap())!;
      expect(back.base, first.name);
      expect(back.isOverride, isTrue);
      final list = exercisesFor('chest', [back]);
      expect(list.length, exercisesFor('chest').length, reason: 'qo-shilmaydi — almashtiriladi');
      expect(list.first.video, 'https://example.com/v');
      expect(list.first.key, first.key, reason: 'bajardim belgisi yo-qolmaydi');
      expect(back.isNew(now), isFalse, reason: 'o-zgartirilgan namunaviy — yangi emas');
      // o'zini tahrirlash takror hisoblanmaydi, boshqa mashq nomini olish — hisoblanadi
      expect(sameExercise(first.name, [back], exceptId: 'o1', exceptBase: first.name), isNull);
      expect(sameExercise(first.name, const [], exceptBase: first.name), isNull);
      expect(sameExercise('Otjimaniya', [back], exceptId: 'o1', exceptBase: first.name)?.name,
          'Otjimaniya');
    });

    testWidgets('shogird trener qo-shgan mashqni va video havolasini ko-radi', (t) async {
      t.view.physicalSize = const Size(420, 7000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        home: MusclesScreen(
          gymDays: evenDays,
          weekday: DateTime.tuesday,
          onBack: () {},
          custom: Stream.value([custom(at: DateTime.now())]),
        ),
      ));
      await t.pump(const Duration(seconds: 3));
      expect(find.text('Trener mashqi'), findsOneWidget);
      expect(find.text('YANGI'), findsOneWidget);
      await t.tap(find.text('Trener mashqi'));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('https://example.com/v'), findsOneWidget);
      expect(find.text("Videoni ko'rish"), findsOneWidget);
      expect(find.text('Havolani nusxalash'), findsOneWidget);
    });

    testWidgets('qo-shish varag-i: chizma bosilsa mushak o-zgaradi, nomsiz saqlanmaydi', (t) async {
      t.view.physicalSize = const Size(500, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: ExerciseForm(adminId: 't1', muscle: 'chest')),
      ));
      expect(find.text("Asosiy mushak: Ko'krak"), findsOneWidget);
      expect(find.text("Yordamchi mushaklar: yo'q"), findsOneWidget);
      expect(find.text('Professional'), findsOneWidget, reason: 'daraja tanlash formada bor');
      // old tomon chizmasida qorin (press) bo'lagi bosiladi — asosiy mushak o'zgaradi
      final front = t.getTopLeft(find.byType(BodyMap).first);
      const k = 210 / 440;
      await t.tapAt(front + const Offset(66 * k, 140 * k));
      await t.pump();
      expect(find.text('Asosiy mushak: Qorin (press)'), findsOneWidget);
      // yordamchi rejimida ko'krak bosiladi — yordamchiga qo'shiladi
      await t.tap(find.text('Yordamchi mushaklar'));
      await t.pump();
      await t.tapAt(front + const Offset(76 * k, 108 * k));
      await t.pump();
      expect(find.text("Yordamchi: Ko'krak"), findsOneWidget);
      await t.tap(find.text('Saqlash'));
      await t.pump();
      expect(find.text('Mashq nomini yozing'), findsOneWidget);
      // bor mashq nomi yozilsa — saqlanmaydi, qaysi mushakda borligi aytiladi
      await t.enterText(find.byType(TextField).first, 'otjimaniya');
      await t.tap(find.text('Saqlash'));
      await t.pump();
      expect(find.text("Bunday mashq bor: Otjimaniya — Ko'krak"), findsOneWidget);
    });
  });

  group('Mashg-ulot navbati', () {
    List<String> keys(String m) => [for (final e in exercisesFor(m)) e.key];

    test('navbatdagi mushak: birinchisi tugamaguncha keyingisi ochilmaydi', () {
      const plan = ['shoulders', 'triceps', 'traps'];
      expect(activeMuscle(plan, {}, keys), 'shoulders');
      expect(activeMuscle(plan, {keys('shoulders').first}, keys), 'shoulders',
          reason: 'bittasi bajarildi');
      expect(activeMuscle(plan, {...keys('shoulders')}, keys), 'triceps', reason: 'yelka tugadi');
      // tartibni buzib bo'lmaydi: triceps bajarilgan bo'lsa ham, yelka tugamagan — yelka turadi
      expect(activeMuscle(plan, {...keys('triceps')}, keys), 'shoulders');
      expect(activeMuscle(plan, {for (final m in plan) ...keys(m)}, keys), isNull,
          reason: 'hammasi tugadi');
      expect(activeMuscle(const ['x', 'traps'], {}, (m) => m == 'x' ? [] : keys(m)), 'traps',
          reason: 'mashqi yo-q mushak o-tkazib yuboriladi');
    });

    testWidgets('boshlash → faqat birinchi mushak; hammasi bajarilgach keyingisi ochiladi',
        (t) async {
      t.view.physicalSize = const Size(420, 7000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final marked = <String>[];
      var started = false;
      await t.pumpWidget(MaterialApp(
        home: MusclesScreen(
          gymDays: evenDays,
          weekday: DateTime.tuesday, // ko'krak → biceps → bilak
          onBack: () {},
          onStart: () => started = true,
          onDone: (k, d) => marked.add('$k=$d'),
        ),
      ));
      await t.pump(const Duration(seconds: 3));
      expect(find.text('Bajardim'), findsNothing, reason: 'boshlanmaguncha belgi yo-q');
      await t.tap(find.text("Mashg'ulotni boshlash"));
      await t.pump(const Duration(seconds: 1));
      expect(started, isTrue);
      expect(find.text("Mashg'ulotni boshlash"), findsNothing,
          reason: 'boshlangach tugma yo-qoladi');
      expect(find.text("HOZIR: KO'KRAK"), findsOneWidget);
      expect(find.text('0 / 3 bajarildi'), findsOneWidget);
      expect(find.text("Hozir: Ko'krak · 0 / 3 bajarildi"), findsOneWidget,
          reason: 'tepada ham holat');
      expect(find.text(exercisesFor('biceps').first.name), findsNothing, reason: 'qo-l hali yopiq');
      expect(find.textContaining('Navbatda:'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await t.tap(find.text('Bajardim').first);
        await t.pump(const Duration(seconds: 1));
      }
      expect(marked.length, 3);
      expect(find.text("HOZIR: QO'LNING OLDI (BICEPS)"), findsOneWidget,
          reason: 'ko-krak tugadi — qo-l ochildi');
      expect(find.text("✓ Ko'krak — tugadi"), findsOneWidget);
      expect(find.text('Shtanga bilan yotib siqish'), findsNothing);
      expect(find.text(exercisesFor('biceps').first.name), findsOneWidget);
    });

    testWidgets('bazadan kelgan holat: hammasi bajarilgan — mashg-ulot tugadi', (t) async {
      t.view.physicalSize = const Size(420, 7000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final all = {for (final m in musclesFor(evenDays, DateTime.tuesday)) ...keys(m)};
      await t.pumpWidget(MaterialApp(
        home: MusclesScreen(
          gymDays: evenDays,
          weekday: DateTime.tuesday,
          onBack: () {},
          progress: Stream.value(WorkoutProgress(started: true, done: all)),
        ),
      ));
      await t.pump(const Duration(seconds: 3));
      expect(find.text("Bugungi mashg'ulot tugadi"), findsNWidgets(2),
          reason: 'tepada va mashqlar o-rnida');
      expect(find.text('Bajardim'), findsNothing);
    });
  });

  group('Video havolasi', () {
    test('YouTube id har xil havoladan ajratiladi', () {
      for (final u in [
        'https://youtu.be/dQw4w9WgXcQ',
        'https://youtu.be/dQw4w9WgXcQ?si=abc',
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=10s',
        'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://youtube.com/shorts/dQw4w9WgXcQ',
        'https://www.youtube.com/embed/dQw4w9WgXcQ',
        'https://www.youtube.com/live/dQw4w9WgXcQ?feature=share',
        '  https://youtu.be/dQw4w9WgXcQ  ',
      ]) {
        expect(youtubeId(u), 'dQw4w9WgXcQ', reason: u);
      }
      expect(youtubeThumb('https://youtu.be/dQw4w9WgXcQ'),
          'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
    });

    test('YouTube bo-lmagan yoki buzuq havola — null', () {
      for (final u in [
        '',
        'https://t.me/kanal/123',
        'https://example.com/watch?v=dQw4w9WgXcQ',
        'https://www.youtube.com/watch?v=qisqa',
        'https://www.youtube.com/@kanal',
        'youtu.be/dQw4w9WgXcQ',
      ]) {
        expect(youtubeId(u), isNull, reason: u);
        expect(youtubeThumb(u), isNull, reason: u);
      }
    });

    testWidgets('YouTube havolali mashqda muqova va o-ynatish tugmasi; havola matni yo-q',
        (t) async {
      t.view.physicalSize = const Size(420, 7000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      String? asked;
      debugVideoThumb = (u) {
        asked = u;
        return const SizedBox();
      };
      addTearDown(() => debugVideoThumb = null);
      final e = Exercise('Video mashq', 'chest', '3 × 10', 'Sekin',
          id: 'v1',
          video: 'https://youtu.be/dQw4w9WgXcQ',
          createdAt: DateTime.now(),
          createdBy: 't1');
      await t.pumpWidget(MaterialApp(
        home: MusclesScreen(
            gymDays: evenDays, weekday: DateTime.tuesday, onBack: () {}, custom: Stream.value([e])),
      ));
      await t.pump(const Duration(seconds: 3));
      await t.tap(find.text('Video mashq'));
      await t.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(asked, 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
          reason: 'muqova so-raldi');
      expect(find.text('https://youtu.be/dQw4w9WgXcQ'), findsNothing,
          reason: 'havola matni emas — muqova');
      expect(find.text('Havolani nusxalash'), findsNothing);
    });
  });

  group('Shogird dasturi (trener tanlagan mashqlar)', () {
    final chest = exercisesFor('chest');
    final easy = Exercise('Yengil itarish', 'chest', '2 × 10', '',
        id: 'b1', level: 'beginner', createdAt: DateTime(2026, 1, 1), createdBy: 't1');

    test('tanlangan bo-lsa — faqat shular, trener tartibida', () {
      final p = {
        'chest': [chest[2].key, chest[0].key]
      };
      expect(exercisesForStudent('chest', const [], p).map((e) => e.key),
          [chest[2].key, chest[0].key]);
    });

    test('tanlanmagan — Boshlovchi; ular ham yo-q — hammasi', () {
      expect(exercisesForStudent('chest', [easy], const {}).map((e) => e.name), ['Yengil itarish']);
      expect(exercisesForStudent('chest', const [], const {}).length, chest.length);
    });

    test('o-chirilgan mashq kaliti tashlab ketiladi; hammasi o-chgan bo-lsa — standart', () {
      expect(
          exercisesForStudent('chest', const [], {
            'chest': ['yoq-mashq', chest[1].key]
          }).map((e) => e.key),
          [chest[1].key]);
      expect(
          exercisesForStudent('chest', [
            easy
          ], {
            'chest': ['yoq-mashq']
          }).map((e) => e.name),
          ['Yengil itarish']);
    });

    test('dastur profil saqlanganda yozilmaydi (toMap da yo-q)', () {
      final u = AppUser(id: 'u1', name: 'A', email: '', program: const {
        'chest': ['x']
      });
      expect(u.toMap().containsKey('program'), isFalse);
      expect(
          u.copyWith(name: 'B').program,
          {
            'chest': ['x']
          },
          reason: 'nusxada saqlanadi');
    });

    testWidgets('ikki shogird — har biri faqat o-ziga tanlanganini ko-radi', (t) async {
      t.view.physicalSize = const Size(420, 7000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      Future<void> open(Map<String, List<String>> program) async {
        await t.pumpWidget(MaterialApp(
          home: MusclesScreen(
            key: UniqueKey(),
            gymDays: evenDays,
            weekday: DateTime.tuesday,
            onBack: () {},
            program: program,
          ),
        ));
        await t.pump(const Duration(seconds: 3));
      }

      // Nodir: ko'krakdan uchala mashq; boshqa bola: faqat bittasi
      await open({
        'chest': [for (final e in chest) e.key]
      });
      for (final e in chest) {
        expect(find.text(e.name), findsOneWidget, reason: e.name);
      }
      await open({
        'chest': [chest[2].key]
      });
      expect(find.text(chest[2].name), findsOneWidget);
      expect(find.text(chest[0].name), findsNothing);
      expect(find.text(chest[1].name), findsNothing);
    });
  });
}
