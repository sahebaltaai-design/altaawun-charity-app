<?php
/**
 * Plugin Name: Altaawun App Tile Settings
 * Description: Manage home tile icons, colors and sizes for the Altaawun mobile app.
 * Version: 1.0.0
 */
if (!defined('ABSPATH')) exit;

add_action('admin_menu', function () {
    add_options_page('مربعات تطبيق الجمعية', 'مربعات تطبيق الجمعية', 'manage_options', 'altaawun-tiles', 'altaawun_tiles_admin');
});
function altaawun_tiles_categories() {
    $items = [];
    foreach (get_categories(['hide_empty'=>false]) as $cat) {
        $items['category:'.$cat->term_id] = $cat->name;
    }
    if (taxonomy_exists('product_cat')) {
        foreach (get_terms(['taxonomy'=>'product_cat','hide_empty'=>false]) as $cat) {
            if (!is_wp_error($cat)) $items['product_cat:'.$cat->term_id] = $cat->name;
        }
    }
    return $items;
}
function altaawun_tiles_clean($data) {
    $result = [];
    if (!is_array($data)) return $result;
    foreach (altaawun_tiles_categories() as $key=>$label) {
        if (empty($data[$key]) || !is_array($data[$key])) continue;
        $entry = $data[$key];
        $icon = sanitize_key($entry['icon'] ?? 'school');
        $allowed = ['school','groups','favorite','volunteer_activism','article','photo_library','menu_book','home','campaign','public','local_library','auto_stories'];
        if (!in_array($icon, $allowed, true)) $icon='school';
        $color = function($value,$default) {
            $hex = sanitize_hex_color($value ?? '');
            return $hex ?: $default;
        };
        $image_id = absint($entry['image_id'] ?? 0);
        if ($image_id && !wp_attachment_is_image($image_id)) $image_id=0;
        $result[$key] = [
            'icon'=>$icon,
            'image_id'=>$image_id,
            'background'=>$color($entry['background'] ?? '', '#E3F5E9'),
            'icon_color'=>$color($entry['icon_color'] ?? '', '#00642D'),
            'text_color'=>$color($entry['text_color'] ?? '', '#111111'),
            'icon_size'=>max(24,min(100,absint($entry['icon_size'] ?? 52))),
            'tile_height'=>max(90,min(260,absint($entry['tile_height'] ?? 160))),
        ];
    }
    return $result;
}
add_action('admin_post_altaawun_tiles_save', function() {
    if (!current_user_can('manage_options')) wp_die('Forbidden');
    check_admin_referer('altaawun_tiles_save');
    update_option('altaawun_app_tiles', altaawun_tiles_clean(wp_unslash($_POST['tiles'] ?? [])), false);
    wp_safe_redirect(add_query_arg(['page'=>'altaawun-tiles','updated'=>'1'],admin_url('options-general.php')));
    exit;
});
function altaawun_tiles_admin() {
    if (!current_user_can('manage_options')) return;
    wp_enqueue_media();
    $settings = get_option('altaawun_app_tiles', []);
    $icons=['school','groups','favorite','volunteer_activism','article','photo_library','menu_book','home','campaign','public','local_library','auto_stories'];
    echo '<div class="wrap" dir="rtl"><h1>مربعات تطبيق جمعية التعاون الخيرية</h1><p>اختر أيقونة جاهزة أو ارفع صورة من مكتبة الوسائط. الألوان والحجم مستقلان لكل مربع.</p>';
    if (isset($_GET['updated'])) echo '<div class="notice notice-success"><p>تم الحفظ.</p></div>';
    echo '<form method="post" action="'.esc_url(admin_url('admin-post.php')).'"><input type="hidden" name="action" value="altaawun_tiles_save">';
    wp_nonce_field('altaawun_tiles_save');
    echo '<table class="widefat striped"><thead><tr><th>التصنيف</th><th>الأيقونة</th><th>صورة خاصة</th><th>الخلفية</th><th>لون الأيقونة</th><th>لون النص</th><th>حجم الأيقونة</th><th>ارتفاع المربع</th></tr></thead><tbody>';
    foreach (altaawun_tiles_categories() as $key=>$label) {
        $s=$settings[$key] ?? [];
        $prefix='tiles['.esc_attr($key).']';
        echo '<tr><td>'.esc_html($label).'</td><td><select name="'.$prefix.'[icon]">';
        foreach ($icons as $icon) echo '<option value="'.esc_attr($icon).'" '.selected($s['icon'] ?? 'school',$icon,false).'>'.esc_html($icon).'</option>';
        echo '</select></td><td><input class="altaawun-image-id" type="hidden" name="'.$prefix.'[image_id]" value="'.absint($s['image_id'] ?? 0).'"><button type="button" class="button altaawun-pick">اختيار صورة</button> <button type="button" class="button altaawun-clear">حذف</button><span class="altaawun-preview">';
        $url=wp_get_attachment_image_url(absint($s['image_id'] ?? 0),'thumbnail');
        if ($url) echo '<img src="'.esc_url($url).'" alt="" style="width:44px;height:44px;object-fit:contain">';
        echo '</span></td>';
        foreach (['background'=>'#E3F5E9','icon_color'=>'#00642D','text_color'=>'#111111'] as $field=>$default) {
            echo '<td><input type="color" name="'.$prefix.'['.$field.']" value="'.esc_attr(sanitize_hex_color($s[$field] ?? '') ?: $default).'"></td>';
        }
        foreach (['icon_size'=>52,'tile_height'=>160] as $field=>$default) {
            $min=$field==='icon_size'?24:90; $max=$field==='icon_size'?100:260;
            echo '<td><input type="number" style="width:75px" min="'.$min.'" max="'.$max.'" name="'.$prefix.'['.$field.']" value="'.absint($s[$field] ?? $default).'"></td>';
        }
        echo '</tr>';
    }
    echo '</tbody></table>';
    submit_button('حفظ إعدادات المربعات');
    echo '</form><p>واجهة القراءة: <code>/wp-json/altaawun/v1/tiles</code></p></div>';
    echo "<script>document.addEventListener('click',function(e){var row=e.target.closest('td');if(!row)return;if(e.target.classList.contains('altaawun-clear')){row.querySelector('.altaawun-image-id').value='0';row.querySelector('.altaawun-preview').innerHTML='';}if(e.target.classList.contains('altaawun-pick')){var picker=wp.media({title:'اختيار أيقونة',button:{text:'استخدام الصورة'},multiple:false,library:{type:'image'}});picker.on('select',function(){var item=picker.state().get('selection').first().toJSON();row.querySelector('.altaawun-image-id').value=item.id;row.querySelector('.altaawun-preview').innerHTML='<img alt=\\\"\\\" style=\\\"width:44px;height:44px;object-fit:contain\\\" src=\\\"'+item.url+'\\\">';});picker.open();}});</script>";
}
add_action('rest_api_init', function() {
    register_rest_route('altaawun/v1','/tiles',[
        'methods'=>'GET',
        'permission_callback'=>'__return_true',
        'callback'=>function() {
            $stored=get_option('altaawun_app_tiles',[]);
            $output=[];
            foreach (altaawun_tiles_categories() as $key=>$label) {
                $s=$stored[$key] ?? [];
                $image_id=absint($s['image_id'] ?? 0);
                $output[$key]=[
                    'icon'=>sanitize_key($s['icon'] ?? 'school'),
                    'image_url'=>$image_id ? (wp_get_attachment_image_url($image_id,'medium') ?: '') : '',
                    'background'=>$s['background'] ?? '#E3F5E9',
                    'icon_color'=>$s['icon_color'] ?? '#00642D',
                    'text_color'=>$s['text_color'] ?? '#111111',
                    'icon_size'=>(int)($s['icon_size'] ?? 52),
                    'tile_height'=>(int)($s['tile_height'] ?? 160),
                ];
            }
            return rest_ensure_response($output);
        }
    ]);
});
