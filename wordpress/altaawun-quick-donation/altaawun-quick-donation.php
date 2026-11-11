<?php
/**
 * Plugin Name: Altaawun Quick Donation
 * Description: تفعيل أو تعطيل زر تبرع الآن في تطبيق الجمعية، مع التصنيفات والمبالغ والدفع عبر WooCommerce.
 * Version: 1.3.0
 * Author: Altaawun Charity
 * Requires Plugins: woocommerce
 */
defined('ABSPATH') || exit;

define('ALTA_QD_OPTION', 'altaawun_quick_donation_v1');
define('ALTA_QD_PRODUCT_OPTION', 'altaawun_quick_donation_product_v1');
define('ALTA_QD_SESSION_TTL', 600);
define('ALTA_QD_CBI_OPTION', 'altaawun_qd_cbi_rate_v1');
define('ALTA_QD_CBI_URL', 'https://cbi.iq/?pid=Home');
define('ALTA_QD_CBI_CRON', 'altaawun_qd_refresh_cbi');
define('ALTA_QD_FX_MAX_AGE', 3 * DAY_IN_SECONDS);

function alta_qd_defaults() {
    return array(
        'enabled' => 0,
        'categories' => "general|التبرعات العامة\norphans|كفالة الأيتام\neducation|المدرسة والتعليم\nfood|السلة الغذائية",
        'amounts' => '',
        // Optional display-only conversion. WooCommerce itself stays in IQD.
        // No rate is guessed: an admin must publish and periodically refresh it.
        'usd_to_iqd_rate' => '',
        'usd_rate_updated_at' => 0,
        'auto_rate_enabled' => 1,
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
    // All quick donations are denominated and charged in Iraqi dinars.
    // Do NOT silently change the global WooCommerce store currency.
    return array(1000, 10000000);
}

/**
 * The official CBI website publishes a visible USD row on its home page.
 * This is a trusted, fixed-domain HTML data source, NOT an official CBI API.
 * We never guess a conversion rate or use untrusted provider domains.
 */
function alta_qd_parse_cbi_html($html) {
    if (!is_string($html) || strlen($html) > 1000000) return 0;
    $rows = array();
    if (preg_match_all('/<tr\b[^>]*>.*?<\/tr>/is', $html, $matches)) {
        $rows = $matches[0];
    }
    // Prefer a single USD table row so that unrelated page figures cannot
    // accidentally be interpreted as the USD exchange rate.
    foreach ($rows as $row) {
        $text = html_entity_decode(
            preg_replace('/<[^>]+>/', ' ', $row), ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $text = preg_replace('/\s+/u', ' ', $text);
        if (preg_match('/U\.?\s*S\.?\s*dollar\s+USD\s+([0-9]{3,5}(?:\.[0-9]{1,3})?)/i', $text, $m)) {
            $rate = (float)$m[1];
            return is_finite($rate) && $rate >= 100 && $rate <= 10000 ? $rate : 0;
        }
    }
    // The public CBI page is HTML, not a documented machine API. If its
    // layout changes, fail closed rather than scraping unrelated currencies.
    return 0;
}
function alta_qd_refresh_cbi_rate() {
    $old = (array)get_option(ALTA_QD_CBI_OPTION, array());
    $now = time();
    $result = array_merge($old, array('last_attempt' => $now, 'last_error' => ''));
    if (empty(alta_qd_options()['auto_rate_enabled'])) {
        $result['last_error'] = 'التحديث التلقائي غير مفعّل';
        update_option(ALTA_QD_CBI_OPTION, $result, false);
        return false;
    }
    $response = wp_safe_remote_get(ALTA_QD_CBI_URL, array(
        'timeout' => 15, 'redirection' => 0, 'sslverify' => true,
        'limit_response_size' => 1000000,
        'headers' => array('Accept' => 'text/html'),
    ));
    if (is_wp_error($response)) {
        $result['last_error'] = 'تعذر الاتصال بموقع البنك المركزي';
    } elseif ((int)wp_remote_retrieve_response_code($response) !== 200) {
        $result['last_error'] = 'موقع البنك المركزي لم يُرجع صفحة صحيحة';
    } else {
        $rate = alta_qd_parse_cbi_html(wp_remote_retrieve_body($response));
        if (!$rate) {
            $result['last_error'] = 'لم يُعثر على سعر USD بصيغة موثوقة في الصفحة الرسمية';
        } else {
            $old_rate = (float)($old['rate'] ?? 0);
            if ($old_rate > 0 && abs($rate - $old_rate) / $old_rate > 0.25) {
                $result['last_error'] = 'تغير السعر بأكثر من 25٪ ويحتاج مراجعة يدوية';
            } else {
                $result['rate'] = $rate;
                $result['updated_at'] = $now;
                $result['source_url'] = ALTA_QD_CBI_URL;
                $result['last_error'] = '';
            }
        }
    }
    update_option(ALTA_QD_CBI_OPTION, $result, false);
    return empty($result['last_error']);
}
add_action(ALTA_QD_CBI_CRON, 'alta_qd_refresh_cbi_rate');
add_action('init', static function () {
    if (!wp_next_scheduled(ALTA_QD_CBI_CRON)) {
        wp_schedule_event(time() + 60, 'twicedaily', ALTA_QD_CBI_CRON);
    }
});
register_deactivation_hook(__FILE__, static function () {
    wp_clear_scheduled_hook(ALTA_QD_CBI_CRON);
});
add_action('admin_post_altaawun_qd_refresh_cbi', static function () {
    if (!current_user_can('manage_options')) wp_die('غير مصرح');
    check_admin_referer('altaawun_qd_refresh_cbi');
    $last = (array)get_option(ALTA_QD_CBI_OPTION, array());
    if (time() - absint($last['last_attempt'] ?? 0) >= 60) {
        alta_qd_refresh_cbi_rate();
    }
    wp_safe_redirect(admin_url('options-general.php?page=altaawun-quick-donation&fx_checked=1'));
    exit;
});

/**
 * Prioritize a freshly VERIFIED CBI home-page rate. If it cannot be read or
 * becomes stale, use a recently approved manual rate. No silent stale FX.
 * Currency paid to WooCommerce stays IQD regardless of display preference.
 */
function alta_qd_usd_quote() {
    $config = alta_qd_options();
    $cbi = (array)get_option(ALTA_QD_CBI_OPTION, array());
    $current = function_exists('get_woocommerce_currency')
        && get_woocommerce_currency() === 'IQD';
    $manual_rate = (float)($config['usd_to_iqd_rate'] ?? 0);
    $manual_time = absint($config['usd_rate_updated_at'] ?? 0);
    $auto_rate = (float)($cbi['rate'] ?? 0);
    $auto_time = absint($cbi['updated_at'] ?? 0);
    $is_recent = static function ($rate, $updated) {
        return is_finite($rate) && $rate >= 100 && $rate <= 10000 &&
            $updated > 0 && $updated <= time() &&
            (time() - $updated) <= ALTA_QD_FX_MAX_AGE;
    };
    $automatic_valid = !empty($config['auto_rate_enabled']) &&
        $is_recent($auto_rate, $auto_time);
    $manual_valid = $is_recent($manual_rate, $manual_time);
    $rate = $automatic_valid ? $auto_rate : ($manual_valid ? $manual_rate : 0);
    $stamp = $automatic_valid ? $auto_time : ($manual_valid ? $manual_time : 0);
    $source = $automatic_valid ? 'cbi_auto' : ($manual_valid ? 'manual_fallback' : 'unavailable');
    return array(
        'enabled' => $current && $rate > 0,
        'rate' => $rate,
        'updated_at' => $stamp,
        'source' => $source,
        'source_url' => $automatic_valid ? ALTA_QD_CBI_URL : '',
        'store_currency_iqd' => $current,
        'auto_checked_at' => absint($cbi['last_attempt'] ?? 0),
    );
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
        && function_exists('get_woocommerce_currency')
        && get_woocommerce_currency() === 'IQD'
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
        'auto_rate_enabled' => empty($raw['auto_rate_enabled']) ? 0 : 1,
        'categories' => $categories ? implode("\n", $categories) : alta_qd_defaults()['categories'],
        'amounts' => isset($raw['amounts'])
            ? substr(preg_replace('/[^0-9,; ]/', '', (string)$raw['amounts']), 0, 200) : '',
        'gateway_visa' => sanitize_key($raw['gateway_visa'] ?? ''),
        'gateway_mastercard' => sanitize_key($raw['gateway_mastercard'] ?? ''),
        'gateway_zaincash' => sanitize_key($raw['gateway_zaincash'] ?? ''),
        'gateway_qicard' => sanitize_key($raw['gateway_qicard'] ?? ''),
    );
    $input_rate = trim(sanitize_text_field(wp_unslash((string)($raw['usd_to_iqd_rate'] ?? ''))));
    if ($input_rate !== '' && preg_match('/^\\d{3,5}(?:\\.\\d{1,2})?$/', $input_rate)) {
        $numeric_rate = (float)$input_rate;
        if ($numeric_rate >= 100 && $numeric_rate <= 10000) {
            $clean['usd_to_iqd_rate'] = $input_rate;
            // Saving this field is the administrator's explicit rate review.
            $clean['usd_rate_updated_at'] = time();
        }
    }
    if (!isset($clean['usd_to_iqd_rate'])) {
        $clean['usd_to_iqd_rate'] = '';
        $clean['usd_rate_updated_at'] = 0;
    }
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
    $quote = alta_qd_usd_quote();
    echo '<tr><th>سعر الصرف التلقائي</th><td><label><input type="checkbox" name="'
        . esc_attr(ALTA_QD_OPTION) . '[auto_rate_enabled]" value="1" '
        . checked(!empty($config['auto_rate_enabled']), true, false)
        . '> تحديث السعر تلقائيًا من الصفحة الرسمية للبنك المركزي العراقي (الأولوية)</label>';
    echo '<p><a href="' . esc_url(ALTA_QD_CBI_URL)
        . '" target="_blank" rel="noopener noreferrer">مصدر سعر الدولار: البنك المركزي العراقي</a></p>';
    $cbi = (array)get_option(ALTA_QD_CBI_OPTION, array());
    if (!empty($cbi['updated_at'])) {
        echo '<p>آخر سعر تلقائي ناجح: <strong>' . esc_html((string)($cbi['rate'] ?? ''))
            . ' دينار/دولار</strong> — '
            . esc_html(wp_date('Y-m-d H:i', absint($cbi['updated_at']))) . '</p>';
    }
    if (!empty($cbi['last_error'])) {
        echo '<p style="color:#9b1c1c">تنبيه التحديث: '
            . esc_html($cbi['last_error']) . '</p>';
    }
    echo '<p class="description">يحاول الموقع التحديث مرتين يوميًا وفق WP-Cron. إذا فشل أو أصبح السعر قديمًا، ينتقل إلى السعر اليدوي الحديث فقط. لم يُتحقق بعد من إمكانية اتصال استضافة الجمعية بالموقع الرسمي.</p></td></tr>';
    echo '<tr><th>السعر اليدوي الاحتياطي</th><td><label>1 دولار أمريكي = <input type="number" step="0.01" min="100" max="10000" name="'
        . esc_attr(ALTA_QD_OPTION) . '[usd_to_iqd_rate]" value="'
        . esc_attr($config['usd_to_iqd_rate'] ?? '') . '" placeholder="يُدخل السعر المعتمد من الجمعية"> دينار عراقي</label>';
    echo '<p class="description">يُستخدم هذا السعر عند فشل السعر التلقائي فقط. يجب أن تعتمده الجمعية ويظل صالحًا لمدة 3 أيام بعد الحفظ.</p>';
    if (!empty($quote['updated_at'])) {
        echo '<p>آخر اعتماد للسعر: ' . esc_html(wp_date('Y-m-d H:i', $quote['updated_at'])) . '</p>';
    }
    $source_label = $quote['source'] === 'cbi_auto' ? 'تلقائي — البنك المركزي العراقي'
        : ($quote['source'] === 'manual_fallback' ? 'يدوي احتياطي' : 'لا يوجد سعر صالح');
    echo '<p><strong>السعر المستخدم حاليًا: ' . esc_html($source_label) . '</strong>';
    if ($quote['enabled']) {
        echo ' — ' . esc_html((string)$quote['rate']) . ' IQD/USD';
        echo ' — آخر تحقق: ' . esc_html(wp_date('Y-m-d H:i', $quote['updated_at']));
    }
    echo '</p></td></tr>';
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
    echo '</form>';
    echo '<form method="post" action="' . esc_url(admin_url('admin-post.php')) . '">';
    echo '<input type="hidden" name="action" value="altaawun_qd_refresh_cbi">';
    wp_nonce_field('altaawun_qd_refresh_cbi');
    submit_button('جلب السعر الرسمي الآن', 'secondary', 'submit', false);
    echo '</form>';
    echo '<p>حالة الواجهة: <strong>'
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
                'currency' => 'IQD',
                'store_currency' => function_exists('get_woocommerce_currency')
                    ? get_woocommerce_currency() : '',
                'usd_available' => alta_qd_usd_quote()['enabled'],
                'usd_to_iqd_rate' => alta_qd_usd_quote()['enabled']
                    ? alta_qd_usd_quote()['rate'] : null,
                'usd_rate_updated_at' => alta_qd_usd_quote()['updated_at'],
                'usd_rate_source' => alta_qd_usd_quote()['source'],
                'usd_source_url' => alta_qd_usd_quote()['source_url'],
                'usd_auto_last_checked' => alta_qd_usd_quote()['auto_checked_at'],
                'usd_amounts' => array(5, 10, 25, 50, 100),
                'usd_min_amount' => 1,
                'usd_max_amount' => alta_qd_usd_quote()['enabled']
                    ? (int)floor($maximum / alta_qd_usd_quote()['rate']) : 0,
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
            $original_amount = (int)$amount_raw;
            $original_currency = strtoupper(sanitize_text_field(
                (string)($request->get_param('currency') ?: 'IQD')));
            if (!in_array($original_currency, array('IQD', 'USD'), true)) {
                return new WP_Error('invalid_currency', 'عملة التبرع غير معتمدة.', array('status' => 400));
            }
            $usd_quote = alta_qd_usd_quote();
            if ($original_currency === 'USD' && !$usd_quote['enabled']) {
                return new WP_Error('rate_unavailable', 'سعر الدولار غير متاح أو انتهت صلاحيته. يرجى اختيار الدينار.', array('status' => 503));
            }
            $amount = $original_currency === 'USD'
                ? (int)round($original_amount * $usd_quote['rate']) : $original_amount;
            if ($amount < $min || $amount > $max || !isset($categories[$category])) {
                return new WP_Error('invalid_donation', 'التصنيف أو المبلغ غير صالح.', array('status' => 400));
            }
            $expected = $request->get_param('expected_amount_iqd');
            if ($original_currency === 'USD' &&
                (!is_scalar($expected) || !ctype_digit((string)$expected) ||
                (int)$expected !== $amount)) {
                return new WP_Error('rate_changed', 'تغير سعر الصرف؛ راجع المبلغ المحوّل وأعد المحاولة.', array('status' => 409));
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
                'original_currency' => $original_currency,
                'original_amount' => $original_amount,
                'usd_to_iqd_rate' => $original_currency === 'USD'
                    ? $usd_quote['rate'] : null,
                'usd_rate_source' => $original_currency === 'USD'
                    ? $usd_quote['source'] : null,
                'usd_rate_at' => $original_currency === 'USD'
                    ? $usd_quote['updated_at'] : null,
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
                'original_currency' => $payload['original_currency'] ?? 'IQD',
                'original_amount' => $payload['original_amount'] ?? $payload['amount'],
                'usd_to_iqd_rate' => $payload['usd_to_iqd_rate'] ?? null,
                'usd_rate_source' => $payload['usd_rate_source'] ?? null,
                'usd_rate_at' => $payload['usd_rate_at'] ?? null,
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
        if (($qd['original_currency'] ?? 'IQD') === 'USD') {
            $data[] = array('key' => 'المبلغ المختار بالدولار',
                'value' => absint($qd['original_amount'] ?? 0) . ' USD');
            $data[] = array('key' => 'سعر التحويل المعتمد',
                'value' => sanitize_text_field((string)($qd['usd_to_iqd_rate'] ?? ''))
                    . ' IQD / USD');
        }
    }
    return $data;
}, 10, 2);
add_action('woocommerce_checkout_create_order_line_item', static function ($item, $cart_item_key, $values) {
    $qd = $values['altaawun_qd'] ?? null;
    if (!is_array($qd)) return;
    $item->add_meta_data('وجهة التبرع', sanitize_text_field($qd['label'] ?? ''), true);
    $item->add_meta_data('عملة المبلغ المختار',
        sanitize_text_field($qd['original_currency'] ?? 'IQD'), true);
    $item->add_meta_data('المبلغ المختار',
        absint($qd['original_amount'] ?? $qd['amount'] ?? 0), true);
    if (($qd['original_currency'] ?? '') === 'USD') {
        $item->add_meta_data('سعر الدولار بالدينار عند التبرع',
            sanitize_text_field((string)($qd['usd_to_iqd_rate'] ?? '')), true);
        $item->add_meta_data('مصدر سعر الصرف',
            ($qd['usd_rate_source'] ?? '') === 'cbi_auto'
                ? 'البنك المركزي العراقي — تلقائي' : 'معتمد يدويًا من الجمعية', true);
        $item->add_meta_data('وقت اعتماد سعر الصرف',
            wp_date('Y-m-d H:i', absint($qd['usd_rate_at'] ?? 0)), true);
    }
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
