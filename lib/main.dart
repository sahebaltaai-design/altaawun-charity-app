import 'charity_about_content.dart';
import 'charity_account_page.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _initializeNotificationChannels();
  runApp(const AltaawunApp());
}

const _notificationChannelPrefix = 'altaawun_tone_v2_';
final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
final ValueNotifier<String?> notificationTapUrl = ValueNotifier<String?>(null);

Future<void> _initializeNotificationChannels() async {
  await _localNotifications.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ), onDidReceiveNotificationResponse: (response) {
    notificationTapUrl.value = response.payload;
  });
  final launch = await _localNotifications.getNotificationAppLaunchDetails();
  if (launch?.didNotificationLaunchApp == true) {
    notificationTapUrl.value = launch?.notificationResponse?.payload;
  }
  final android = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  for (final tone in const ['urgent', 'news', 'soft', 'default']) {
    for (final vibration in [true, false]) {
      final isDefault = tone == 'default';
      await android?.createNotificationChannel(AndroidNotificationChannel(
        _notificationChannelPrefix + tone + (vibration ? '_vibrate' : '_silent'),
        'إشعارات الجمعية - ' + tone + (vibration ? ' مع اهتزاز' : ' بدون اهتزاز'),
        description: 'قناة صوت إشعارات الجمعية',
        importance: Importance.high,
        playSound: true,
        sound: isDefault ? null : RawResourceAndroidNotificationSound('altaawun_' + tone),
        enableVibration: vibration,
      ));
    }
  }
}

const green = Color(0xFF00642D);
const deepGreen = Color(0xFF004521);
const red = Color(0xFFB70922);
const ivory = Color(0xFFF8F8F5);

final ValueNotifier<String> selectedAppFont = ValueNotifier('Tajawal');
final ValueNotifier<String> selectedAppFontSize = ValueNotifier('medium');

class AltaawunApp extends StatefulWidget {
  const AltaawunApp({super.key});
  @override
  State<AltaawunApp> createState() => _AltaawunAppState();
}

class _AltaawunAppState extends State<AltaawunApp> {
  @override
  void initState() {
    super.initState();
    _restoreTypography();
  }

  Future<void> _restoreTypography() async {
    final prefs = await SharedPreferences.getInstance();
    selectedAppFont.value = prefs.getString('app_font') ?? 'Tajawal';
    selectedAppFontSize.value = prefs.getString('app_font_size') ?? 'medium';
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: selectedAppFont,
    builder: (context, font, _) => ValueListenableBuilder<String>(
      valueListenable: selectedAppFontSize,
      builder: (context, size, _) {
        final textTheme = switch (font) {
          'Cairo' => GoogleFonts.cairoTextTheme(),
          'Almarai' => GoogleFonts.almaraiTextTheme(),
          'Amiri' => GoogleFonts.amiriTextTheme(),
          _ => GoogleFonts.tajawalTextTheme(),
        };
        final scale = size == 'small' ? 0.9 : size == 'large' ? 1.15 : 1.0;
        return MaterialApp(
          title: 'جمعية التعاون الخيرية',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            textTheme: textTheme,
            scaffoldBackgroundColor: ivory,
            colorScheme: ColorScheme.fromSeed(seedColor: green),
            appBarTheme: const AppBarTheme(backgroundColor: green, foregroundColor: Colors.white, centerTitle: true),
          ),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child ?? const SizedBox(),
            ),
          ),
          home: const SplashScreen(),
        );
      },
    ),
  );
}

class ProductDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final name = (product['name'] ?? 'تفاصيل المنتج').toString();
    final image = (product['image'] ?? '').toString();
    final price = (product['price'] ?? '').toString();
    final description = (product['description'] ?? '').toString();
    final link = (product['link'] ?? '').toString();
    final uri = Uri.tryParse(link);
    final validLink = uri != null && uri.scheme == 'https' &&
        (uri.host == 'aytamaliraq.com' || uri.host == 'www.aytamaliraq.com');
    return Scaffold(
      appBar: AppBar(title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        if (image.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(image, height: 260, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 180, child: Icon(Icons.shopping_bag, size: 80))),
          ),
        const SizedBox(height: 18),
        Text(name, style: Theme.of(context).textTheme.headlineSmall),
        if (price.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(price, style: const TextStyle(
            color: green, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
        if (description.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(description, style: const TextStyle(fontSize: 16, height: 1.6)),
        ],
        const SizedBox(height: 26),
        FilledButton.icon(
          onPressed: validLink ? () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DonationWebScreen(url: link))) : null,
          icon: const Icon(Icons.volunteer_activism),
          label: const Text('تبرع الآن'),
        ),
        const SizedBox(height: 8),
        const Text('يتم إكمال التبرع عبر صفحة المنتج الآمنة على موقع الجمعية داخل التطبيق.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
      ]),
    );
  }
}

class DonationWebScreen extends StatefulWidget {
  final String url;
  const DonationWebScreen({super.key, required this.url});
  @override
  State<DonationWebScreen> createState() => _DonationWebScreenState();
}

class _DonationWebScreenState extends State<DonationWebScreen> {
  late final WebViewController controller;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null || uri.scheme != 'https') return NavigationDecision.prevent;
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إكمال التبرع')),
    body: WebViewWidget(controller: controller),
  );
}

