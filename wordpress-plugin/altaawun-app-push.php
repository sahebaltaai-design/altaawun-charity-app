<?php
/**
 * Plugin Name: Al-Taawun App Push Notifications
 * Description: إشعارات Firebase تلقائية للمقالات والمنتجات الجديدة وإرسال يدوي من لوحة التحكم.
 * Version: 1.0.1
 */
if (!defined('ABSPATH')) exit;

/**
 * Set these constants in wp-config.php (never commit private credentials):
 * ALTAWUN_FCM_CLIENT_EMAIL, ALTAWUN_FCM_PRIVATE_KEY.
 * The service account must have permission to send Firebase Cloud Messaging.
 */
function altaawun_fcm_access_token() {
    if (!defined('ALTAWUN_FCM_CLIENT_EMAIL') || !defined('ALTAWUN_FCM_PRIVATE_KEY')) {
        return new WP_Error('missing_credentials', 'إعدادات حساب خدمة Firebase غير مكتملة');
    }
    $now = time();
    $b64 = static function ($value) {
        return rtrim(strtr(base64_encode(wp_json_encode($value)), '+/', '-_'), '=');
    };
    $jwt = $b64(array('alg'=>'RS256','typ'=>'JWT')).'.'.$b64(array(
        'iss'=>ALTAWUN_FCM_CLIENT_EMAIL,
        'scope'=>'https://www.googleapis.com/auth/firebase.messaging',
        'aud'=>'https://oauth2.googleapis.com/token',
        'iat'=>$now, 'exp'=>$now+3500,
    ));
    $signature = '';
    if (!openssl_sign($jwt, $signature, str_replace('\\n', "\n", ALTAWUN_FCM_PRIVATE_KEY), OPENSSL_ALGO_SHA256)) {
        return new WP_Error('sign_failed', 'تعذر توقيع طلب Firebase');
    }
    $jwt .= '.'.rtrim(strtr(base64_encode($signature), '+/', '-_'), '=');
    $response = wp_remote_post('https://oauth2.googleapis.com/token', array(
        'timeout'=>20,
        'body'=>array('grant_type'=>'urn:ietf:params:oauth:grant-type:jwt-bearer','assertion'=>$jwt),
    ));
    if (is_wp_error($response)) return $response;
    $body = json_decode(wp_remote_retrieve_body($response), true);
    if (wp_remote_retrieve_response_code($response) !== 200 || empty($body['access_token'])) {
        return new WP_Error('token_failed', 'تعذر الحصول على تصريح Firebase');
    }
    return $body['access_token'];
}

function altaawun_fcm_send($title, $message, $url = '') {
    $token = altaawun_fcm_access_token();
    if (is_wp_error($token)) return $token;
    // Compatible with the single tone/vibration topic used by existing builds.
    // Do not send a second copy to altaawun_updates: new clients also listen
    // there for backwards compatibility and would otherwise get duplicates.
    $failed = array();
    foreach (array('urgent', 'news', 'soft', 'default') as $tone) {
        foreach (array('vibrate', 'silent') as $mode) {
            $topic = 'altaawun_tone_'.$tone.'_'.$mode;
            $payload = array('message'=>array(
                'topic'=>$topic,
                'notification'=>array('title'=>wp_strip_all_tags($title), 'body'=>wp_strip_all_tags($message)),
                'data'=>array('url'=>esc_url_raw($url), 'type'=>'normal'),
                'android'=>array(
                    'priority'=>'NORMAL',
                    'notification'=>array(
                        'channel_id'=>'altaawun_tone_v2_'.$tone.'_'.$mode,
                        'default_vibrate_timings'=>$mode==='vibrate',
                    ),
                ),
                'apns'=>array(
                    'headers'=>array('apns-push-type'=>'alert', 'apns-priority'=>'10'),
                    'payload'=>array('aps'=>array(
                        'sound'=>'default',
                        'thread-id'=>'altaawun-normal',
                    )),
                ),
            ));
            $response = wp_remote_post(
                'https://fcm.googleapis.com/v1/projects/al-taawun-charity/messages:send',
                array('timeout'=>12,'headers'=>array(
                    'Authorization'=>'Bearer '.$token,
                    'Content-Type'=>'application/json; charset=utf-8',
                ),'body'=>wp_json_encode($payload))
            );
            if (is_wp_error($response) || wp_remote_retrieve_response_code($response) !== 200) {
                $failed[] = $topic;
            }
        }
    }
    if ($failed) return new WP_Error('partial_send', 'تعذر الإرسال إلى قنوات: '.implode(', ', $failed));
    return true;
}

add_action('transition_post_status', function ($new, $old, $post) {
    if ($new !== 'publish' || $old === 'publish') return;
    if (!in_array($post->post_type, array('post','product'), true)) return;
    if (wp_is_post_revision($post->ID)) return;
    if (get_post_meta($post->ID, '_altaawun_push_sent', true)) return;
    $title = get_the_title($post);
    $type = $post->post_type === 'product' ? 'حملة أو حالة كفالة جديدة' : 'مقال جديد';
    $sent = altaawun_fcm_send('جمعية التعاون الخيرية', $type.': '.$title, get_permalink($post));
    if (!is_wp_error($sent)) update_post_meta($post->ID, '_altaawun_push_sent', '1');
}, 10, 3);

add_action('admin_menu', function () {
    add_menu_page('إشعارات التطبيق', 'إشعارات التطبيق', 'manage_options',
        'altaawun-push', 'altaawun_push_admin_page', 'dashicons-bell', 31);
});

function altaawun_push_admin_page() {
    if (!current_user_can('manage_options')) return;
    echo '<div class="wrap"><h1>إشعارات تطبيق جمعية التعاون الخيرية</h1>';
    if (isset($_POST['altaawun_push_submit'])) {
        check_admin_referer('altaawun_push_send');
        $title = sanitize_text_field(wp_unslash($_POST['push_title'] ?? ''));
        $body = sanitize_textarea_field(wp_unslash($_POST['push_body'] ?? ''));
        $url = esc_url_raw(wp_unslash($_POST['push_url'] ?? ''));
        if (!$title || !$body) {
            echo '<div class="notice notice-error"><p>العنوان والنص مطلوبان.</p></div>';
        } else {
            $result = altaawun_fcm_send($title, $body, $url);
            echo is_wp_error($result)
                ? '<div class="notice notice-error"><p>'.esc_html($result->get_error_message()).'</p></div>'
                : '<div class="notice notice-success"><p>تم إرسال الإشعار إلى المشتركين.</p></div>';
        }
    }
    echo '<p>تُرسل الإشعارات التلقائية عند نشر مقال أو منتج WooCommerce جديد فقط. لا تُرسل عند التعديل.</p>';
    echo '<form method="post">';
    wp_nonce_field('altaawun_push_send');
    echo '<p><label>عنوان الإشعار<br><input name="push_title" class="regular-text" required></label></p>';
    echo '<p><label>نص الإشعار<br><textarea name="push_body" rows="4" class="large-text" required></textarea></label></p>';
    echo '<p><label>رابط المحتوى (اختياري)<br><input name="push_url" type="url" class="regular-text"></label></p>';
    submit_button('إرسال الإشعار', 'primary', 'altaawun_push_submit');
    echo '</form></div>';
}
