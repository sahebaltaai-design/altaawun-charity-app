<?php
/**
 * Plugin Name: إشعارات جمعية التعاون الخيرية
 * Description: إشعارات Firebase تلقائية عند نشر الأخبار والمنتجات ويدوية من لوحة التحكم.
 * Version: 1.2.5
 * Author: Saheb Altaai
 * Update URI: https://github.com/sahebaltaai-design/altaawun-charity-app
 * Requires PHP: 8.0
 * Requires at least: 5.8
 */
defined('ABSPATH') || exit;
add_action('admin_menu', function () {
 add_menu_page('إشعارات الجمعية','إشعارات الجمعية','manage_options','altaawun-push','altaawun_push_page','dashicons-megaphone');
 add_submenu_page('altaawun-push','إدارة النغمات','إدارة النغمات','manage_options','altaawun-tones','altaawun_tones_page');
});
function altaawun_push_page() {
 if (!current_user_can('manage_options')) return;
 if (isset($_POST['altaawun_save']) && check_admin_referer('altaawun_push_save')) {
  $raw=wp_unslash($_POST['credentials'] ?? '');
  $data=json_decode($raw,true);
  if (is_array($data) && !empty($data['project_id']) && !empty($data['private_key']) && !empty($data['client_email']))
   update_option('altaawun_push_credentials',wp_json_encode($data),false);
  echo '<div class="notice notice-info"><p>تمت معالجة إعدادات Firebase.</p></div>';
 }
 if (isset($_POST['altaawun_send']) && check_admin_referer('altaawun_push_send')) {
  $result=altaawun_push_send(
    sanitize_text_field(wp_unslash($_POST['title'] ?? '')),
    sanitize_textarea_field(wp_unslash($_POST['body'] ?? '')),
    esc_url_raw(wp_unslash($_POST['url'] ?? '')),
    sanitize_key(wp_unslash($_POST['notification_type'] ?? 'normal'))
  );
  echo '<div class="notice notice-info"><p>'.esc_html(is_wp_error($result)?$result->get_error_message():'تم قبول الإشعار من Firebase').'</p></div>';
 }
 echo '<div class="wrap" dir="rtl"><h1>إشعارات جمعية التعاون الخيرية</h1><p><strong>الإصدار: 1.2.5</strong><br><span dir="ltr" style="display:inline-block">By Saheb Altaai</span></p><p>الإرسال إلى قنوات نغمات التطبيق الثماني (altaawun_tone_*). يُحافظ التطبيق أيضًا على اشتراك القناة القديمة للتوافق.</p>';
 echo '<h2>إعداد Firebase Service Account</h2><form method="post">';
 wp_nonce_field('altaawun_push_save');
 echo '<textarea name="credentials" rows="8" style="width:90%;direction:ltr" placeholder="Service Account JSON"></textarea><p><button class="button button-primary" name="altaawun_save">حفظ</button></p></form>';
 echo '<h2>إرسال إشعار يدوي</h2><form method="post">';
 wp_nonce_field('altaawun_push_send');
 echo '<p><input name="title" required maxlength="120" placeholder="عنوان الإشعار" class="regular-text"></p><p><textarea name="body" required maxlength="1000" placeholder="نص الإشعار" rows="4" style="width:90%"></textarea></p>';
 echo '<p><input type="url" name="url" placeholder="رابط الخبر أو الحملة (اختياري)" class="regular-text" style="direction:ltr"></p>';
 echo '<p><label>نوع الإشعار <select name="notification_type"><option value="normal">عادي</option><option value="urgent">عاجل</option></select></label></p>';
 echo '<button class="button button-primary" name="altaawun_send">إرسال الإشعار</button></form><p>يُرسل إشعار تلقائي عند نشر مقال أو منتج جديد لأول مرة.</p></div>';
}
function altaawun_push_send($title,$body,$url='',$type='normal') {
 $a=json_decode(get_option('altaawun_push_credentials',''),true);
 if (empty($a['private_key'])||empty($a['client_email'])||empty($a['project_id'])) return new WP_Error('config','أدخل ملف Service Account أولاً.');
 if (!$title||!$body) return new WP_Error('empty','العنوان والنص مطلوبان.');
 $now=time();
 $b64=function($s){return rtrim(strtr(base64_encode($s),'+/','-_'),'=');};
 $jwt=$b64(wp_json_encode(['alg'=>'RS256','typ'=>'JWT'])).'.'.$b64(wp_json_encode(['iss'=>$a['client_email'],'scope'=>'https://www.googleapis.com/auth/firebase.messaging','aud'=>'https://oauth2.googleapis.com/token','iat'=>$now,'exp'=>$now+3500]));
 if (!openssl_sign($jwt,$signature,$a['private_key'],OPENSSL_ALGO_SHA256)) return new WP_Error('sign','تعذر توقيع Firebase JWT.');
 $tokenResponse=wp_remote_post('https://oauth2.googleapis.com/token',['timeout'=>20,'body'=>['grant_type'=>'urn:ietf:params:oauth:grant-type:jwt-bearer','assertion'=>$jwt.'.'.$b64($signature)]]);
 if (is_wp_error($tokenResponse)) return $tokenResponse;
 $token=json_decode(wp_remote_retrieve_body($tokenResponse),true)['access_token']??'';
 if (!$token) return new WP_Error('oauth','تعذر الحصول على رمز Firebase.');
 $type=$type==='urgent'?'urgent':'normal';
 $title=mb_substr($title,0,120);
 $body=mb_substr($body,0,1000);
 // Older builds subscribe to a single tone topic (and not altaawun_updates).
 // Send exactly once to each tone/vibration topic. Every device is subscribed
 // to one selected topic; do NOT also broadcast to altaawun_updates, which
 // would cause duplicate notifications on new builds.
 $failed=[];
 foreach (['urgent','news','soft','default'] as $tone) {
  foreach (['vibrate','silent'] as $vibration) {
   $topic='altaawun_tone_'.$tone.'_'.$vibration;
   $channel='altaawun_tone_v2_'.$tone.'_'.$vibration;
   $message=[
    'topic'=>$topic,
    'notification'=>[
     'title'=>$type==='urgent'?'عاجل: '.$title:$title,
     'body'=>$body,
    ],
    'data'=>['type'=>$type],
    'android'=>[
     'priority'=>$type==='urgent'?'HIGH':'NORMAL',
     'notification'=>[
      'channel_id'=>$channel,
      'default_vibrate_timings'=>$vibration==='vibrate',
     ],
    ],
    'apns'=>[
     'headers'=>['apns-push-type'=>'alert','apns-priority'=>'10'],
     'payload'=>['aps'=>[
      'sound'=>'default',
      'thread-id'=>'altaawun-'.$type,
     ]],
    ],
   ];
   if ($url) $message['data']['url']=esc_url_raw($url);
   $response=wp_remote_post(
    'https://fcm.googleapis.com/v1/projects/'.rawurlencode($a['project_id']).'/messages:send',
    ['timeout'=>12,'headers'=>[
     'Authorization'=>'Bearer '.$token,
     'Content-Type'=>'application/json',
    ],'body'=>wp_json_encode(['message'=>$message])]
   );
   if (is_wp_error($response)) {
    $failed[]=$topic.' (network)';
   } elseif (wp_remote_retrieve_response_code($response)!==200) {
    $failed[]=$topic.' (HTTP '.wp_remote_retrieve_response_code($response).')';
   }
  }
 }
 if ($failed) {
  return new WP_Error('fcm_partial','تعذر إرسال الإشعار إلى بعض القنوات: '.implode(', ',$failed));
 }
 return true;
}
add_action('transition_post_status',function($new,$old,$post){
 if (!in_array($post->post_type,['post','product'],true)||$new!=='publish'||$old==='publish'||get_post_meta($post->ID,'_altaawun_push_sent',true)) return;
 // Delay sending until WordPress finishes saving post metadata and content.
 if (!wp_next_scheduled('altaawun_send_post_notification',[$post->ID]))
  wp_schedule_single_event(time()+30,'altaawun_send_post_notification',[$post->ID]);
},10,3);
// WooCommerce can create products directly with publish status; cover that path as well.
function altaawun_queue_new_product_notification($id) {
 $post=get_post($id);
 if (!$post||$post->post_type!=='product'||$post->post_status!=='publish'||get_post_meta($id,'_altaawun_push_sent',true)) return;
 $created=get_post_time('U',true,$post);
 if (!$created||time()-$created>600) return; // Never alert for ordinary edits to older products.
 if (!wp_next_scheduled('altaawun_send_post_notification',[$id]))
  wp_schedule_single_event(time()+30,'altaawun_send_post_notification',[$id]);
}
add_action('save_post_product','altaawun_queue_new_product_notification',20,1);
add_action('woocommerce_new_product','altaawun_queue_new_product_notification',20,1);
add_action('altaawun_send_post_notification',function($id){
 $post=get_post($id);
 if (!$post||!in_array($post->post_type,['post','product'],true)||$post->post_status!=='publish'||get_post_meta($id,'_altaawun_push_sent',true)) return;
 if (!add_post_meta($id,'_altaawun_push_lock',time(),true)) return;
 $type=get_post_meta($id,'_altaawun_notification_type',true)==='urgent'?'urgent':'normal';
 $body=wp_strip_all_tags(wp_trim_words($post->post_content,28,'…'));
 if (!$body) $body=get_the_title($post);
 $result=altaawun_push_send(get_the_title($post),$body,get_permalink($post),$type);
 if (is_wp_error($result)) {
  update_post_meta($id,'_altaawun_push_last_error',$result->get_error_message());
  update_post_meta($id,'_altaawun_push_last_attempt',current_time('mysql'));
 } else {
  update_post_meta($id,'_altaawun_push_sent',1);
  delete_post_meta($id,'_altaawun_push_last_error');
  update_post_meta($id,'_altaawun_push_last_attempt',current_time('mysql'));
 }
 delete_post_meta($id,'_altaawun_push_lock');
});
add_action('admin_notices',function(){
 if (!current_user_can('edit_posts')||!isset($_GET['post'])) return;
 $id=absint($_GET['post']);
 if (!$id||!in_array(get_post_type($id),['post','product'],true)) return;
 $error=get_post_meta($id,'_altaawun_push_last_error',true);
 if ($error) echo '<div class="notice notice-error"><p>'.esc_html('تعذر إرسال إشعار الجمعية: '.$error).'</p></div>';
});
add_action('add_meta_boxes',function(){add_meta_box('altaawun_push_type','نوع إشعار الجمعية',function($post){wp_nonce_field('altaawun_push_type','altaawun_push_type_nonce');$v=get_post_meta($post->ID,'_altaawun_notification_type',true);echo '<label><select name="altaawun_notification_type"><option value="normal">عادي</option><option value="urgent" '.selected($v,'urgent',false).'>عاجل</option></select></label>';},['post','product'],'side');});
add_action('save_post',function($id){if (!in_array(get_post_type($id),['post','product'],true)||!isset($_POST['altaawun_push_type_nonce'])||!wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['altaawun_push_type_nonce'])),'altaawun_push_type')||!current_user_can('edit_post',$id)||wp_is_post_revision($id))return;update_post_meta($id,'_altaawun_notification_type',sanitize_key(wp_unslash($_POST['altaawun_notification_type']??'normal'))==='urgent'?'urgent':'normal');});

