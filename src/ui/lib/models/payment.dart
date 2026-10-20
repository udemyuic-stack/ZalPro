import '../services/api/json_helpers.dart';

/// To'lov tizimlari (server `providers` ro'yxatidagi kodlar)
const payProviderPayme = 'payme';
const payProviderClick = 'click';

/// `GET /v1/payments/options` — sotib olish mumkin bo'lgan muddatlar va ulangan to'lov tizimlari.
/// Narxni faqat server belgilaydi; ilova uni ko'rsatadi, xolos.
class PaymentOptions {
  final List<String> providers;
  final List<PaymentPlan> plans;

  const PaymentOptions({this.providers = const [], this.plans = const []});

  bool get available => providers.isNotEmpty && plans.isNotEmpty;

  factory PaymentOptions.fromJson(Map<String, dynamic> j) => PaymentOptions(
        providers: jsonStrings(j['providers']),
        plans: jsonMaps(j['plans']).map(PaymentPlan.fromJson).toList(),
      );
}

class PaymentPlan {
  final int months;
  final int price;
  final String currency;

  const PaymentPlan({required this.months, required this.price, this.currency = 'UZS'});

  factory PaymentPlan.fromJson(Map<String, dynamic> j) => PaymentPlan(
        months: jsonInt(j['months'], 1),
        price: jsonInt(j['price']),
        currency: jsonString(j['currency'], 'UZS'),
      );
}

/// `payment_orders` — bitta to'lov urinishi. `pending`/`created` — kutilmoqda,
/// `paid` — obuna faollashgan, `canceled` — to'lanmagan.
class PaymentOrder {
  final String id;
  final String provider;
  final int months;
  final int amount;
  final String currency;
  final String status;
  final String? payUrl;
  final DateTime? paidAt;
  final DateTime? expiresAt;

  const PaymentOrder({
    required this.id,
    this.provider = '',
    this.months = 1,
    this.amount = 0,
    this.currency = 'UZS',
    this.status = 'pending',
    this.payUrl,
    this.paidAt,
    this.expiresAt,
  });

  bool get isPaid => status == 'paid';
  bool get isCanceled => status == 'canceled';
  bool get isFinal => isPaid || isCanceled;

  factory PaymentOrder.fromJson(Map<String, dynamic> j) => PaymentOrder(
        id: jsonString(j['id']),
        provider: jsonString(j['provider']),
        months: jsonInt(j['months'], 1),
        amount: jsonInt(j['amount']),
        currency: jsonString(j['currency'], 'UZS'),
        status: jsonString(j['status'], 'pending'),
        payUrl: jsonStringOrNull(j['pay_url']),
        paidAt: jsonDate(j['paid_at']),
        expiresAt: jsonDate(j['expires_at']),
      );
}
