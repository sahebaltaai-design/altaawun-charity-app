<?php
/**
 * Plugin Name: إشعارات جمعية التعاون الخيرية
 * Description: إشعارات Firebase تلقائية عند نشر الأخبار ويدوية من لوحة التحكم.
 * Version: 1.0.0
 */
defined('ABSPATH') || exit;
add_action('admin_menu', function () {
 add_menu_page('إشعارات الجمعية','إشعارات الجمعية','manage_options','altaawun-push','altaawun_push_page','dashicons-megaphone');
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
  $result=altaawun_push_send(sanitize_text_field(wp_unslash($_POST['title'] ?? '')),sanitize_textarea_field(wp_unslash($_POST['body'] ?? '')));
  echo '<div class="notice notice-info"><p>'.esc_html(is_wp_error($result)?$result->get_error_message():'تم قبول الإشعار من Firebase').'</p></div>';
 }
 echo '<div class="wrap" dir="rtl"><h1>إشعارات جمعية التعاون الخيرية</h1><p>الموضوع: altaawun_updates</p>';
 echo '<h2>إعداد Firebase Service Account</h2><form method="post">';
 wp_nonce_field('altaawun_push_save');
 echo '<textarea name="credentials" rows="8" style="width:90%;direction:ltr" placeholder="Service Account JSON"></textarea><p><button class="button button-primary" name="altaawun_save">حفظ</button></p></form>';
 echo '<h2>إرسال إشعار يدوي</h2><form method="post">';
 wp_nonce_field('altaawun_push_send');
 echo '<p><input name="title" required maxlength="120" placeholder="عنوان الإشعار" class="regular-text"></p><p><textarea name="body" required maxlength="1000" placeholder="نص الإشعار" rows="4" style="width:90%"></textarea></p>';
 echo '<button class="button button-primary" name="altaawun_send">إرسال الإشعار</button></form><p>يُرسل إشعار تلقائي عند نشر مقال جديد لأول مرة.</p></div>';
}
function altaawun_push_send($title,$body,$url='') {
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
 $message=['topic'=>'altaawun_updates','notification'=>['title'=>mb_substr($title,0,120),'body'=>mb_substr($body,0,1000)],'android'=>['priority'=>'high']];
 if ($url) $message['data']=['url'=>$url];
 $response=wp_remote_post('https://fcm.googleapis.com/v1/projects/'.rawurlencode($a['project_id']).'/messages:send',['timeout'=>20,'headers'=>['Authorization'=>'Bearer '.$token,'Content-Type'=>'application/json'],'body'=>wp_json_encode(['message'=>$message])]);
 if (is_wp_error($response)) return $response;
 if (wp_remote_retrieve_response_code($response)!==200) return new WP_Error('fcm','Firebase HTTP '.wp_remote_retrieve_response_code($response).' '.substr(wp_remote_retrieve_body($response),0,150));
 return true;
}
add_action('transition_post_status',function($new,$old,$post){
 if ($post->post_type!=='post'||$new!=='publish'||$old==='publish'||get_post_meta($post->ID,'_altaawun_push_sent',true)) return;
 if (!add_post_meta($post->ID,'_altaawun_push_lock',time(),true)) return;
 $result=altaawun_push_send(get_the_title($post),wp_strip_all_tags(wp_trim_words($post->post_content,28,'…')),get_permalink($post));
 if (!is_wp_error($result)) update_post_meta($post->ID,'_altaawun_push_sent',1);
 delete_post_meta($post->ID,'_altaawun_push_lock');
},10,3);