function altaawun_tones_page() {
 if (!current_user_can('manage_options')) return;
 $tones=get_option('altaawun_tones',[]);
 if (!is_array($tones)) $tones=[];
 if ($_SERVER['REQUEST_METHOD']==='POST' && isset($_POST['altaawun_tones_nonce']) && check_admin_referer('altaawun_tones_action','altaawun_tones_nonce')) {
  if (isset($_POST['altaawun_tone_upload']) && !empty($_FILES['tone_file']['name'])) {
   require_once ABSPATH.'wp-admin/includes/file.php';
   $file=$_FILES['tone_file'];
   $allowed=['mp3'=>'audio/mpeg','wav'=>'audio/wav','ogg'=>'audio/ogg'];
   $ext=strtolower(pathinfo(sanitize_file_name($file['name']),PATHINFO_EXTENSION));
   if (!isset($allowed[$ext]) || $file['size']>5*1024*1024 || $file['size']<=0) {
    echo '<div class="notice notice-error"><p>الملف غير مدعوم أو يتجاوز 5 ميغابايت.</p></div>';
   } else {
    $upload=wp_handle_upload($file,['test_form'=>false,'mimes'=>$allowed]);
    if (!empty($upload['url']) && empty($upload['error'])) {
     $id=wp_generate_uuid4();
     $tones[$id]=['name'=>sanitize_text_field(wp_unslash($_POST['tone_name']??'')) ?: sanitize_file_name($file['name']),'url'=>esc_url_raw($upload['url']),'file'=>$upload['file']];
     update_option('altaawun_tones',$tones,false);
     echo '<div class="notice notice-success"><p>تم رفع النغمة بنجاح.</p></div>';
    } else echo '<div class="notice notice-error"><p>'.esc_html($upload['error']??'فشل رفع الملف').'</p></div>';
   }
  }
  if (isset($_POST['altaawun_tone_delete'])) {
   $id=sanitize_text_field(wp_unslash($_POST['tone_id']??''));
   if (isset($tones[$id])) {
    $entry=$tones[$id];
    $uploads=wp_get_upload_dir();
    $root=realpath($uploads['basedir']);
    $path=realpath($entry['file']??'');
    if ($root && $path && str_starts_with($path,$root.DIRECTORY_SEPARATOR) && is_file($path)) wp_delete_file($path);
    unset($tones[$id]);
    update_option('altaawun_tones',$tones,false);
   }
  }
 }
 echo '<div class="wrap" dir="rtl"><h1>إدارة نغمات إشعارات الجمعية</h1>';
 echo '<p>ارفع النغمات واستمع إليها. ملاحظة: رفع النغمة هنا لا يغير تلقائيًا صوت إشعارات Android عندما يكون التطبيق مغلقًا؛ يلزم ربطها بقنوات الإشعارات داخل التطبيق.</p>';
 echo '<form method="post" enctype="multipart/form-data">';
 wp_nonce_field('altaawun_tones_action','altaawun_tones_nonce');
 echo '<p><input type="text" name="tone_name" placeholder="اسم النغمة" required class="regular-text"></p>';
 echo '<p><input type="file" name="tone_file" accept=".mp3,.wav,.ogg,audio/*" required></p>';
 echo '<p><button class="button button-primary" name="altaawun_tone_upload" value="1">رفع نغمة</button></p></form>';
 echo '<h2>النغمات المرفوعة</h2><table class="widefat striped"><thead><tr><th>الاسم</th><th>استماع</th><th>إجراء</th></tr></thead><tbody>';
 foreach ($tones as $id=>$tone) {
  echo '<tr><td>'.esc_html($tone['name']).'</td><td><audio controls preload="none" src="'.esc_url($tone['url']).'"></audio></td><td>';
  echo '<form method="post">';
  wp_nonce_field('altaawun_tones_action','altaawun_tones_nonce');
  echo '<input type="hidden" name="tone_id" value="'.esc_attr($id).'"><button class="button" name="altaawun_tone_delete" value="1" onclick="return confirm(\'حذف النغمة؟\')">حذف</button></form></td></tr>';
 }
 echo '</tbody></table></div>';
}
add_action('rest_api_init',function(){
 register_rest_route('altaawun/v1','/tones',['methods'=>'GET','permission_callback'=>'__return_true','callback'=>function(){
  $tones=get_option('altaawun_tones',[]);
  return rest_ensure_response(array_values(array_map(function($tone){return ['name'=>$tone['name'],'url'=>$tone['url']];},is_array($tones)?$tones:[])));
 }]);
});


