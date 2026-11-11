<?php
/**
 * Plugin Name: Altaawun Quick Donation
 * Description: تفعيل أو تعطيل زر تبرع الآن في تطبيق الجمعية، مع التصنيفات والمبالغ والدفع عبر WooCommerce.
 * Version: 1.1.1
 * Author: Altaawun Charity
 * Requires Plugins: woocommerce
 */
defined('ABSPATH') || exit;

define('ALTA_QD_OPTION', 'altaawun_quick_donation_v1');
define('ALTA_QD_PRODUCT_OPTION', 'altaawun_quick_donation_product_v1');
define('ALTA_QD_SESSION_TTL', 600);

function alta_qd_defaults() {
    return array(
        'enabled' => 0,
        'categories' => "general|التبرعات العامة\norphans|كفالة الأيتام\neducation|المدرسة والتعليم\nfood|السلة الغذائية",
        'amounts' => '',
        // Use WooCommerce's actual gateway IDs. Nothing is shown to a donor
        // until a gateway is installed, enabled and mapped by the administrator.
        'gateway_visa' => '',
        'gateway_mastercard' => '',
        'gateway_zaincash' => '',
        'gateway_qicard' => '',
    );
}
function alta_qd_options() {
    return wp_parse_args((array) get_option(ALTA_QD_OPTION, array()), alta_qd_defaults());
}
function alta_qd_categories() {
    $items = array();
    foreach (array_slice(preg_split('/\r\n|\r|\n/', alta_qd_options()['categories']), 0, 30) as $line) {
        $parts = explode('|', $line, 2);
        if (count($parts) !== 2) continue;
        $key = sanitize_key(trim($parts[0]));
        $name = sanitize_text_field(trim($parts[1]));
        if ($key && $name && strlen($key) <= 40) $items[$key] = $name;
    }
    return $items;
}
function alta_qd_limits() {
    $currency = function_exists('get_woocommerce_currency') ? get_woocommerce_currency() : 'USD';
    return in_array($currency, array('IQD', 'IRR', 'LBP', 'SYP'), true)
        ? array(1000, 10000000) : array(1, 10000);
}
function alta_qd_amounts() {
    list($min, $max) = alta_qd_limits();
    $raw = trim((string) alta_qd_options()['amounts']);
    $default = $min >= 1000 ? array(5000,10000,25000,50000,100000) : array(5,10,25,50,100);
    if (!$raw) return $default;
    $amounts = array();
    foreach (array_slice(preg_split('/[\s,;]+/', $raw), 0, 20) as $part) {
        if (!ctype_digit($part)) continue;
        $amount = (int)$part;
        if ($amount >= $min && $amount <= $max) $amounts[] = $amount;
    }
    return array_values(array_unique($amounts)) ?: $default;
}
function alta_qd_product_id() {
    $id = absint(get_option(ALTA_QD_PRODUCT_OPTION, 0));
    if (!$id || !function_exists('wc_get_product')) return 0;
    $product = wc_get_product($id);
    return $product instanceof WC_Product ? $id : 0;
}
function alta_qd_create_product() {
    if (!class_exists('WC_Product_Simple')) return 0;
    $id = alta_qd_product_id();
    $product = $id ? wc_get_product($id) : new WC_Product_Simple();
    if (!$product) $product = new WC_Product_Simple();
    $product->set_name('تبرع سريع — جمعية التعاون الخيرية');
    $product->set_status('publish');
    $product->set_catalog_visibility('hidden');
    $product->set_virtual(true);
    $product->set_tax_status('none');
    $product->set_regular_price((string) alta_qd_limits()[0]);
    $product->set_price((string) alta_qd_limits()[0]);
    $id = $product->save();
    update_option(ALTA_QD_PRODUCT_OPTION, $id, false);
    return $id;
}
register_activation_hook(__FILE__, static function () {
    if (!get_option(ALTA_QD_OPTION)) add_option(ALTA_QD_OPTION, alta_qd_defaults(), '', false);
    alta_qd_create_product();
});
// The visible quick donation form is controlled ONLY by the administrator's
// on/off switch. Connecting a real payment gateway is a separate stage.
function alta_qd_enabled() {
    return !empty(alta_qd_options()['enabled']);
}

