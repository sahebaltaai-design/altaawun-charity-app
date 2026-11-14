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
  final surname = TextEditingController();
  final phone = TextEditingController();
  final country = TextEditingController(text: 'IQ');
  final province = TextEditingController();
  final city = TextEditingController();
  final address = TextEditingController();
  final code = TextEditingController();
  String? pendingEmail;
  DateTime? lastSent;
  String? token, error;
  Map<String, dynamic>? user;
  List<dynamic> orders = [];
  String mode = 'login';
  bool busy = false;

  @override
  void initState() { super.initState(); restore(); }
  @override
  void dispose() { email.dispose(); password.dispose(); name.dispose(); surname.dispose(); phone.dispose(); country.dispose(); province.dispose(); city.dispose(); address.dispose(); code.dispose(); super.dispose(); }

  Future<Map<String, dynamic>> api(String path, {Map<String, String>? body, String? bearer, bool v2 = false}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (bearer != null) headers['Authorization'] = 'Bearer ' + bearer;
    final uri = Uri.parse((v2 ? base.replaceFirst('/v1/', '/v2/') : base) + path);
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
        'email_unverified': 'يجب تأكيد البريد الإلكتروني أولًا',
        'invalid_code': 'رمز التأكيد غير صحيح',
        'code_expired': 'انتهت صلاحية الرمز؛ اطلب رمزًا جديدًا',
        'otp_cooldown': 'انتظر 60 ثانية قبل طلب رمز جديد',
        'otp_attempts_exceeded': 'محاولات كثيرة؛ اطلب رمزًا جديدًا',
        'invalid_phone': 'رقم الهاتف غير صحيح',
        'invalid_country': 'أدخل رمز الدولة مثل IQ أو US',
        'missing_registration_field': 'أكمل حقول التسجيل المطلوبة',
        'email_delivery_failed': 'تعذر إرسال البريد من الموقع',
        'invalid_current_password': 'كلمة المرور الحالية غير صحيحة',
        'invalid_confirmation': 'يجب تأكيد حذف الحساب',
        'protected_account': 'لا يمكن حذف حساب الإدارة من التطبيق',
        'account_delete_failed': 'تعذر حذف الحساب؛ حاول مرة أخرى',
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

  Future<void> resend() async {
    if (busy || pendingEmail == null) return;
    if (lastSent != null && DateTime.now().difference(lastSent!).inSeconds < 60) {
      setState(() => error = 'انتظر 60 ثانية قبل إعادة الإرسال');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await api('register-resend', v2: true, body: {'email': pendingEmail!});
      lastSent = DateTime.now();
      if (mounted) setState(() => error = 'إذا كان الحساب بانتظار التأكيد، سيصل رمز جديد');
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (busy) return;
    if (mode == 'register' && [name, surname, phone, country, province, city, address]
        .any((field) => field.text.trim().isEmpty)) {
      setState(() => error = 'أكمل الاسم والهاتف والعنوان');
      return;
    }
    if (mode == 'verify' && !RegExp(r'^[0-9]{6}$').hasMatch(code.text.trim())) {
      setState(() => error = 'أدخل رمز التأكيد من 6 أرقام');
      return;
    }
    if (email.text.trim().isEmpty ||
        (mode != 'forgot' && mode != 'verify' && password.text.isEmpty) ||
        (mode == 'register' && password.text.runes.length < 12)) {
      setState(() => error = 'أكمل البيانات المطلوبة؛ كلمة مرور التسجيل 12 حرفًا على الأقل');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final current = mode;
      final fields = current == 'forgot' ? {'email': email.text.trim()} :
        current == 'verify' ? {'email': pendingEmail ?? email.text.trim(), 'code': code.text.trim()} :
        current == 'register' ? {
          'email': email.text.trim(), 'password': password.text,
          'name': '${name.text.trim()} ${surname.text.trim()}',
          'billing_first_name': name.text.trim(),
          'billing_last_name': surname.text.trim(),
          'billing_phone': phone.text.trim(),
          'billing_country': country.text.trim().toUpperCase(),
          'billing_state': province.text.trim(),
          'billing_city': city.text.trim(),
          'billing_address_1': address.text.trim(),
        } : {'login': email.text.trim(), 'password': password.text};
      final endpoint = current == 'forgot' ? 'forgot-password' :
          current == 'register' ? 'register-start' :
          current == 'verify' ? 'register-verify' : 'login';
      final result = await api(endpoint, v2: current == 'register' || current == 'verify', body: fields);
      if (!mounted) return;
      if (current == 'forgot') {
        setState(() { mode = 'login'; error = 'إذا كان البريد مسجلًا، ستصلك رسالة الاستعادة'; });
      } else if (current == 'register') {
        if (result['verification_required'] != true) throw Exception('لم يبدأ تأكيد البريد الإلكتروني');
        setState(() {
          pendingEmail = email.text.trim();
          lastSent = result['email_sent'] == true ? DateTime.now() : null;
          mode = 'verify';
          error = result['email_sent'] == true
              ? 'أرسلنا رمزًا من 6 أرقام إلى بريدك، صالح لمدة 10 دقائق'
              : 'تعذر إرسال الرمز؛ تحقق من إعدادات بريد الموقع ثم أعد الإرسال';
        });
      } else {
        final received = result['token']?.toString();
        if (received == null || received.isEmpty || result['user'] is! Map) throw Exception('جلسة غير صالحة');
        await storage.write(key: 'altaawun_token', value: received);
        password.clear();
        code.clear();
        if (!mounted) return;
        setState(() { token = received; user = Map<String, dynamic>.from(result['user'] as Map); mode = 'login'; pendingEmail = null; });
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
    if (busy || token == null) return;
    final currentPassword = TextEditingController();
    bool confirmed = false;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('حذف حسابي نهائيًا'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('سيُحذف حسابك من الموقع ولن تتمكن من تسجيل الدخول إليه. قد تُحتفظ سجلات التبرعات والطلبات المالية وفق المتطلبات القانونية. لا يمكن التراجع عن حذف الحساب.'),
              const SizedBox(height: 16),
              TextField(
                controller: currentPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الحالية للتأكيد',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
            TextButton(
              onPressed: () {
                if (currentPassword.text.isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('تأكيد الحذف النهائي', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ) ?? false;
      if (!confirmed || !mounted) return;
      setState(() { busy = true; error = null; });
      final result = await api('delete-account', v2: true, bearer: token,
        body: {'confirm': 'DELETE', 'password': currentPassword.text});
      if (result['deleted'] != true) throw Exception('لم يؤكد الخادم حذف الحساب');
      await storage.delete(key: 'altaawun_token');
      if (!mounted) return;
      setState(() {
        token = null;
        user = null;
        orders = [];
        mode = 'login';
        error = 'تم حذف الحساب بنجاح';
        busy = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        busy = false;
      });
    } finally {
      currentPassword.dispose();
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
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: busy ? null : deleteAccount,
        icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
        label: const Text('حذف حسابي نهائيًا', style: TextStyle(color: Colors.red)),
      ),
    ] else ...[
      Text(mode == 'register' ? 'إنشاء حساب جديد' : mode == 'verify' ? 'تأكيد البريد الإلكتروني' : mode == 'forgot' ? 'استعادة كلمة المرور' : 'تسجيل الدخول',
        textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (mode == 'register') ...[
        TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم الأول', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: surname, decoration: const InputDecoration(labelText: 'اسم العائلة', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: country, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'رمز الدولة مثل IQ أو US', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: province, decoration: const InputDecoration(labelText: 'المحافظة أو الولاية', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: city, decoration: const InputDecoration(labelText: 'المدينة', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder())),
        const SizedBox(height: 12),
      ],
      if (mode == 'verify') ...[
        Text('أدخل الرمز المرسل إلى ${pendingEmail ?? email.text.trim()}', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6,
          decoration: const InputDecoration(labelText: 'رمز التأكيد', border: OutlineInputBorder())),
        TextButton(onPressed: busy ? null : resend, child: const Text('إعادة إرسال الرمز')),
        TextButton(onPressed: busy ? null : () => setState(() { mode = 'login'; error = null; }),
          child: const Text('العودة لتسجيل الدخول')),
      ] else TextField(controller: email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder())),
      if (mode != 'forgot' && mode != 'verify') ...[
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: true,
          decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder())),
      ],
      const SizedBox(height: 16),
      FilledButton(onPressed: busy ? null : submit,
        child: Text(mode == 'register' ? 'إرسال رمز التأكيد' : mode == 'verify' ? 'تأكيد البريد والدخول' : mode == 'forgot' ? 'إرسال رابط الاستعادة' : 'دخول')),
      if (mode != 'verify') TextButton(onPressed: busy ? null : () => setState(() { mode = mode == 'register' ? 'login' : 'register'; error = null; }),
        child: Text(mode == 'register' ? 'لدي حساب' : 'إنشاء حساب جديد')),
      if (mode != 'verify') TextButton(onPressed: busy ? null : () => setState(() { mode = mode == 'forgot' ? 'login' : 'forgot'; error = null; }),
        child: Text(mode == 'forgot' ? 'العودة لتسجيل الدخول' : 'نسيت كلمة المرور؟')),
      const Text('يمكنك تصفح التطبيق كزائر دون تسجيل الدخول', textAlign: TextAlign.center),
    ],
  ]);
}
