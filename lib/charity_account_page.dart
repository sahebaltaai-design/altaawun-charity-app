import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class CharityAccountPage extends StatefulWidget {
  final int? cartCount;
  final VoidCallback onOpenCart;
  final VoidCallback? onSignedIn;
  const CharityAccountPage({super.key, required this.cartCount, required this.onOpenCart, this.onSignedIn});
  @override
  State<CharityAccountPage> createState() => _AccountState();
}

class _AccountState extends State<CharityAccountPage> {
  static const base = 'https://www.aytamaliraq.com/wp-json/altaawun-app/v1/';
  static const storage = FlutterSecureStorage();
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final customDialCode = TextEditingController();
  String dialCode = '+964';

  static const Map<String, String> countryDialCodes = {
    '+964': '🇮🇶 العراق (+964)',
    '+1': '🇺🇸 أمريكا وكندا (+1)',
    '+44': '🇬🇧 بريطانيا (+44)',
    '+966': '🇸🇦 السعودية (+966)',
    '+971': '🇦🇪 الإمارات (+971)',
    '+965': '🇰🇼 الكويت (+965)',
    '+974': '🇶🇦 قطر (+974)',
    '+973': '🇧🇭 البحرين (+973)',
    '+968': '🇴🇲 عُمان (+968)',
    '+962': '🇯🇴 الأردن (+962)',
    '+961': '🇱🇧 لبنان (+961)',
    '+963': '🇸🇾 سوريا (+963)',
    '+970': '🇵🇸 فلسطين (+970)',
    '+20': '🇪🇬 مصر (+20)',
    '+98': '🇮🇷 إيران (+98)',
    '+90': '🇹🇷 تركيا (+90)',
    '+49': '🇩🇪 ألمانيا (+49)',
    '+33': '🇫🇷 فرنسا (+33)',
    '+39': '🇮🇹 إيطاليا (+39)',
    '+46': '🇸🇪 السويد (+46)',
    '+61': '🇦🇺 أستراليا (+61)',
    'other': '🌐 دولة أخرى (إدخال المفتاح)',
  };

