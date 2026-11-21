<?php
/**
 * Plugin Name: إشعارات جمعية التعاون الخيرية
 * Description: إشعارات Firebase تلقائية عند نشر الأخبار والمنتجات ويدوية من لوحة التحكم.
 * Version: 1.2.11
 */
defined('ABSPATH') || exit;

add_action('admin_menu', function () {
 add_menu_page('إعدادات التطبيق','إعدادات التطبيق','manage_options','altaawun-app-settings','altaawun_splash_settings_page','dashicons-smartphone',58);
 add_submenu_page('altaawun-app-settings','شاشة الترحيب','شاشة الترحيب','manage_options','altaawun-app-settings','altaawun_splash_settings_page');
}, 20);

add_action('admin_enqueue_scripts', function($hook) {
 if ($hook === 'toplevel_page_altaawun-app-settings') {
  wp_enqueue_media();
 }
});
function altaawun_splash_defaults() {
 return [
  'image_id'=>0, 'fit'=>'smart', 'show_caption'=>true, 'scale'=>1.0,
  'align_x'=>0.0, 'align_y'=>-1.0, 'duration_ms'=>1500,
  'updated_at'=>0,
 ];
}
function altaawun_splash_settings() {
 $saved=get_option('altaawun_app_splash',[]);
 return wp_parse_args(is_array($saved)?$saved:[],altaawun_splash_defaults());
}
function altaawun_splash_image_url($id) {
 $id=absint($id);
 if (!$id || !wp_attachment_is_image($id)) return '';
 $url=wp_get_attachment_url($id);
 return $url && wp_parse_url($url,PHP_URL_SCHEME)==='https' ? esc_url_raw($url) : '';
}
function altaawun_splash_public_settings() {
 $settings=altaawun_splash_settings();
 return [
  'image_url'=>altaawun_splash_image_url($settings['image_id']),
  'fit'=>in_array($settings['fit'],['smart','contain','cover'],true)?$settings['fit']:'smart',
  'show_caption'=>!empty($settings['show_caption']),
  'scale'=>(float)$settings['scale'],
  'align_x'=>(float)$settings['align_x'],
  'align_y'=>(float)$settings['align_y'],
  'duration_ms'=>(int)$settings['duration_ms'],
  'updated_at'=>(int)$settings['updated_at'],
 ];
}
add_action('rest_api_init',function() {
 register_rest_route('altaawun/v1','/app-splash',[
  'methods'=>WP_REST_Server::READABLE,
  'permission_callback'=>'__return_true',
  'callback'=>function() {
   $response=rest_ensure_response(altaawun_splash_public_settings());
   $response->header('Cache-Control','no-store, no-cache, must-revalidate, max-age=0');
   return $response;
  },
 ]);
});
function altaawun_splash_settings_page() {
 if (!current_user_can('manage_options')) return;
 if ($_SERVER['REQUEST_METHOD']==='POST' && isset($_POST['altaawun_splash_action'])) {
  check_admin_referer('altaawun_splash_save');
  $action=sanitize_key(wp_unslash($_POST['altaawun_splash_action']));
  if ($action==='reset') {
   delete_option('altaawun_app_splash');
   echo '<div class="notice notice-success"><p>تمت استعادة إعدادات الترحيب الافتراضية.</p></div>';
  } elseif ($action==='save') {
   $image_id=absint($_POST['image_id']??0);
   if ($image_id && !altaawun_splash_image_url($image_id)) {
    echo '<div class="notice notice-error"><p>اختر صورة صحيحة من مكتبة الوسائط بموقع الجمعية (HTTPS).</p></div>';
   } else {
    $fit=sanitize_key(wp_unslash($_POST['fit']??'smart'));
    $scale=(float)($_POST['scale']??1);
    $align_x=(float)($_POST['align_x']??0);
    $align_y=(float)($_POST['align_y']??-1);
    $duration=(int)($_POST['duration_ms']??1500);
    update_option('altaawun_app_splash',[
     'image_id'=>$image_id,
     'fit'=>in_array($fit,['smart','contain','cover'],true)?$fit:'smart',
     'show_caption'=>!empty($_POST['show_caption']),
     'scale'=>max(0.7,min($fit==='smart'?1.0:1.5,$scale)),
     'align_x'=>max(-1,min(1,$align_x)),
     'align_y'=>max(-1,min(1,$align_y)),
     'duration_ms'=>max(700,min(8000,$duration)),
     'updated_at'=>time(),
    ],false);
    echo '<div class="notice notice-success"><p>تم حفظ شاشة الترحيب. ستقرأ التطبيقات المحدثة هذه الإعدادات عند تشغيلها.</p></div>';
   }
  }
 }
 $cfg=altaawun_splash_settings();
 $url=altaawun_splash_image_url($cfg['image_id']);
 $default_preview_url=plugins_url('assets/welcome_background-2.png',__FILE__);
 $preview_src=$url?:$default_preview_url;
 echo '<div class="wrap" dir="rtl"><h1>إعدادات التطبيق ← شاشة الترحيب</h1>';
 echo '<p>تحكم بصورة الترحيب وظهورها على أندرويد وآيفون من هنا دون تعديل الكود. التطبيق الجديد يعرض الصورة المخزنة إذا تعذر الاتصال بالموقع.</p>';
 echo '<form method="post" id="altaawun-splash-form">';
 wp_nonce_field('altaawun_splash_save');
 echo '<input type="hidden" name="image_id" id="altaawun-splash-image-id" value="'.esc_attr($cfg['image_id']).'">';
 echo '<p><button type="button" class="button button-primary" id="altaawun-splash-choose">اختيار / رفع صورة من الوسائط</button> ';
 echo '<button type="button" class="button" id="altaawun-splash-clear">استخدام صورة التطبيق الافتراضية</button></p>';
 echo '<table class="form-table" role="presentation" style="max-width:760px"><tbody>';
 echo '<tr><th><label for="altaawun-splash-fit">طريقة العرض</label></th><td><select id="altaawun-splash-fit" name="fit">';
 foreach (['smart'=>'ملء المكان مع الحفاظ على الصورة كاملة (موصى به)','cover'=>'ملء الشاشة — قد تُقص أطراف الصورة','contain'=>'إظهار الصورة كاملة — قد تظهر هوامش'] as $value=>$label)
  echo '<option value="'.esc_attr($value).'" '.selected($cfg['fit'],$value,false).'>'.esc_html($label).'</option>';
 echo '</select></td></tr>';
 echo '<tr><th>العبارة السفلية</th><td><label><input type="checkbox" name="show_caption" id="altaawun-splash-caption-toggle" value="1" '.checked(!empty($cfg['show_caption']),true,false).'> عرض «معًا .. نصنع لهم مستقبلًا أفضل» فوق الصورة</label><p class="description">أوقف هذا الخيار إذا كانت العبارة موجودة داخل الصورة المختارة أصلًا.</p></td></tr>';
 echo '<tr><th><label for="altaawun-splash-scale">حجم الصورة</label></th><td><input type="range" id="altaawun-splash-scale" name="scale" min=".7" max="1.5" step=".05" value="'.esc_attr($cfg['scale']).'"> <output id="altaawun-splash-scale-out"></output></td></tr>';
 echo '<tr><th><label for="altaawun-splash-x">الموضع الأفقي</label></th><td><input type="range" id="altaawun-splash-x" name="align_x" min="-1" max="1" step=".1" value="'.esc_attr($cfg['align_x']).'"> <span>يسار — وسط — يمين</span></td></tr>';
 echo '<tr><th><label for="altaawun-splash-y">الموضع العمودي</label></th><td><input type="range" id="altaawun-splash-y" name="align_y" min="-1" max="1" step=".1" value="'.esc_attr($cfg['align_y']).'"> <span>أعلى — وسط — أسفل</span></td></tr>';
 echo '<tr><th><label for="altaawun-splash-duration">مدة الترحيب</label></th><td><input type="range" id="altaawun-splash-duration" name="duration_ms" min="700" max="8000" step="100" value="'.esc_attr($cfg['duration_ms']).'"> <output id="altaawun-splash-duration-out"></output></td></tr>';
 echo '</tbody></table>';
 echo '<p><button class="button button-primary button-large" type="submit" name="altaawun_splash_action" value="save">حفظ الإعدادات</button> ';
 echo '<button class="button button-secondary" type="submit" name="altaawun_splash_action" value="reset" onclick="return confirm(\'استعادة صورة الترحيب الافتراضية؟\')">استعادة الافتراضي</button></p></form>';
 echo '<h2>معاينة الهاتف (قبل الحفظ)</h2>';
 echo '<div id="altaawun-splash-preview-frame" style="position:relative;width:300px;max-width:95%;height:600px;border:7px solid #333;border-radius:28px;overflow:hidden;background:#075c39;box-shadow:0 5px 18px #0003">';
 echo '<div id="altaawun-splash-preview-background" style="position:absolute;inset:-28px;background-position:center;background-size:cover;filter:blur(18px);transform:scale(1.13);display:none;"></div>';
 echo '<div style="position:absolute;inset:0;overflow:hidden;padding-top:12px;box-sizing:border-box"><img id="altaawun-splash-preview-image" src="'.esc_url($preview_src).'" alt="معاينة شاشة الترحيب" style="display:block;width:100%;height:100%;object-fit:contain;object-position:center top;"></div>';
 echo '<div id="altaawun-splash-caption-preview" style="position:absolute;bottom:14px;left:12px;right:12px;padding:12px 5px;border:1px solid #efcf76;border-radius:14px;background:#003b1d;color:white;text-align:center;font-size:16px">معًا .. نصنع لهم مستقبلًا أفضل</div></div>';
 echo '<p class="description">المعاينة تشمل صورة التطبيق الافتراضية. وضع «ملء المكان مع الحفاظ على الصورة كاملة» يملأ الهوامش بخلفية ضبابية دون قص الشعار أو المدرسة.</p></div>';
 ?>
 <script>
 jQuery(function($) {
   var picker;
   var defaultSource=<?php echo wp_json_encode($default_preview_url); ?>;
   var img=$('#altaawun-splash-preview-image');
   function render() {
     var source=img.attr('src') || defaultSource;
     var fit=$('#altaawun-splash-fit').val();
     var x=parseFloat($('#altaawun-splash-x').val());
     var y=parseFloat($('#altaawun-splash-y').val());
     var smart=fit==='smart';
     var scaleControl=$('#altaawun-splash-scale');
     scaleControl.attr('max',smart?'1':'1.5');
     var scale=parseFloat(scaleControl.val());
     if (smart && scale>1) {
       scale=1;
       scaleControl.val('1');
     }
     var origin=(50+x*50)+'% '+(50+y*50)+'%';
     img.css({'object-fit':smart?'contain':fit,'object-position':origin,'transform-origin':origin,'transform':'scale('+scale+')'});
     $('#altaawun-splash-preview-background').css('background-image','url("'+source.replace(/"/g,'')+'")').toggle(smart);
     $('#altaawun-splash-caption-preview').toggle($('#altaawun-splash-caption-toggle').is(':checked'));
     $('#altaawun-splash-scale-out').text(Math.round(scale*100)+'%');
     $('#altaawun-splash-duration-out').text((parseInt($('#altaawun-splash-duration').val(),10)/1000).toFixed(1)+' ثانية');
   }
   $('#altaawun-splash-choose').on('click',function(e) {
     e.preventDefault();
     if(!picker) {
       picker=wp.media({title:'اختيار صورة الترحيب',button:{text:'استخدام الصورة'},library:{type:'image'},multiple:false});
       picker.on('select',function(){
         var file=picker.state().get('selection').first().toJSON();
         $('#altaawun-splash-image-id').val(file.id);
         img.attr('src',file.url);
         render();
       });
     }
     picker.open();
   });
   $('#altaawun-splash-clear').on('click',function(){
     $('#altaawun-splash-image-id').val('0');
     img.attr('src',defaultSource);
     render();
   });
   $('#altaawun-splash-fit,#altaawun-splash-caption-toggle,#altaawun-splash-scale,#altaawun-splash-x,#altaawun-splash-y,#altaawun-splash-duration').on('input change',render);
   render();
 });
 </script>
 <?php
}

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
  // Nine FCM topic calls in an admin HTTP request can exceed PHP/proxy timeouts.
  // Queue the job and let WP-Cron perform the same fan-out in the background.
  $title=sanitize_text_field(wp_unslash($_POST['title'] ?? ''));
  $body=sanitize_textarea_field(wp_unslash($_POST['body'] ?? ''));
  $url=esc_url_raw(wp_unslash($_POST['url'] ?? ''));
  $type=sanitize_key(wp_unslash($_POST['notification_type'] ?? 'normal'));
  $result=altaawun_queue_manual_notification($title,$body,$url,$type,absint($_POST['post_id'] ?? 0),!empty($_POST['open_home']));
  echo '<div class="notice notice-'.(is_wp_error($result)?'error':'success').'"><p>'.esc_html(
   is_wp_error($result)?$result->get_error_message():($result==='sent'?'قبل Firebase الإشعار اليدوي، تحقق من وصوله على الهاتف.':'تم إدراج الإشعار اليدوي للإرسال في الخلفية. راقب حالة الإرسال أدناه.')
  ).'</p></div>';
 }
 $last=get_option('altaawun_push_last_manual_status',[]);
 if (is_array($last) && !empty($last['status'])) {
  $names=['queued'=>'قيد الانتظار','sending'=>'جاري الإرسال','accepted'=>'قبله Firebase — تحقق من الهاتف','failed'=>'فشل الإرسال'];
  $status=$last['status'];
  $label=$names[$status]??'غير معروف';
  $note=($status==='failed' && !empty($last['error'])) ? ': '.$last['error'] : '';
  echo '<div class="notice notice-'.($status==='failed'?'error':'info').'"><p>'.esc_html(
   'آخر إشعار يدوي: '.$label.$note.' — '.($last['time']??'')
  ).'</p></div>';
 }
 echo '<div class="wrap" dir="rtl"><h1>إشعارات جمعية التعاون الخيرية — 1.2.11</h1><p>إرسال إلى قنوات النغمات الجديدة والقناة القديمة للأجهزة السابقة.</p>';
 echo '<h2>إعداد Firebase Service Account</h2><form method="post">';
 wp_nonce_field('altaawun_push_save');
 echo '<textarea name="credentials" rows="8" style="width:90%;direction:ltr" placeholder="Service Account JSON"></textarea><p><button class="button button-primary" name="altaawun_save">حفظ</button></p></form>';
 echo '<h2>إرسال إشعار يدوي</h2><form method="post">';
 wp_nonce_field('altaawun_push_send');
 echo '<p><input name="title" required maxlength="120" placeholder="عنوان الإشعار" class="regular-text"></p><p><textarea name="body" required maxlength="1000" placeholder="نص الإشعار" rows="4" style="width:90%"></textarea></p>';
 echo '<p><label>اختر خبرًا منشورًا لعرض تفاصيله داخل التطبيق:</label> <select name="post_id"><option value="0">— اختر الخبر —</option>';
 foreach (get_posts(['post_type'=>'post','post_status'=>'publish','posts_per_page'=>50,'orderby'=>'date','order'=>'DESC']) as $item)
  echo '<option value="'.absint($item->ID).'">'.esc_html(get_the_title($item)).'</option>';
 echo '</select></p>';
 echo '<p><label>أو أدخل رابط الخبر من موقع الجمعية:<br><input type="url" name="url" placeholder="https://www.aytamaliraq.com/..." style="width:90%;direction:ltr"></label></p>';
 echo '<p><strong>إشعار نصي فقط:</strong> اترك اختيار الخبر والرابط فارغين. عند الضغط على الإشعار ستظهر نافذة داخل التطبيق تعرض العنوان والنص الكامل.</p>';
 echo '<p>تتطلب نافذة التفاصيل النصية نسخة التطبيق المحدثة. إشعارات الأخبار ذات الروابط تستمر بالعمل كالسابق.</p>';
 echo '<p><label>نوع الإشعار <select name="notification_type"><option value="normal">عادي</option><option value="urgent">عاجل</option></select></label></p>';
 echo '<button class="button button-primary" name="altaawun_send">إرسال الإشعار</button></form><p>يُرسل إشعار تلقائي عند نشر مقال أو منتج جديد لأول مرة.</p></div>';
}
/**
 * Queue a manual notification, retaining one visible admin status.
 * Avoids running nine sequential FCM HTTP calls inside a web admin request.
 * Does not modify the automatic new-post publishing workflow.
 */
