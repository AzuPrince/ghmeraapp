import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

typedef DeviceAddressResolver = Future<LatLng?> Function(String address);

class MapGeocodingService {
  MapGeocodingService({
    http.Client? client,
    DeviceAddressResolver? deviceAddressResolver,
    Duration minimumHttpInterval = const Duration(seconds: 1),
  }) : _client = client ?? http.Client(),
       _deviceAddressResolver =
           deviceAddressResolver ?? _resolveWithDeviceGeocoder,
       _shouldUseDeviceGeocoder =
           deviceAddressResolver != null || _deviceGeocoderIsSupported,
       _minimumHttpInterval = minimumHttpInterval;

  static final MapGeocodingService instance = MapGeocodingService();

  static const String _nominatimHost = 'nominatim.openstreetmap.org';
  static const String _applicationUserAgent =
      'Ghmera/1.0 (info@peatechservice.com)';

  final http.Client _client;
  final DeviceAddressResolver _deviceAddressResolver;
  final bool _shouldUseDeviceGeocoder;
  final Duration _minimumHttpInterval;
  final Map<String, LatLng> _cache = <String, LatLng>{};
  final Map<String, Future<LatLng?>> _inFlight = <String, Future<LatLng?>>{};

  DateTime? _lastHttpRequestAt;

  Future<LatLng?> resolveAddress(String address) async {
    final normalizedAddress = address.trim();
    if (normalizedAddress.isEmpty) {
      return null;
    }

    final cacheKey = normalizedAddress.toLowerCase();
    final cachedPoint = _cache[cacheKey];
    if (cachedPoint != null) {
      return cachedPoint;
    }

    final pendingPoint = _inFlight[cacheKey];
    if (pendingPoint != null) {
      return pendingPoint;
    }

    final resolution = _resolveAddress(normalizedAddress);
    _inFlight[cacheKey] = resolution;
    try {
      final point = await resolution;
      if (point != null) {
        _cache[cacheKey] = point;
      }
      return point;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Future<LatLng?> _resolveAddress(String address) async {
    if (_shouldUseDeviceGeocoder) {
      try {
        final point = await _deviceAddressResolver(address);
        if (_isValidPoint(point)) {
          return point;
        }
      } catch (_) {
        // Continue with the cross-platform HTTP fallback.
      }
    }

    return _resolveWithNominatim(address);
  }

  Future<LatLng?> _resolveWithNominatim(String address) async {
    try {
      await _respectHttpRateLimit();
      final uri = Uri.https(_nominatimHost, '/search', <String, String>{
        'q': address,
        'format': 'jsonv2',
        'limit': '1',
        'email': 'info@peatechservice.com',
      });
      final headers = <String, String>{
        'Accept': 'application/json',
        'Accept-Language': 'en',
        if (!kIsWeb) 'User-Agent': _applicationUserAgent,
      };
      _lastHttpRequestAt = DateTime.now();
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
        return null;
      }

      final result = decoded.first as Map;
      final latitude = _readCoordinate(result['lat']);
      final longitude = _readCoordinate(result['lon']);
      if (latitude == null || longitude == null) {
        return null;
      }

      final point = LatLng(latitude, longitude);
      return _isValidPoint(point) ? point : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _respectHttpRateLimit() async {
    final lastRequestAt = _lastHttpRequestAt;
    if (lastRequestAt == null || _minimumHttpInterval == Duration.zero) {
      return;
    }

    final elapsed = DateTime.now().difference(lastRequestAt);
    final remaining = _minimumHttpInterval - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  static Future<LatLng?> _resolveWithDeviceGeocoder(String address) async {
    final locations = await locationFromAddress(address);
    if (locations.isEmpty) {
      return null;
    }

    return LatLng(locations.first.latitude, locations.first.longitude);
  }

  static bool get _deviceGeocoderIsSupported {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static double? _readCoordinate(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  static bool _isValidPoint(LatLng? point) {
    if (point == null) {
      return false;
    }

    return point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }
}