class _HtmlContent extends StatefulWidget {
  final String content;
  final ValueChanged<String> onLink;
  const _HtmlContent({required this.content, required this.onLink});
  @override
  State<_HtmlContent> createState() => _HtmlContentState();
}
class _HtmlContentState extends State<_HtmlContent> {
  late final WebViewController controller;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri != null && uri.scheme == 'https' && request.isMainFrame) {
            widget.onLink(request.url);
          }
          return NavigationDecision.prevent;
        },
      ));
    controller.loadHtmlString(
      '<!doctype html><html lang="ar" dir="rtl"><head>'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '<style>body{font-family:sans-serif;font-size:17px;line-height:1.8;'
      'padding:8px;margin:0;overflow-wrap:anywhere;}'
      'img,video,audio,iframe,embed{max-width:100%;}'
      'img{height:auto;}video{height:auto;}audio{width:100%;}'
      'iframe{width:100%;min-height:260px;border:0;}</style></head><body>'
      '${widget.content}'
      '<script>document.querySelectorAll("video,audio").forEach(function(m){'
      'm.setAttribute("controls","controls");m.setAttribute("preload","metadata");'
      '});</script></body></html>',
      baseUrl: 'https://www.aytamaliraq.com/',
    );
  }
  @override
  Widget build(BuildContext context) => WebViewWidget(controller: controller);
}
class _CheckoutContent extends StatefulWidget {
  final String url;
  final ValueChanged<int> onCartCount;
  const _CheckoutContent({super.key, required this.url, required this.onCartCount});
  @override
  State<_CheckoutContent> createState() => _CheckoutContentState();
}
class _CheckoutContentState extends State<_CheckoutContent> {
  late final WebViewController controller;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('AltaawunCart', onMessageReceived: (message) {
        final count = int.tryParse(message.message);
        if (count != null && count >= 0 && mounted) widget.onCartCount(count);
      })
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null || uri.scheme != 'https') return NavigationDecision.prevent;
          if (!request.isMainFrame) return NavigationDecision.navigate;
          final initial = Uri.tryParse(widget.url);
          if (initial == null) return NavigationDecision.prevent;
          final host = uri.host.toLowerCase();
          final sameSite = host == 'aytamaliraq.com' || host == 'www.aytamaliraq.com';
          if (!sameSite) {
            // External payment providers may be needed after the user begins checkout.
            final current = await controller.currentUrl();
            final currentPath = Uri.tryParse(current ?? '')?.path.toLowerCase() ?? '';
            return currentPath.contains('/checkout') || currentPath.contains('/order-pay')
                ? NavigationDecision.navigate : NavigationDecision.prevent;
          }
          final path = uri.path.toLowerCase();
          final originalPath = initial.path.toLowerCase();
          final isOriginal = path == originalPath;
          final isCheckout = path.contains('/checkout') || path.contains('/cart') ||
              path.contains('/order-pay') || path.contains('/order-received') ||
              path.contains('/my-account') || path.contains('/wc-api/');
          final isAction = uri.queryParameters.containsKey('add-to-cart') ||
              uri.queryParameters.containsKey('wc-ajax') ||
              uri.queryParameters.containsKey('remove_item') ||
              uri.queryParameters.containsKey('undo_item');
          return isOriginal || isCheckout || isAction
              ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
        onPageFinished: (url) {
          final uri = Uri.tryParse(url);
          if (uri != null && (uri.host == 'www.aytamaliraq.com' || uri.host == 'aytamaliraq.com')) {
            controller.runJavaScript(_cartWatcherScript);
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }
  static const _cartWatcherScript = r'''(function(){
  if(window.__altaawunCartInstalled) return;
  window.__altaawunCartInstalled = true;
  var last = -1, pending;
  function parse(doc){
    var fields = Array.from(doc.querySelectorAll(
      '.woocommerce-cart-form input.qty, .wc-block-cart-items input.wc-block-components-quantity-selector__input, .wc-block-cart-items input[type="number"]'));
    if(fields.length) return fields.reduce(function(sum,el){return sum+(parseInt(el.value,10)||0);},0);
    var empty = doc.querySelector('.cart-empty, .wc-block-cart__empty-cart__title, .wc-block-cart__empty-cart');
    if(empty) return 0;
    var rows = doc.querySelectorAll('.woocommerce-cart-form .cart_item, .wc-block-cart-items__row');
    if(rows.length) return rows.length;
    return null;
  }
  function report(n){
    if(n !== null && n >= 0 && n !== last && window.AltaawunCart){
      last=n; window.AltaawunCart.postMessage(String(n));
    }
  }
  function refresh(){
    clearTimeout(pending);
    pending=setTimeout(function(){
      var current = parse(document);
      if(/\/cart\/?($|[?#])/.test(location.pathname) && current !== null){report(current);return;}
      fetch('/cart/?altaawun_cart_count=1',{credentials:'same-origin',cache:'no-store'})
        .then(function(r){if(!r.ok)throw Error('cart');return r.text();})
        .then(function(html){report(parse(new DOMParser().parseFromString(html,'text/html')));})
        .catch(function(){});
    },600);
  }
  refresh();
  if(window.jQuery){
    window.jQuery(document.body).on('added_to_cart removed_from_cart wc_fragments_refreshed updated_wc_div updated_cart_totals',refresh);
  }
  document.addEventListener('change',function(e){if(e.target.matches('input.qty'))refresh();});
  new MutationObserver(function(m){
    if(m.some(function(x){return x.addedNodes.length || x.removedNodes.length;}))refresh();
  }).observe(document.body,{childList:true,subtree:true});
})();''';
  @override
  void didUpdateWidget(covariant _CheckoutContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      controller.loadRequest(Uri.parse(widget.url));
    }
  }
  @override
  Widget build(BuildContext context) => WebViewWidget(controller: controller);
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(builder: (context, constraints) => Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/welcome_background-2.png',
          fit: BoxFit.fill,
          errorBuilder: (_, __, ___) => const ColoredBox(color: deepGreen),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const CharityShell())),
                    icon: const Icon(Icons.login, size: 27),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('الدخول إلى التطبيق',
                        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00652A),
                      foregroundColor: Colors.white,
                      elevation: 6,
                      side: const BorderSide(color: Color(0xFFFFD66A), width: 2.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(36)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003B1D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD66A), width: 1),
                  ),
                  child: const Text(
                    'معًا .. نصنع لهم مستقبلًا أفضل',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    )),
  );
}

class _SchoolIllustration extends StatelessWidget {
  const _SchoolIllustration();
  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned.fill(child: CustomPaint(painter: _SchoolPainter())),
    const Positioned(left: 15, bottom: 22,
      child: Icon(Icons.park, color: Color(0xFF318D45), size: 86)),
    const Positioned(right: 8, bottom: 20,
      child: Icon(Icons.park, color: Color(0xFF318D45), size: 96)),
    const Positioned(left: 55, right: 55, bottom: 8,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        Icon(Icons.backpack, color: Color(0xFF194A75), size: 48),
        Icon(Icons.backpack, color: Color(0xFF194A75), size: 52),
        Icon(Icons.backpack, color: Color(0xFF194A75), size: 46),
        Icon(Icons.backpack, color: Color(0xFF194A75), size: 50),
      ])),
  ]);
}

class _SchoolPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final wall = Paint()..color = const Color(0xFFF0D7AE);
    final outline = Paint()..color = const Color(0xFFCAAC81);
    canvas.drawRect(Rect.fromLTWH(w * .10, h * .20, w * .80, h * .52), wall);
    canvas.drawRect(Rect.fromLTWH(w * .28, h * .11, w * .44, h * .61), wall);
    canvas.drawRect(Rect.fromLTWH(w * .26, h * .10, w * .48, h * .035), outline);
    for (var i = 0; i < 7; i++) {
      final x = w * (.16 + i * .115);
      canvas.drawRect(Rect.fromLTWH(x, h * .33, w * .062, h * .13),
        Paint()..color = const Color(0xFF74B5D0));
    }
    canvas.drawRect(Rect.fromLTWH(w * .44, h * .43, w * .12, h * .29),
      Paint()..color = const Color(0xFF5E8B96));
    canvas.drawRect(Rect.fromLTWH(w * .47, h * .17, w * .06, h * .09),
      Paint()..color = red);
    canvas.drawRect(Rect.fromLTWH(w * .08, h * .71, w * .84, h * .025),
      Paint()..color = const Color(0xFFB9C49C));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Emblem extends StatelessWidget {
  final double size;
  const _Emblem({this.size = 48});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(size * .24),
      border: Border.all(color: green, width: 2),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 12)],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(size * .22), child: Image.asset('assets/welcome_background-2.png', fit: BoxFit.cover, alignment: const Alignment(0, -.82), errorBuilder: (_, __, ___) => Icon(Icons.volunteer_activism, size: size * .67, color: red))),
  );
}

class CharityShell extends StatefulWidget {
  const CharityShell({super.key});
  @override
  State<CharityShell> createState() => _CharityShellState();
}