function alta_qd_checkout_ready() {
    return alta_qd_enabled()
        && class_exists('WooCommerce')
        && alta_qd_product_id() > 0
        && count(alta_qd_categories()) > 0
        && count(alta_qd_payment_methods()) > 0;
}
function alta_qd_clean_settings($raw) {
    $raw = is_array($raw) ? $raw : array();
    $categories = array();
    $input = isset($raw['categories']) ? (string)$raw['categories'] : '';
    foreach (array_slice(preg_split('/\r\n|\r|\n/', $input), 0, 30) as $line) {
        $parts = explode('|', wp_unslash($line), 2);
        if (count($parts) !== 2) continue;
        $key = sanitize_key(trim($parts[0]));
        $label = sanitize_text_field(trim($parts[1]));
        if ($key && $label && strlen($key) <= 40) {
            $categories[$key] = $key . '|' . $label;
        }
    }
    $clean = array(
        'enabled' => empty($raw['enabled']) ? 0 : 1,
        'categories' => $categories ? implode("\n", $categories) : alta_qd_defaults()['categories'],
        'amounts' => isset($raw['amounts'])
            ? substr(preg_replace('/[^0-9,; ]/', '', (string)$raw['amounts']), 0, 200) : '',
        'gateway_visa' => sanitize_key($raw['gateway_visa'] ?? ''),
        'gateway_mastercard' => sanitize_key($raw['gateway_mastercard'] ?? ''),
        'gateway_zaincash' => sanitize_key($raw['gateway_zaincash'] ?? ''),
        'gateway_qicard' => sanitize_key($raw['gateway_qicard'] ?? ''),
    );
    if ($clean['enabled']) alta_qd_create_product();
    return $clean;
}

