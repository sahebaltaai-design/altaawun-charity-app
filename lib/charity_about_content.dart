import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

/// Displays the published WordPress About page without leaving the Flutter shell.
class CharityAboutContent extends StatefulWidget {
  const CharityAboutContent({super.key});
  @override
  State<CharityAboutContent> createState() => _CharityAboutContentState();
}

class _CharityAboutContentState extends State<CharityAboutContent> {
  late Future<Map<String, dynamic>?> _page;
  @override
  void initState() {
    super.initState();
    _page = _loadPage();
  }

  Future<Map<String, dynamic>?> _loadPage() async {
    const base = 'https://www.aytamaliraq.com/wp-json/wp/v2/pages';
    for (final slug in ['about-us', 'about', 'about-the-association', 'عن-الجمعية']) {
      final uri = Uri.parse(base).replace(queryParameters: {
        'slug': slug, 'status': 'publish', '_fields': 'id,title,content,link'
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) continue;
      final list = jsonDecode(response.body);
      if (list is List && list.isNotEmpty && list.first is Map) {
        return Map<String, dynamic>.from(list.first as Map);
      }
    }
    final uri = Uri.parse(base).replace(queryParameters: {
      'search': 'عن الجمعية', 'per_page': '20', '_fields': 'id,title,content,link'
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body);
      if (list is List) {
        for (final p in list) {
          if (p is Map) {
            final title = (p['title'] is Map ? p['title']['rendered'] : '').toString();
            if (title.contains('عن الجمعية') || title.contains('عن جمعية التعاون')) {
              return Map<String, dynamic>.from(p);
            }
          }
        }
      }
    }
    return null;
  }

  String _rendered(dynamic value) =>
      value is Map ? (value['rendered'] ?? '').toString() : '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _page,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Column(children: [
            const Text('تعذر تحميل معلومات الجمعية. تحقق من الاتصال بالإنترنت.'),
            TextButton.icon(onPressed: () => setState(() => _page = _loadPage()),
              icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          ]);
        }
        final page = snapshot.data;
        if (page == null) {
          return const Padding(padding: EdgeInsets.all(12),
            child: Text('لإضافة التفاصيل: أنشئ صفحة منشورة في ووردبريس بعنوان «عن الجمعية» واجعل رابطها about-us. ستظهر المعلومات هنا تلقائيًا.',
              textAlign: TextAlign.center));
        }
        final html = _rendered(page['content']);
        if (html.trim().isEmpty) {
          return const Text('صفحة «عن الجمعية» موجودة، لكن لم يُضف إليها محتوى بعد.');
        }
        return _AboutHtml(html: html);
      },
    );
  }
}

class _AboutHtml extends StatefulWidget {
  final String html;
  const _AboutHtml({required this.html});
  @override
  State<_AboutHtml> createState() => _AboutHtmlState();
}

class _AboutHtmlState extends State<_AboutHtml> {
  late final WebViewController _controller;
  double _height = 450;
  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xfff8f9f5))
      ..addJavaScriptChannel('AboutHeight', onMessageReceived: (message) {
        final height = double.tryParse(message.message);
        if (mounted && height != null && height > 0 && height < 30000 &&
            (height - _height).abs() > 3) setState(() => _height = height);
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _controller.runJavaScript('''
          function reportAboutHeight() {
            AboutHeight.postMessage(String(Math.max(
              document.documentElement.scrollHeight, document.body.scrollHeight)));
          }
          reportAboutHeight();
          new ResizeObserver(reportAboutHeight).observe(document.body);
          window.addEventListener('load', reportAboutHeight);
        '''),
      ))
      ..loadHtmlString('''
<!doctype html><html lang="ar" dir="rtl"><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
body{margin:0;padding:8px;background:#f8f9f5;color:#202a22;font-family:Arial,sans-serif;font-size:17px;line-height:1.85;overflow-x:hidden}
img,video,iframe{max-width:100%;height:auto;border-radius:12px}
h1,h2,h3{color:#005b32;line-height:1.5}
a{color:#006c3b} table{max-width:100%;display:block;overflow-x:auto}
*{box-sizing:border-box}
</style></head><body>${widget.html}</body></html>
''', baseUrl: 'https://www.aytamaliraq.com/');
  }
  @override
  Widget build(BuildContext context) => SizedBox(
    height: _height, child: WebViewWidget(controller: _controller));
}
