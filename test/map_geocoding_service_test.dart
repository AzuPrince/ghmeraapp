import 'package:flutter_test/flutter_test.dart';
import 'package:ghmera_app/app/services/map_geocoding_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test(
    'uses the HTTP fallback and caches successful address results',
    () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount += 1;
        expect(request.url.host, 'nominatim.openstreetmap.org');
        expect(request.url.queryParameters['q'], 'East Legon, Accra');
        expect(request.url.queryParameters['limit'], '1');
        return http.Response('[{"lat":"5.6401","lon":"-0.1535"}]', 200);
      });
      final service = MapGeocodingService(
        client: client,
        deviceAddressResolver: (_) async => throw UnsupportedError('device'),
        minimumHttpInterval: Duration.zero,
      );

      final first = await service.resolveAddress('East Legon, Accra');
      final second = await service.resolveAddress('  east legon, accra  ');

      expect(first, const LatLng(5.6401, -0.1535));
      expect(second, first);
      expect(requestCount, 1);
    },
  );

  test('prefers a valid device geocoder result', () async {
    final client = MockClient((_) async {
      fail('HTTP geocoding should not run after device geocoding succeeds.');
    });
    final service = MapGeocodingService(
      client: client,
      deviceAddressResolver: (_) async => const LatLng(5.6037, -0.1870),
      minimumHttpInterval: Duration.zero,
    );

    final point = await service.resolveAddress('Accra');

    expect(point, const LatLng(5.6037, -0.1870));
  });

  test('rejects malformed HTTP geocoding responses', () async {
    final client = MockClient((_) async => http.Response('[{"lat":"x"}]', 200));
    final service = MapGeocodingService(
      client: client,
      deviceAddressResolver: (_) async => null,
      minimumHttpInterval: Duration.zero,
    );

    expect(await service.resolveAddress('Unknown place'), isNull);
  });
}
