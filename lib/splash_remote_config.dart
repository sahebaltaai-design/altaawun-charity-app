import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Public, read-only splash settings served by the charity WordPress site.
/// Last approved image and settings persist locally for use during an outage.
/// The bundled welcome artwork is the final offline fallback.
class SplashRemoteConfig {
  static const String preferencesKey = 'altaawun_splash_remote_v1';
  static const String imageFileKey = 'altaawun_splash_image_file_v1';
  static const String endpoint =
      'https://www.aytamaliraq.com/wp-json/altaawun/v1/app-splash';
  static const int _maxImageBytes = 10 * 1024 * 1024;

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

  static bool _safeImageFilename(String? filename) =>
      filename != null &&
      RegExp(r'^altaawun_splash_[0-9]+[.]img$').hasMatch(filename);

  static Future<File?> _localImageFile(String? name) async {
    if (!_safeImageFilename(name)) return null;
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    if (!await file.exists()) return null;
    if (await file.length() == 0) return null;
    return file;
  }

  /// Last confirmed image remains available without internet, even after
  /// a restart. It is not merely an in-memory Image.network cache.
  static Future<File?> cachedImage() async {
    final prefs = await SharedPreferences.getInstance();
    return _localImageFile(prefs.getString(imageFileKey));
  }

  static bool _isImage(Uint8List data) {
    if (data.length < 12) return false;
    // JPEG, PNG, GIF and WebP. No HTML, JavaScript or SVG is persisted.
    if (data[0] == 0xFF && data[1] == 0xD8) return true;
    if (data[0] == 0x89 && data[1] == 0x50 &&
        data[2] == 0x4E && data[3] == 0x47) return true;
    if (data[0] == 0x47 && data[1] == 0x49 &&
        data[2] == 0x46 && data[3] == 0x38) return true;
    return data[0] == 0x52 && data[1] == 0x49 &&
        data[2] == 0x46 && data[3] == 0x46 &&
        data[8] == 0x57 && data[9] == 0x45 &&
        data[10] == 0x42 && data[11] == 0x50;
  }

  static Future<File> _downloadVerifiedImage(
      String url, String filename) async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final destination = File(
        '${directory.path}${Platform.pathSeparator}$filename');
    final temporary = File('${destination.path}.download');
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Accept'] = 'image/png,image/jpeg,image/webp,image/gif';
      final response =
          await client.send(request).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > _maxImageBytes) {
        throw const FormatException('Invalid splash image response');
      }
      final contentType =
          (response.headers['content-type'] ?? '').toLowerCase();
      if (contentType.contains('text/html') ||
          contentType.contains('application/json') ||
          contentType.contains('image/svg')) {
        throw const FormatException('Unsupported splash image type');
      }
      final chunks = BytesBuilder(copy: false);
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 5))) {
        if (chunks.length + chunk.length > _maxImageBytes) {
          throw const FormatException('Splash image is too large');
        }
        chunks.add(chunk);
      }
      final bytes = chunks.takeBytes();
      if (!_isImage(bytes)) {
        throw const FormatException('Invalid splash image bytes');
      }
      await temporary.writeAsBytes(bytes, flush: true);
      return await temporary.rename(destination.path);
    } finally {
      client.close();
      if (await temporary.exists()) {
        try {
          await temporary.delete();
        } catch (_) {}
      }
    }
  }

  static Future<void> _deleteOldImage(String? name, String? keep) async {
    if (!_safeImageFilename(name) || name == keep) return;
    try {
      final previous = await _localImageFile(name);
      if (previous != null) await previous.delete();
    } catch (_) {}
  }

  /// Update only after the new image has been downloaded and verified.
  /// A failed WordPress/image request never destroys the previous design.
  static Future<SplashRemoteConfig?> refresh() async {
    final url = Uri.parse(endpoint).replace(queryParameters: {
      'refresh': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    final response = await http.get(url, headers: {
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    }).timeout(const Duration(milliseconds: 1800));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) return null;
    final config = SplashRemoteConfig.fromJson(decoded);
    if ((decoded['image_url'] ?? '').toString().trim().isNotEmpty &&
        config.imageUrl.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final oldName = prefs.getString(imageFileKey);
    final oldConfig = await cached();

    if (config.imageUrl.isEmpty) {
      // The administrator deliberately selected the bundled default image.
      await prefs.setString(preferencesKey, jsonEncode(config.toJson()));
      await prefs.remove(imageFileKey);
      await _deleteOldImage(oldName, null);
      return config;
    }

    if (oldConfig != null &&
        oldConfig.imageUrlWithRevision == config.imageUrlWithRevision &&
        await _localImageFile(oldName) != null) {
      // Only alignment/scale/duration might have changed; cached bytes suffice.
      await prefs.setString(preferencesKey, jsonEncode(config.toJson()));
      return config;
    }

    // A new or changed photo is persisted to application-support storage
    // before replacing the previous photo or its configuration.
    final newName =
        'altaawun_splash_${DateTime.now().microsecondsSinceEpoch}.img';
    await _downloadVerifiedImage(config.imageUrlWithRevision, newName);
    await prefs.setString(imageFileKey, newName);
    await prefs.setString(preferencesKey, jsonEncode(config.toJson()));
    await _deleteOldImage(oldName, newName);
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
