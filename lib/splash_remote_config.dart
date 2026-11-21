import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Public, read-only splash settings served by the charity WordPress site.
/// The bundled welcome artwork always remains the offline fallback.
class SplashRemoteConfig {
  static const String preferencesKey = 'altaawun_splash_remote_v1';
  static const String endpoint =
      'https://www.aytamaliraq.com/wp-json/altaawun/v1/app-splash';

  final String imageUrl;
  final BoxFit fit;
  final double zoom;
  final double alignX;
  final double alignY;
  final int durationMs;
  final int updatedAt;

  const SplashRemoteConfig({
    this.imageUrl = '',
    this.fit = BoxFit.cover,
    this.zoom = 1,
    this.alignX = 0,
    this.alignY = -1,
    this.durationMs = 1500,
    this.updatedAt = 0,
  });

  static double _bound(dynamic raw, double defaultValue, double low, double high) {
    final candidate = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (candidate == null || !candidate.isFinite) return defaultValue;
    return candidate.clamp(low, high).toDouble();
  }

  static int _integer(dynamic raw, int defaultValue, int low, int high) {
    final candidate = raw is num ? raw.toInt() : int.tryParse('$raw');
    return (candidate ?? defaultValue).clamp(low, high).toInt();
  }

  factory SplashRemoteConfig.fromJson(Map<String, dynamic> payload) {
    final rawUrl = (payload['image_url'] ?? '').toString().trim();
    final uri = Uri.tryParse(rawUrl);
    // Only safe HTTPS image URLs are rendered by the mobile app.
    final imageUrl = uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? rawUrl
        : '';
    return SplashRemoteConfig(
      imageUrl: imageUrl,
      fit: payload['fit'] == 'contain' ? BoxFit.contain : BoxFit.cover,
      zoom: _bound(payload['scale'], 1.0, 0.7, 1.5),
      alignX: _bound(payload['align_x'], 0, -1, 1),
      alignY: _bound(payload['align_y'], -1, -1, 1),
      durationMs: _integer(payload['duration_ms'], 1500, 700, 8000),
      updatedAt: _integer(payload['updated_at'], 0, 0, 2147483647),
    );
  }

  Map<String, dynamic> toJson() => {
        'image_url': imageUrl,
        'fit': fit == BoxFit.contain ? 'contain' : 'cover',
        'scale': zoom,
        'align_x': alignX,
        'align_y': alignY,
        'duration_ms': durationMs,
        'updated_at': updatedAt,
      };

  /// Cache helps a new launch show the last approved design even offline.
  static Future<SplashRemoteConfig?> cached() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(preferencesKey);
    if (data == null || data.isEmpty) return null;
    try {
      final decoded = jsonDecode(data);
      return decoded is Map<String, dynamic>
          ? SplashRemoteConfig.fromJson(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Called on each launch, without a mobile store release after media changes.
  static Future<SplashRemoteConfig?> refresh() async {
    final url = Uri.parse(endpoint).replace(queryParameters: {
      'refresh': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    final response = await http.get(
      url,
      headers: {'Accept': 'application/json', 'Cache-Control': 'no-cache'},
    ).timeout(const Duration(milliseconds: 1800));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) return null;
    final config = SplashRemoteConfig.fromJson(decoded);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferencesKey, jsonEncode(config.toJson()));
    return config;
  }

  String get imageUrlWithRevision {
    if (imageUrl.isEmpty || updatedAt <= 0) return imageUrl;
    final uri = Uri.tryParse(imageUrl);
    if (uri == null) return imageUrl;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'altaawun_splash_version': updatedAt.toString(),
    }).toString();
  }

  Alignment get alignment => Alignment(alignX, alignY);
}