  String? normalizedPhone() {
    final prefix = (dialCode == 'other' ? customDialCode.text : dialCode).trim();
    if (!RegExp(r'^\+[1-9][0-9]{0,3}$').hasMatch(prefix)) return null;
    var local = phone.text.trim().replaceAll(RegExp(r'[\s().-]'), '');
    if (!RegExp(r'^[0-9]+$').hasMatch(local)) return null;
    if (prefix == '+964' && local.startsWith('0')) local = local.substring(1);
    final full = prefix + local;
    // Basic E.164 format check, not verification of phone ownership.
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(full)) return null;
    return full;
  }
  final otpCode = TextEditingController();
  static const googleWebClientId = String.fromEnvironment('ALTAWUN_GOOGLE_WEB_CLIENT_ID');
  static const googleIosClientId = String.fromEnvironment('ALTAWUN_GOOGLE_IOS_CLIENT_ID');
  bool supportsEmailOtp = false;
  bool supportsGoogleLogin = false;
  bool googleInitialized = false;
  String? pendingEmail;
  String? token, error;
  Map<String, dynamic>? user;
  List<dynamic> orders = [];
  String mode = 'login';
  bool busy = false;

  @override
  void initState() { super.initState(); restore(); checkAuthCapabilities(); }
  @override
  void dispose() { email.dispose(); password.dispose(); name.dispose(); phone.dispose(); customDialCode.dispose(); otpCode.dispose(); super.dispose(); }

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
        'invalid_code': 'رمز التحقق غير صحيح',
        'code_expired': 'انتهت صلاحية الرمز. اطلب رمزًا جديدًا',
        'email_delivery_failed': 'تعذر إرسال البريد. تحقق من إعدادات بريد الموقع',
        'email_unverified': 'يجب تأكيد البريد الإلكتروني أولًا',
      };
      throw Exception(messages[code] ?? 'فشل الاتصال: ' + response.statusCode.toString());
    }
    if (decoded is! Map) throw Exception('استجابة غير متوقعة');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> checkAuthCapabilities() async {
    try {
      final data = await api('auth-capabilities');
      if (!mounted) return;
      setState(() {
        supportsEmailOtp = data['email_otp'] == true;
        supportsGoogleLogin = data['google_login'] == true && googleWebClientId.isNotEmpty;
      });
    } catch (_) {
      // Keep the existing working email/password flow while the new WordPress
      // extension is not installed or configured.
    }
  }

  Future<void> saveSession(Map<String, dynamic> result) async {
    final received = result['token']?.toString();
    if (received == null || received.isEmpty || result['user'] is! Map) {
      throw Exception('جلسة غير صالحة');
    }
    await storage.write(key: 'altaawun_token', value: received);
    password.clear();
    otpCode.clear();
    if (!mounted) return;
    setState(() {
      token = received;
      user = Map<String, dynamic>.from(result['user'] as Map);
      mode = 'login';
      pendingEmail = null;
    });
    await loadOrders();
    widget.onSignedIn?.call();
  }

  Future<void> googleLogin() async {
    if (busy || googleWebClientId.isEmpty || !supportsGoogleLogin) return;
    setState(() { busy = true; error = null; });
    try {
      final signIn = GoogleSignIn.instance;
      if (!googleInitialized) {
        await signIn.initialize(
          serverClientId: googleWebClientId,
          clientId: googleIosClientId.isEmpty ? null : googleIosClientId,
        );
        googleInitialized = true;
      }
      if (!signIn.supportsAuthenticate()) {
        throw Exception('تسجيل Google غير مدعوم على هذا الجهاز');
      }
      final googleAccount = await signIn.authenticate();
      final idToken = googleAccount.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('تعذر التحقق من حساب Google');
      }
      // The WordPress endpoint MUST validate Google's signed token, audience,
      // issuer and expiration, then issue the SAME token format as email login.
      final result = await api('google-login', body: {'id_token': idToken});
      await saveSession(result);
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر دخول Google: ' + e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verifyEmail() async {
    if (busy || pendingEmail == null || !RegExp(r'^\d{6}$').hasMatch(otpCode.text.trim())) {
      setState(() => error = 'أدخل رمز التحقق المكون من 6 أرقام');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await api('register-verify', body: {
        'email': pendingEmail!, 'code': otpCode.text.trim()
      });
      // Use existing WordPress-issued app credentials for WooCommerce/session
      // compatibility; verification never creates a separate account.
      final result = await api('login', body: {
        'login': pendingEmail!, 'password': password.text
      });
      await saveSession(result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resendCode() async {
    if (busy || pendingEmail == null) return;
    setState(() { busy = true; error = null; });
    try {
      await api('register-resend', body: {'email': pendingEmail!});
      if (mounted) setState(() => error = 'إذا كان الحساب بانتظار التحقق، أرسلنا رمزًا جديدًا إلى بريدك.');
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
    if (email.text.trim().isEmpty || (mode != 'forgot' && password.text.isEmpty) ||
        (mode == 'register' && (name.text.trim().isEmpty || password.text.length < 12))) {
      setState(() => error = 'أكمل البيانات المطلوبة؛ كلمة مرور التسجيل 12 حرفًا على الأقل');
      return;
    }
    if (mode == 'register' && normalizedPhone() == null) {
      setState(() => error = 'أدخل رقم الهاتف مع مفتاح الدولة الدولي بشكل صحيح (إلزامي).');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final current = mode;
      final fields = current == 'forgot' ? {'email': email.text.trim()} :
        current == 'register' ? {
          'email': email.text.trim(), 'password': password.text,
          'name': name.text.trim(), 'phone': normalizedPhone()!
        } : {'login': email.text.trim(), 'password': password.text};
      final route = current == 'forgot' ? 'forgot-password'
          : current == 'register' && supportsEmailOtp ? 'register-start' : current;
      final result = await api(route, body: fields);
      if (!mounted) return;
      if (current == 'forgot') {
        setState(() { mode = 'login'; error = 'إذا كان البريد مسجلًا، ستصلك رسالة الاستعادة'; });
      } else if (current == 'register' && supportsEmailOtp) {
        setState(() {
          pendingEmail = email.text.trim();
          mode = 'verify';
          otpCode.clear();
          error = 'أرسلنا رمز تأكيد من 6 أرقام إلى بريدك. صلاحيته 10 دقائق.';
        });
      } else {
        await saveSession(result);
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
      Text(mode == 'verify' ? 'تأكيد البريد الإلكتروني' : mode == 'register' ? 'إنشاء حساب جديد' : mode == 'forgot' ? 'استعادة كلمة المرور' : 'تسجيل الدخول',
        textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (mode == 'register') ...[
        TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: dialCode,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'مفتاح الدولة الدولي *', border: OutlineInputBorder(),
          ),
          items: countryDialCodes.entries.map((entry) =>
            DropdownMenuItem<String>(value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (value) {
            if (value != null) setState(() => dialCode = value);
          },
        ),
        const SizedBox(height: 12),
        if (dialCode == 'other') ...[
          TextField(
            controller: customDialCode,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'مفتاح الاتصال الدولي (مثال +212) *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          decoration: const InputDecoration(
            labelText: 'رقم الهاتف بدون مفتاح الدولة *',
            hintText: 'مثال للعراق: 07701234567',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (mode == 'verify') ...[
        Text('أرسلنا رمز التحقق إلى ${pendingEmail ?? ''}', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextField(controller: otpCode, textAlign: TextAlign.center,
          keyboardType: TextInputType.number, maxLength: 6,
          decoration: const InputDecoration(labelText: 'رمز التحقق (6 أرقام)', border: OutlineInputBorder())),
        FilledButton(onPressed: busy ? null : verifyEmail, child: const Text('تأكيد البريد وإكمال الدخول')),
        TextButton(onPressed: busy ? null : resendCode, child: const Text('إعادة إرسال الرمز')),
        TextButton(onPressed: busy ? null : () => setState(() { mode = 'register'; error = null; }),
          child: const Text('تصحيح البريد الإلكتروني')),
      ] else ...[
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
      if (supportsGoogleLogin && mode != 'forgot') ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : googleLogin,
          icon: const Icon(Icons.account_circle_outlined),
          label: const Text('المتابعة باستخدام Google'),
        ),
      ],
      const Text('يمكنك تصفح التطبيق كزائر دون تسجيل الدخول', textAlign: TextAlign.center),
      ],
    ],
  ]);
}