/** The payment provider plugin owns money collection and signed callbacks. */
function alta_qd_active_gateways() {
    if (!function_exists('WC') || !WC() || !WC()->payment_gateways()) return array();
    $list = array();
    foreach (WC()->payment_gateways()->payment_gateways() as $gateway) {
        if (!is_object($gateway) || empty($gateway->id) ||
            $gateway->enabled !== 'yes' ||
            in_array(sanitize_key($gateway->id), array('cod', 'bacs', 'cheque'), true)) continue;
        $list[sanitize_key($gateway->id)] = wp_strip_all_tags($gateway->get_title());
    }
    return $list;
}
function alta_qd_payment_methods() {
    $map = array(
        'visa' => array('label'=>'Visa', 'key'=>'gateway_visa'),
        'mastercard' => array('label'=>'Mastercard', 'key'=>'gateway_mastercard'),
        'zaincash' => array('label'=>'زين كاش', 'key'=>'gateway_zaincash'),
        'qicard' => array('label'=>'كي كارد', 'key'=>'gateway_qicard'),
    );
    $active = alta_qd_active_gateways();
    $config = alta_qd_options();
    $result = array();
    foreach ($map as $id => $item) {
        $gateway = sanitize_key($config[$item['key']] ?? '');
        if ($gateway && isset($active[$gateway])) {
            $result[$id] = array('id'=>$id, 'name'=>$item['label'], 'gateway'=>$gateway);
        }
    }
    return $result;
}
add_action('admin_init', static function () {
    register_setting('alta_qd_group', ALTA_QD_OPTION, array(
        'type' => 'array', 'sanitize_callback' => 'alta_qd_clean_settings',
        'default' => alta_qd_defaults(),
    ));
});
add_action('admin_menu', static function () {
    add_options_page('التبرع السريع', 'التبرع السريع', 'manage_options',
        'altaawun-quick-donation', 'alta_qd_admin_page');
});
function alta_qd_admin_page() {
    if (!current_user_can('manage_options')) return;
    $config = alta_qd_options();
    echo '<div class="wrap"><h1>التبرع السريع — تطبيق الجمعية</h1>';
    echo '<p>زر «تبرع الآن» يظهر بمجرد تفعيله، حتى لو لم تُربط بوابات الدفع بعد. يبقى زر إتمام الدفع معطلاً حتى تفعيل بوابة حقيقية.</p>';
    if (!class_exists('WooCommerce')) echo '<div class="notice notice-error"><p>يجب تفعيل WooCommerce أولًا.</p></div>';
    echo '<form method="post" action="options.php">';
    settings_fields('alta_qd_group');
    echo '<table class="form-table"><tbody>';
    echo '<tr><th>إظهار الزر</th><td><label><input type="checkbox" name="' . esc_attr(ALTA_QD_OPTION) . '[enabled]" value="1" '
        . checked(!empty($config['enabled']), true, false) . '> تفعيل «تبرع الآن» داخل التطبيق</label></td></tr>';
    echo '<tr><th>التصنيفات</th><td><textarea class="large-text" rows="6" name="' . esc_attr(ALTA_QD_OPTION)
        . '[categories]">' . esc_textarea($config['categories']) . '</textarea>'
        . '<p class="description">كل تصنيف على سطر بصيغة key|اسم التصنيف. يمكن تغييرها من هنا.</p></td></tr>';
    echo '<tr><th>المبالغ السريعة</th><td><input class="regular-text" name="' . esc_attr(ALTA_QD_OPTION)
        . '[amounts]" value="' . esc_attr($config['amounts']) . '" placeholder="5000,10000,25000,50000">'
        . '<p class="description">افصل المبالغ بفاصلة؛ اتركها فارغة لاستخدام القيم الافتراضية حسب عملة WooCommerce.</p></td></tr>';
    $gateways = alta_qd_active_gateways();
    echo '<tr><th>طرق الدفع المتاحة</th><td><p class="description">يظهر الخيار داخل التطبيق فقط إذا ربطته ببوابة WooCommerce مثبتة ومفعّلة. يمكن ربط Visa وMastercard بنفس بوابة QiCard إن أكد مزود الدفع دعمهما. لا تضع بيانات دخول حساسة هنا.</p>';
    $choices = array(
      'gateway_visa'=>'Visa', 'gateway_mastercard'=>'Mastercard',
      'gateway_zaincash'=>'زين كاش', 'gateway_qicard'=>'كي كارد'
    );
    foreach ($choices as $key => $label) {
        echo '<p><label>' . esc_html($label) . ' <select name="'
          . esc_attr(ALTA_QD_OPTION) . '[' . esc_attr($key) . ']">';
        echo '<option value="">غير مفعّل</option>';
        foreach ($gateways as $gateway_id => $title) {
            echo '<option value="' . esc_attr($gateway_id) . '"'
               . selected($config[$key] ?? '', $gateway_id, false) . '>'
               . esc_html($title . ' (' . $gateway_id . ')') . '</option>';
        }
        echo '</select></label></p>';
    }
    echo '</td></tr></tbody></table>';
    submit_button('حفظ إعدادات التبرع السريع');
    echo '</form><p>حالة الواجهة: <strong>'
        . (alta_qd_enabled() ? 'مفعّلة' : 'معطلة') . '</strong></p>';
    echo '<p>حالة الدفع: <strong>'
        . (alta_qd_checkout_ready() ? 'جاهز من ناحية إعدادات النظام — اختبر بوابات الدفع قبل الإطلاق' : 'غير مفعّل حتى إعداد بوابة دفع فعلية') . '</strong></p>';
    echo '</div>';
}
add_action('rest_api_init', static function () {
    register_rest_route('altaawun/v1', '/quick-donation', array(
        'methods' => WP_REST_Server::READABLE,
        'permission_callback' => '__return_true',
        'callback' => static function () {
            $enabled = alta_qd_enabled();
            list($minimum, $maximum) = alta_qd_limits();
            $categories = array();
            if ($enabled) {
                foreach (alta_qd_categories() as $key => $name) {
                    $categories[] = array('id' => $key, 'name' => $name);
                }
            }
            $response = rest_ensure_response(array(
                'enabled' => (bool)$enabled,
                'checkout_ready' => (bool)alta_qd_checkout_ready(),
                'categories' => $categories,
                'amounts' => $enabled ? alta_qd_amounts() : array(),
                'min_amount' => $minimum, 'max_amount' => $maximum,
                'currency' => function_exists('get_woocommerce_currency')
                    ? get_woocommerce_currency() : 'USD',
                'payment_methods' => $enabled ? array_values(alta_qd_payment_methods()) : array(),
            ));
            $response->header('Cache-Control', 'no-store, private, max-age=0');
            return $response;
        },
    ));
    register_rest_route('altaawun/v1', '/quick-donation/prepare', array(
        'methods' => WP_REST_Server::CREATABLE,
        'permission_callback' => '__return_true',
        'callback' => static function (WP_REST_Request $request) {
            if (!alta_qd_checkout_ready()) {
                return new WP_Error('donations_unavailable', 'التبرع السريع ظاهر للمعاينة لكن الدفع غير مفعّل حتى ربط بوابة إلكترونية.', array('status' => 503));
            }
            $category = sanitize_key((string)$request->get_param('category'));
            $categories = alta_qd_categories();
            $amount_raw = $request->get_param('amount');
            list($min,$max) = alta_qd_limits();
            if (!is_scalar($amount_raw) || !ctype_digit((string)$amount_raw)) {
                return new WP_Error('invalid_amount', 'أدخل مبلغًا صحيحًا.', array('status' => 400));
            }
            $amount = (int)$amount_raw;
            if ($amount < $min || $amount > $max || !isset($categories[$category])) {
                return new WP_Error('invalid_donation', 'التصنيف أو المبلغ غير صالح.', array('status' => 400));
            }
            $method_id = sanitize_key((string)$request->get_param('payment_method'));
            $methods = alta_qd_payment_methods();
            if (!isset($methods[$method_id])) {
                return new WP_Error('invalid_payment', 'طريقة الدفع غير مفعّلة.', array('status' => 400));
            }
            $notes = sanitize_textarea_field((string)$request->get_param('notes'));
            $nonce = wp_generate_password(32, false, false);
            set_transient('alta_qd_' . $nonce, array(
                'amount' => $amount, 'category' => $category,
                'label' => $categories[$category],
                'notes' => substr($notes, 0, 500),
                'payment_method' => $method_id,
                'gateway' => $methods[$method_id]['gateway'],
            ), ALTA_QD_SESSION_TTL);
            $signature = hash_hmac('sha256', $nonce, wp_salt('auth'));
            $link = add_query_arg(array('altaawun_qd' => $nonce,
                'qd_sig' => $signature), wc_get_cart_url());
            $response = rest_ensure_response(array('checkout_url' => esc_url_raw($link)));
            $response->header('Cache-Control', 'no-store, private');
            return $response;
        },
    ));
});

