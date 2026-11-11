<?php
/**
 * Plugin Name: Altaawun Member Backup
 * Description: حفظ واستعادة تفضيلات أعضاء تطبيق جمعية التعاون الخيرية وسلة WooCommerce بعد تسجيل الدخول.
 * Version: 1.0.1
 * Author: Altaawun Charity
 * Requires Plugins: woocommerce
 */
defined('ABSPATH') || exit;

const ALTAAWUN_BACKUP_META = '_altaawun_member_app_backup_v1';
const ALTAAWUN_CART_META = '_altaawun_member_saved_cart_v1';

/**
 * Reuse the installed Altaawun authentication service. Never accept a client-
 * supplied WordPress user ID or a decoded-but-unverified JWT as identity.
 * Fail closed if /me is unavailable. The REST endpoint is same-origin only.
 */
function altaawun_backup_member(WP_REST_Request $request) {
    $header = trim((string) $request->get_header('authorization'));
    if (!preg_match('/^Bearer\\s+([^\\s]+)$/i', $header, $match)) {
        return new WP_Error('missing_auth', 'سجل الدخول إلى حسابك أولًا.', array('status' => 401));
    }
    $verify = wp_remote_get(rest_url('altaawun-app/v1/me'), array(
        'headers' => array('Authorization' => 'Bearer ' . $match[1], 'Accept' => 'application/json'),
        'timeout' => 8, 'redirection' => 0, 'sslverify' => true,
    ));
    if (is_wp_error($verify) || wp_remote_retrieve_response_code($verify) !== 200) {
        return new WP_Error('session_expired', 'تعذر التحقق من حساب العضو.', array('status' => 401));
    }
    $payload = json_decode(wp_remote_retrieve_body($verify), true);
    $id = is_array($payload) && isset($payload['user']['id'])
        ? absint($payload['user']['id']) : 0;
    if (!$id || !get_user_by('id', $id)) {
        return new WP_Error('invalid_auth', 'جلسة العضو غير صالحة.', array('status' => 401));
    }
    return $id;
}

function altaawun_backup_allowed_keys() {
    return array(
        'app_font', 'app_font_size', 'notification_tone',
        'notification_vibration', 'home_tile_size',
        'home_wp_category_order', 'home_wp_category_hidden',
        'home_wp_category_colors', 'home_wp_category_text_colors',
        'home_wp_category_icon_colors', 'home_category_order',
        'home_category_hidden', 'home_custom_categories',
    );
}

function altaawun_backup_clean_preferences($input) {
    if (!is_array($input)) {
        return new WP_Error('invalid_backup', 'بيانات النسخة الاحتياطية غير صحيحة.', array('status' => 400));
    }
    $output = array();
    $list_keys = array('home_wp_category_order', 'home_wp_category_hidden',
        'home_category_order', 'home_category_hidden', 'home_custom_categories');
    $color_keys = array('home_wp_category_colors', 'home_wp_category_text_colors',
        'home_wp_category_icon_colors');
    foreach (altaawun_backup_allowed_keys() as $key) {
        if (!array_key_exists($key, $input)) continue;
        $value = $input[$key];
        if ($key === 'notification_vibration') {
            if (!is_bool($value)) return new WP_Error('invalid_backup', $key, array('status' => 400));
            $output[$key] = $value;
        } elseif (in_array($key, $list_keys, true)) {
            if (!is_array($value) || count($value) > 100) {
                return new WP_Error('invalid_backup', $key, array('status' => 400));
            }
            $output[$key] = array_values(array_map(static function ($x) {
                return substr(sanitize_text_field((string)$x), 0, 180);
            }, $value));
        } elseif (in_array($key, $color_keys, true)) {
            if (!is_array($value) || count($value) > 100) {
                return new WP_Error('invalid_backup', $key, array('status' => 400));
            }
            $colors = array();
            foreach ($value as $category => $color) {
                if (!is_numeric($color) || $color < 0 || $color > 4294967295) continue;
                $colors[substr(sanitize_text_field((string)$category), 0, 80)] = (int)$color;
            }
            $output[$key] = $colors;
        } else {
            if (!is_string($value) || strlen($value) > 100) {
                return new WP_Error('invalid_backup', $key, array('status' => 400));
            }
            $output[$key] = sanitize_text_field($value);
        }
    }
    return $output;
}

