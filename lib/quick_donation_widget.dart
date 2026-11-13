import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Reads the actual WordPress Quick Donation v1.3.1 configuration.
/// All money amounts and USD conversion are revalidated by WordPress.
class AltaawunQuickDonation extends StatefulWidget {
  final ValueChanged<String> onCheckoutUrl;

  const AltaawunQuickDonation({super.key, required this.onCheckoutUrl});

  @override
  State<AltaawunQuickDonation> createState() => _AltaawunQuickDonationState();
}

class _AltaawunQuickDonationState extends State<AltaawunQuickDonation> {
  static final Uri _endpoint = Uri.https(
    'www.aytamaliraq.com', '/wp-json/altaawun/v1/quick-donation');
  static const Color _green = Color(0xFF00642D);
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  bool _enabled = false;
  bool _checkoutReady = false;
  bool _usdAvailable = false;
  String _currency = 'IQD';
  String? _category;
  String? _payment;
  String? _error;
  int _minAmount = 1000;
  int _maxAmount = 10000000;
  int _usdMaximum = 0;
  double _usdRate = 0;
  String _rateSource = '';
  final Map<String, String> _categories = {};
  final Map<String, String> _methods = {};
  List<int> _iqdAmounts = const [5000, 10000, 25000, 50000, 100000];
  List<int> _usdAmounts = const [5, 10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  int _int(dynamic value, [int fallback = 0]) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  Future<void> _refresh() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final response = await http.get(_endpoint,
        headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('خدمة التبرع السريع غير متاحة من الموقع حاليًا.');
      }
      final raw = jsonDecode(utf8.decode(response.bodyBytes));
      if (raw is! Map) throw Exception('استجابة إعدادات التبرع غير صالحة.');
      final categories = <String, String>{};
      for (final item in (raw['categories'] as List? ?? const [])) {
        if (item is Map) {
          final id = (item['id'] ?? '').toString();
          final name = (item['name'] ?? '').toString();
          if (id.isNotEmpty && name.isNotEmpty) categories[id] = name;
        }
      }
      final methods = <String, String>{};
      for (final item in (raw['payment_methods'] as List? ?? const [])) {
        if (item is Map) {
          final id = (item['id'] ?? '').toString();
          final name = (item['name'] ?? '').toString();
          if (id.isNotEmpty && name.isNotEmpty) methods[id] = name;
        }
      }
      final usdRate = raw['usd_to_iqd_rate'] is num
          ? (raw['usd_to_iqd_rate'] as num).toDouble() : 0.0;
      final usdAvailable = raw['usd_available'] == true && usdRate > 0;
      final iqd = (raw['amounts'] as List? ?? const [])
          .map((value) => _int(value)).where((value) => value > 0).toList();
      final usd = (raw['usd_amounts'] as List? ?? const [])
          .map((value) => _int(value)).where((value) => value > 0).toList();

      if (!mounted) return;
      setState(() {
        _enabled = raw['enabled'] == true;
        _checkoutReady = raw['checkout_ready'] == true;
        _categories..clear()..addAll(categories);
        _methods..clear()..addAll(methods);
        _category = categories.containsKey(_category) ? _category
            : (categories.isNotEmpty ? categories.keys.first : null);
        _payment = methods.containsKey(_payment) ? _payment
            : (methods.isNotEmpty ? methods.keys.first : null);
        _minAmount = _int(raw['min_amount'], 1000);
        _maxAmount = _int(raw['max_amount'], 10000000);
        _usdMaximum = _int(raw['usd_max_amount']);
        _usdAvailable = usdAvailable;
        _usdRate = usdRate;
        _rateSource = (raw['usd_rate_source'] ?? '').toString();
        if (!usdAvailable && _currency == 'USD') _currency = 'IQD';
        if (iqd.isNotEmpty) _iqdAmounts = iqd;
        if (usd.isNotEmpty) _usdAmounts = usd;
        _amount.text = (_currency == 'IQD' ? _iqdAmounts : _usdAmounts).first.toString();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _chooseCurrency(String currency) {
    if (currency == 'USD' && !_usdAvailable) return;
    setState(() {
      _currency = currency;
      _amount.text = (currency == 'USD' ? _usdAmounts : _iqdAmounts).first.toString();
      _error = null;
    });
  }

  Future<void> _prepare() async {
    if (_sending || !_checkoutReady || !_enabled) return;
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0 || _category == null || _payment == null) {
      setState(() => _error = 'اختر التصنيف وطريقة الدفع وأدخل مبلغًا صحيحًا.');
      return;
    }
    final expectedIqd = _currency == 'USD' ? (amount * _usdRate).round() : amount;
    if ((_currency == 'USD' && (!_usdAvailable || amount > _usdMaximum)) ||
        expectedIqd < _minAmount || expectedIqd > _maxAmount) {
      setState(() => _error = 'المبلغ خارج الحدود المعتمدة للتبرع.');
      return;
    }

    setState(() { _sending = true; _error = null; });
    try {
      final payload = <String, dynamic>{
        'category': _category,
        'amount': amount.toString(),
        'currency': _currency,
        'payment_method': _payment,
        'notes': _notes.text.trim(),
        if (_currency == 'USD') 'expected_amount_iqd': expectedIqd.toString(),
      };
      final response = await http.post(
        _endpoint.replace(path: '${_endpoint.path}/prepare'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 20));
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 || data is! Map) {
        final serverMessage = data is Map ? (data['message'] ?? '').toString() : '';
        throw Exception(serverMessage.isNotEmpty ? serverMessage :
          'تعذر تجهيز التبرع. راجع طريقة الدفع وسعر الصرف.');
      }
      final url = Uri.tryParse((data['checkout_url'] ?? '').toString());
      if (url == null || url.scheme != 'https' ||
          (url.host != 'aytamaliraq.com' && url.host != 'www.aytamaliraq.com') ||
          !url.queryParameters.containsKey('altaawun_qd') ||
          !url.queryParameters.containsKey('qd_sig')) {
        throw Exception('لم يرسل الموقع رابط دفع موثوقًا.');
      }
      if (mounted) widget.onCheckoutUrl(url.toString());
    } catch (e) {
      if (mounted) setState(() =>
        _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = _currency == 'IQD' ? _iqdAmounts : _usdAmounts;
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    final equivalent = (amount * _usdRate).round();
    final symbol = _currency == 'IQD' ? 'د.ع' : 'USD';
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFF8F7F1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('التبرع السريع', style: TextStyle(
            color: _green, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('اختر العملة والمبلغ والتصنيف، ثم أكمل الدفع داخل تطبيق الجمعية.'),
          if (_loading) const Padding(
            padding: EdgeInsets.all(22), child: Center(child: CircularProgressIndicator())),
          if (_error != null) Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(_error!, style: const TextStyle(color: Colors.red))),
          if (!_loading && _error != null)
            OutlinedButton.icon(onPressed: _refresh,
              icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          if (!_loading && !_enabled)
            const Padding(padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('خدمة التبرع السريع غير مفعّلة حاليًا. يمكن للمسؤول تفعيلها من إعدادات التبرع السريع في WordPress.')),
          if (!_loading && _enabled) ...[
            const SizedBox(height: 16),
            const Text('عملة التبرع', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 9, children: [
              ChoiceChip(label: const Text('الدينار العراقي (IQD)'),
                selected: _currency == 'IQD',
                onSelected: (_) => _chooseCurrency('IQD')),
              ChoiceChip(label: const Text('الدولار الأمريكي (USD)'),
                selected: _currency == 'USD',
                onSelected: _usdAvailable ? (_) => _chooseCurrency('USD') : null),
            ]),
            if (!_usdAvailable) const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('الدولار متاح بعد اعتماد سعر صرف حديث من إعدادات التبرع السريع في الموقع.',
                style: TextStyle(color: Colors.brown))),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'وجهة التبرع',
                border: OutlineInputBorder()),
              isExpanded: true,
              items: _categories.entries.map((entry) =>
                DropdownMenuItem<String>(value: entry.key,
                  child: Text(entry.value))).toList(),
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 14),
            Text('المبلغ ($symbol)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final option in values)
                ChoiceChip(
                  label: Text('$option $symbol'),
                  selected: amount == option,
                  onSelected: (_) => setState(() { _amount.text = option.toString(); _error = null; }),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'أو أدخل مبلغًا مخصصًا ($symbol)',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_currency == 'USD' && _usdAvailable) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('المقابل التقريبي: $equivalent دينار عراقي — '
                  'سعر الصرف المعتمد: $_usdRate د.ع/دولار '
                  '(${_rateSource == 'cbi_auto' ? 'البنك المركزي العراقي' : 'سعر احتياطي معتمد'}). '
                  'يتحقق الخادم من السعر قبل الدفع.')),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _payment,
              decoration: const InputDecoration(labelText: 'طريقة الدفع',
                border: OutlineInputBorder()),
              isExpanded: true,
              items: _methods.entries.map((entry) =>
                DropdownMenuItem<String>(value: entry.key, child: Text(entry.value))).toList(),
              onChanged: _methods.isNotEmpty ? (value) => setState(() => _payment = value) : null,
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes, maxLines: 2, maxLength: 500,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder())),
            if (!_checkoutReady) const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('يمكن معاينة خيارات التبرع. إتمام الدفع غير مفعل حتى تربط الجمعية بوابة دفع حقيقية ويكون متجر WooCommerce بالدينار العراقي.',
                style: TextStyle(color: Colors.brown))),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _green,
                minimumSize: const Size.fromHeight(48)),
              onPressed: _checkoutReady && _category != null &&
                _payment != null && !_sending ? _prepare : null,
              icon: _sending
                ? const SizedBox(width: 17, height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.volunteer_activism_outlined),
              label: Text(_sending ? 'جارٍ تجهيز التبرع...' : 'متابعة التبرع بأمان'),
            ),
            const SizedBox(height: 8),
            const Text('تتم معالجة الدفع لدى بوابة WooCommerce المفعلة لدى الجمعية.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ]),
      ),
    );
  }
}