/** Consume a one-time, server-signed donation token on the WooCommerce web session. */
add_action('template_redirect', static function () {
    if (!isset($_GET['altaawun_qd'], $_GET['qd_sig'])) return;
    if (!alta_qd_checkout_ready() || !function_exists('WC') || !WC()->cart) {
        wp_die(esc_html__('خدمة التبرع غير متاحة حاليًا. يرجى المحاولة لاحقًا.'), '', array('response' => 503));
    }
    $nonce = sanitize_text_field(wp_unslash($_GET['altaawun_qd']));
    $received = sanitize_text_field(wp_unslash($_GET['qd_sig']));
    if (!preg_match('/^[a-zA-Z0-9]{32}$/', $nonce) ||
        !hash_equals(hash_hmac('sha256', $nonce, wp_salt('auth')), $received)) {
        wp_die('رابط التبرع غير صالح.', '', array('response' => 400));
    }
    $key = 'alta_qd_' . $nonce;
    $payload = get_transient($key);
    if (!is_array($payload)) {
        wp_die('انتهت صلاحية الرابط أو تم استخدامه. أعد اختيار التبرع.', '', array('response' => 410));
    }
    delete_transient($key); // A donation link may create at most one cart item.
    $GLOBALS['alta_qd_authorized'] = true;
    try {
        $added = WC()->cart->add_to_cart(alta_qd_product_id(), 1, 0, array(), array(
            'altaawun_qd' => array(
                'amount' => $payload['amount'],
                'category' => $payload['category'],
                'label' => $payload['label'],
                'notes' => $payload['notes'],
                'nonce' => $nonce,
            ),
        ));
    } finally {
        $GLOBALS['alta_qd_authorized'] = false;
    }
    if (!$added) {
        wp_die('تعذر إضافة التبرع إلى السلة. يرجى المحاولة مرة أخرى.', '', array('response' => 400));
    }
    // Preselect only the currently configured/enabled gateway; the checkout
    // still performs the provider's secure authorization and webhook flow.
    $methods = alta_qd_payment_methods();
    $selected_method = sanitize_key($payload['payment_method'] ?? '');
    if (isset($methods[$selected_method]) && WC()->session) {
        WC()->session->set('chosen_payment_method', $methods[$selected_method]['gateway']);
    }
    wp_safe_redirect(wc_get_checkout_url());
    exit;
}, 5);

