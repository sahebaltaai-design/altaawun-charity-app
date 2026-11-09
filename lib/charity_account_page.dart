import 'dart:convert';
import 'package:flutter/material.dart';
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
  final name = TextEditingController();
  final lastName = TextEditingController();
  final confirmPassword = TextEditingController();
  final phone = TextEditingController();
  final country = TextEditingController();
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
  bool editingProfile = false;

  @override
  void initState() { super.initState(); restore(); }
  @override
  void dispose() { email.dispose(); password.dispose(); name.dispose(); lastName.dispose(); confirmPassword.dispose(); phone.dispose(); country.dispose(); state.dispose(); city.dispose(); address.dispose(); address2.dispose(); postcode.dispose(); super.dispose(); }

  Future<Map<String, dynamic>> api(String path, {Map<String, String>? body, String? bearer}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (bearer != null) headers['Authorization'] = 'Bearer ' + bearer;
    final uri = Uri.parse(base + path);
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
        'rate_limited': 'محاولات كثيرة، حاول لاحقًا',
        'invalid_fields': 'تأكد من البيانات وكلمة المرور (12 حرفًا على الأقل)',
        'session_expired': 'انتهت الجلسة، سجل الدخول مرة أخرى',
      };
      throw Exception(messages[code] ?? 'فشل الاتصال: ' + response.statusCode.toString());
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

  // WooCommerce stores ISO 3166-1 alpha-2 country codes, not display names.
  String get normalizedCountry {
    final value = country.text.trim();
    final normalized = value.toLowerCase();
    const known = <String, String>{
      'العراق': 'IQ', 'iraq': 'IQ', 'iq': 'IQ',
      'الولايات المتحدة': 'US', 'الولايات المتحدة الأمريكية': 'US',
      'united states': 'US', 'usa': 'US', 'us': 'US',
      'المملكة المتحدة': 'GB', 'united kingdom': 'GB', 'gb': 'GB',
    };
    return known[normalized] ?? value.toUpperCase();
  }

  String accountValue(String key) {
    final billing = user?['billing'];
    final nested = billing is Map ? billing[key] : null;
    return (nested ?? user?['billing_$key'] ?? user?[key] ?? '').toString();
  }

  Widget accountDetail(String label, String value) => Card(
    child: ListTile(
      title: Text(label),
      subtitle: Text(value.trim().isEmpty ? 'غير مسجل' : value),
    ),
  );

  void beginProfileEdit() {
    name.text = accountValue('first_name');
    lastName.text = accountValue('last_name');
    phone.text = accountValue('phone');
    country.text = accountValue('country') == 'IQ' ? 'العراق' : accountValue('country');
    state.text = accountValue('state');
    city.text = accountValue('city');
    address.text = accountValue('address_1');
    address2.text = accountValue('address_2');
    postcode.text = accountValue('postcode');
    setState(() { editingProfile = true; error = null; });
  }

  Future<void> saveProfile() async {
    if (busy || token == null) return;
    if ([name, lastName, phone, country, state, city, address]
        .any((field) => field.text.trim().isEmpty) ||
        !RegExp(r'^\\+?[0-9 ()-]{7,20} [name, lastName, phone, country, state, city, address]
      .every((field) => field.text.trim().isNotEmpty) &&
      RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(phone.text.trim()) &&
      password.text.length >= 12 && password.text == confirmPassword.text;

  Widget registrationField(TextEditingController controller, String label,
      {TextInputType keyboard = TextInputType.text, bool optional = false}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller, keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: optional ? '$label (اختياري)' : '$label *',
          border: const OutlineInputBorder(),
        ),
      ),
    );

  Future<void> submit() async {
    if (busy) return;
    if (email.text.trim().isEmpty || (mode != 'forgot' && password.text.isEmpty) ||
        (mode == 'register' && !validRegistration)) {
      setState(() => error = 'أكمل جميع الحقول المطلوبة، وتأكد من رقم الهاتف وتطابق كلمتي المرور (12 حرفًا على الأقل)');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final current = mode;
      final fields = current == 'forgot' ? {'email': email.text.trim()} :
        current == 'register' ? {'email': email.text.trim(), 'password': password.text, 'name': '${name.text.trim()} ${lastName.text.trim()}', 'first_name': name.text.trim(), 'last_name': lastName.text.trim(), 'billing_first_name': name.text.trim(), 'billing_last_name': lastName.text.trim(), 'billing_phone': phone.text.trim(), 'billing_country': normalizedCountry, 'billing_state': state.text.trim(), 'billing_city': city.text.trim(), 'billing_address_1': address.text.trim(), 'billing_address_2': address2.text.trim(), 'billing_postcode': postcode.text.trim()} :
        {'login': email.text.trim(), 'password': password.text};
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
      const SizedBox(height: 12),
      Row(children: [
        const Expanded(child: Text('بيانات الاتصال والعنوان', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
        if (!editingProfile) TextButton.icon(onPressed: busy ? null : beginProfileEdit,
          icon: const Icon(Icons.edit_outlined), label: const Text('تعديل')),
      ]),
      if (editingProfile) ...[
        registrationField(name, 'الاسم الأول'),
        registrationField(lastName, 'الاسم الأخير'),
        registrationField(phone, 'رقم الهاتف', keyboard: TextInputType.phone),
        registrationField(country, 'الدولة (العراق أو IQ)'),
        registrationField(state, 'المحافظة / الولاية'),
        registrationField(city, 'المدينة'),
        registrationField(address, 'الشارع والعنوان'),
        registrationField(address2, 'العنوان الإضافي', optional: true),
        registrationField(postcode, 'الرمز البريدي', optional: true),
        Row(children: [
          Expanded(child: FilledButton(onPressed: busy ? null : saveProfile, child: const Text('حفظ التعديلات'))),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: busy ? null : () => setState(() { editingProfile = false; error = null; }),
            child: const Text('إلغاء')),
        ]),
      ] else ...[
        accountDetail('الاسم الأول', accountValue('first_name')),
        accountDetail('الاسم الأخير', accountValue('last_name')),
        accountDetail('رقم الهاتف', accountValue('phone')),
        accountDetail('الدولة', accountValue('country') == 'IQ' ? 'العراق' : accountValue('country')),
        accountDetail('المحافظة / الولاية', accountValue('state')),
        accountDetail('المدينة', accountValue('city')),
        accountDetail('العنوان', accountValue('address_1')),
        accountDetail('العنوان الإضافي', accountValue('address_2')),
        accountDetail('الرمز البريدي', accountValue('postcode')),
      ],
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
    ] else ...[
      Text(mode == 'register' ? 'إنشاء حساب جديد' : mode == 'forgot' ? 'استعادة كلمة المرور' : 'تسجيل الدخول',
        textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (mode == 'register') ...[
        registrationField(name, 'الاسم الأول'),
        registrationField(lastName, 'الاسم الأخير'),
        registrationField(phone, 'رقم الهاتف', keyboard: TextInputType.phone),
        registrationField(country, 'الدولة (كتابة يدوية)'),
        registrationField(state, 'المحافظة / الولاية (كتابة يدوية)'),
        registrationField(city, 'المدينة / المنطقة (كتابة يدوية)'),
        registrationField(address, 'الشارع والحي والعنوان التفصيلي'),
        registrationField(address2, 'رقم الشقة أو الوحدة', optional: true),
        registrationField(postcode, 'الرمز البريدي ZIP Code', optional: true),
        const Text('يمكن كتابة العنوان يدويًا بالكامل. لا تكتب رمزًا بريديًا وهميًا إذا لم يكن متوفرًا في منطقتك.', style: TextStyle(fontSize: 12)),
        const Text('تأكيد الهاتف عبر SMS يتطلب تفعيل خدمة التحقق على الخادم.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
      ],
      TextField(controller: email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder())),
      if (mode != 'forgot') ...[
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: true,
          decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder())),
      ],
      if (mode == 'register') ...[
        const SizedBox(height: 12),
        TextField(controller: confirmPassword, obscureText: true,
          decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور *', border: OutlineInputBorder())),
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
).hasMatch(phone.text.trim()) ||
        !RegExp(r'^[A-Z]{2} [name, lastName, phone, country, state, city, address]
      .every((field) => field.text.trim().isNotEmpty) &&
      RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(phone.text.trim()) &&
      password.text.length >= 12 && password.text == confirmPassword.text;

  Widget registrationField(TextEditingController controller, String label,
      {TextInputType keyboard = TextInputType.text, bool optional = false}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller, keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: optional ? '$label (اختياري)' : '$label *',
          border: const OutlineInputBorder(),
        ),
      ),
    );

  Future<void> submit() async {
    if (busy) return;
    if (email.text.trim().isEmpty || (mode != 'forgot' && password.text.isEmpty) ||
        (mode == 'register' && !validRegistration)) {
      setState(() => error = 'أكمل جميع الحقول المطلوبة، وتأكد من رقم الهاتف وتطابق كلمتي المرور (12 حرفًا على الأقل)');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final current = mode;
      final fields = current == 'forgot' ? {'email': email.text.trim()} :
        current == 'register' ? {'email': email.text.trim(), 'password': password.text, 'name': '${name.text.trim()} ${lastName.text.trim()}', 'first_name': name.text.trim(), 'last_name': lastName.text.trim(), 'billing_first_name': name.text.trim(), 'billing_last_name': lastName.text.trim(), 'billing_phone': phone.text.trim(), 'billing_country': normalizedCountry, 'billing_state': state.text.trim(), 'billing_city': city.text.trim(), 'billing_address_1': address.text.trim(), 'billing_address_2': address2.text.trim(), 'billing_postcode': postcode.text.trim()} :
        {'login': email.text.trim(), 'password': password.text};
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
      const SizedBox(height: 12),
      const Text('بيانات الاتصال والعنوان', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      accountDetail('الاسم الأول', accountValue('first_name')),
      accountDetail('الاسم الأخير', accountValue('last_name')),
      accountDetail('رقم الهاتف', accountValue('phone')),
      accountDetail('الدولة (رمز WooCommerce)', accountValue('country')),
      accountDetail('المحافظة / الولاية', accountValue('state')),
      accountDetail('المدينة', accountValue('city')),
      accountDetail('العنوان', accountValue('address_1')),
      accountDetail('العنوان الإضافي', accountValue('address_2')),
      accountDetail('الرمز البريدي', accountValue('postcode')),
      const Text('هذه البيانات للعرض والتحقق. تعديلها يتطلب دعم تحديث الملف الشخصي في خادم ووردبريس.',
        style: TextStyle(fontSize: 12)),
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
    ] else ...[
      Text(mode == 'register' ? 'إنشاء حساب جديد' : mode == 'forgot' ? 'استعادة كلمة المرور' : 'تسجيل الدخول',
        textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (mode == 'register') ...[
        registrationField(name, 'الاسم الأول'),
        registrationField(lastName, 'الاسم الأخير'),
        registrationField(phone, 'رقم الهاتف', keyboard: TextInputType.phone),
        registrationField(country, 'الدولة (كتابة يدوية)'),
        registrationField(state, 'المحافظة / الولاية (كتابة يدوية)'),
        registrationField(city, 'المدينة / المنطقة (كتابة يدوية)'),
        registrationField(address, 'الشارع والحي والعنوان التفصيلي'),
        registrationField(address2, 'رقم الشقة أو الوحدة', optional: true),
        registrationField(postcode, 'الرمز البريدي ZIP Code', optional: true),
        const Text('يمكن كتابة العنوان يدويًا بالكامل. لا تكتب رمزًا بريديًا وهميًا إذا لم يكن متوفرًا في منطقتك.', style: TextStyle(fontSize: 12)),
        const Text('تأكيد الهاتف عبر SMS يتطلب تفعيل خدمة التحقق على الخادم.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
      ],
      TextField(controller: email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder())),
      if (mode != 'forgot') ...[
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: true,
          decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder())),
      ],
      if (mode == 'register') ...[
        const SizedBox(height: 12),
        TextField(controller: confirmPassword, obscureText: true,
          decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور *', border: OutlineInputBorder())),
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
).hasMatch(normalizedCountry)) {
      setState(() => error = 'أكمل بيانات الاتصال والعنوان، واختر دولة صحيحة (مثل العراق أو IQ).');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final result = await api('profile', bearer: token, body: {
        'first_name': name.text.trim(),
        'last_name': lastName.text.trim(),
        'billing_first_name': name.text.trim(),
        'billing_last_name': lastName.text.trim(),
        'billing_phone': phone.text.trim(),
        'billing_country': normalizedCountry,
        'billing_state': state.text.trim(),
        'billing_city': city.text.trim(),
        'billing_address_1': address.text.trim(),
        'billing_address_2': address2.text.trim(),
        'billing_postcode': postcode.text.trim(),
      });
      if (result['user'] is! Map) throw Exception('لم يؤكد الخادم حفظ البيانات.');
      final refreshed = await api('me', bearer: token);
      if (refreshed['user'] is! Map) throw Exception('تعذر التحقق من البيانات المحفوظة.');
      if (mounted) setState(() {
        user = Map<String, dynamic>.from(refreshed['user'] as Map);
        editingProfile = false;
        error = 'تم حفظ البيانات والتحقق منها على الخادم.';
      });
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر حفظ التعديلات. قد تحتاج إضافة ووردبريس إلى تفعيل مسار profile. ' +
          e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool get validRegistration => [name, lastName, phone, country, state, city, address]
      .every((field) => field.text.trim().isNotEmpty) &&
      RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(phone.text.trim()) &&
      password.text.length >= 12 && password.text == confirmPassword.text;

  Widget registrationField(TextEditingController controller, String label,
      {TextInputType keyboard = TextInputType.text, bool optional = false}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller, keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: optional ? '$label (اختياري)' : '$label *',
          border: const OutlineInputBorder(),
        ),
      ),
    );

  Future<void> submit() async {
    if (busy) return;
    if (email.text.trim().isEmpty || (mode != 'forgot' && password.text.isEmpty) ||
        (mode == 'register' && !validRegistration)) {
      setState(() => error = 'أكمل جميع الحقول المطلوبة، وتأكد من رقم الهاتف وتطابق كلمتي المرور (12 حرفًا على الأقل)');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final current = mode;
      final fields = current == 'forgot' ? {'email': email.text.trim()} :
        current == 'register' ? {'email': email.text.trim(), 'password': password.text, 'name': '${name.text.trim()} ${lastName.text.trim()}', 'first_name': name.text.trim(), 'last_name': lastName.text.trim(), 'billing_first_name': name.text.trim(), 'billing_last_name': lastName.text.trim(), 'billing_phone': phone.text.trim(), 'billing_country': normalizedCountry, 'billing_state': state.text.trim(), 'billing_city': city.text.trim(), 'billing_address_1': address.text.trim(), 'billing_address_2': address2.text.trim(), 'billing_postcode': postcode.text.trim()} :
        {'login': email.text.trim(), 'password': password.text};
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
      const SizedBox(height: 12),
      const Text('بيانات الاتصال والعنوان', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      accountDetail('الاسم الأول', accountValue('first_name')),
      accountDetail('الاسم الأخير', accountValue('last_name')),
      accountDetail('رقم الهاتف', accountValue('phone')),
      accountDetail('الدولة (رمز WooCommerce)', accountValue('country')),
      accountDetail('المحافظة / الولاية', accountValue('state')),
      accountDetail('المدينة', accountValue('city')),
      accountDetail('العنوان', accountValue('address_1')),
      accountDetail('العنوان الإضافي', accountValue('address_2')),
      accountDetail('الرمز البريدي', accountValue('postcode')),
      const Text('هذه البيانات للعرض والتحقق. تعديلها يتطلب دعم تحديث الملف الشخصي في خادم ووردبريس.',
        style: TextStyle(fontSize: 12)),
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
    ] else ...[
      Text(mode == 'register' ? 'إنشاء حساب جديد' : mode == 'forgot' ? 'استعادة كلمة المرور' : 'تسجيل الدخول',
        textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (mode == 'register') ...[
        registrationField(name, 'الاسم الأول'),
        registrationField(lastName, 'الاسم الأخير'),
        registrationField(phone, 'رقم الهاتف', keyboard: TextInputType.phone),
        registrationField(country, 'الدولة (كتابة يدوية)'),
        registrationField(state, 'المحافظة / الولاية (كتابة يدوية)'),
        registrationField(city, 'المدينة / المنطقة (كتابة يدوية)'),
        registrationField(address, 'الشارع والحي والعنوان التفصيلي'),
        registrationField(address2, 'رقم الشقة أو الوحدة', optional: true),
        registrationField(postcode, 'الرمز البريدي ZIP Code', optional: true),
        const Text('يمكن كتابة العنوان يدويًا بالكامل. لا تكتب رمزًا بريديًا وهميًا إذا لم يكن متوفرًا في منطقتك.', style: TextStyle(fontSize: 12)),
        const Text('تأكيد الهاتف عبر SMS يتطلب تفعيل خدمة التحقق على الخادم.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
      ],
      TextField(controller: email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder())),
      if (mode != 'forgot') ...[
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: true,
          decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder())),
      ],
      if (mode == 'register') ...[
        const SizedBox(height: 12),
        TextField(controller: confirmPassword, obscureText: true,
          decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور *', border: OutlineInputBorder())),
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