function altaawun_queue_manual_notification($title,$body,$url='',$type='normal',$post_id=0,$open_home=false) {
 if (!get_option('altaawun_push_credentials','')) return new WP_Error('config','إعداد Firebase Service Account غير موجود.');
 if (!$title||!$body) return new WP_Error('empty','العنوان والنص مطلوبان.');
 if ($url) {
  $post_id=0;
  $uri=wp_parse_url($url);
  if (!$uri || strtolower($uri['scheme']??'')!=='https' || empty($uri['host']) || !empty($uri['user']) || !empty($uri['pass'])
   || !in_array(strtolower($uri['host']),['aytamaliraq.com','www.aytamaliraq.com'],true))
   return new WP_Error('url','أدخل رابط HTTPS لخبر موجود على موقع الجمعية.');
 } elseif ($post_id>0) {
  $post=get_post($post_id);
  if (!$post || $post->post_status!=='publish' || $post->post_type!=='post')
   return new WP_Error('post','الخبر المحدد غير منشور. اختر خبرًا منشورًا.');
  $url=get_permalink($post_id);
 } else {
  // No published post selected and no URL: show the message itself.
  $open_home=true;
 }
 // Fast path: send immediately, without waiting for WP-Cron.
 // cURL multi dispatches all nine topic messages concurrently, while
 // automatic publication alerts still use their original code unchanged.
 if (function_exists('curl_multi_init') && !defined('WP_PROXY_HOST')) {
  $result=altaawun_push_send($title,$body,$url,$type,0,$post_id,($open_home && !$url));
  update_option('altaawun_push_last_manual_status',[
   'id'=>wp_generate_uuid4(),
   'status'=>is_wp_error($result)?'failed':'accepted',
   'error'=>is_wp_error($result)?$result->get_error_message():'',
   'time'=>current_time('mysql')
  ],false);
  return is_wp_error($result)?$result:'sent';
 }
 $id=wp_generate_uuid4();
 $payload=['id'=>$id,'title'=>$title,'body'=>$body,'url'=>$url,'post_id'=>$post_id,'open_home'=>($open_home && !$url),'type'=>$type==='urgent'?'urgent':'normal','time'=>current_time('mysql')];
 $key='altaawun_push_manual_job_'.$id;
 add_option($key,$payload,'','no');
 $scheduled=wp_schedule_single_event(time(),'altaawun_push_manual_send_job',[$id],true);
 if (is_wp_error($scheduled) || !$scheduled) {
  delete_option($key);
  return new WP_Error('schedule','تعذر جدولة الإشعار اليدوي. تحقق من عمل WP-Cron.');
 }
 update_option('altaawun_push_last_manual_status',['id'=>$id,'status'=>'queued','time'=>current_time('mysql')],false);
 if (!wp_doing_cron()) add_action('shutdown','altaawun_push_kick_cron',100);
 return 'queued';
}
add_action('altaawun_push_manual_send_job',function($id){
 $key='altaawun_push_manual_job_'.$id;
 $job=get_option($key,[]);
 if (!is_array($job) || ($job['id']??'')!==$id) return;
 $status=get_option('altaawun_push_last_manual_status',[]);
 $is_current=is_array($status) && ($status['id']??'')===$id;
 if ($is_current) update_option('altaawun_push_last_manual_status',['id'=>$id,'status'=>'sending','time'=>current_time('mysql')],false);
 $result=altaawun_push_send($job['title'],$job['body'],$job['url'],$job['type'],0,absint($job['post_id']??0),!empty($job['open_home']));
 if ($is_current) update_option('altaawun_push_last_manual_status',[
  'id'=>$id,'status'=>is_wp_error($result)?'failed':'accepted',
  'error'=>is_wp_error($result)?$result->get_error_message():'',
  'time'=>current_time('mysql')
 ],false);
 delete_option($key);
},10,1);
function altaawun_push_topics() {
 $result=['altaawun_updates'=>'altaawun_normal_v1'];
 foreach (['urgent','news','soft','default'] as $tone)
  foreach (['vibrate','silent'] as $mode)
   $result['altaawun_tone_'.$tone.'_'.$mode]='altaawun_tone_v2_'.$tone.'_'.$mode;
 return $result;
}
function altaawun_push_send($title,$body,$url='',$type='normal',$post_id=0,$related_post_id=0,$open_home=false) {
 $a=json_decode(get_option('altaawun_push_credentials',''),true);
 if (empty($a['private_key'])||empty($a['client_email'])||empty($a['project_id'])) return new WP_Error('config','أدخل ملف Service Account أولاً.');
 if (!$title||!$body) return new WP_Error('empty','العنوان والنص مطلوبان.');
 $url=trim((string)$url);
 if ($url) {
  $uri=wp_parse_url($url);
  if (!$uri || strtolower($uri['scheme']??'')!=='https' || empty($uri['host']) || !empty($uri['user']) || !empty($uri['pass']))
   return new WP_Error('url','رابط الخبر يجب أن يكون HTTPS صالحًا.');
 }
 $now=time();
 $b64=function($s){return rtrim(strtr(base64_encode($s),'+/','-_'),'=');};
 $jwt=$b64(wp_json_encode(['alg'=>'RS256','typ'=>'JWT'])).'.'.$b64(wp_json_encode(['iss'=>$a['client_email'],'scope'=>'https://www.googleapis.com/auth/firebase.messaging','aud'=>'https://oauth2.googleapis.com/token','iat'=>$now,'exp'=>$now+3500]));
 if (!openssl_sign($jwt,$signature,$a['private_key'],OPENSSL_ALGO_SHA256)) return new WP_Error('sign','تعذر توقيع Firebase JWT.');
 $auth=wp_remote_post('https://oauth2.googleapis.com/token',['timeout'=>20,'body'=>['grant_type'=>'urn:ietf:params:oauth:grant-type:jwt-bearer','assertion'=>$jwt.'.'.$b64($signature)]]);
 if (is_wp_error($auth)) return $auth;
 $token=json_decode(wp_remote_retrieve_body($auth),true)['access_token']??'';
 if (!$token) return new WP_Error('oauth','تعذر الحصول على رمز Firebase.');
 $sent=$post_id>0?get_post_meta($post_id,'_altaawun_push_topics_sent',true):[];
 if (!is_array($sent)) $sent=[];
 $errors=[];
 $manual_messages=[];
 foreach (altaawun_push_topics() as $topic=>$channel) {
  if (in_array($topic,$sent,true)) continue;
  $data=['type'=>$type==='urgent'?'urgent':'normal','screen'=>($open_home && !$url)?'message':'news'];
  if ($open_home && !$url) {
   $data['title']=mb_substr(wp_strip_all_tags($title),0,120);
   $data['body']=mb_substr(wp_strip_all_tags($body),0,1000);
  }
  if ($url) $data['url']=$url;
  if ($related_post_id>0) $data['post_id']=(string)$related_post_id;
  elseif ($post_id>0) $data['post_id']=(string)$post_id;
  $message=[
   'topic'=>$topic,
   'notification'=>['title'=>mb_substr($title,0,120),'body'=>mb_substr($body,0,1000)],
   'data'=>$data,
   'android'=>['priority'=>'high','notification'=>['channel_id'=>$channel]],
   'apns'=>['headers'=>['apns-push-type'=>'alert','apns-priority'=>'10'],'payload'=>['aps'=>['sound'=>'default']]]
  ];
  // Manual notifications can dispatch all tone topics concurrently.
  // Keep the existing, working automatic-post send path unchanged.
  if ($post_id===0 && function_exists('curl_multi_init') && !defined('WP_PROXY_HOST')) {
   $manual_messages[$topic]=$message;
   continue;
  }
  $response=wp_remote_post('https://fcm.googleapis.com/v1/projects/'.rawurlencode($a['project_id']).'/messages:send',['timeout'=>20,'headers'=>['Authorization'=>'Bearer '.$token,'Content-Type'=>'application/json'],'body'=>wp_json_encode(['message'=>$message])]);
  if (is_wp_error($response)) $errors[]=$topic.': '.$response->get_error_message();
  elseif (wp_remote_retrieve_response_code($response)!==200) $errors[]=$topic.': HTTP '.wp_remote_retrieve_response_code($response).' '.mb_substr(wp_strip_all_tags(wp_remote_retrieve_body($response)),0,160);
  else {
   $sent[]=$topic;
   if ($post_id>0) update_post_meta($post_id,'_altaawun_push_topics_sent',$sent);
  }
 }
 if ($manual_messages) {
  $batch=altaawun_push_send_manual_parallel($manual_messages,$token,$a['project_id']);
  if (is_wp_error($batch)) $errors[]=$batch->get_error_message();
 }
 if ($errors) return new WP_Error('fcm','فشل الإرسال إلى '.count($errors).' قنوات؛ '.implode(' | ',array_slice($errors,0,2)));
 return true;
}

