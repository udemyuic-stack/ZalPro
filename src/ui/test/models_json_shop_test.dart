import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/photo.dart';
import 'package:kotta_qani_diet/models/shop.dart';
import 'package:kotta_qani_diet/models/subscription.dart';

void main() {
  test('Product full payload', () {
    final p = Product.fromJson({
      'id': 'p1',
      'category': 'Protein',
      'name': 'Whey',
      'note': 'shokolad',
      'name_ru': 'Вей',
      'name_en': 'Whey EN',
      'note_ru': 'шоколад',
      'note_en': 'chocolate',
      'image_urls': ['a.png', 'b.png'],
      'image_keys': ['k/a', 'k/b'],
      'sizes': ['XL', 'XXL'],
      'colors': ['sariq'],
      'price': 450000,
      'currency': 'USD',
      'stock': 7,
      'size_stock': {'XL': 3, 'XXL': 4.0},
      'cost_price': 300000,
      'active': false,
    });
    expect(p.id, 'p1');
    expect(p.category, 'Protein');
    expect(p.name, 'Whey');
    expect(p.note, 'shokolad');
    expect(p.nameRu, 'Вей');
    expect(p.nameEn, 'Whey EN');
    expect(p.noteRu, 'шоколад');
    expect(p.noteEn, 'chocolate');
    expect(p.imageUrls, ['a.png', 'b.png']);
    expect(p.imageKeys, ['k/a', 'k/b']);
    expect(p.image, 'a.png');
    expect(p.toJson().containsKey('image'), false);
    expect(p.toJson().containsKey('images'), false);
    expect(p.toJson().containsKey('image_urls'), false);
    expect(p.toJson().containsKey('image_keys'), false);
    expect(p.sizes, ['XL', 'XXL']);
    expect(p.colors, ['sariq']);
    expect(p.price, 450000);
    expect(p.currency, 'USD');
    expect(p.stock, 7);
    expect(p.sizeStock, {'XL': 3, 'XXL': 4});
    expect(p.costPrice, 300000);
    expect(p.active, false);
  });

  test('Product null cost_price and empty payload', () {
    final p = Product.fromJson({'cost_price': null});
    expect(p.costPrice, 0);
    final e = Product.fromJson({});
    expect(e.id, '');
    expect(e.category, '');
    expect(e.name, '');
    expect(e.note, '');
    expect(e.nameRu, '');
    expect(e.nameEn, '');
    expect(e.noteRu, '');
    expect(e.noteEn, '');
    expect(e.image, '');
    expect(e.imageUrls, isEmpty);
    expect(e.imageKeys, isEmpty);
    expect(e.sizes, isEmpty);
    expect(e.colors, isEmpty);
    expect(e.price, 0);
    expect(e.currency, uzs);
    expect(e.stock, 0);
    expect(e.sizeStock, isEmpty);
    expect(e.costPrice, 0);
    expect(e.active, true);
  });

  test('ShopOrder full payload', () {
    final o = ShopOrder.fromJson({
      'id': 'o1',
      'client_id': 'c1',
      'client_name': 'Ali',
      'client_phone': '998901234567',
      'trainer_id': 't1',
      'gym_id': 'g1',
      'product_id': 'p1',
      'product_name': 'Whey',
      'category': 'Protein',
      'size': 'XL',
      'color': 'sariq',
      'price': 100000,
      'currency': 'USD',
      'qty': 3,
      'status': 'given',
      'created_at': '2026-01-02T03:04:05Z',
      'updated_at': '2026-01-03T00:00:00Z',
      'given_by': 't1',
      'given_at': '2026-01-04T05:06:07+00:00',
      'total': 300000,
    });
    expect(o.id, 'o1');
    expect(o.clientId, 'c1');
    expect(o.clientName, 'Ali');
    expect(o.clientPhone, '998901234567');
    expect(o.trainerId, 't1');
    expect(o.gymId, 'g1');
    expect(o.productId, 'p1');
    expect(o.productName, 'Whey');
    expect(o.category, 'Protein');
    expect(o.size, 'XL');
    expect(o.color, 'sariq');
    expect(o.price, 100000);
    expect(o.currency, 'USD');
    expect(o.qty, 3);
    expect(o.total, 300000);
    expect(o.status, orderGiven);
    expect(o.createdAt!.toUtc(), DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(o.givenBy, 't1');
    expect(o.givenAt!.toUtc(), DateTime.utc(2026, 1, 4, 5, 6, 7));
  });

  test('ShopOrder empty payload', () {
    final o = ShopOrder.fromJson({});
    expect(o.id, '');
    expect(o.clientId, '');
    expect(o.clientName, '');
    expect(o.clientPhone, '');
    expect(o.trainerId, '');
    expect(o.gymId, '');
    expect(o.productId, '');
    expect(o.productName, '');
    expect(o.category, '');
    expect(o.size, '');
    expect(o.color, '');
    expect(o.price, 0);
    expect(o.currency, uzs);
    expect(o.qty, 1);
    expect(o.status, orderNew);
    expect(o.createdAt, isNull);
    expect(o.givenBy, '');
    expect(o.givenAt, isNull);
  });

  test('Subscription full payload', () {
    final s = Subscription.fromJson({
      'id': 's1',
      'user_id': 'u1',
      'start_date': '2026-01-02T00:00:00Z',
      'months': 3,
      'days': 0,
      'price': 1500000,
      'currency': 'USD',
      'paid_date': '2026-01-01T10:00:00Z',
      'created_at': '2026-01-01T11:00:00Z',
      'paid_at': '2026-01-01T10:00:00Z',
      'expires_at': '2026-04-02T00:00:00Z',
    });
    expect(s.id, 's1');
    expect(s.startDate.toUtc(), DateTime.utc(2026, 1, 2));
    expect(s.months, 3);
    expect(s.days, 0);
    expect(s.price, 1500000);
    expect(s.currency, 'USD');
    expect(s.paidDate!.toUtc(), DateTime.utc(2026, 1, 1, 10));
    expect(s.createdAt!.toUtc(), DateTime.utc(2026, 1, 1, 11));
  });

  test('Subscription empty payload', () {
    final before = DateTime.now();
    final s = Subscription.fromJson({});
    expect(s.id, '');
    expect(s.startDate.isBefore(before), false);
    expect(s.months, 1);
    expect(s.days, 0);
    expect(s.price, 0);
    expect(s.currency, 'UZS');
    expect(s.paidDate, isNull);
    expect(s.createdAt, isNull);
  });

  test('Reminder full payload', () {
    final r = Reminder.fromJson({
      'id': 'r1',
      'client_id': 'c1',
      'client_name': 'Ali',
      'trainer_id': 't1',
      'sent_by': 't1',
      'sent_at': '2026-02-03T04:05:06Z',
      'days_left': 2,
    });
    expect(r.id, 'r1');
    expect(r.clientId, 'c1');
    expect(r.clientName, 'Ali');
    expect(r.trainerId, 't1');
    expect(r.sentBy, 't1');
    expect(r.sentAt!.toUtc(), DateTime.utc(2026, 2, 3, 4, 5, 6));
    expect(r.daysLeft, 2);
  });

  test('Reminder empty payload', () {
    final r = Reminder.fromJson({});
    expect(r.id, '');
    expect(r.clientId, '');
    expect(r.clientName, '');
    expect(r.trainerId, '');
    expect(r.sentBy, '');
    expect(r.sentAt, isNull);
    expect(r.daysLeft, 0);
  });

  test('Membership full payload', () {
    final m = Membership.fromJson({
      'user_id': 'u1',
      'name': 'Ali',
      'gym_id': 'g1',
      'months': 6,
      'days': 2,
      'price': 900000,
      'currency': 'USD',
      'paid_date': '2026-01-01T00:00:00Z',
      'expires_at': '2026-07-01T00:00:00Z',
      'updated_at': '2026-01-02T00:00:00Z',
    });
    expect(m.uid, 'u1');
    expect(m.name, 'Ali');
    expect(m.gymId, 'g1');
    expect(m.months, 6);
    expect(m.days, 2);
    expect(m.price, 900000);
    expect(m.currency, 'USD');
    expect(m.paidDate!.toUtc(), DateTime.utc(2026, 1, 1));
    expect(m.expiresAt!.toUtc(), DateTime.utc(2026, 7, 1));
  });

  test('Membership empty payload', () {
    final m = Membership.fromJson({});
    expect(m.uid, '');
    expect(m.name, '');
    expect(m.gymId, '');
    expect(m.months, 0);
    expect(m.days, 0);
    expect(m.price, 0);
    expect(m.currency, 'UZS');
    expect(m.paidDate, isNull);
    expect(m.expiresAt, isNull);
  });

  test('ProgressPhoto full payload', () {
    final expiry = DateTime.utc(2026, 5, 6, 7);
    final p = ProgressPhoto.fromJson({
      'id': '3f2b1c9e-0000-4000-8000-000000000001',
      'taken_at': '2026-05-06T04:05:06Z',
      'weight': 72,
      'size': 1234,
      'download_url': 'https://s3.example/x?sig=1',
    }, urlExpiresAt: expiry);
    expect(p.id, '3f2b1c9e-0000-4000-8000-000000000001');
    expect(p.takenAt!.toUtc(), DateTime.utc(2026, 5, 6, 4, 5, 6));
    expect(p.weight, 72.0);
    expect(p.url, 'https://s3.example/x?sig=1');
    expect(p.urlExpiresAt, expiry);
    expect(p.bytes, isEmpty);
  });

  test('ProgressPhoto empty payload', () {
    final p = ProgressPhoto.fromJson({});
    expect(p.id, '');
    expect(p.takenAt, isNull);
    expect(p.weight, 0);
    expect(p.url, isNull);
    expect(p.urlExpiresAt, isNull);
    expect(p.bytes, isEmpty);
  });
}
