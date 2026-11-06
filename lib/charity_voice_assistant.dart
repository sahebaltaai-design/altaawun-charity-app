import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Voice access is opt-in. Continuous mode re-arms between utterances only
/// while this screen is visible; it is not a background microphone service.
class CharityVoiceAssistant extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final ValueChanged<Map<String, dynamic>> onOpenPost;
  const CharityVoiceAssistant({super.key, required this.onNavigate, required this.onOpenPost});
  @override
  State<CharityVoiceAssistant> createState() => _CharityVoiceAssistantState();
}

class _CharityVoiceAssistantState extends State<CharityVoiceAssistant> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _ready = false, _listening = false, _continuous = false, _speaking = false;
  String _heard = '', _message = 'اضغط الميكروفون وقل أمرًا مثل: افتح الأخبار';
  List<Map<String, dynamic>> _results = [];
  Timer? _restart;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final prefs = await SharedPreferences.getInstance();
    _continuous = prefs.getBool('voice_continuous_mode') ?? false;
    await _tts.setLanguage('ar-SA');
    await _tts.setSpeechRate(0.48);
    _tts.setCompletionHandler(() {
      _speaking = false;
      if (_continuous) _scheduleListen();
    });
    _ready = await _speech.initialize(
      onStatus: (status) {
        if (_disposed) return;
        if (status == 'done' || status == 'notListening') {
          _listening = false;
          if (mounted) setState(() {});
          if (_continuous && !_speaking) _scheduleListen();
        }
      },
      onError: (error) {
        _listening = false;
        if (mounted) setState(() => _message = 'تعذر التعرف على الصوت. حاول مرة أخرى.');
        if (_continuous && !_speaking) _scheduleListen();
      },
    );
    if (!mounted) return;
    setState(() {});
    if (_continuous && _ready) _scheduleListen();
  }

  void _scheduleListen() {
    _restart?.cancel();
    if (!_continuous || _disposed || _speaking) return;
    _restart = Timer(const Duration(milliseconds: 900), () {
      if (mounted && !_listening && !_speaking) _listen();
    });
  }

  Future<void> _say(String message) async {
    if (!mounted) return;
    _restart?.cancel();
    await _speech.stop();
    _listening = false;
    _speaking = true;
    setState(() => _message = message);
    await _tts.speak(message);
  }

  Future<void> _listen() async {
    if (!_ready || _listening || _speaking || !mounted) return;
    setState(() { _listening = true; _heard = ''; _message = 'أستمع إليك الآن'; });
    await _speech.listen(
      localeId: 'ar_SA',
      listenFor: const Duration(seconds: 25),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _heard = result.recognizedWords);
        if (result.finalResult && _heard.trim().isNotEmpty) {
          _restart?.cancel();
          _speech.stop();
          _execute(_heard.trim());
        }
      },
    );
  }

  Future<void> _execute(String command) async {
    final q = command.toLowerCase();
    if (q.contains('توقف') || q.contains('اسكت') || q.contains('إيقاف')) {
      _restart?.cancel();
      _continuous = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('voice_continuous_mode', false);
      await _tts.stop();
      await _speech.stop();
      if (mounted) setState(() { _speaking = false; _listening = false; _message = 'تم إيقاف الاستماع المستمر'; });
      return;
    }
    if (q.contains('الرئيسية') || q.contains('الرئيسيه')) {
      widget.onNavigate(0);
      await _say('تم فتح الرئيسية');
      return;
    }
    if (q.contains('تبرع') || q.contains('الكفالة') || q.contains('كفالة')) {
      widget.onNavigate(1);
      await _say('تم فتح قسم التبرعات والكفالات. لا يتم تأكيد أي تبرع بالصوت.');
      return;
    }
    if (q.contains('الأخبار') || q.contains('اخبار')) {
      widget.onNavigate(4);
      await _say('تم فتح قسم الأخبار');
      return;
    }
    if (q.contains('حسابي')) {
      widget.onNavigate(7);
      await _say('تم فتح صفحة حسابي');
      return;
    }
    if (q.contains('التالي') && _results.isNotEmpty) {
      _results.add(_results.removeAt(0));
      await _readFirst();
      return;
    }
    if ((q.contains('اقرأ') || q.contains('افتح') || q.contains('الأول')) && _results.isNotEmpty) {
      await _readFirst();
      return;
    }
    await _search(command);
  }

  Future<void> _readFirst() async {
    final item = _results.first;
    widget.onOpenPost(item);
    final title = (item['title'] is Map ? item['title']['rendered'] : '').toString()
        .replaceAll(RegExp(r'<[^>]*>'), '');
    final body = (item['content'] is Map ? item['content']['rendered'] : '').toString()
        .replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\\s+'), ' ');
    await _say('$title. ${body.length > 1800 ? body.substring(0, 1800) : body}');
  }

  Future<void> _search(String command) async {
    setState(() => _message = 'أبحث عن $command');
    try {
      final uri = Uri.parse('https://www.aytamaliraq.com/wp-json/wp/v2/search')
          .replace(queryParameters: {'search': command, 'per_page': '10'});
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception('search');
      final matches = jsonDecode(utf8.decode(response.bodyBytes));
      if (matches is! List || matches.isEmpty) {
        await _say('لم أجد نتائج لهذا الطلب. جرب كلمات أخرى.');
        return;
      }
      _results = [];
      for (final match in matches.take(5)) {
        if (match is! Map || match['id'] == null) continue;
        final kind = match['type'] == 'post' ? 'posts' : 'pages';
        final detail = await http.get(Uri.parse('https://www.aytamaliraq.com/wp-json/wp/v2/$kind/${match['id']}?_embed=1'))
            .timeout(const Duration(seconds: 12));
        if (detail.statusCode == 200) {
          final item = jsonDecode(utf8.decode(detail.bodyBytes));
          if (item is Map) _results.add(Map<String, dynamic>.from(item));
        }
      }
      if (_results.isEmpty) {
        await _say('وجدت نتائج لكن لا أستطيع قراءة تفاصيلها الآن.');
        return;
      }
      final titles = _results.take(3).map((item) =>
          (item['title'] is Map ? item['title']['rendered'] : '').toString().replaceAll(RegExp(r'<[^>]*>'), '')).join('، ');
      await _say('وجدت ${_results.length} نتائج: $titles. قل اقرأ الأول أو التالي.');
    } catch (_) {
      await _say('تعذر البحث حاليًا. تحقق من الإنترنت ثم حاول مرة أخرى.');
    }
  }

  Future<void> _changeMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_continuous_mode', value);
    setState(() => _continuous = value);
    if (value) _scheduleListen();
    else { _restart?.cancel(); await _speech.stop(); setState(() => _listening = false); }
  }

  @override
  void dispose() {
    _disposed = true;
    _restart?.cancel();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مساعد التعاون الصوتي'), foregroundColor: const Color(0xFF00642D)),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const Icon(Icons.accessibility_new, size: 72, color: Color(0xFF00642D)),
      const SizedBox(height: 12),
      SwitchListTile(
        title: const Text('الاستماع المستمر أثناء فتح المساعد'),
        subtitle: const Text('أو أوقفه واستخدم زر الميكروفون فقط. لا يعمل والشاشة مغلقة.'),
        value: _continuous,
        onChanged: _changeMode,
      ),
      const SizedBox(height: 18),
      Semantics(button: true, label: _listening ? 'إيقاف الاستماع' : 'ابدأ الاستماع', child:
        FilledButton.icon(
          onPressed: !_ready ? null : () async {
            if (_listening) {
              _restart?.cancel();
              await _speech.stop();
              setState(() => _listening = false);
            } else {
              await _tts.stop();
              _speaking = false;
              _listen();
            }
          },
          icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic),
          label: Text(_listening ? 'إيقاف الاستماع' : 'تحدث الآن'),
        )),
      const SizedBox(height: 20),
      Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19)),
      if (_heard.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('سمعت: $_heard', textAlign: TextAlign.center)),
      const SizedBox(height: 20),
      OutlinedButton.icon(onPressed: () { _tts.stop(); _speech.stop(); _restart?.cancel(); _changeMode(false); },
        icon: const Icon(Icons.stop), label: const Text('إيقاف المساعد')),
      const Text('أمثلة: افتح الأخبار، افتح الرئيسية، ابحث عن المدرسة، اقرأ الأول، التالي، توقف.',
        textAlign: TextAlign.center),
    ])),
  );
}
