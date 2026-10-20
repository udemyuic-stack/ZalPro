import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/core/input_rules.dart';
import 'package:kotta_qani_diet/models/models.dart';

void main() {
  test('mapUrl validator', () {
    expect(InputRules.mapUrl(''), isNull);
    expect(InputRules.mapUrl('https://maps.app.goo.gl/abc'), isNull);
    expect(InputRules.mapUrl('javascript:alert(1)'), isNotNull);
    expect(InputRules.mapUrl('https://a b'), isNotNull);
    expect(InputRules.mapUrl('abc'), isNotNull);
  });

  test('Gym map_url roundtrip', () {
    final g = Gym.fromJson({'id': 'g', 'name': 'N', 'map_url': 'https://x.y/z'});
    expect(g.mapUrl, 'https://x.y/z');
    expect(g.toMap()['map_url'], 'https://x.y/z');
  });
}
