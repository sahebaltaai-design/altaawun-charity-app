import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CharityAccountPage extends StatefulWidget {
  final int? cartCount;
  final VoidCallback onOpenCart;
  const CharityAccountPage({super.key, required this.cartCount, required this.onOpenCart});
  @override
  State<CharityAccountPage> createState() => _AccountState();
}

class _AccountState extends State<CharityAccountPage> {
  static const base = 'https://www.aytamaliraq.com/wp-json/altaawun-app/v1/';
  static const storage = FlutterSecureStorage();
  final email = TextEditingController();
  final password = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  late Country _selectedCountry;
  final state = TextEditingController();
  final city = TextEditingController();
  final address = TextEditingController();
  final address2 = TextEditingController();
  final postcode = TextEditingController();
  String? token, error;
  Map<String, dynamic>? user;
  List<dynamic> orders = [];
  String mode = 'login';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final region = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    _selectedCountry = CountryService().findByCode(region) ??
        CountryService().findByCode('IQ')!;
    restore();
  }

  void _selectCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      favorite: const ['IQ', 'US'],
      onSelect: (Country country) => setState(() => _selectedCountry = country),
    );
  }

  String _internationalPhone() {
    final raw = phone.text.trim().replaceAll(RegExp('[^0-9+]'), '');
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('00')) return '+${raw.substring(2)}';
    final local = raw.startsWith('0') ? raw.substring(1) : raw;
    return '+${_selectedCountry.phoneCode}$local';
  }

  String? _validateRegistration() {
    if (firstName.text.trim().isEmpty) return 'أدخل الاسم الأول.';
    if (lastName.text.trim().isEmpty) return 'أدخل اسم العائلة.';
    if (!RegExp(r'^[^@ ]+@[^@ ]+[.][^@ ]+$').hasMatch(email.text.trim())) {
      return 'أدخل بريدًا إلكترونيًا صحيحًا.';
    }
    if (password.text.runes.length < 12) {
      return 'كلمة المرور قصيرة: يجب أن تحتوي على 12 حرفًا على الأقل.';
    }
    if (utf8.encode(password.text).length > 256) {
      return 'كلمة المرور طويلة جدًا (الحد الأقصى 256 بايت).';
    }
    if (!RegExp(r'^[+][1-9][0-9]{7,14}$').hasMatch(_internationalPhone())) {
      return 'أدخل رقم هاتف صحيحًا مع مفتاح الدولة.';
    }
    if (state.text.trim().isEmpty) return 'أدخل المحافظة أو الولاية.';
    if (city.text.trim().isEmpty) return 'أدخل المدينة.';
    if (address.text.trim().isEmpty) return 'أدخل العنوان.';
    return null;
  }
  @override
  void dispose() {
    for (final controller in [
      email, password, firstName, lastName, phone,
      state, city, address, address2, postcode,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>> api(String path, {Map<String, String>? body, String? bearer}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (bearer != null) headers['Authorization'] = 'Bearer ' + bearer;
    // The v1 register route is shadowed by an older WordPress integration.
    // v2 uses a dedicated endpoint published by auth plugin 1.1.11.
    final uri = path == 'register'
        ? Uri.parse('https://www.aytamaliraq.com/wp-json/altaawun-app/v2/register')
        : Uri.parse(base + path);
    final response = await (body == null
      ? http.get(uri, headers: headers)
      : http.post(uri, headers: headers, body: jsonEncode(body))).timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = decoded is Map ? decoded['code']?.toString() : '';
      final messages = <String, String>{
        'invalid_credentials': 'البريد أو كلمة المرور غير صحيحة',
        'email_in_use': 'البريد مستخدم مسبقًا',
        'registration_closed': 'التسجيل غير مفعل في إعدادات ووردبريس',
        'rest_no_route': 'خدمة إنشاء الحساب الجديدة غير مفعّلة. حدّث إضافة Altaawun App Authentication إلى الإصدار 1.1.11 في WordPress.',
        'rate_limited': 'محاولات كثيرة، حاول لاحقًا',
        'invalid_fields': 'رفض الموقع بعض بيانات التسجيل. راجع البريد والاسم والعنوان ثم حاول مجددًا.',
        'invalid_password': 'كلمة المرور يجب أن تتكون من 12 حرفًا على الأقل (وبحد أقصى 256 بايت).',
        'invalid_email': 'البريد الإلكتروني غير صحيح.',
        'missing_registration_field': 'يرجى إكمال بيانات التسجيل المطلوبة.',
        'session_expired': 'انتهت الجلسة، سجل الدخول مرة أخرى',
        'invalid_current_password': 'كلمة المرور الحالية غير صحيحة',
        'invalid_confirmation': 'لم يتم تأكيد طلب حذف الحساب',
        'account_delete_failed': 'تعذر حذف الحساب من الخادم. حاول مجددًا',
        'protected_account': 'لا يمكن حذف حساب الإدارة من التطبيق',
        'invalid_phone': 'أدخل رقم هاتف صحيحًا',
        'invalid_country': 'اختر رمز دولة صحيحًا مثل IQ أو US',
      };
      // Preserve the rejected field name without exposing private input values.
      final details = decoded is Map && decoded['data'] is Map
          ? decoded['data'] as Map : const {};
      final field = (details['field'] ?? '').toString();
      const fieldLabels = {
        'name': 'الاسم',
        'billing_first_name': 'الاسم الأول',
        'billing_last_name': 'اسم العائلة',
        'billing_country': 'الدولة',
        'billing_phone': 'رقم الهاتف',
        'billing_state': 'المحافظة أو الولاية',
        'billing_city': 'المدينة',
        'billing_address_1': 'العنوان',
      };
      final fieldHint = fieldLabels[field];
      final problem = messages[code] ?? 'فشل الاتصال: ${response.statusCode}';
      throw Exception(fieldHint == null ? problem : '$problem الحقل المطلوب: $fieldHint');
    }
    if (decoded is! Map) throw Exception('استجابة غير متوقعة');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> restore() async {
    final saved = await storage.read(key: 'altaawun_token');
    if (saved == null || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await api('me', bearer: saved);
      if (mounted) setState(() { token = saved; user = Map<String, dynamic>.from(result['user'] as Map); });
      await loadOrders();
    } catch (_) { await storage.delete(key: 'altaawun_token'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> submit() async {
    if (busy) return;
    if (mode == 'register') {
      final problem = _validateRegistration();
      if (problem != null) {
        setState(() => error = problem);
        return;
      }
    } else if (email.text.trim().isEmpty ||
               (mode == 'login' && password.text.isEmpty)) {
      setState(() => error = 'أدخل البريد الإلكتروني وكلمة المرور.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final current = mode;
      final fields = current == 'forgot' ? {'email': email.text.trim()} :
        current == 'register' ? {
          'email': email.text.trim(),
          'password': password.text,
          'name': '${firstName.text.trim()} ${lastName.text.trim()}',
          'billing_first_name': firstName.text.trim(),
          'billing_last_name': lastName.text.trim(),
          'billing_phone': _internationalPhone(),
          'billing_country': _selectedCountry.countryCode,
          'billing_state': state.text.trim(),
          'billing_city': city.text.trim(),
          'billing_address_1': address.text.trim(),
          'billing_address_2': address2.text.trim(),
          'billing_postcode': postcode.text.trim(),
        } : {'login': email.text.trim(), 'password': password.text};
      final result = await api(current == 'forgot' ? 'forgot-password' : current, body: fields);
      if (!mounted) return;
      if (current == 'forgot') {
        setState(() { mode = 'login'; error = 'إذا كان البريد مسجلًا، ستصلك رسالة الاستعادة'; });
      } else {
        final received = result['token']?.toString();
        if (received == null || received.isEmpty || result['user'] is! Map) throw Exception('جلسة غير صالحة');
        await storage.write(key: 'altaawun_token', value: received);
        password.clear();
        if (!mounted) return;
        setState(() { token = received; user = Map<String, dynamic>.from(result['user'] as Map); });
        await loadOrders();
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> loadOrders() async {
    if (token == null) return;
    if (mounted) setState(() => error = null);
    try {
      final result = await api('orders', bearer: token);
      if (!mounted) return;
      final fetched = result['orders'];
      if (fetched is! List) {
        setState(() => error = 'تعذر قراءة بيانات الطلبات من خادم الجمعية. لم يتم حذف أي بيانات.');
        return;
      }
      setState(() => orders = fetched);
    } catch (e) {
      if (mounted) setState(() => error =
        'تعذر استعادة الكفالات والطلبات من الخادم. يرجى إعادة المحاولة. ' +
        e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    final old = token;
    setState(() => busy = true);
    try { if (old != null) await api('logout', body: {}, bearer: old); } catch (_) {}
    await storage.delete(key: 'altaawun_token');
    if (mounted) setState(() { token = null; user = null; orders = []; busy = false; mode = 'login'; });
  }

  Future<void> deleteAccount() async {
    if (busy || token == null || user == null) return;
    final currentToken = token!;
    String passwordConfirmation = '';
    final passwordToVerify = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('حذف حسابي نهائيًا'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                'سيُحذف حسابك في الجمعية وبيانات ملفك الشخصي المرتبطة به. '
                'قد تحتفظ الجمعية بسجلات التبرعات والطلبات اللازمة للمحاسبة '
                'والالتزامات القانونية وفق سياسة الخصوصية. '
                'لا يمكن التراجع عن حذف الحساب.',
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => passwordConfirmation = value,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الحالية للتأكيد',
                  border: OutlineInputBorder(),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(dialogContext, passwordConfirmation),
              child: const Text('تأكيد حذف الحساب'),
            ),
          ],
        ),
      );
    if (!mounted || passwordToVerify == null) return;
    if (passwordToVerify.isEmpty) {
      setState(() => error = 'أدخل كلمة المرور الحالية لتأكيد الحذف');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final result = await api(
        'delete-account',
        body: {'password': passwordToVerify, 'confirm': 'DELETE'},
        bearer: currentToken,
      );
      if (result['deleted'] != true) {
        throw Exception('لم يؤكد الخادم حذف الحساب');
      }
      // The server permanently invalidates this token after deleting the user.
      // Do not log out locally until the server confirms deletion.
      await storage.delete(key: 'altaawun_token');
      if (!mounted) return;
      password.clear();
      email.clear();
      setState(() {
        token = null;
        user = null;
        orders = [];
        mode = 'login';
        error = 'تم حذف حسابك من الخادم بنجاح.';
      });
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() => error = 'لم يُحذف الحساب: $message');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const SizedBox(height: 16),
    const Icon(Icons.account_circle_outlined, size: 80, color: Color(0xFF00652A)),
    const SizedBox(height: 12),
    Text(user == null ? 'حسابي' : (user!['name']?.toString() ?? 'حسابي'),
      textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 16),
    if (busy) const LinearProgressIndicator(),
    if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!,
      textAlign: TextAlign.center, style: const TextStyle(color: Colors.deepOrange))),
    if (user != null) ...[
      Card(child: ListTile(title: const Text('البريد الإلكتروني'), subtitle: Text(user!['email']?.toString() ?? ''))),
      const SizedBox(height: 16),
      const Text('كفالاتي في السلة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      Card(child: ListTile(
        leading: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF00652A)),
        title: Text(widget.cartCount == null ? 'عرض سلة الكفالات' :
          'عدد الكفالات في السلة: ' + widget.cartCount.toString()),
        subtitle: const Text('راجع الأيتام والمبالغ قبل إتمام التبرع'),
        trailing: const Icon(Icons.chevron_left),
        onTap: widget.onOpenCart,
      )),
      const SizedBox(height: 14),
      Row(children: [const Expanded(child: Text('كفالاتي وطلباتي', style: TextStyle(fontWeight: FontWeight.bold))),
        IconButton(onPressed: busy ? null : loadOrders, icon: const Icon(Icons.refresh))]),
      if (orders.isEmpty && error == null) const Card(child: ListTile(title: Text('لا تظهر طلبات مرتبطة بهذا الحساب حاليًا'), subtitle: Text('إذا كانت لديك طلبات سابقة، تواصل مع الجمعية للتحقق من ربطها بحسابك.'))),
      for (final order in orders) if (order is Map) Card(child: ListTile(
        title: Text('طلب رقم ' + (order['id']?.toString() ?? '')),
        subtitle: Text('التاريخ: ' + (order['date']?.toString() ?? '') + ' | الحالة: ' + (order['status']?.toString() ?? '')),
        trailing: Text((order['total']?.toString() ?? '') + ' ' + (order['currency']?.toString() ?? '')))),
      OutlinedButton.icon(onPressed: busy ? null : logout, icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج')),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: busy ? null : deleteAccount,
        icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
        label: const Text('حذف حسابي نهائيًا', style: TextStyle(color: Colors.red)),
      ),
      const Text(
        'يمكنك حذف حسابك من داخل التطبيق. قد تحتفظ الجمعية بسجلات '
        'التبرعات المطلوبة للمحاسبة وفق سياسة الخصوصية.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ] else ...[
      Text(mode == 'register' ? 'إنشاء حساب جديد' : mode == 'forgot' ? 'استعادة كلمة المرور' : 'تسجيل الدخول',
        textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (mode == 'register') ...[
        TextField(controller: firstName, textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'الاسم الأول *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: lastName, textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'اسم العائلة *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectCountry,
          borderRadius: BorderRadius.circular(9),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'الدولة ومفتاح الاتصال *',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              '${_selectedCountry.flagEmoji} ${_selectedCountry.name} (+${_selectedCountry.phoneCode})',
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'رقم الهاتف *',
            prefixText: '+${_selectedCountry.phoneCode}  ',
            helperText: 'مفتاح الدولة يضاف تلقائيًا؛ يمكنك كتابة الرقم المحلي.',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(controller: state,
          decoration: const InputDecoration(labelText: 'المحافظة / الولاية *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: city,
          decoration: const InputDecoration(labelText: 'المدينة *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: address,
          decoration: const InputDecoration(labelText: 'العنوان *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: address2,
          decoration: const InputDecoration(labelText: 'عنوان إضافي (اختياري)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: postcode,
          decoration: const InputDecoration(labelText: 'الرمز البريدي (اختياري)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
      ],
      TextField(controller: email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder())),
      if (mode != 'forgot') ...[
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: true,
          decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder())),
      ],
      const SizedBox(height: 16),
      FilledButton(onPressed: busy ? null : submit,
        child: Text(mode == 'register' ? 'إنشاء الحساب' : mode == 'forgot' ? 'إرسال رابط الاستعادة' : 'دخول')),
      TextButton(onPressed: busy ? null : () => setState(() { mode = mode == 'register' ? 'login' : 'register'; error = null; }),
        child: Text(mode == 'register' ? 'لدي حساب' : 'إنشاء حساب جديد')),
      TextButton(onPressed: busy ? null : () => setState(() { mode = mode == 'forgot' ? 'login' : 'forgot'; error = null; }),
        child: Text(mode == 'forgot' ? 'العودة لتسجيل الدخول' : 'نسيت كلمة المرور؟')),
      const Text('يمكنك تصفح التطبيق كزائر دون تسجيل الدخول', textAlign: TextAlign.center),
    ],
  ]);
}
