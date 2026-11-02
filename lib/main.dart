import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

void main() => runApp(const AltaawunApp());

const green = Color(0xFF00642D);
const deepGreen = Color(0xFF004521);
const red = Color(0xFFB70922);
const ivory = Color(0xFFF8F8F5);

class AltaawunApp extends StatelessWidget {
  const AltaawunApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'جمعية التعاون الخيرية',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: ivory,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      appBarTheme: const AppBarTheme(backgroundColor: green, foregroundColor: Colors.white, centerTitle: true),
    ),
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox()),
    home: const SplashScreen(),
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
  const _CheckoutContent({super.key, required this.url});
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
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          return uri != null && uri.scheme == 'https'
              ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
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
  DateTime? _lastCategoryFetch;
  static const _refreshInterval = Duration(hours: 6);
  bool _fetchingCategories = false;
  int page = 0;
  final names = const ['الرئيسية', 'كفالة الأيتام', 'المدرسة والتعليم', 'التبرعات والمساهمات', 'الأخبار والأنشطة', 'الصور والفيديوهات', 'عن الجمعية'];
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
        icon: const Icon(Icons.arrow_forward), label: const Text('العودة إلى التصنيف')),
      if (image.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(14),
        child: Image.network(image, height: 240, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 60))),
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      if (price.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(_plainText(price), style: const TextStyle(fontSize: 19, color: green))),
      if (content.isNotEmpty) SizedBox(height: MediaQuery.sizeOf(context).height * 0.72, child: _HtmlContent(content: content, onLink: (url) => setState(() => checkoutUrl = url))),
      if (isProduct) FilledButton.icon(
        onPressed: valid ? () => setState(() => checkoutUrl = link) : null,
        icon: const Icon(Icons.volunteer_activism), label: const Text('تبرع الآن')),
    ]);
  }

  Widget _inAppCheckout() => Column(children: [
    TextButton.icon(onPressed: () => setState(() => checkoutUrl = null),
      icon: const Icon(Icons.arrow_forward), label: const Text('العودة إلى التطبيق')),
    Expanded(child: _CheckoutContent(key: ValueKey(checkoutUrl), url: checkoutUrl!)),
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
      context: context, isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refreshSheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .76,
            child: Column(children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('إدارة تصنيفات الصفحة الرئيسية',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const Text('اسحب علامة الترتيب، أو أخفِ التصنيف بالمفتاح'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _CategoryAddField(
                  onAdd: (name) => _addCategoryInline(name, refreshSheet),
                ),
              ),
              Expanded(child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: categoryOrder.length,
                onReorder: (oldIndex, newIndex) {
                  refreshSheet(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = categoryOrder.removeAt(oldIndex);
                    categoryOrder.insert(newIndex, item);
                  });
                  setState(() {});
                  _saveCategorySettings();
                },
                itemBuilder: (context, index) {
                  final id = categoryOrder[index];
                  return ListTile(
                    key: ValueKey(id),
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, color: green)),
                    title: Text(_labelFor(id)),
                    subtitle: customCategories.containsKey(id) ? const Text('تصنيف مخصص') : null,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (customCategories.containsKey(id))
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: red),
                          onPressed: () {
                            refreshSheet(() {
                              categoryOrder.remove(id);
                              customCategories.remove(id);
                              hiddenCategories.remove(id);
                            });
                            setState(() {});
                            _saveCategorySettings();
                          },
                        ),
                      Switch(
                      value: !hiddenCategories.contains(id),
                      onChanged: (visible) {
                        refreshSheet(() {
                          if (visible) {
                            hiddenCategories.remove(id);
                          } else {
                            hiddenCategories.add(id);
                          }
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
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: sheetContext,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('استعادة الإعدادات الافتراضية'),
                        content: const Text(
                          'سيعود ترتيب التصنيفات الستة إلى وضعه الأصلي، '
                          'وتظهر جميع التصنيفات المخفية. '
                          'ستبقى التصنيفات المضافة محفوظة بعد التصنيفات الأساسية.'
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('إلغاء'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('استعادة'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !mounted || !sheetContext.mounted) return;
                    refreshSheet(() {
                      categoryOrder = [..._defaultCategoryOrder, ...customCategories.keys];
                      hiddenCategories.clear();
                    });
                    setState(() {});
                    await _saveCategorySettings();
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('تمت استعادة الترتيب الافتراضي وإظهار جميع التصنيفات')),
                      );
                    }
                  },
                  child: const Text('استعادة الترتيب الافتراضي'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('تم'),
                ),
              ])),
            ]),
          ),
        ),
      ),
    );
  }

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
      actions: page == 0 ? [IconButton(onPressed: () {}, icon: const Badge(label: Text('3'), child: Icon(Icons.notifications, color: green)))] : null,
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
      Expanded(child: ListView(children: [
        for (var i = 0; i < names.length; i++)
          ListTile(
            leading: Icon(_icons[i], color: green), title: Text(names[i]),
            onTap: () { Navigator.pop(context); go(i); },
          ),
      ])),
    ]))),
    body: checkoutUrl != null ? _inAppCheckout() : selectedItem != null ? _inAppDetails() : wpSelectedCategory != null ? _wordPressPosts() : customPage != null ? _customSection(customPage!) : page == 0 ? _home() : _section(),
    bottomNavigationBar: NavigationBar(
      height: 72,
      selectedIndex: [0, 1, 4, 3, 6].indexOf(page) < 0 ? 0 : [0, 1, 4, 3, 6].indexOf(page),
      onDestinationSelected: (index) => go([0, 1, 4, 3, 6][index]),
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
    Icons.article, Icons.photo_library, Icons.menu_book,
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
        crossAxisCount: 3, mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: .93,
        children: [
          for (final category in wpCategories)
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openWordPressCategory(
                    category['id'] as int, category['name'] as String,
                    category['type'] as String),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.folder_open, size: 36, color: green),
                  const SizedBox(height: 9),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(category['name'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
      Card(child: ListTile(
        leading: const Icon(Icons.article, color: green, size: 35),
        title: const Text('أخبار وأنشطة الجمعية', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('تابع أحدث أخبار وأنشطة الجمعية'),
        onTap: () => go(4),
      )),
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
      return const Padding(padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()));
    }
    if (categories.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16),
        child: Text('لعرض الأيتام هنا، اختر تصنيف منتجات الكفالة من لوحة ووردبريس ← تصنيفات التطبيق. ستظهر المنتجات المنشورة تلقائيًا.',
          textAlign: TextAlign.center));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('الأيتام المتاحون للكفالة',
        style: TextStyle(fontSize: 21, color: deepGreen, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      for (final category in categories)
        Card(child: ListTile(
          leading: const Icon(Icons.favorite, color: green),
          title: Text((category['name'] ?? '').toString()),
          subtitle: const Text('عرض الصور والتفاصيل والكفالة'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _openWordPressCategory(
            category['id'] as int, (category['name'] ?? '').toString(), 'product_cat'),
        )),
    ]);
  }

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
        _feature(Icons.lock_outline, 'سيُربط الدفع ببوابة آمنة بعد اعتمادها'),
        _disabledAction('التبرع الإلكتروني — قريبًا'),
      ] else if (page == 6) ...[
        _feature(Icons.language, 'www.aytamaliraq.com'),
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
