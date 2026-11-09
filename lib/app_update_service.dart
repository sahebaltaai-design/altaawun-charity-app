import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// A Play Store version name can remain 1.0.1 while versionCode increases.
/// The WordPress endpoint advertises only releases actually made available
/// to the specified channel; this avoids claiming a GitHub build is released.
class AppUpdateService {
  static const channel = String.fromEnvironment(
    'ALTAAWUN_UPDATE_CHANNEL',
    defaultValue: 'production',
  );

  static String? get platform => switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        _ => null,
      };

  static Future<PackageInfo> installedVersion() => PackageInfo.fromPlatform();

  static Future<void> checkForUpdates(BuildContext context,
      {bool manual = false}) async {
    final targetPlatform = platform;
    if (targetPlatform == null) return;

    try {
      final package = await installedVersion();
      final installedBuild = int.tryParse(package.buildNumber) ?? 0;
      final response = await http
          .get(Uri.https('www.aytamaliraq.com',
              '/wp-json/altaawun-app/v1/update', {
            'platform': targetPlatform,
            'channel': channel,
          }), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw StateError('Update server returned ${response.statusCode}');
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Invalid update response');
      }
      final enabled = payload['enabled'] == true;
      final newestBuild = int.tryParse('${payload['build'] ?? ''}') ?? 0;
      if (!context.mounted) return;

      if (!enabled || newestBuild <= 0) {
        if (manual) _message(context, 'لم يتم الإعلان عن تحديث جديد بعد.');
        return;
      }
      if (newestBuild <= installedBuild) {
        if (manual) _message(context, 'التطبيق محدّث إلى أحدث إصدار متاح.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final reminderKey = 'altaawun_update_later_${targetPlatform}_${channel}_$newestBuild';
      final lastReminder = prefs.getInt(reminderKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!manual && lastReminder > 0 &&
          now - lastReminder < const Duration(hours: 24).inMilliseconds) {
        return;
      }
      if (!context.mounted) return;

      final newVersion = (payload['version'] ?? '').toString().trim();
      final notes = (payload['notes'] ?? '').toString().trim();
      final mustUpdate = payload['required'] == true;
      final storeUrl = _storeUrl(payload['url']?.toString(), package.packageName,
          targetPlatform);
      if (storeUrl == null) {
        if (manual) _message(context, 'رابط التحديث غير متاح بعد.');
        return;
      }
      final shouldOpen = await showDialog<bool>(
        context: context,
        barrierDismissible: !mustUpdate,
        builder: (dialogContext) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.system_update_alt, color: Color(0xFF00642D)),
            SizedBox(width: 10),
            Expanded(child: Text('يتوفر تحديث جديد')),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('يتوفر إصدار أحدث من تطبيق جمعية التعاون الخيرية.'),
              const SizedBox(height: 12),
              Text('الإصدار: ${newVersion.isEmpty ? 'جديد' : newVersion}'),
              Text('رقم البناء: $newestBuild'),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(notes),
              ],
            ]),
          ),
          actions: [
            if (!mustUpdate)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('لاحقًا'),
              ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00642D)),
              onPressed: storeUrl == null
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              child: const Text('تحديث الآن'),
            ),
          ],
        ),
      );
      if (shouldOpen != true) {
        await prefs.setInt(reminderKey, now);
        return;
      }
      // Avoid showing the same popup immediately after returning from Play.
      await prefs.setInt(reminderKey, now);
      if (storeUrl != null && !await launchUrl(storeUrl,
          mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          _message(context, 'تعذر فتح المتجر. افتح صفحة التطبيق في المتجر.');
        }
      }
    } catch (error) {
      debugPrint('App update check unavailable: $error');
      if (manual && context.mounted) {
        _message(context, 'تعذر التحقق من التحديثات. حاول مرة أخرى لاحقًا.');
      }
    }
  }

  static Uri? _storeUrl(
      String? configuredUrl, String packageName, String targetPlatform) {
    if (targetPlatform == 'android') {
      // Only open this exact app's Play listing, never download an APK.
      return Uri.https('play.google.com', '/store/apps/details',
          {'id': packageName});
    }
    final candidate = Uri.tryParse(configuredUrl ?? '');
    if (candidate != null && candidate.scheme == 'https' &&
        candidate.host == 'apps.apple.com') {
      return candidate;
    }
    return null;
  }

  static void _message(BuildContext context, String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(text)));
  }
}