/**
 * Self-hosted plugin updates.
 *
 * WordPress checks the public GitHub Releases feed for releases tagged
 * "altaawun-notifications-vX.Y.Z". The update package must be named
 * "altaawun-notifications-X.Y.Z.zip" and contain the standard
 * "altaawun-notifications/altaawun-notifications.php" path.
 *
 * Version 1.2.5 is the one-time manual bootstrap; subsequent versions use
 * the native WordPress updater. Automatic installation is opt-in from the
 * normal Plugins screen and is never silently enabled by this code.
 */
function altaawun_notifications_release_info() {
    $cached = get_transient('altaawun_notifications_release_v1');
    if (false !== $cached) {
        return is_array($cached) ? $cached : false;
    }

    $api = 'https://api.github.com/repos/sahebaltaai-design/altaawun-charity-app/releases?per_page=30';
    $response = wp_remote_get($api, array(
        'timeout' => 8,
        'headers' => array(
            'Accept' => 'application/vnd.github+json',
            'User-Agent' => 'Altaawun-Notifications-WordPress',
        ),
    ));
    if (is_wp_error($response) || 200 !== wp_remote_retrieve_response_code($response)) {
        set_transient('altaawun_notifications_release_v1', 'unavailable', 30 * MINUTE_IN_SECONDS);
        return false;
    }

    $releases = json_decode(wp_remote_retrieve_body($response), true);
    if (!is_array($releases)) {
        set_transient('altaawun_notifications_release_v1', 'unavailable', 30 * MINUTE_IN_SECONDS);
        return false;
    }

    $best = false;
    foreach ($releases as $release) {
        if (!is_array($release) || !empty($release['draft']) || !empty($release['prerelease'])) {
            continue;
        }
        $tag = isset($release['tag_name']) ? (string) $release['tag_name'] : '';
        if (!preg_match('/^altaawun-notifications-v([0-9]+\\.[0-9]+\\.[0-9]+)$/', $tag, $matches)) {
            continue;
        }
        $version = $matches[1];
        $expected = 'altaawun-notifications-' . $version . '.zip';
        if (empty($release['assets']) || !is_array($release['assets'])) {
            continue;
        }
        foreach ($release['assets'] as $asset) {
            if (!is_array($asset) || ($asset['name'] ?? '') !== $expected) {
                continue;
            }
            $package = (string) ($asset['browser_download_url'] ?? '');
            if ('https' !== wp_parse_url($package, PHP_URL_SCHEME)
                || 'github.com' !== wp_parse_url($package, PHP_URL_HOST)) {
                continue;
            }
            if (!$best || version_compare($version, $best['version'], '>')) {
                $best = array(
                    'version' => $version,
                    'package' => $package,
                    'url' => esc_url_raw((string) ($release['html_url'] ?? '')),
                    'description' => sanitize_textarea_field((string) ($release['body'] ?? '')),
                );
            }
        }
    }

    set_transient('altaawun_notifications_release_v1', $best ? $best : 'unavailable', 6 * HOUR_IN_SECONDS);
    return $best;
}

