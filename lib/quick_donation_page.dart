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
  String selectedCurrency = 'IQD';
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

  // Always fetch fresh donation settings. A price change in WordPress must
  // not be hidden by a CDN/browser proxy cache.
  Future<Map<String, dynamic>> load() async {
    final url = Uri.parse(_base).replace(queryParameters: {
      '_qd_refresh': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    final response = await http.get(url, headers: {
      'Accept': 'application/json',
      'Cache-Control': 'no-cache, no-store, max-age=0',
      'Pragma': 'no-cache',
    }).timeout(const Duration(seconds: 15));
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
    final isUsd = selectedCurrency == 'USD';
    final rate = (options['usd_to_iqd_rate'] as num?)?.toDouble() ?? 0;
    final rateReady = options['usd_available'] == true && rate > 0;
    if (isUsd && !rateReady) {
      setState(() => message = 'سعر الصرف غير معتمد حاليًا. اختر الدينار العراقي.');
      return;
    }
    final minimum = (options[isUsd ? 'usd_min_amount' : 'min_amount'] as num?)?.toInt() ?? 1;
    final maximum = (options[isUsd ? 'usd_max_amount' : 'max_amount'] as num?)?.toInt() ?? 10000;
    if (amount == null || amount < minimum || amount > maximum) {
      setState(() => message = 'اختر مبلغًا بين ' + minimum.toString() +
          ' و' + maximum.toString() + ' ' + selectedCurrency);
      return;
    }
    final iqdAmount = isUsd ? (amount * rate).round() : amount;
    setState(() { busy = true; message = null; });
    try {
      final response = await http.post(Uri.parse(_base + '/prepare'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({
            'amount': amount.toString(),
            'currency': selectedCurrency,
            'expected_amount_iqd': iqdAmount.toString(),
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
      if (mounted) setState(() {
        message = 'تعذر تجهيز التبرع. ربما تغير سعر الصرف؛ أغلق الصفحة وأعد فتحها أو تحقق من بوابة الدفع.';
      });
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
        final usdAvailable = options['usd_available'] == true &&
            options['usd_to_iqd_rate'] is num;
        final isUsd = selectedCurrency == 'USD' && usdAvailable;
        final amountSource = isUsd ? options['usd_amounts'] : options['amounts'];
        final amounts = amountSource is List
            ? amountSource.whereType<num>().map((n) => n.toInt()).toList()
            : <int>[];
        final rate = (options['usd_to_iqd_rate'] as num?)?.toDouble() ?? 0;
        final rateSource = options['usd_rate_source'] == 'cbi_auto'
            ? 'البنك المركزي العراقي — تحديث تلقائي'
            : 'السعر الاحتياطي المعتمد من الجمعية';
        final rateChecked = (options['usd_rate_updated_at'] as num?)?.toInt() ?? 0;
        final rateDate = rateChecked > 0
            ? DateTime.fromMillisecondsSinceEpoch(rateChecked * 1000).toLocal()
            : null;
        final rateDateLabel = rateDate == null ? '' :
            '${rateDate.year}-${rateDate.month.toString().padLeft(2, '0')}-${rateDate.day.toString().padLeft(2, '0')}';
        final typedAmount = customAmount.text.trim().isNotEmpty
            ? int.tryParse(customAmount.text.trim()) : chosenAmount;
        final estimatedIqd = typedAmount == null ? null
            : (isUsd ? (typedAmount * rate).round() : typedAmount);
        if (categories.isEmpty) return const Center(child: Text('لا توجد تصنيفات مفعلة.'));
        final category = categories.any((c) => c['id'] == categoryId)
            ? categoryId! : categories.first['id']!;
        final payment = methods.any((m) => m['id'] == methodId)
            ? methodId : null;
        final currency = isUsd ? 'USD' : 'IQD';
        return ListView(padding: const EdgeInsets.all(12), children: [
          // Center the form on tablets in portrait and landscape, instead
          // of stretching every input to the entire screen width.
          Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Card(elevation: 0, color: Colors.white, child: Padding(
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
              const Text('اختر العملة', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 8, children: [
                ChoiceChip(
                  label: const Text('دينار عراقي IQD'),
                  selected: !isUsd,
                  onSelected: (_) => setState(() {
                    selectedCurrency = 'IQD';
                    chosenAmount = null;
                    customAmount.clear();
                    message = null;
                  }),
                ),
                ChoiceChip(
                  label: const Text('دولار أمريكي USD'),
                  selected: isUsd,
                  onSelected: usdAvailable ? (_) => setState(() {
                    selectedCurrency = 'USD';
                    chosenAmount = null;
                    customAmount.clear();
                    message = null;
                  }) : null,
                ),
              ]),
              if (!usdAvailable) Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  options['store_currency'] != 'IQD'
                      ? 'عملة WooCommerce ليست الدينار العراقي. راجع إعدادات العملة في المتجر.'
                      : 'لم تصل إلى التطبيق بيانات سعر صرف الدولار المعتمد. اضغط تحديث السعر.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54))),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    config = load();
                    message = null;
                  }),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('تحديث سعر الصرف'),
                ),
              ),
              const SizedBox(height: 22),
              Row(children: [
                const Text('المبلغ', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(currency == 'USD' ? 'دولار أمريكي' : 'دينار عراقي',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
              const SizedBox(height: 8),
              // Compact, identical amount tiles. On phones the default five
              // amounts fit in a single row; very narrow screens wrap, and
              // tablets use the available width without oversized chips.
              LayoutBuilder(builder: (context, constraints) {
                final available = constraints.maxWidth;
                final columns = available < 270 ? 3 :
                    available >= 720 ? 6 : 5;
                final count = amounts.length < columns ? amounts.length : columns;
                if (count == 0) return const SizedBox.shrink();
                const spacing = 6.0;
                final tileWidth = (available - spacing * (count - 1)) / count;
                return Wrap(spacing: spacing, runSpacing: spacing, children: [
                  for (final amount in amounts)
                    SizedBox(
                      width: tileWidth,
                      height: 44,
                      child: Material(
                        color: chosenAmount == amount && customAmount.text.isEmpty
                            ? _green : const Color(0xFFE3F2E9),
                        borderRadius: BorderRadius.circular(9),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setState(() {
                            chosenAmount = amount;
                            customAmount.clear();
                            message = null;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Center(child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(amount.toString(),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold,
                                  color: chosenAmount == amount &&
                                      customAmount.text.isEmpty
                                      ? Colors.white : _green)),
                            )),
                          ),
                        ),
                      ),
                    ),
                ]);
              }),
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
              if (isUsd && rate > 0) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('1 USD = ' +
                    rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2) +
                    ' IQD', style: const TextStyle(color: _green,
                    fontWeight: FontWeight.bold)),
                  Text('مصدر السعر: ' + rateSource +
                    (rateDateLabel.isEmpty ? '' : ' — آخر تحقق: ' + rateDateLabel),
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  if (estimatedIqd != null && estimatedIqd > 0)
                    Text('المبلغ المطلوب دفعه: ' + estimatedIqd.toString() +
                        ' دينار عراقي', style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17)),
                  const Text('الدولار للعرض واختيار المبلغ فقط؛ تحصيل WooCommerce بالدينار. قد يختلف سعر تحويل جهة إصدار البطاقة وتُضاف رسومها.',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
              ),
              const SizedBox(height: 22),
              const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
              if (options['checkout_ready'] != true) const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: Text('يمكن اختيار المبلغ ومعاينة تحويل الدولار إلى الدينار، لكن الدفع غير متاح حتى تهيئة عملة الدفع IQD وربط بوابة دفع إلكترونية.',
                  style: TextStyle(fontSize: 12, color: Colors.black54))),
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
                onPressed: busy || payment == null || options['checkout_ready'] != true
                    ? null : () => prepare(options, category, payment),
                icon: const Icon(Icons.lock_outline),
                label: Text(busy ? 'جارٍ التجهيز...' : 'متابعة التبرع والدفع الآمن'),
              ),
              const SizedBox(height: 12),
              const Text('لا يخزن التطبيق بيانات البطاقة أو المحفظة. لا يُحصّل أي مبلغ قبل إتمام الدفع وتأكيده من بوابة الدفع.',
                style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
            ]),
          )))),
        ]);
      },
    ),
  );
}