add_action('rest_api_init', static function () {
    register_rest_route('altaawun-app/v1', '/member-backup', array(
        array(
            'methods' => WP_REST_Server::READABLE,
            'permission_callback' => '__return_true',
            'callback' => static function (WP_REST_Request $request) {
                $id = altaawun_backup_member($request);
                if (is_wp_error($id)) return $id;
                $saved = get_user_meta($id, ALTAAWUN_BACKUP_META, true);
                $cart = get_user_meta($id, ALTAAWUN_CART_META, true);
                return rest_ensure_response(array(
                    'user_id' => $id,
                    'has_backup' => is_array($saved) && isset($saved['preferences']),
                    'preferences' => is_array($saved) ? ($saved['preferences'] ?? array()) : array(),
                    'updated_at' => is_array($saved) ? ($saved['updated_at'] ?? '') : '',
                    'saved_cart_count' => is_array($cart)
                        ? array_sum(array_map(static function ($item) { return absint($item['quantity'] ?? 0); }, $cart))
                        : 0,
                ));
            },
        ),
        array(
            'methods' => WP_REST_Server::CREATABLE,
            'permission_callback' => '__return_true',
            'callback' => static function (WP_REST_Request $request) {
                $id = altaawun_backup_member($request);
                if (is_wp_error($id)) return $id;
                $body = $request->get_json_params();
                if (!is_array($body) || !isset($body['preferences'])) {
                    return new WP_Error('invalid_backup', 'لم يتم إرسال التفضيلات.', array('status' => 400));
                }
                $prefs = altaawun_backup_clean_preferences($body['preferences']);
                if (is_wp_error($prefs)) return $prefs;
                $data = array('preferences' => $prefs, 'updated_at' => gmdate('c'));
                update_user_meta($id, ALTAAWUN_BACKUP_META, $data);
                return rest_ensure_response(array('saved' => true, 'user_id' => $id,
                    'updated_at' => $data['updated_at']));
            },
        ),
    ));
});

/**
 * Store only WooCommerce product IDs/variations/quantity. Never write payment
 * data, addresses, or raw session/cart objects into user metadata.
 */
function altaawun_backup_cart_snapshot() {
    if (empty($GLOBALS['altaawun_cart_restoring']) && is_user_logged_in()
        && function_exists('WC') && WC()->cart) {
        $items = array();
        foreach (WC()->cart->get_cart() as $item) {
            $product_id = absint($item['product_id'] ?? 0);
            $variation_id = absint($item['variation_id'] ?? 0);
            $quantity = absint($item['quantity'] ?? 0);
            if (!$product_id || !$quantity) continue;
            // Quick-donation carts depend on a signed one-time amount token.
            // Do not restore them as ordinary products with a placeholder price.
            if (function_exists('alta_qd_product_id') &&
                $product_id === alta_qd_product_id()) continue;
            $items[] = array(
                'product_id' => $product_id,
                'variation_id' => $variation_id,
                'quantity' => min($quantity, 1000),
                'variation' => isset($item['variation']) && is_array($item['variation'])
                    ? array_map('sanitize_text_field', $item['variation']) : array(),
            );
        }
        update_user_meta(get_current_user_id(), ALTAAWUN_CART_META, $items);
    }
}
add_action('woocommerce_add_to_cart', 'altaawun_backup_cart_snapshot', 99);
add_action('woocommerce_cart_updated', 'altaawun_backup_cart_snapshot', 99);
add_action('woocommerce_cart_item_removed', 'altaawun_backup_cart_snapshot', 99);
add_action('woocommerce_after_cart_item_quantity_update', 'altaawun_backup_cart_snapshot', 99);

add_action('woocommerce_cart_emptied', static function () {
    if (is_user_logged_in() && empty($GLOBALS['altaawun_cart_restoring'])) {
        update_user_meta(get_current_user_id(), ALTAAWUN_CART_META, array());
    }
}, 99);

/**
 * Restore only if the current authenticated WooCommerce cart is empty.
 * Existing live carts take priority. Invalid/out-of-stock items are skipped by WC.
 * Completed sponsorship orders always remain WooCommerce orders, not cart items.
 */
add_action('woocommerce_cart_loaded_from_session', static function ($cart) {
    if (!is_user_logged_in() || !$cart || !$cart->is_empty()) return;
    $saved = get_user_meta(get_current_user_id(), ALTAAWUN_CART_META, true);
    if (!is_array($saved) || !$saved) return;
    $GLOBALS['altaawun_cart_restoring'] = true;
    try {
        foreach ($saved as $item) {
            $id = absint($item['product_id'] ?? 0);
            $quantity = absint($item['quantity'] ?? 0);
            if (!$id || !$quantity) continue;
            if (function_exists('alta_qd_product_id') &&
                $id === alta_qd_product_id()) continue;
            $cart->add_to_cart($id, min($quantity, 1000),
                absint($item['variation_id'] ?? 0),
                isset($item['variation']) && is_array($item['variation'])
                    ? $item['variation'] : array());
        }
    } finally {
        $GLOBALS['altaawun_cart_restoring'] = false;
    }
}, 30);