// WordPress 5.8+ custom Update URI mechanism.
add_filter('update_plugins_github.com', function ($update, $plugin_data, $plugin_file, $locales) {
    if ($plugin_file !== plugin_basename(__FILE__)) {
        return $update;
    }
    $release = altaawun_notifications_release_info();
    if (!$release || !version_compare($release['version'], $plugin_data['Version'], '>')) {
        return false;
    }
    return array(
        'slug' => 'altaawun-notifications',
        'version' => $release['version'],
        'url' => $release['url'],
        'package' => $release['package'],
        'requires' => '5.8',
        'requires_php' => '8.0',
    );
}, 10, 4);

// "View version details" in the native WordPress plugin update screen.
add_filter('plugins_api', function ($result, $action, $args) {
    if ('plugin_information' !== $action || empty($args->slug) || 'altaawun-notifications' !== $args->slug) {
        return $result;
    }
    $release = altaawun_notifications_release_info();
    if (!$release) {
        return $result;
    }
    return (object) array(
        'name' => 'إشعارات جمعية التعاون الخيرية',
        'slug' => 'altaawun-notifications',
        'version' => $release['version'],
        'author' => 'Al-Taawun Charity Association',
        'homepage' => 'https://github.com/sahebaltaai-design/altaawun-charity-app',
        'download_link' => $release['package'],
        'requires' => '5.8',
        'requires_php' => '8.0',
        'sections' => array(
            'description' => 'إشعارات الجمعية وربط Firebase. تحصل الإضافة على تحديثات من إصدارات GitHub الرسمية فقط.',
            'changelog' => nl2br(esc_html($release['description'])),
        ),
    );
}, 10, 3);
