<?php
/**
 * Plugin Name: Al-Taawun App Categories
 * Description: اختيار وترتيب تصنيفات ووردبريس التي تظهر في تطبيق جمعية التعاون الخيرية.
 * Version: 1.1.0
 * Requires PHP: 7.4
 */
if (!defined('ABSPATH')) exit;

add_action('admin_menu', function () {
    add_menu_page('تصنيفات التطبيق', 'تصنيفات التطبيق', 'manage_options', 'altaawun-app-categories', 'altaawun_render_app_categories', 'dashicons-screenoptions', 30);
});

function altaawun_render_app_categories() {
    if (!current_user_can('manage_options')) wp_die('غير مصرح');
    if (isset($_POST['altaawun_save'])) {
        // Both post categories and WooCommerce product categories are supported.
        check_admin_referer('altaawun_categories_save');
        $raw = isset($_POST['category_ids']) && is_array($_POST['category_ids'])
            ? wp_unslash($_POST['category_ids']) : array();
        $ids = array();
        foreach ($raw as $entry) {
            $parts = explode(':', sanitize_text_field($entry), 2);
            if (count($parts) !== 2 || !in_array($parts[0], array('category', 'product_cat'), true)) continue;
            $id = absint($parts[1]);
            if (!$id || !taxonomy_exists($parts[0])) continue;
            $term = get_term($id, $parts[0]);
            if (!$term || is_wp_error($term)) continue;
            $ids[] = $parts[0].':'.$id;
        }
        $ids = array_values(array_unique($ids));
        update_option('altaawun_app_category_ids', $ids, false);
        echo '<div class="notice notice-success"><p>تم حفظ تصنيفات التطبيق.</p></div>';
    }
    $selected = get_option('altaawun_app_category_ids', array());
    $taxonomies = array('category');
    if (taxonomy_exists('product_cat')) $taxonomies[] = 'product_cat';
    $terms = get_terms(array('taxonomy'=>$taxonomies,'hide_empty'=>false));
    if (is_wp_error($terms)) $terms = array();
    $by_key = array();
    foreach ($terms as $term) $by_key[$term->taxonomy.':'.$term->term_id] = $term;
    echo '<div class="wrap" dir="rtl"><h1>تصنيفات التطبيق</h1><p>اختر التصنيفات التي تظهر لجميع مستخدمي التطبيق. غيّر ترتيبها بأزرار الأعلى والأسفل ثم احفظ.</p>';
    echo '<form method="post">';
    wp_nonce_field('altaawun_categories_save');
    echo '<ul id="altaawun-selected" style="max-width:700px;list-style:none">';
    foreach ($selected as $id) {
        $key = is_numeric($id) ? 'category:'.absint($id) : $id;
        if (!isset($by_key[$key])) continue;
        $term = $by_key[$key];
        echo '<li style="padding:10px;margin:6px 0;background:#fff;border:1px solid #ccc"><input type="hidden" name="category_ids[]" value="'.esc_attr($key).'"><strong>'.esc_html($term->name).' ('.($term->taxonomy === 'product_cat' ? 'ووكومرس' : 'مقالات').')</strong> <button type="button" class="button move-up">↑</button> <button type="button" class="button move-down">↓</button> <button type="button" class="button remove-category">إزالة</button></li>';
    }
    echo '</ul><h2>إضافة تصنيف إلى التطبيق</h2><select id="altaawun-add-select"><option value="">اختر تصنيفًا</option>';
    foreach ($terms as $term) echo '<option value="'.esc_attr($term->taxonomy.':'.$term->term_id).'">'.esc_html($term->name).' — '.($term->taxonomy === 'product_cat' ? 'ووكومرس' : 'مقالات').'</option>';
    echo '</select> <button type="button" id="altaawun-add" class="button">إضافة</button>';
    submit_button('حفظ التصنيفات', 'primary', 'altaawun_save');
    echo '</form></div>';
    ?>
    <script>
    (function(){
      const list=document.getElementById('altaawun-selected'), select=document.getElementById('altaawun-add-select');
      document.getElementById('altaawun-add').addEventListener('click',()=>{
        const id=select.value;
        if(!id || list.querySelector('input[value="'+id+'"]')) return;
        const li=document.createElement('li');
        li.style.cssText='padding:10px;margin:6px 0;background:#fff;border:1px solid #ccc';
        const hidden=document.createElement('input');hidden.type='hidden';hidden.name='category_ids[]';hidden.value=id;
        const title=document.createElement('strong');title.textContent=select.options[select.selectedIndex].text;
        li.append(hidden,title);
        ['↑','↓','إزالة'].forEach((label,i)=>{const b=document.createElement('button');b.type='button';b.className='button '+['move-up','move-down','remove-category'][i];b.textContent=label;li.append(' ',b);});
        list.append(li);select.value='';
      });
      list.addEventListener('click',e=>{
        const li=e.target.closest('li');if(!li)return;
        if(e.target.classList.contains('remove-category'))li.remove();
        if(e.target.classList.contains('move-up')&&li.previousElementSibling)list.insertBefore(li,li.previousElementSibling);
        if(e.target.classList.contains('move-down')&&li.nextElementSibling)list.insertBefore(li.nextElementSibling,li);
      });
    })();
    </script>
    <?php
}