class _CharityShellState extends State<CharityShell> with WidgetsBindingObserver {
  int? _cartCount;
  int _cartRefreshKey = 0;
  String? _fcmToken;
  String _notificationTone = 'urgent';
  bool _notificationVibration = true;
  String _homeTileSize = 'medium';

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final tone = const ['urgent', 'news', 'soft', 'default'].contains(_notificationTone)
        ? _notificationTone : 'default';
    final channelId = _notificationChannelPrefix + tone + (_notificationVibration ? '_vibrate' : '_silent');
    await _localNotifications.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'جمعية التعاون الخيرية',
      message.notification?.body ?? 'لديك إشعار جديد',
      NotificationDetails(android: AndroidNotificationDetails(
        channelId, 'إشعارات الجمعية',
        importance: Importance.high, priority: Priority.high,
        playSound: true,
        sound: tone == 'default' ? null : RawResourceAndroidNotificationSound('altaawun_' + tone),
        enableVibration: _notificationVibration,
      )),
      payload: (message.data['url'] ?? message.data['link'] ?? '').toString(),
    );
  }

  Future<void> _syncNotificationToneTopic() async {
    final tone = const ['urgent', 'news', 'soft', 'default'].contains(_notificationTone)
        ? _notificationTone : 'default';
    final desired = 'altaawun_tone_' + tone + (_notificationVibration ? '_vibrate' : '_silent');
    final messaging = FirebaseMessaging.instance;
    // Remove legacy broadcasts to prevent duplicate notifications.
    await messaging.subscribeToTopic(desired);
    for (final candidate in const ['urgent', 'news', 'soft', 'default']) {
      for (final mode in const ['_vibrate', '_silent']) {
        final topic = 'altaawun_tone_' + candidate + mode;
        if (topic != desired) await messaging.unsubscribeFromTopic(topic);
      }
    }
    await messaging.unsubscribeFromTopic('altaawun_updates');
  }

  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationTone = prefs.getString('notification_tone') ?? 'urgent';
      _notificationVibration = prefs.getBool('notification_vibration') ?? true;
    });
  }

  Future<void> _showFontPreferences() async {
    String font = selectedAppFont.value;
    String size = selectedAppFontSize.value;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('نوع الخط وحجمه'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final option in const ['Tajawal', 'Cairo', 'Almarai', 'Amiri'])
                RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: font,
                  onChanged: (value) => refresh(() => font = value ?? 'Tajawal'),
                ),
              const Divider(),
              const Text('حجم الخط'),
              for (final option in const [('small', 'صغير'), ('medium', 'متوسط'), ('large', 'كبير')])
                RadioListTile<String>(
                  title: Text(option.$2),
                  value: option.$1,
                  groupValue: size,
                  onChanged: (value) => refresh(() => size = value ?? 'medium'),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('app_font', font);
                await prefs.setString('app_font_size', size);
                selectedAppFont.value = font;
                selectedAppFontSize.value = size;
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotificationPreferences() async {
    String selected = _notificationTone;
    bool vibration = _notificationVibration;
    final preview = AudioPlayer();
    String? playing;
    try {
      await showDialog<void>(context: context, builder: (dialogContext) =>
        StatefulBuilder(builder: (context, update) => AlertDialog(
          title: const Text('إعدادات الإشعارات'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('استمع إلى النغمة قبل اختيارها وحفظها.'),
            for (final option in const [
              ('urgent', 'تنبيه الأخبار العاجلة'),
              ('news', 'نغمة الأخبار'),
              ('soft', 'نغمة هادئة'),
              ('default', 'النغمة الافتراضية (معاينة تقريبية)'),
            ]) Row(children: [
              Expanded(child: RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text(option.$2, style: const TextStyle(fontSize: 13)),
                value: option.$1, groupValue: selected,
                onChanged: (value) => update(() => selected = value ?? 'urgent'),
              )),
              IconButton(
                tooltip: 'استماع',
                icon: const Icon(Icons.play_circle_outline),
                onPressed: () async {
                  await preview.stop();
                  await preview.play(AssetSource('tones/${option.$1}.wav'));
                  update(() => playing = option.$1);
                },
              ),
              IconButton(
                tooltip: 'إيقاف',
                icon: const Icon(Icons.stop_circle_outlined),
                onPressed: playing == option.$1 ? () async {
                  await preview.stop();
                  update(() => playing = null);
                } : null,
              ),
            ]),
            SwitchListTile(title: const Text('الاهتزاز'), value: vibration,
              onChanged: (value) => update(() => vibration = value)),
            const Text('تُطبّق النغمة المختارة أثناء فتح التطبيق. إشعارات الخلفية تعتمد على قناة Android وإعدادات Firebase.',
              style: TextStyle(fontSize: 12)),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('notification_tone', selected);
              await prefs.setBool('notification_vibration', vibration);
              if (!mounted) return;
              setState(() { _notificationTone = selected; _notificationVibration = vibration; });
              try { await _syncNotificationToneTopic(); } catch (e) { debugPrint('Tone topic sync: $e'); }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }, child: const Text('حفظ')),
          ],
        )));
    } finally {
      await preview.stop();
      await preview.dispose();
    }
  }

  bool _validNewsUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' &&
        (uri.host == 'aytamaliraq.com' || uri.host == 'www.aytamaliraq.com');
  }

  void _openNotificationNews(RemoteMessage message) {
    final url = (message.data['url'] ?? message.data['link'] ?? '').toString();
    _openNotificationUrl(url);
  }

  void _openNotificationUrl(String url) {
    if (!_validNewsUrl(url) || !mounted) return;
    setState(() {
      checkoutUrl = url;
      selectedItem = null;
      wpSelectedCategory = null;
      page = 4;
    });
  }

  void _onLocalNotificationTap() {
    final url = notificationTapUrl.value;
    if (url == null || url.isEmpty) return;
    notificationTapUrl.value = null;
    _openNotificationUrl(url);
  }

  Future<void> _setupPush() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      await _syncNotificationToneTopic();
      final token = await messaging.getToken();
      if (mounted) setState(() => _fcmToken = token);
      FirebaseMessaging.instance.onTokenRefresh.listen((value) {
        if (mounted) setState(() => _fcmToken = value);
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_openNotificationNews);
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openNotificationNews(initial));
      }
      FirebaseMessaging.onMessage.listen((message) {
        if (!mounted) return;
        _showForegroundNotification(message);
        final url = (message.data['url'] ?? '').toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message.notification?.title ?? 'إشعار جديد من الجمعية'),
          action: _validNewsUrl(url) ? SnackBarAction(
            label: 'قراءة الخبر',
            onPressed: () => _openNotificationNews(message),
          ) : null,
        ));
      });
    } catch (e) {
      debugPrint('FCM initialization: $e');
    }
  }
  DateTime? _lastCategoryFetch;
  static const _refreshInterval = Duration(hours: 6);
  bool _fetchingCategories = false;
  int page = 0;
  final names = const ['الرئيسية', 'كفالة الأيتام', 'المدرسة والتعليم', 'التبرعات والمساهمات', 'الأخبار والأنشطة', 'الصور والفيديوهات', 'عن الجمعية', 'حسابي'];
  static const _defaultCategoryOrder = [2, 1, 3, 5, 4, 6];
  static const _categoryLabels = {
    2: 'المدرسة والتعليم', 1: 'كفالة الأيتام',
    3: 'التبرعات والمساهمات', 5: 'الصور والفيديوهات',
    4: 'الأخبار والأنشطة', 6: 'عن الجمعية',
  };
  static const _categoryIcons = {
    2: Icons.school, 1: Icons.groups, 3: Icons.volunteer_activism,
    5: Icons.photo_library, 4: Icons.article, 6: Icons.menu_book,
  };
  List<int> categoryOrder = List.of(_defaultCategoryOrder);
  Set<int> hiddenCategories = {};
  Map<int, String> customCategories = {};
  int? customPage;
  List<Map<String, dynamic>> wpCategories = [];
  List<String> wpCategoryOrder = [];
  Set<String> wpHiddenCategories = {};
  Map<String, int> wpCategoryColors = {};
  Map<String, int> wpCategoryTextColors = {};
  static const _textColors = <Color>[
    Color(0xFF111111), Color(0xFF00552F), Color(0xFF9B1C1C),
    Color(0xFF163C8C), Color(0xFF663399), Color(0xFFFFFFFF),
  ];
  static const _tileColors = <Color>[
    Colors.white, Color(0xFFE0F2E9), Color(0xFFFFE9E9),
    Color(0xFFFFF1D5), Color(0xFFE6EEFF), Color(0xFFF0E6FF),
    Color(0xFFE0F5F5), Color(0xFFFFE6F0),
  ];
  Color _tileColor(Map<String, dynamic> category) => Color(wpCategoryColors[_wpKey(category)] ?? 0xFFFFFFFF);
  String _wpKey(Map<String, dynamic> c) => '${c['type']}:${c['id']}';
  List<Map<String, dynamic>> get _orderedWpCategories {
    final items = [...wpCategories]..sort((a,b) {
      final ai=wpCategoryOrder.indexOf(_wpKey(a));
      final bi=wpCategoryOrder.indexOf(_wpKey(b));
      if(ai<0 && bi<0) return 0;
      if(ai<0) return 1;
      if(bi<0) return -1;
      return ai.compareTo(bi);
    });
    return items.where((c)=>!wpHiddenCategories.contains(_wpKey(c))).toList();
  }
  bool wpLoading = true;
  String? wpError;
  int? wpSelectedCategory;
  String? wpSelectedTitle;
  String wpSelectedType = 'category';
  Map<String, dynamic>? selectedItem;
  String? checkoutUrl;
  static const String _site = 'https://aytamaliraq.com';

  Future<void> _loadWordPressCategories({bool silent = false}) async {
    if (_fetchingCategories) return;
    if (silent && _lastCategoryFetch != null &&
        DateTime.now().difference(_lastCategoryFetch!) < _refreshInterval) return;
    _fetchingCategories = true;
    if (!silent && mounted) setState(() { wpLoading = true; wpError = null; });
    try {
      final response = await http.get(
        Uri.parse('$_site/wp-json/altaawun/v1/categories'),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['categories'] is! List) {
        throw const FormatException('Invalid categories response');
      }
      final categories = <Map<String, dynamic>>[];
      for (final item in decoded['categories'] as List) {
        if (item is Map && item['id'] is num && item['name'] is String) {
          categories.add({'id': (item['id'] as num).toInt(), 'name': item['name'] as String, 'type': item['type'] == 'product_cat' ? 'product_cat' : 'category'});
        }
      }
      _lastCategoryFetch = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wp_categories_cache', jsonEncode(categories));
      if (!mounted) return;
      setState(() { wpCategories = categories; wpLoading = false; wpError = null; });
    } catch (_) {
      if (!mounted) return;
      if (!silent || wpCategories.isEmpty) {
        setState(() { wpError = 'تعذر تحميل تصنيفات الجمعية. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.'; wpLoading = false; });
      }
    } finally {
      _fetchingCategories = false;
    }
  }

  void _openWordPressCategory(int id, String title, String type) {
    setState(() { selectedItem = null; checkoutUrl = null; wpSelectedCategory = id; wpSelectedTitle = title; wpSelectedType = type; page = 0; customPage = null; });
  }

  String _plainText(String html) => html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&nbsp;', ' ');

  Widget _inAppDetails() {
    final item = selectedItem!;
    final isProduct = wpSelectedType == 'product_cat';
    final title = isProduct ? (item['name'] ?? '').toString()
        : _plainText((item['title']?['rendered'] ?? '').toString());
    final content = isProduct ? (item['full_description'] ?? item['description'] ?? '').toString()
        : (item['content']?['rendered'] ?? '').toString();
    final image = isProduct ? (item['image'] ?? '').toString() : _postImage(item);
    final price = (item['price'] ?? '').toString();
    final link = (item['link'] ?? '').toString();
    final uri = Uri.tryParse(link);
    final valid = uri != null && uri.scheme == 'https' &&
        (uri.host == 'aytamaliraq.com' || uri.host == 'www.aytamaliraq.com');
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextButton.icon(onPressed: () => setState(() => selectedItem = null),
        icon: const Icon(Icons.arrow_forward), label: Text(page == 4 && wpSelectedCategory == null ? 'العودة إلى الأخبار' : 'العودة إلى التصنيف')),
      if (image.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(14),
        child: Image.network(image, height: 240, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 60))),
      const SizedBox(height: 12),
      if (!isProduct) const Padding(padding: EdgeInsets.only(bottom: 10),
        child: Text('تفاصيل الخبر', style: TextStyle(fontSize: 16, color: green, fontWeight: FontWeight.bold))),
      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      if (price.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(_plainText(price), style: const TextStyle(fontSize: 19, color: green))),
      if (content.isNotEmpty && isProduct) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_plainText(content), style: const TextStyle(fontSize: 16, height: 1.7))),
      if (content.isNotEmpty && !isProduct) SizedBox(height: MediaQuery.sizeOf(context).height * 0.72, child: _HtmlContent(content: content, onLink: (url) {
        final uri = Uri.tryParse(url);
        if (uri == null || uri.scheme != 'https') return;
        if (uri.host != 'aytamaliraq.com' && uri.host != 'www.aytamaliraq.com') return;
        final path = uri.path.toLowerCase();
        final isDonation = path.contains('/checkout') || path.contains('/cart') ||
            path.contains('/order-pay') || uri.queryParameters.containsKey('add-to-cart');
        if (isDonation) setState(() => checkoutUrl = url);
      })),
      if (isProduct) FilledButton.icon(
        onPressed: valid ? () => setState(() => checkoutUrl = link) : null,
        icon: const Icon(Icons.shopping_cart_outlined), label: const Text('اختيار الكفالة وإضافتها للسلة')),
    ]);
  }

  Widget _inAppCheckout() => Column(children: [
    TextButton.icon(onPressed: () => setState(() => checkoutUrl = null),
      icon: const Icon(Icons.arrow_forward), label: const Text('العودة إلى التطبيق')),
    Expanded(child: _CheckoutContent(url: checkoutUrl ?? 'https://www.aytamaliraq.com/cart/', onCartCount: (count) {
      if (mounted && _cartCount != count) setState(() => _cartCount = count);
    })),
  ]);

  String _postImage(dynamic post) {
    if (post is! Map) return '';
    final direct = (post['featured_image_url'] ?? '').toString();
    if (direct.isNotEmpty) return direct;
    final embedded = post['_embedded'];
    if (embedded is Map) {
      final media = embedded['wp:featuredmedia'];
      if (media is List && media.isNotEmpty && media.first is Map) {
        final image = (media.first['source_url'] ?? '').toString();
        if (image.isNotEmpty) return image;
      }
    }
    final content = (post['content'] is Map
        ? (post['content']['rendered'] ?? '') : '').toString();
    final match = RegExp(r'''<img\b[^>]*\bsrc\s*=\s*["']([^"']+)''',
      caseSensitive: false).firstMatch(content);
    final src = (match?.group(1) ?? '').replaceAll('&amp;', '&');
    if (src.isEmpty) {
      final youtube = RegExp(
        r'''(?:youtube\.com/(?:embed/|watch\?v=)|youtu\.be/)([A-Za-z0-9_-]{11})''',
        caseSensitive: false).firstMatch(content.replaceAll('&amp;', '&'));
      if (youtube != null) return 'https://img.youtube.com/vi/${youtube.group(1)}/hqdefault.jpg';
    }
    if (src.startsWith('//')) return 'https:$src';
    if (src.startsWith('/')) return '$_site$src';
    return src.startsWith('https://') || src.startsWith('http://') ? src : '';
  }

  bool _postHasVideo(dynamic post) {
    if (post is! Map) return false;
    final content = (post['content'] is Map
        ? (post['content']['rendered'] ?? '') : '').toString();
    return RegExp(r'<video\b|<iframe\b|youtube\.com|youtu\.be|vimeo\.com|\.mp4',
      caseSensitive: false).hasMatch(content);
  }

  String _selectedCategoryImage() {
    for (final category in wpCategories) {
      if (category['id'] == wpSelectedCategory &&
          category['type'] == wpSelectedType) {
        return (category['image'] ?? '').toString();
      }
    }
    return '';
  }

  Widget _wordPressPosts() {
    final id = wpSelectedCategory!;
    final isProducts = wpSelectedType == 'product_cat';
    return FutureBuilder<http.Response>(
      key: ValueKey(id),
      future: http.get(Uri.parse(isProducts
        ? '$_site/wp-json/altaawun/v1/products?category=$id'
        : '$_site/wp-json/wp/v2/posts?categories=$id&per_page=30&_embed=1')).timeout(const Duration(seconds: 15)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data?.statusCode != 200) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('تعذر تحميل مقالات هذا التصنيف'),
            TextButton(onPressed: () => setState(() {}), child: const Text('إعادة المحاولة')),
            TextButton(onPressed: () => go(0), child: const Text('العودة للرئيسية')),
          ]));
        }
        try {
          final decoded = jsonDecode(utf8.decode(snapshot.data!.bodyBytes));
          final posts = isProducts ? (decoded['products'] as List) : (decoded as List);
          return ListView(children: [
            ListTile(
              leading: _selectedCategoryImage().isNotEmpty
                  ? ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: Image.network(_selectedCategoryImage(), width: 62,
                        height: 62, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.folder)))
                  : const Icon(Icons.folder_outlined, color: green),
              title: Text(wpSelectedTitle ?? 'التصنيف',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 21)),
              trailing: IconButton(icon: const Icon(Icons.home), onPressed: () => go(0))),
            if (posts.isEmpty) const Padding(
              padding: EdgeInsets.all(28), child: Center(child: Text('لا توجد مقالات في هذا التصنيف حاليًا'))),
            for (final post in posts) ...[
              InkWell(
                onTap: () => setState(() => selectedItem = Map<String, dynamic>.from(post as Map)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 94, height: 82,
                        child: Stack(children: [
                          Positioned.fill(child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: (isProducts ? (post['image'] ?? '').toString() : _postImage(post)).isNotEmpty
                              ? Image.network(isProducts ? (post['image'] ?? '').toString() : _postImage(post),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, color: green))
                              : const Icon(Icons.image_outlined, color: green),
                          )),
                          if (!isProducts && _postHasVideo(post))
                            const Positioned(bottom: 4, right: 4,
                              child: Icon(Icons.play_circle_fill, color: Colors.white, size: 26)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isProducts ? (post['name'] ?? '').toString()
                              : _plainText((post['title']?['rendered'] ?? '').toString()),
                            maxLines: 3, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.3)),
                          const SizedBox(height: 7),
                          Text(isProducts ? (post['price'] ?? '').toString()
                              : (wpSelectedTitle ?? 'أخبار'),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          if (!isProducts && (post['date'] ?? '').toString().isNotEmpty)
                            Text((post['date'] ?? '').toString().split('T').first,
                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      )),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, indent: 14, endIndent: 14),
            ],
          ]);
        } catch (_) {
          return const Center(child: Text('تعذر قراءة بيانات المقالات'));
        }
      },
    );
  }
  String _labelFor(int id) => customCategories[id] ?? _categoryLabels[id] ?? 'تصنيف';

  @override
  void initState() {
    super.initState();
    _loadCategorySettings();
    _loadNotificationPreferences();
    _setupPush();
    notificationTapUrl.addListener(_onLocalNotificationTap);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onLocalNotificationTap());
    WidgetsBinding.instance.addObserver(this);
    _loadCachedWordPressCategories();
  }

  Future<void> _loadCachedWordPressCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('wp_categories_cache');
    if (cached != null) {
      try {
        final items = jsonDecode(cached) as List;
        if (mounted) {
          setState(() {
            wpCategories = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            wpLoading = false;
          });
        }
      } catch (_) {}
    }
    await _loadWordPressCategories(silent: cached != null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadWordPressCategories(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadCategorySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('home_category_order');
    final savedTileSize = prefs.getString('home_tile_size') ?? 'medium';
    final parsed = savedOrder?.map(int.tryParse).whereType<int>().toList();
    final savedHidden = prefs.getStringList('home_category_hidden') ?? [];
    final savedCustom = prefs.getStringList('home_custom_categories') ?? [];
    final custom = <int, String>{};
    for (final item in savedCustom) {
      final separator = item.indexOf('|');
      if (separator < 0) continue;
      final id = int.tryParse(item.substring(0, separator));
      final name = item.substring(separator + 1).trim();
      if (id != null && id >= 100 && name.isNotEmpty) custom[id] = name;
    }
    if (!mounted) return;
    setState(() {
      _homeTileSize = ['small', 'medium', 'large'].contains(savedTileSize) ? savedTileSize : 'medium';
      wpCategoryOrder = prefs.getStringList('home_wp_category_order') ?? [];
      wpHiddenCategories = (prefs.getStringList('home_wp_category_hidden') ?? []).toSet();
      try {
        final raw = jsonDecode(prefs.getString('home_wp_category_colors') ?? '{}') as Map;
        wpCategoryColors = raw.map((k,v) => MapEntry(k.toString(), (v as num).toInt()));
      } catch (_) { wpCategoryColors = {}; }
      try {
        final raw = jsonDecode(prefs.getString('home_wp_category_text_colors') ?? '{}') as Map;
        wpCategoryTextColors = raw.map((k,v) => MapEntry(k.toString(), (v as num).toInt()));
      } catch (_) { wpCategoryTextColors = {}; }
      customCategories = custom;
      final valid = {..._defaultCategoryOrder, ...custom.keys};
      if (parsed != null && parsed.toSet().length == parsed.length &&
          parsed.toSet().containsAll(valid) && valid.containsAll(parsed)) {
        categoryOrder = parsed;
      } else {
        categoryOrder = [..._defaultCategoryOrder, ...custom.keys];
      }
      hiddenCategories = savedHidden.map(int.tryParse).whereType<int>()
          .where(valid.contains).toSet();
    });
  }

  Future<void> _saveCategorySettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home_tile_size', _homeTileSize);
    await prefs.setStringList('home_wp_category_order', wpCategoryOrder);
    await prefs.setStringList('home_wp_category_hidden', wpHiddenCategories.toList());
    await prefs.setString('home_wp_category_colors', jsonEncode(wpCategoryColors));
    await prefs.setString('home_wp_category_text_colors', jsonEncode(wpCategoryTextColors));
    await prefs.setStringList('home_category_order',
        categoryOrder.map((id) => '$id').toList());
    await prefs.setStringList('home_category_hidden',
        hiddenCategories.map((id) => '$id').toList());
    await prefs.setStringList('home_custom_categories',
        customCategories.entries.map((e) => '${e.key}|${e.value}').toList());
  }

  void _addCategoryInline(String value, StateSetter refreshSheet) {
    final name = value.trim();
    if (name.isEmpty) return;
    final id = customCategories.keys.fold<int>(99, (max, x) => x > max ? x : max) + 1;
    refreshSheet(() {
      customCategories[id] = name;
      categoryOrder.add(id);
    });
    if (mounted) setState(() {});
    _saveCategorySettings();
  }

  void _openCustomCategory(int id) {
    setState(() { customPage = id; page = 0; });
  }

  void _manageCategories() {
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refreshSheet) {
          final items = [...wpCategories]..sort((a,b) {
            final ai=wpCategoryOrder.indexOf(_wpKey(a));
            final bi=wpCategoryOrder.indexOf(_wpKey(b));
            if(ai<0 && bi<0) return 0;
            if(ai<0) return 1;
            if(bi<0) return -1;
            return ai.compareTo(bi);
          });
          return SafeArea(child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .76,
            child: Column(children: [
              const Padding(padding: EdgeInsets.all(12), child: Text(
                'تخصيص الواجهة الرئيسية',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('اختر من تصنيفات WordPress الموجودة فقط، واسحب لتغيير ترتيب ظهورها في الصفحة الرئيسية.')),
              Padding(padding: const EdgeInsets.all(12), child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value:'small',label:Text('صغير')),
                  ButtonSegment(value:'medium',label:Text('متوسط')),
                  ButtonSegment(value:'large',label:Text('كبير')),
                ],
                selected: {_homeTileSize},
                onSelectionChanged: (values) {
                  refreshSheet(() => _homeTileSize = values.first);
                  setState(() {});
                  _saveCategorySettings();
                },
              )),
              Expanded(child: items.isEmpty
                ? const Center(child: Text('لا توجد تصنيفات محمّلة من WordPress. افتح تصنيفات التطبيق لتحديثها.'))
                : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: items.length,
                  onReorder: (oldIndex,newIndex) {
                    if(newIndex>oldIndex) newIndex--;
                    final moved=items.removeAt(oldIndex);
                    items.insert(newIndex,moved);
                    refreshSheet(() => wpCategoryOrder=items.map(_wpKey).toList());
                    setState(() {});
                    _saveCategorySettings();
                  },
                  itemBuilder: (context,index) {
                    final item=items[index];
                    final key=_wpKey(item);
                    return ListTile(
                      key: ValueKey(key),
                      leading: ReorderableDragStartListener(
                        index:index, child:const Icon(Icons.drag_handle,color:green)),
                      title: Text(item['name'] as String),
                      subtitle: Text(item['type']=='product_cat'?'تصنيف منتجات':'تصنيف مقالات'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        PopupMenuButton<int>(
                          tooltip: 'لون المربع',
                          icon: Icon(Icons.palette, color: Color(wpCategoryColors[key] ?? 0xFF006633)),
                          onSelected: (value) {
                            refreshSheet(() => wpCategoryColors[key] = value);
                            setState(() {});
                            _saveCategorySettings();
                          },
                          itemBuilder: (_) => [
                            for (final color in _tileColors)
                              PopupMenuItem<int>(value: color.toARGB32(), child: Row(children: [
                                Container(width: 24, height: 24, decoration: BoxDecoration(
                                  color: color, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5))),
                                const SizedBox(width: 10),
                                Text(color == Colors.white ? 'أبيض' : 'اختيار اللون'),
                              ])),
                          ],
                        ),
                        PopupMenuButton<int>(
                          tooltip: 'لون الكتابة',
                          icon: Icon(Icons.format_color_text, color: Color(wpCategoryTextColors[key] ?? 0xFF111111)),
                          onSelected: (value) {
                            refreshSheet(() => wpCategoryTextColors[key] = value);
                            setState(() {});
                            _saveCategorySettings();
                          },
                          itemBuilder: (_) => [
                            for (final color in _textColors)
                              PopupMenuItem<int>(value: color.toARGB32(), child: Row(children: [
                                Container(width: 24, height: 24, decoration: BoxDecoration(
                                  color: color, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5))),
                                const SizedBox(width: 10),
                                const Text('لون الكتابة'),
                              ])),
                          ],
                        ),
                        Switch(
                        value: !wpHiddenCategories.contains(key),
                        onChanged: (visible) {
                          refreshSheet(() {
                            if(visible) {wpHiddenCategories.remove(key);}
                            else {wpHiddenCategories.add(key);}
                          });
                          setState(() {});
                          _saveCategorySettings();
                        },
                      ),
                      ]),
                    );
                  },
                )),
              Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                TextButton(onPressed: () {
                  refreshSheet(() {
                    wpCategoryOrder=[];
                    wpHiddenCategories.clear();
                    _homeTileSize='medium';
                    wpCategoryColors.clear();
                    wpCategoryTextColors.clear();
                  });
                  setState(() {});
                  _saveCategorySettings();
                }, child: const Text('استعادة الافتراضي')),
                const Spacer(),
                FilledButton(onPressed: () async {
                  await _saveCategorySettings();
                  if(sheetContext.mounted) Navigator.pop(sheetContext);
                }, child: const Text('حفظ')),
              ])),
            ]),
          ));
        },
      ),
    );
  }

  void _openCart() => setState(() { checkoutUrl = 'https://www.aytamaliraq.com/cart/'; _cartRefreshKey++; });

  void go(int value) => setState(() { page = value; customPage = null; wpSelectedCategory = null; selectedItem = null; checkoutUrl = null; });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 86,
      backgroundColor: Colors.white,
      foregroundColor: deepGreen,
      leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer())),
      title: page == 0 ? const Column(mainAxisSize: MainAxisSize.min, children: [
        _Emblem(size: 38),
        Text('جمعية التعاون الخيرية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        Text('مدرسة الأيتام وكفالتهم', style: TextStyle(fontSize: 10)),
      ]) : Text(names[page], style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      actions: [IconButton(
        tooltip: 'سلة الكفالات والتبرعات',
        onPressed: _openCart,
        icon: Badge(
          isLabelVisible: _cartCount != null && _cartCount! > 0,
          label: Text((_cartCount ?? 0).toString()),
          child: const Icon(Icons.shopping_cart_outlined, color: green),
        ),
      ), if (page == 0) IconButton(
        tooltip: 'الإشعارات',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('الإشعارات'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('رمز الجهاز للاختبار عبر Firebase. لا يوجد سجل إشعارات محفوظ حتى الآن.'),
              const SizedBox(height: 12),
              SelectableText(_fcmToken ?? 'لم يتوفر رمز FCM بعد. تأكد من اتصال الإنترنت والسماح بالإشعارات.',
                style: const TextStyle(fontSize: 12)),
            ]),
            actions: [TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق'),
            )],
          ),
        ),
        icon: const Icon(Icons.notifications_outlined, color: green),
      )],
    ),
    drawer: Drawer(child: SafeArea(child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(24), color: green,
        child: const Column(children: [_Emblem(size: 76), SizedBox(height: 12),
          Text('جمعية التعاون الخيرية', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold))])),
      ListTile(
        leading: const Icon(Icons.refresh, color: green),
        title: const Text('تصنيفات التطبيق'),
        subtitle: const Text('تُحدّث تلقائيًا من لوحة إدارة الموقع'),
        onTap: () { Navigator.pop(context); go(0); },
      ),
      ListTile(leading: const Icon(Icons.shopping_cart_outlined, color: green),
        title: const Text('سلة الكفالات والتبرعات'),
        onTap: () { Navigator.pop(context); _openCart(); }),
      ListTile(
        leading: const Icon(Icons.tune, color: green),
        title: const Text('تخصيص الواجهة الرئيسية'),
        subtitle: const Text('ترتيب الأقسام وحجم المربعات وإخفاؤها'),
        onTap: () { Navigator.pop(context); _manageCategories(); },
      ),
      ListTile(leading: const Icon(Icons.notifications_active, color: green),
        title: const Text('إعدادات الإشعارات'),
        onTap: () { Navigator.pop(context); _showNotificationPreferences(); }),
      ListTile(
        leading: const Icon(Icons.text_fields, color: green),
        title: const Text('نوع الخط وحجمه'),
        subtitle: const Text('Tajawal، Cairo، Almarai، Amiri'),
        onTap: () { Navigator.pop(context); _showFontPreferences(); },
      ),
      Expanded(child: ListView(children: [
        for (var i = 0; i < names.length; i++)
          ListTile(
            leading: Icon(_icons[i], color: green), title: Text(names[i]),
            onTap: () { Navigator.pop(context); go(i); },
          ),
      ])),
    ]))),
    body: Stack(children: [
      IndexedStack(index: checkoutUrl == null ? 0 : 1, children: [
      selectedItem != null ? _inAppDetails() : wpSelectedCategory != null ? _wordPressPosts() : customPage != null ? _customSection(customPage!) : page == 0 ? _home() : page == 7 ? _accountPage() : _section(),
      _inAppCheckout(),
      ]),
      // Separate same-origin cart reader: initialise the badge when the app starts,
      // even if the customer has not opened the visible WooCommerce checkout.
      Offstage(
        offstage: true,
        child: SizedBox(width: 1, height: 1,
          child: _CheckoutContent(
            key: ValueKey('cart-reader-$_cartRefreshKey'),
            url: 'https://www.aytamaliraq.com/cart/',
            onCartCount: (count) {
              if (mounted && _cartCount != count) setState(() => _cartCount = count);
            },
          ),
        ),
      ),
    ]),
    bottomNavigationBar: NavigationBar(
      height: 72,
      selectedIndex: [0, 1, 4, 3, 7].indexOf(page) < 0 ? 0 : [0, 1, 4, 3, 7].indexOf(page),
      onDestinationSelected: (index) => go([0, 1, 4, 3, 7][index]),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.favorite_border), label: 'تبرع'),
        NavigationDestination(icon: Icon(Icons.article_outlined), label: 'الأخبار'),
        NavigationDestination(icon: Icon(Icons.volunteer_activism_outlined), label: 'المزيد'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
      ],
    ),
  );

  static const _icons = [
    Icons.home, Icons.favorite, Icons.school, Icons.volunteer_activism,
    Icons.article, Icons.photo_library, Icons.menu_book, Icons.person_outline,
  ];

  Widget _customSection(int id) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      TextButton.icon(
        onPressed: () => go(0),
        icon: const Icon(Icons.arrow_forward),
        label: const Text('العودة إلى الرئيسية'),
      ),
      const SizedBox(height: 30),
      const Icon(Icons.folder_open, size: 86, color: green),
      const SizedBox(height: 18),
      Text(_labelFor(id), textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: deepGreen)),
      const SizedBox(height: 12),
      const Text('هذا التصنيف جاهز للعرض. يمكن ربط محتواه لاحقًا بموقع الجمعية.',
          textAlign: TextAlign.center),
    ],
  );

  Widget _home() => ListView(padding: EdgeInsets.zero, children: [
    SizedBox(height: 260, child: Stack(fit: StackFit.expand, children: [
      Image.asset(
        'assets/home_hero.jpg',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF194B2F), Color(0xFF00642D)]))),
      ),
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [Colors.transparent, Color(0xE8004C29)]))),
      Positioned(top: 28, right: 18, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('بكفالتك\nنمنحهم\nمستقبلًا أفضل',
            style: TextStyle(fontSize: 29, color: Colors.white, fontWeight: FontWeight.w900, height: 1.3)),
        ],
      )),
      Positioned(bottom: 18, right: 18, child: FilledButton.icon(
        onPressed: () => go(1),
        style: FilledButton.styleFrom(backgroundColor: green, side: const BorderSide(color: Colors.white)),
        icon: const Icon(Icons.favorite_border), label: const Text('كفالة يتيم',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      )),
    ])),
    Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      GridView.count(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: _homeTileSize == 'small' ? 4 : (_homeTileSize == 'large' ? 2 : 3),
        mainAxisSpacing: 9, crossAxisSpacing: 9,
        mainAxisExtent: _homeTileSize == 'small' ? 124 : (_homeTileSize == 'large' ? 174 : 148),
        children: [
          for (final category in _orderedWpCategories)
            Material(
              color: _tileColor(category),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openWordPressCategory(
                    category['id'] as int, category['name'] as String,
                    category['type'] as String),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.folder_open, size: _homeTileSize == 'small' ? 28 : 36, color: green),
                  const SizedBox(height: 7),
                  Flexible(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(category['name'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: _homeTileSize == 'small' ? 11 : 13, fontWeight: FontWeight.bold, color: Color(wpCategoryTextColors[_wpKey(category)] ?? 0xFF111111)))),
                  ),
                ]),
              ),
            ),
        ],
      ),
      if (wpLoading)
        const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator())
      else if (wpError != null)
        Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          Text(wpError!, textAlign: TextAlign.center),
          TextButton(onPressed: _loadWordPressCategories, child: const Text('إعادة المحاولة')),
        ]))
      else if (wpCategories.isEmpty)
        const Padding(padding: EdgeInsets.all(16),
          child: Text('لم يتم اختيار تصنيفات للتطبيق من لوحة ووردبريس بعد.',
            textAlign: TextAlign.center)),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('أحدث الأخبار', style: TextStyle(color: deepGreen, fontSize: 22, fontWeight: FontWeight.w900)),
        TextButton(onPressed: () => go(4), child: const Text('عرض الكل')),
      ]),
      _newsFeed(homePreview: true),
      Center(child: TextButton.icon(onPressed: () => go(4),
        icon: const Icon(Icons.arrow_back), label: const Text('المزيد — جميع الأخبار'))),
    ])),
  ]);

  Widget _shortcut(IconData icon, String title, int destination, {Color color = green}) =>
    Material(color: Colors.white, borderRadius: BorderRadius.circular(14),
      child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => destination >= 100 ? _openCustomCategory(destination) : go(destination),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(height: 9),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ])));

  Widget _sponsorshipProducts() {
    final categories = wpCategories.where((c) =>
      c['type'] == 'product_cat' &&
      RegExp(r'كفال|يتيم|أيتام|ايتام|orphan|sponsor', caseSensitive: false)
        .hasMatch((c['name'] ?? '').toString())).toList();
    if (wpLoading && wpCategories.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20),
        child: CircularProgressIndicator()));
    }
    if (categories.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16),
        child: Text('لا يوجد تصنيف كفالات منشور حاليًا', textAlign: TextAlign.center));
    }
    final category = categories.first;
    final id = category['id'] as int;
    final title = (category['name'] ?? 'اكفل يتيمًا').toString();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('الأيتام المتاحون للكفالة',
        style: TextStyle(fontSize: 21, color: deepGreen, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      FutureBuilder<http.Response>(
        future: http.get(Uri.parse('$_site/wp-json/altaawun/v1/products?category=$id'))
          .timeout(const Duration(seconds: 15)),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: Padding(padding: EdgeInsets.all(20),
              child: CircularProgressIndicator()));
          }
          if (snapshot.hasError || snapshot.data?.statusCode != 200) {
            return const Text('تعذر تحميل الأيتام، تحقق من اتصال الإنترنت');
          }
          try {
            final decoded = jsonDecode(utf8.decode(snapshot.data!.bodyBytes));
            final products = (decoded['products'] as List).whereType<Map>().take(10).toList();
            if (products.isEmpty) return const Text('لا توجد كفالات منشورة حاليًا');
            return Column(children: [
              for (final product in products) Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(padding: const EdgeInsets.all(12), child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text((product['name'] ?? '').toString(), textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text((product['price'] ?? '').toString(),
                        style: const TextStyle(fontSize: 15, color: green)),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => setState(() {
                          wpSelectedType = 'product_cat';
                          wpSelectedCategory = id;
                          wpSelectedTitle = title;
                          selectedItem = Map<String, dynamic>.from(product);
                          checkoutUrl = null;
                        }),
                        child: const Text('اكفل الآن')),
                    ])),
                    const SizedBox(width: 12),
                    ClipRRect(borderRadius: BorderRadius.circular(9),
                      child: (product['image'] ?? '').toString().isNotEmpty
                        ? Image.network((product['image'] ?? '').toString(), width: 100, height: 112,
                            fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 100, child: Icon(Icons.person_outline)))
                        : const SizedBox(width: 100, height: 112,
                            child: Icon(Icons.person_outline, color: green, size: 44))),
                  ]),
                )),
              TextButton.icon(
                onPressed: () => _openWordPressCategory(id, title, 'product_cat'),
                icon: const Icon(Icons.arrow_back), label: const Text('المزيد — جميع الأيتام')),
            ]);
          } catch (_) {
            return const Text('تعذر قراءة بيانات الكفالات');
          }
        },
      ),
    ]);
  }

  Widget _donationCategories() {
    final categories = wpCategories.where((c) => c['type'] == 'product_cat').toList();
    if (wpLoading && wpCategories.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (categories.isEmpty) {
      return Column(children: [
        const Text('لا توجد حالات تبرع أو كفالة منشورة حاليًا.'),
        TextButton.icon(onPressed: () => _loadWordPressCategories(),
          icon: const Icon(Icons.refresh), label: const Text('تحديث الحالات')),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('حالات التبرع والكفالة', style: TextStyle(
        fontSize: 21, fontWeight: FontWeight.bold, color: deepGreen)),
      const SizedBox(height: 12),
      for (final category in categories) Card(
        child: ListTile(
          leading: const Icon(Icons.volunteer_activism, color: green),
          title: Text((category['name'] ?? '').toString()),
          subtitle: const Text('عرض الحالات والتفاصيل'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _openWordPressCategory(
            category['id'] as int, (category['name'] ?? '').toString(), 'product_cat'),
        ),
      ),
      const Padding(padding: EdgeInsets.all(8),
        child: Text('يتم إتمام أي تبرع متاح عبر موقع الجمعية داخل التطبيق، ولا يجمع التطبيق بيانات الدفع مباشرة.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
    ]);
  }

  Future<List<Map<String, dynamic>>>? _newsCache;
  Future<List<Map<String, dynamic>>> _fetchNews() async {
    final uri = Uri.parse('https://www.aytamaliraq.com/wp-json/wp/v2/posts?_embed=1&per_page=50&orderby=date&order=desc');
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('تعذر تحميل الأخبار');
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) throw Exception('استجابة غير متوقعة');
    return data.whereType<Map<String, dynamic>>().toList();
  }

  void _refreshNews() => setState(() { _newsCache = _fetchNews(); });

  void _openNewsPost(Map<String, dynamic> post) => setState(() {
    page = 4;
    wpSelectedType = 'category';
    wpSelectedCategory = null;
    checkoutUrl = null;
    selectedItem = Map<String, dynamic>.from(post);
  });

  Widget _newsFeed({bool homePreview = false}) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _newsCache ??= _fetchNews(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Column(children: [
          const Text('تعذر تحميل الأخبار. تحقق من الإنترنت وحاول مجددًا.'),
          TextButton.icon(onPressed: _refreshNews, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
        ]);
      }
      final allPosts = snapshot.data ?? [];
      final posts = homePreview ? allPosts.take(10).toList() : allPosts.take(50).toList();
      if (posts.isEmpty) return const Center(child: Text('لا توجد أخبار منشورة حاليًا'));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!homePreview) Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('آخر ' + posts.length.toString() + ' خبر', textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: deepGreen))),
        for (final post in posts) Column(children: [
          InkWell(
            onTap: () => _openNewsPost(post),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_plainText((post['title']?['rendered'] ?? '').toString()),
                    textAlign: TextAlign.right, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 7),
                  Text((post['date'] ?? '').toString().split('T').first,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ])),
                const SizedBox(width: 12),
                ClipRRect(borderRadius: BorderRadius.circular(10), child:
                  _postImage(post).isNotEmpty
                    ? Image.network(_postImage(post), width: 92, height: 86, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 92, height: 86,
                          child: Icon(Icons.article_outlined, color: green)))
                    : const SizedBox(width: 92, height: 86,
                        child: Icon(Icons.article_outlined, color: green, size: 35))),
              ]),
            ),
          ),
          const Divider(height: 1),
        ]),
      ]);
    },
  );

  Widget _accountPage() => CharityAccountPage(cartCount: _cartCount, onOpenCart: _openCart);

  Widget _section() {
    final descriptions = [
      '',
      'كن سببًا في سعادة يتيم. الكفالة ليست مالًا فقط، بل هي رعاية واهتمام ومستقبل مشرق.',
      'نوفر لأبنائنا بيئة تعليمية آمنة ومتكاملة لبناء مستقبلهم.',
      'ساهم في دعم برامج الجمعية عبر وسائل تبرع موثوقة.',
      'تابع آخر الأخبار والأنشطة والمبادرات.',
      'صور وفيديوهات أنشطة المدرسة والجمعية.',
      'جمعية التعاون الخيرية — مدرسة الأيتام وكفالتهم.',
    ];
    return ListView(padding: const EdgeInsets.all(18), children: [
      Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [deepGreen, green]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(child: Icon(_icons[page], size: 85, color: Colors.white)),
      ),
      const SizedBox(height: 18),
      Text(names[page], textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 25, color: deepGreen, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      Text(descriptions[page], textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.7)),
      const SizedBox(height: 18),
      if (page == 1) ...[
        _feature(Icons.description_outlined, 'تقرير دوري عن حالة اليتيم'),
        _feature(Icons.auto_stories_outlined, 'متابعة تطوره الدراسي'),
        _feature(Icons.shield_outlined, 'خصوصية وأمان بيانات الأطفال'),
        const SizedBox(height: 8),
        _sponsorshipProducts(),
      ] else if (page == 2) ...[
        _feature(Icons.menu_book, 'مناهج دراسية'),
        _feature(Icons.groups, 'أنشطة طلابية'),
        _feature(Icons.school, 'المرافق والمدرسون'),
        _feature(Icons.photo_library, 'الصور والفيديوهات'),
      ] else if (page == 3) ...[
        _donationCategories(),
      ] else if (page == 4) ...[
        _newsFeed(),
      ] else if (page == 6) ...[
        const CharityAboutContent(),
      ] else ...[
        _feature(Icons.info_outline, 'سيظهر المحتوى المعتمد بعد ربط لوحة إدارة الجمعية'),
      ],
    ]);
  }

  Widget _feature(IconData icon, String text) => Card(
    child: ListTile(leading: Icon(icon, color: green), title: Text(text)),
  );
  Widget _disabledAction(String text) => FilledButton(
    onPressed: null, child: Padding(padding: const EdgeInsets.all(10), child: Text(text)),
  );
}

class _CategoryAddField extends StatefulWidget {
  final ValueChanged<String> onAdd;
  const _CategoryAddField({required this.onAdd});

  @override
  State<_CategoryAddField> createState() => _CategoryAddFieldState();
}

class _CategoryAddFieldState extends State<_CategoryAddField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    widget.onAdd(name);
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: TextField(
      controller: _controller,
      maxLength: 50,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: const InputDecoration(
        labelText: 'اسم التصنيف الجديد',
        hintText: 'مثال: مشاريع الجمعية',
        counterText: '',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    )),
    const SizedBox(width: 8),
    FilledButton.icon(
      onPressed: _submit,
      icon: const Icon(Icons.add),
      label: const Text('إضافة'),
    ),
  ]);
}
