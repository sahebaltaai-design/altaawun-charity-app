import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps non-sensitive UI preferences in the WordPress member account.
/// Requires the separately installed Altaawun Member Backup WordPress plugin.
/// Passwords, payment data and auth tokens are NEVER copied to the backup.
class MemberBackupService {
  static const _endpoint =
      'https://www.aytamaliraq.com/wp-json/altaawun-app/v1/member-backup';
  static const _storage = FlutterSecureStorage();
  static const _ownerKey = 'altaawun_backup_owner';
  static const _dirtyKey = 'altaawun_backup_dirty';

  static const _strings = <String>{
    'app_font', 'app_font_size', 'notification_tone', 'home_tile_size',
  };
  static const _boolean = <String>{'notification_vibration'};
  static const _stringLists = <String>{
    'home_wp_category_order', 'home_wp_category_hidden',
    'home_category_order', 'home_category_hidden', 'home_custom_categories',
  };
  static const _jsonMaps = <String>{
    'home_wp_category_colors', 'home_wp_category_text_colors',
    'home_wp_category_icon_colors',
  };

  static Map<String, dynamic> _export(SharedPreferences prefs) {
    final result = <String, dynamic>{};
    for (final key in _strings) {
      final value = prefs.getString(key);
      if (value != null) result[key] = value;
    }
    for (final key in _boolean) {
      final value = prefs.getBool(key);
      if (value != null) result[key] = value;
    }
    for (final key in _stringLists) {
      final value = prefs.getStringList(key);
      if (value != null) result[key] = value;
    }
    for (final key in _jsonMaps) {
      try {
        final value = prefs.getString(key);
        if (value != null) {
          final map = jsonDecode(value);
          if (map is Map) result[key] = map;
        }
      } catch (_) {
        // A corrupt local color map is never sent to the server.
      }
    }
    return result;
  }

  static Future<void> _import(
      SharedPreferences prefs, Map<String, dynamic> values) async {
    // Server preferences take precedence on reinstall or a different device.
    // Missing keys reset to the app's approved defaults.
    for (final key in _strings) {
      final value = values[key];
      if (value is String) {
        await prefs.setString(key, value);
      } else {
        await prefs.remove(key);
      }
    }
    for (final key in _boolean) {
      final value = values[key];
      if (value is bool) {
        await prefs.setBool(key, value);
      } else {
        await prefs.remove(key);
      }
    }
    for (final key in _stringLists) {
      final value = values[key];
      if (value is List && value.every((x) => x is String)) {
        await prefs.setStringList(key, value.cast<String>());
      } else {
        await prefs.remove(key);
      }
    }
    for (final key in _jsonMaps) {
      final value = values[key];
      if (value is Map) {
        await prefs.setString(key, jsonEncode(value));
      } else {
        await prefs.remove(key);
      }
    }
    // Prevent the old palette migration from erasing restored custom colors.
    await prefs.setBool('home_palette_nov2026_migrated', true);
    await prefs.setBool('cairo_default_migrated', true);
  }

  static Future<bool> _send(
      String token, String owner, SharedPreferences prefs) async {
    final response = await http
        .post(Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'preferences': _export(prefs)}))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return false;
    final result = jsonDecode(response.body);
    if (result is! Map || result['saved'] != true ||
        result['user_id'].toString() != owner) {
      return false;
    }
    await prefs.setString(_ownerKey, owner);
    await prefs.setBool(_dirtyKey, false);
    return true;
  }

  /// Returns restored, saved, signed_out or unavailable.
  /// Never overwrites an existing server backup with fresh-install defaults.
  static Future<String> synchronize() async {
    try {
      final token = await _storage.read(key: 'altaawun_token');
      if (token == null || token.isEmpty) return 'signed_out';
      final response = await http.get(Uri.parse(_endpoint), headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return 'unavailable';
      final raw = jsonDecode(response.body);
      if (raw is! Map) return 'unavailable';
      final owner = (raw['user_id'] ?? '').toString();
      if (int.tryParse(owner) == null || owner == '0') return 'unavailable';
      final prefs = await SharedPreferences.getInstance();
      final previousOwner = prefs.getString(_ownerKey);
      final dirty = prefs.getBool(_dirtyKey) ?? false;
      final hasBackup = raw['has_backup'] == true;

      // Changes from a signed-in member that were made while offline take
      // priority over that same member's older server snapshot.
      if (dirty && previousOwner == owner) {
        return await _send(token, owner, prefs) ? 'saved' : 'unavailable';
      }

      if (hasBackup) {
        final values = raw['preferences'];
        if (values is! Map) return 'unavailable';
        await _import(prefs, Map<String, dynamic>.from(values));
        await prefs.setString(_ownerKey, owner);
        await prefs.setBool(_dirtyKey, false);
        return 'restored';
      }

      if (previousOwner != null && previousOwner != owner) {
        // A different member's preferences must not leak into this account.
        await _import(prefs, <String, dynamic>{});
      }
      // First login: back up the existing local preferences. A new install
      // with no preferences creates an empty backup instead of fake values.
      return await _send(token, owner, prefs) ? 'saved' : 'unavailable';
    } catch (error) {
      debugPrint('Member backup unavailable: $error');
      return 'unavailable';
    }
  }

  /// Called after a real local user change; if offline, pending changes are
  /// retried at the next sign-in, launch, or manual synchronization.
  static Future<bool> saveChanges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dirtyKey, true);
    final token = await _storage.read(key: 'altaawun_token');
    if (token == null || token.isEmpty) return false;
    return await synchronize() == 'saved';
  }
}
