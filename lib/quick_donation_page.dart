import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const _green = Color(0xFF075C39);
const _base = 'https://www.aytamaliraq.com/wp-json/altaawun/v1/quick-donation';

/// No payment credentials are processed in Flutter. WooCommerce owns checkout.
class QuickDonationPage extends StatefulWidget {
  final ValueChanged<String> onCheckout;
  const QuickDonationPage({super.key, required this.onCheckout});

  @override
  State<QuickDonationPage> createState() => _QuickDonationPageState();
}

class _QuickDonationPageState extends State<QuickDonationPage> {
  late Future<Map<String, dynamic>> config;
  final customAmount = TextEditingController();
  String? categoryId, methodId, message;
  int? chosenAmount;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    config = load();
  }

  @override
  void dispose() {
    customAmount.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> load() async {
    final response = await http.get(Uri.parse(_base))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw StateError('No quick donation endpoint');
    final value = jsonDecode(utf8.decode(response.bodyBytes));
    if (value is! Map || value['enabled'] != true) {
      throw StateError('Quick donation disabled');
    }
    return Map<String, dynamic>.from(value);
  }

  List<Map<String, String>> choices(dynamic data) {
    if (data is! List) return [];
    return data.whereType<Map>().map((item) => <String, String>{
      'id': (item['id'] ?? '').toString(),
      'name': (item['name'] ?? '').toString(),
    }).where((item) => item['id']!.isNotEmpty && item['name']!.isNotEmpty).toList();
  }

  Future<void> prepare(Map<String, dynamic> options, String category,
      String payment) async {
    if (busy) return;
    final amount = customAmount.text.trim().isNotEmpty
        ? int.tryParse(customAmount.text.trim()) : chosenAmount;
    final minimum = (options['min_amount'] as num?)?.toInt() ?? 1;
    final maximum = (options['max_amount'] as num?)?.toInt() ?? 10000;
    if (amount == null || amount < minimum || amount > maximum) {
      setState(() => message = 'اختر مبلغًا بين ' + minimum.toString() +
          ' و' + maximum.toString() + ' ' + (options['currency'] ?? '').toString());
      return;
    }
    setState(() { busy = true; message = null; });
    try {
      final response = await http.post(Uri.parse(_base + '/prepare'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({
            'amount': amount.toString(),
            'category': category,
            'payment_method': payment,
          })).timeout(const Duration(seconds: 20));
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 || data is! Map) throw StateError('Failed');
      final checkout = Uri.tryParse((data['checkout_url'] ?? '').toString());
      if (checkout == null || checkout.scheme != 'https' ||
          !['aytamaliraq.com', 'www.aytamaliraq.com'].contains(checkout.host) ||
          !checkout.path.toLowerCase().contains('/cart')) {
        throw StateError('Invalid checkout URL');
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCheckout(checkout.toString());
    } catch (_) {
      if (mounted) setState(() => message =
          'تعذر تجهيز التبرع. تأكد من الاتصال وإعدادات بوابة الدفع.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F7F1),
    appBar: AppBar(
      title: const Text('تبرع الآن'),
      foregroundColor: _green, backgroundColor: Colors.white),
    body: FutureBuilder<Map<String, dynamic>>(
      future: config,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('التبرع السريع غير مفعّل حاليًا.'),
            TextButton.icon(
              onPressed: () => setState(() => config = load()),
              icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          ]));
        }
        final options = snapshot.data!;
        final categories = choices(options['categories']);
        final methods = choices(options['payment_methods']);
        final amounts = options['amounts'] is List
            ? (options['amounts'] as List).whereType<num>().map((n) => n.toInt()).toList()
            : <int>[];
        if (categories.isEmpty) return const Center(child: Text('لا توجد تصنيفات مفعلة.'));
        final category = categories.any((c) => c['id'] == categoryId)
            ? categoryId! : categories.first['id']!;
        final payment = methods.any((m) => m['id'] == methodId)
            ? methodId : null;
        final currency = (options['currency'] ?? 'IQD').toString();
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(elevation: 0, color: Colors.white, child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.volunteer_activism, color: _green, size: 44),
              const Text('تبرع الآن', textAlign: TextAlign.center,
                style: TextStyle(color: _green, fontSize: 25,
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('اختر التصنيف والمبلغ وطريقة الدفع',
                textAlign: TextAlign.center),
              const SizedBox(height: 24),
              const Text('تصنيف التبرع', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category, isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  for (final item in categories)
                    DropdownMenuItem<String>(
                      value: item['id'], child: Text(item['name']!))
                ],
                onChanged: (v) => setState(() => categoryId = v),
              ),
              const SizedBox(height: 22),
              const Text('المبلغ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final amount in amounts)
                  ChoiceChip(
                    label: Text(amount.toString() + ' ' + currency),
                    selected: chosenAmount == amount && customAmount.text.isEmpty,
                    onSelected: (_) => setState(() {
                      chosenAmount = amount;
                      customAmount.clear();
                    }),
                  ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: customAmount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'أو أدخل مبلغًا آخر', suffixText: currency),
              ),
              const SizedBox(height: 22),
              const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
              if (methods.isEmpty) const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('لم تُفعّل بوابات الدفع بعد. تظهر طرق الدفع هنا بعد تفعيلها من لوحة ووردبريس.')),
              for (final item in methods)
                RadioListTile<String>(
                  title: Text(item['name']!), value: item['id']!,
                  groupValue: payment, activeColor: _green,
                  onChanged: (v) => setState(() => methodId = v),
                ),
              if (message != null) Padding(
                padding: const EdgeInsets.all(8),
                child: Text(message!, style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 15)),
                onPressed: busy || payment == null
                    ? null : () => prepare(options, category, payment),
                icon: const Icon(Icons.lock_outline),
                label: Text(busy ? 'جارٍ التجهيز...' : 'متابعة التبرع والدفع الآمن'),
              ),
              const SizedBox(height: 12),
              const Text('لا يخزن التطبيق بيانات البطاقة أو المحفظة. تأكيد التبرع يعتمد على بوابة الدفع.',
                style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
            ]),
          )),
        ]);
      },
    ),
  );
}