add_action('rest_api_init', function () {
    register_rest_route('altaawun/v1', '/categories', array(
        'methods' => 'GET',
        'permission_callback' => '__return_true',
        'callback' => function () {
            $ids = get_option('altaawun_app_category_ids', array());
            $result = array();
            foreach ($ids as $entry) {
                $parts = is_numeric($entry) ? array('category', (int)$entry) : explode(':', $entry, 2);
                if (count($parts) !== 2 || !in_array($parts[0], array('category','product_cat'), true)) continue;
                if (!taxonomy_exists($parts[0])) continue;
                $term = get_term(absint($parts[1]), $parts[0]);
                if (!$term || is_wp_error($term)) continue;
                $result[] = array(
                    'id' => (int)$term->term_id,
                    'type' => $term->taxonomy,
                    'name' => $term->name,
                    'count' => (int)$term->count,
                    'parent' => (int)$term->parent,
                    'link' => get_term_link($term),
                );
            }
            return rest_ensure_response(array('categories'=>$result));
        },
    ));
});

add_action('rest_api_init', function () {
    register_rest_route('altaawun/v1', '/products', array(
        'methods' => 'GET',
        'permission_callback' => '__return_true',
        'args' => array('category' => array('required' => true, 'sanitize_callback' => 'absint')),
        'callback' => function ($request) {
            if (!post_type_exists('product')) {
                return new WP_Error('woocommerce_missing', 'WooCommerce is not active', array('status' => 503));
            }
            $id = absint($request->get_param('category'));
            if (!$id || !term_exists($id, 'product_cat')) {
                return new WP_Error('invalid_category', 'Invalid category', array('status' => 400));
            }
            $query = new WP_Query(array(
                'post_type' => 'product', 'post_status' => 'publish',
                'posts_per_page' => 30,
                'tax_query' => array(array('taxonomy'=>'product_cat','field'=>'term_id','terms'=>$id)),
            ));
            $items = array();
            foreach ($query->posts as $post) {
                $product = function_exists('wc_get_product') ? wc_get_product($post->ID) : false;
                if (!$product || !$product->is_visible()) continue;
                $items[] = array(
                    'id' => $post->ID,
                    'name' => get_the_title($post),
                    'description' => wp_strip_all_tags($product->get_short_description()),
                    'price' => $product->get_price_html() ? wp_strip_all_tags($product->get_price_html()) : '',
                    'image' => get_the_post_thumbnail_url($post->ID, 'medium') ?: '',
                    'link' => get_permalink($post),
                );
            }
            return rest_ensure_response(array('products'=>$items));
        },
    ));
});