/** Send manual alerts to their individual sound channels concurrently. */
function altaawun_push_send_manual_parallel($messages,$token,$project) {
 $multi=curl_multi_init();
 $handles=[];
 $endpoint='https://fcm.googleapis.com/v1/projects/'.rawurlencode($project).'/messages:send';
 foreach ($messages as $topic=>$message) {
  $handle=curl_init($endpoint);
  curl_setopt_array($handle,[
   CURLOPT_POST=>true,
   CURLOPT_POSTFIELDS=>wp_json_encode(['message'=>$message]),
   CURLOPT_HTTPHEADER=>['Authorization: Bearer '.$token,'Content-Type: application/json'],
   CURLOPT_RETURNTRANSFER=>true,
   CURLOPT_CONNECTTIMEOUT=>10,
   CURLOPT_TIMEOUT=>25,
   CURLOPT_SSL_VERIFYPEER=>true,
   CURLOPT_SSL_VERIFYHOST=>2
  ]);
  curl_multi_add_handle($multi,$handle);
  $handles[$topic]=$handle;
 }
 $running=0;
 $status=CURLM_OK;
 do {
  $status=curl_multi_exec($multi,$running);
  if ($status!==CURLM_OK) break;
  if ($running>0) {
   $selected=curl_multi_select($multi,1);
   if ($selected===-1) usleep(100000);
  }
 } while ($running>0);
 $errors=[];
 if ($status!==CURLM_OK) $errors[]='تعذر تنفيذ طلبات Firebase المتزامنة';
 foreach ($handles as $topic=>$handle) {
  $http=(int)curl_getinfo($handle,CURLINFO_HTTP_CODE);
  $error=curl_error($handle);
  if ($error || $http!==200) {
   $body=(string)curl_multi_getcontent($handle);
   $errors[]=$topic.': '.($error?:'Firebase HTTP '.$http.' '.mb_substr(wp_strip_all_tags($body),0,120));
  }
  curl_multi_remove_handle($multi,$handle);
  curl_close($handle);
 }
 curl_multi_close($multi);
 if ($errors) return new WP_Error('fcm_parallel',implode(' | ',array_slice($errors,0,2)));
 return true;
}
function altaawun_push_queue_post($id) {
 $post=get_post($id);
 if (!$post||!in_array($post->post_type,['post','product'],true)||$post->post_status!=='publish'||get_post_meta($id,'_altaawun_push_sent',true)) return;
 if (!wp_next_scheduled('altaawun_send_post_notification',[$id]))
  wp_schedule_single_event(time(),'altaawun_send_post_notification',[$id]);
 // Trigger background cron immediately, without delaying the post editor.
 if (!wp_doing_cron()) add_action('shutdown','altaawun_push_kick_cron',100);
}
function altaawun_push_kick_cron() {
 if (!wp_doing_cron() && function_exists('spawn_cron')) spawn_cron(time());
}
add_action('wp_after_insert_post',function($post,$update,$post_before){
 if (!$post instanceof WP_Post || !in_array($post->post_type,['post','product'],true)||$post->post_status!=='publish') return;
 if ($post_before instanceof WP_Post && $post_before->post_status==='publish') return;
 altaawun_push_queue_post($post->ID);
},20,3);
add_action('transition_post_status',function($new,$old,$post){
 if ($new!=='publish'||$old==='publish'||!$post instanceof WP_Post) return;
 altaawun_push_queue_post($post->ID);
},30,3);
function altaawun_queue_new_product_notification($id) {
 $post=get_post($id);
 if (!$post||$post->post_type!=='product'||$post->post_status!=='publish'||get_post_meta($id,'_altaawun_push_sent',true)) return;
 $created=get_post_time('U',true,$post);
 if (!$created||time()-$created>600) return;
 altaawun_push_queue_post($id);
}
add_action('save_post_product','altaawun_queue_new_product_notification',20,1);
add_action('woocommerce_new_product','altaawun_queue_new_product_notification',20,1);
add_action('altaawun_send_post_notification',function($id){
 $post=get_post($id);
 if (!$post||!in_array($post->post_type,['post','product'],true)||$post->post_status!=='publish'||get_post_meta($id,'_altaawun_push_sent',true)) return;
 $lock=(int)get_post_meta($id,'_altaawun_push_lock',true);
 if ($lock && time()-$lock>600) delete_post_meta($id,'_altaawun_push_lock');
 if (!add_post_meta($id,'_altaawun_push_lock',time(),true)) return;
 try {
  $type=get_post_meta($id,'_altaawun_notification_type',true)==='urgent'?'urgent':'normal';
  $body=wp_strip_all_tags(wp_trim_words($post->post_content,28,'…'));
  if (!$body) $body=get_the_title($post);
  $result=altaawun_push_send(get_the_title($post),$body,get_permalink($post),$type,$id);
  update_post_meta($id,'_altaawun_push_last_attempt',current_time('mysql'));
  if (is_wp_error($result)) {
   update_post_meta($id,'_altaawun_push_last_error',$result->get_error_message());
   $attempts=(int)get_post_meta($id,'_altaawun_push_attempts',true)+1;
   update_post_meta($id,'_altaawun_push_attempts',$attempts);
   if ($attempts<8 && !wp_next_scheduled('altaawun_send_post_notification',[$id]))
    wp_schedule_single_event(time()+min(3600,60*(2**($attempts-1))),'altaawun_send_post_notification',[$id]);
  } else {
   update_post_meta($id,'_altaawun_push_sent',1);
   delete_post_meta($id,'_altaawun_push_last_error');
   delete_post_meta($id,'_altaawun_push_attempts');
  }
 } finally {
  delete_post_meta($id,'_altaawun_push_lock');
 }
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