// Prevent adding the hidden donation product at its placeholder base price.
add_filter('woocommerce_add_to_cart_validation', static function ($passed, $product_id) {
    if ($product_id === alta_qd_product_id() && empty($GLOBALS['alta_qd_authorized'])) {
        return false;
    }
    return $passed;
}, 10, 2);

add_action('woocommerce_before_calculate_totals', static function ($cart) {
    if (!$cart) return;
    foreach ($cart->get_cart() as $cart_item_key => $item) {
        if ((int)($item['product_id'] ?? 0) !== alta_qd_product_id()) continue;
        $qd = $item['altaawun_qd'] ?? null;
        list($min,$max) = alta_qd_limits();
        $amount = is_array($qd) ? absint($qd['amount'] ?? 0) : 0;
        if ($amount < $min || $amount > $max || !isset(alta_qd_categories()[$qd['category'] ?? ''])) {
            // Fail closed: an invalid donation must never be checked out at
            // an unintended placeholder amount.
            $cart->remove_cart_item($cart_item_key);
            continue;
        }
        $item['data']->set_price($amount);
    }
}, 20);
add_filter('woocommerce_get_item_data', static function ($data, $cart_item) {
    $qd = $cart_item['altaawun_qd'] ?? null;
    if (is_array($qd)) {
        $data[] = array('key' => 'وجهة التبرع', 'value' => sanitize_text_field($qd['label'] ?? ''));
    }
    return $data;
}, 10, 2);
add_action('woocommerce_checkout_create_order_line_item', static function ($item, $cart_item_key, $values) {
    $qd = $values['altaawun_qd'] ?? null;
    if (!is_array($qd)) return;
    $item->add_meta_data('وجهة التبرع', sanitize_text_field($qd['label'] ?? ''), true);
    if (!empty($qd['notes'])) $item->add_meta_data('ملاحظة المتبرع', sanitize_textarea_field($qd['notes']), true);
}, 10, 3);

// Saved carts created before this plugin was installed must never contain a
// donation product without its signed amount metadata.
add_action('woocommerce_cart_loaded_from_session', static function ($cart) {
    if (!$cart) return;
    foreach ($cart->get_cart() as $cart_item_key => $item) {
        if ((int)($item['product_id'] ?? 0) !== alta_qd_product_id()) continue;
        $qd = $item['altaawun_qd'] ?? null;
        list($min, $max) = alta_qd_limits();
        $value = is_array($qd) ? absint($qd['amount'] ?? 0) : 0;
        if ($value < $min || $value > $max ||
            !isset(alta_qd_categories()[$qd['category'] ?? ''])) {
            $cart->remove_cart_item($cart_item_key);
        }
    }
}, 100);
