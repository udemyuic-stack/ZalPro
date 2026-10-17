import 'dart:typed_data';

import '../../models/shop.dart';
import 'api_service.dart';
import 'json_helpers.dart';

class ShopApi extends ApiService {
  ShopApi(super.client, {super.bus, super.activity, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const _catalog = Duration(seconds: 60);
  static const _orders = Duration(seconds: 30);
  static const _windowDays = 400;

  final DateTime Function() _now;

  Stream<List<Product>> products() => poll(() async {
        final rows = await client.getList('/v1/products');
        return jsonMaps(rows).map(Product.fromJson).toList();
      }, _catalog, {'products'});

  Future<void> saveProduct(Product p) {
    if (p.id.isEmpty) return write('POST', '/v1/products', p.toJson(), ['products']);
    return write('PATCH', '/v1/products/${p.id}', p.toJson(), ['products']);
  }

  Future<void> deleteProduct(String id) => write('DELETE', '/v1/products/$id', null, ['products']);

  Future<String> uploadProductImage(
    String id,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
    void Function(int sent, int total)? onProgress,
  }) =>
      uploadImage(
        '/v1/products/$id/images/upload-url',
        bytes,
        contentType: contentType,
        onProgress: onProgress,
      );

  Future<Product> setProductImages(String id, List<String> keys) async {
    final saved = await bus.after(
      client.request<Map<String, dynamic>>('PUT', '/v1/products/$id/images', data: {'keys': keys}),
      ['products'],
    );
    return Product.fromJson(saved ?? const {});
  }

  String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Stream<List<ShopOrder>> _list(bool windowed, bool Function(ShopOrder) keep) {
    return poll(() async {
      final query = <String, dynamic>{};
      if (windowed) {
        final today = _now();
        final to = DateTime(today.year, today.month, today.day + 1);
        final from = DateTime(to.year, to.month, to.day - (_windowDays - 1));
        query['from'] = _day(from);
        query['to'] = _day(to);
      }
      final rows = await client.getList('/v1/orders', query: query);
      return jsonMaps(rows).map(ShopOrder.fromJson).where(keep).toList();
    }, _orders, {'orders'});
  }

  Stream<List<ShopOrder>> myOrders(String uid) => _list(true, (o) => o.clientId == uid);

  Stream<List<ShopOrder>> ordersOf(String trainerId) =>
      _list(true, (o) => o.trainerId == trainerId);

  Stream<List<ShopOrder>> allOrders() => _list(false, (_) => true);

  Stream<List<ShopOrder>> gymOrders(String? gymId) {
    final gym = gymId ?? '';
    if (gym.isEmpty) return Stream.value(const <ShopOrder>[]);
    return _list(true, (o) => o.gymId == gym);
  }

  Future<void> createOrder(String productId, int qty, {String size = '', String color = ''}) {
    return write(
      'POST',
      '/v1/orders',
      {'product_id': productId, 'qty': qty, 'size': size, 'color': color},
      ['orders'],
    );
  }

  Future<void> setOrderStatus(String id, String status) => write(
        'PATCH',
        '/v1/orders/$id/status',
        {'status': status},
        ['orders', 'products'],
      );
}
