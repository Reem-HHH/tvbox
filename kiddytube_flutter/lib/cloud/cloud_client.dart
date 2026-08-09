import 'dart:convert';

import 'package:http/http.dart' as http;

class CloudException implements Exception {
  CloudException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PairResult {
  const PairResult({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.token,
    required this.catalogUrl,
  });

  final int deviceId;
  final String name;
  final String platform;
  final String token;
  final String catalogUrl;

  factory PairResult.fromJson(Map<String, dynamic> json) => PairResult(
        deviceId: (json['device_id'] as num).toInt(),
        name: json['name'] as String? ?? 'Device',
        platform: json['platform'] as String? ?? 'unknown',
        token: json['token'] as String,
        catalogUrl: json['catalog_url'] as String? ?? '',
      );
}

class CloudClient {
  CloudClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static String normalizeBaseUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) {
      throw CloudException('Cloud server URL is required');
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Future<PairResult> pair({
    required String baseUrl,
    required String code,
    required String name,
    required String platform,
  }) async {
    final root = normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$root/v1/devices/pair');
    final response = await _http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code': code.trim(),
            'name': name.trim().isEmpty ? 'Device' : name.trim(),
            'platform': platform,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw CloudException(
        _errorMessage(response) ?? 'Pairing failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    final map = jsonDecode(response.body);
    if (map is! Map<String, dynamic>) {
      throw CloudException('Unexpected pairing response');
    }
    return PairResult.fromJson(map);
  }

  Future<Map<String, dynamic>> fetchCatalog({
    required String baseUrl,
    required String token,
  }) async {
    final root = normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$root/v1/catalog');
    final response = await _http
        .get(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw CloudException(
        _errorMessage(response) ??
            'Catalog pull failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    final map = jsonDecode(response.body);
    if (map is! Map<String, dynamic>) {
      throw CloudException('Unexpected catalog response');
    }
    return map;
  }

  String? _errorMessage(http.Response response) {
    try {
      final map = jsonDecode(response.body);
      if (map is Map && map['detail'] != null) {
        return map['detail'].toString();
      }
    } catch (_) {}
    return null;
  }
}
