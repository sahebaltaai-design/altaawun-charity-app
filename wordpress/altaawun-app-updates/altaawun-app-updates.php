<?php
/**
 * Plugin Name: Altaawun App Updates
 * Description: إعداد إعلانات تحديث تطبيق جمعية التعاون الخيرية لأندرويد وآيفون حسب قناة النشر ورقم البناء.
 * Version: 1.0.0
 * Requires PHP: 7.4
 */
if (!defined('ABSPATH')) exit;

const ALTAAWUN_APP_UPDATE_OPTION = 'altaawun_app_update_releases';

function altaawun_update_targets() {
    return array(
        'android_production' => 'Android — الإصدار العام',
        'android_alpha' => 'Android — الاختبار المغلق Alpha',
        'ios_production' => 'iPhone — App Store',
        'ios_alpha' => 'iPhone — TestFlight',
    );
}

add_action('rest_api_init', static function () {
    register_rest_route('altaawun-app/v1', '/update', array(
        'methods' => WP_REST_Server::READABLE,
        'permission_callback' => '__return_true',
        'callback' => static function (WP_REST_Request $request) {
            $platform = $request->get_param('platform') === 'ios' ? 'ios' : 'android';
            $channel = $request->get_param('channel') === 'alpha' ? 'alpha' : 'production';
            $option = get_option(ALTAAWUN_APP_UPDATE_OPTION, array());
            $item = isset($option[$platform . '_' . $channel])
                ? $option[$platform . '_' . $channel] : array();
            $enabled = !empty($item['enabled']) && !empty($item['build']);
            return new WP_REST_Response(array(
                'enabled' => (bool) $enabled,
                'platform' => $platform,
                'channel' => $channel,
                'version' => isset($item['version']) ? (string)$item['version'] : '',
                'build' => isset($item['build']) ? (int)$item['build'] : 0,
                'required' => !empty($item['required']),
                'notes' => isset($item['notes']) ? (string)$item['notes'] : '',
                'url' => $platform === 'ios' && !empty($item['url'])
                    ? esc_url_raw($item['url']) : '',
            ), 200, array('Cache-Control' => 'no-store, no-cache, must-revalidate'));
        },
    ));
});

add_action('admin_init', static function () {
    register_setting('altaawun_app_update_group', ALTAAWUN_APP_UPDATE_OPTION, array(
        'type' => 'array',
        'default' => array(),
        'sanitize_callback' => static function ($value) {
            $value = is_array($value) ? $value : array();
            $safe = array();
            foreach (altaawun_update_targets() as $key => $label) {
                $row = isset($value[$key]) && is_array($value[$key]) ? $value[$key] : array();
                $url = isset($row['url']) ? esc_url_raw($row['url']) : '';
                // Do not advertise arbitrary downloads as app updates.
                if ($url && parse_url($url, PHP_URL_HOST) !== 'apps.apple.com') $url = '';
                $safe[$key] = array(
                    'enabled' => !empty($row['enabled']) ? 1 : 0,
                    'build' => max(0, (int)($row['build'] ?? 0)),
                    'version' => sanitize_text_field($row['version'] ?? ''),
                    'notes' => sanitize_textarea_field($row['notes'] ?? ''),
                    'required' => !empty($row['required']) ? 1 : 0,
                    'url' => $url,
                );
            }
            return $safe;
        },
    ));
});

add_action('admin_menu', static function () {
    add_options_page('تحديثات تطبيق الجمعية', 'تحديثات تطبيق الجمعية',
        'manage_options', 'altaawun-app-updates', 'altaawun_updates_render_settings');
});

function altaawun_updates_render_settings() {
    if (!current_user_can('manage_options')) return;
    $releases = get_option(ALTAAWUN_APP_UPDATE_OPTION, array());
    echo '<div class="wrap" dir="rtl"><h1>تحديثات تطبيق جمعية التعاون الخيرية</h1>';
    echo '<p>فعّل الإصدار فقط بعد ظهوره للمستخدمين المعنيين في Google Play أو App Store/TestFlight. رقم البناء مهم حتى عند بقاء الاسم 1.0.1.</p>';
    echo '<form method="post" action="options.php">';
    settings_fields('altaawun_app_update_group');
    foreach (altaawun_update_targets() as $key => $label) {
        $row = isset($releases[$key]) ? $releases[$key] : array();
        $base = ALTAAWUN_APP_UPDATE_OPTION . '[' . $key . ']';
        echo '<hr><h2>' . esc_html($label) . '</h2><table class="form-table" role="presentation">';
        echo '<tr><th>تفعيل الإعلان</th><td><label><input type="checkbox" name="' . esc_attr($base . '[enabled]') . '" value="1" ' . checked(!empty($row['enabled']), true, false) . '> أظهر رسالة التحديث لهذا المسار فقط</label></td></tr>';
        echo '<tr><th>رقم الإصدار</th><td><input class="regular-text" name="' . esc_attr($base . '[version]') . '" value="' . esc_attr($row['version'] ?? '') . '" placeholder="1.0.2"></td></tr>';
        echo '<tr><th>رقم البناء</th><td><input type="number" min="0" name="' . esc_attr($base . '[build]') . '" value="' . esc_attr($row['build'] ?? '0') . '" required></td></tr>';
        echo '<tr><th>تفاصيل التحديث</th><td><textarea class="large-text" rows="2" name="' . esc_attr($base . '[notes]') . '">' . esc_textarea($row['notes'] ?? '') . '</textarea></td></tr>';
        echo '<tr><th>تحديث إجباري</th><td><label><input type="checkbox" name="' . esc_attr($base . '[required]') . '" value="1" ' . checked(!empty($row['required']), true, false) . '> إخفاء زر «لاحقًا» (استخدمه فقط للضرورة)</label></td></tr>';
        if (strpos($key, 'ios_') === 0) {
            echo '<tr><th>رابط App Store</th><td><input class="large-text" type="url" name="' . esc_attr($base . '[url]') . '" value="' . esc_attr($row['url'] ?? '') . '" placeholder="https://apps.apple.com/..."></td></tr>';
        }
        echo '</table>';
    }
    submit_button('حفظ إعدادات التحديث');
    echo '</form><p>عنوان التحقق: <code>' .
        esc_html(rest_url('altaawun-app/v1/update?platform=android&channel=alpha')) .
        '</code></p></div>';
}
