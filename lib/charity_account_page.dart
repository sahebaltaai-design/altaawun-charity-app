import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
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
  final verificationCode = TextEditingController();
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
  String? deletionStatus;
  bool? deletionAllowed;
  String? pendingVerificationEmail;
  int resendCountdown = 0;
  Timer? _resendTicker;
  String? verificationNotice;
  bool editingProfile = false;

  void _beginResendCountdown(int seconds) {
    _resendTicker?.cancel();
    if (!mounted) return;
    setState(() => resendCountdown = seconds > 0 ? seconds : 0);
    if (seconds <= 0) return;
    _resendTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (resendCountdown <= 1) {
        timer.cancel();
        setState(() => resendCountdown = 0);
      } else {
        setState(() => resendCountdown--);
      }
    });
  }

  void _fillMemberFields(Map<String, dynamic> data) {
    firstName.text = (data['billing_first_name'] ?? '').toString();
    lastName.text = (data['billing_last_name'] ?? '').toString();
    phone.text = (data['billing_phone'] ?? '').toString();
    state.text = (data['billing_state'] ?? '').toString();
    city.text = (data['billing_city'] ?? '').toString();
    address.text = (data['billing_address_1'] ?? '').toString();
    address2.text = (data['billing_address_2'] ?? '').toString();
    postcode.text = (data['billing_postcode'] ?? '').toString();
    final iso = (data['billing_country'] ?? '').toString();
    final selected = CountryService().findByCode(iso);
    if (selected != null) _selectedCountry = selected;
  }

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
    _resendTicker?.cancel();
    for (final controller in [
      email, password, verificationCode, firstName, lastName, phone,
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
    // Registration and account deletion use dedicated v2 routes to avoid
    // collisions with legacy WordPress callbacks. Neither accepts a role
    // or user ID from the app.
    final uri = (path == 'register' || path == 'register-start' ||
        path == 'register-verify' || path == 'register-resend' ||
        path == 'delete-account' || path == 'account-status')
        ? Uri.parse('https://www.aytamaliraq.com/wp-json/altaawun-app/v2/$path')
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
        'email_unverified': 'يجب تأكيد البريد الإلكتروني قبل تسجيل الدخول.',
        'invalid_code': 'رمز التأكيد غير صحيح. تأكد من الأرقام الستة.',
        'code_expired': 'انتهت صلاحية الرمز. اضغط إعادة إرسال الرمز.',
        'otp_attempts_exceeded': 'محاولات كثيرة للرمز. اطلب رمزًا جديدًا.',
        'otp_cooldown': 'انتظر دقيقة قبل طلب رمز جديد.',
        'email_delivery_failed': 'تعذر إرسال البريد من الموقع. تحقق من إعدادات بريد الجمعية.',
        'missing_registration_field': 'يرجى إكمال بيانات التسجيل المطلوبة.',
        'session_expired': 'انتهت الجلسة، سجل الدخول مرة أخرى',
        'invalid_current_password': 'كلمة المرور الحالية غير صحيحة',
        'invalid_confirmation': 'لم يتم تأكيد طلب حذف الحساب',
        'account_delete_failed': 'تعذر حذف الحساب من الخادم. حاول مجددًا',
        'protected_account': 'الحساب الحالي يمتلك صلاحيات إدارية أو خاصة في WordPress ولا يمكن حذفه من التطبيق. تحقق من دور الحساب في لوحة المستخدمين.',
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
    if (saved == null) {
      final pending = await storage.read(key: 'altaawun_pending_verification_email');
      if (mounted && pending != null && pending.isNotEmpty) {
        setState(() {
          pendingVerificationEmail = pending;
          email.text = pending;
          mode = 'verify';
          verificationNotice = 'أدخل الرمز المرسل إلى بريدك الإلكتروني لإكمال التسجيل.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final result = await api('me', bearer: saved);
      if (mounted) {
        final profile = Map<String, dynamic>.from(result['user'] as Map);
        _fillMemberFields(profile);
        setState(() { token = saved; user = profile; });
      }
      await loadOrders();
    } catch (_) { await storage.delete(key: 'altaawun_token'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _completeLogin(Map<String, dynamic> result) async {
    final received = result['token']?.toString();
    if (received == null || received.isEmpty || result['user'] is! Map) {
      throw Exception('لم يُنشئ الموقع جلسة دخول صالحة.');
    }
    final profile = Map<String, dynamic>.from(result['user'] as Map);
    await storage.write(key: 'altaawun_token', value: received);
    await storage.delete(key: 'altaawun_pending_verification_email');
    _resendTicker?.cancel();
    password.clear();
    verificationCode.clear();
    if (!mounted) return;
    _fillMemberFields(profile);
    setState(() {
      token = received;
      user = profile;
      mode = 'login';
      pendingVerificationEmail = null;
      verificationNotice = null;
      resendCountdown = 0;
      editingProfile = false;
    });
    await loadOrders();
  }

  Future<void> verifyEmail() async {
    if (busy || mode != 'verify') return;
    final pending = pendingVerificationEmail ?? email.text.trim();
    final entered = verificationCode.text.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(entered)) {
      setState(() => error = 'أدخل رمز التأكيد المكون من 6 أرقام.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final result = await api('register-verify',
        body: {'email': pending, 'code': entered});
      if (result['verified'] != true) throw Exception('لم يؤكد الموقع البريد الإلكتروني.');
      await _completeLogin(result);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد البريد الإلكتروني وتفعيل الحساب بنجاح.')));
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resendVerificationCode() async {
    if (busy || mode != 'verify' || resendCountdown > 0) return;
    final pending = pendingVerificationEmail ?? email.text.trim();
    if (pending.isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      await api('register-resend', body: {'email': pending});
      if (!mounted) return;
      setState(() => verificationNotice =
        'إذا كان الحساب بانتظار التحقق، أرسل الموقع رمزًا جديدًا. تحقق من البريد الوارد والرسائل غير المرغوب فيها.');
      _beginResendCountdown(60);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// All address fields are saved to the same WordPress / WooCommerce member.
  /// This action is available after OTP verification and on later logins.
  Future<void> saveProfile() async {
    if (busy || token == null || user == null) return;
    if (firstName.text.trim().isEmpty || lastName.text.trim().isEmpty ||
        state.text.trim().isEmpty || city.text.trim().isEmpty ||
        address.text.trim().isEmpty ||
        !RegExp(r'^[+][1-9][0-9]{7,14}$').hasMatch(_internationalPhone())) {
      setState(() => error = 'أكمل الاسم ورقم الهاتف والمحافظة والمدينة والعنوان الصحيح.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final data = await api('profile', bearer: token, body: {
        'billing_first_name': firstName.text.trim(),
        'billing_last_name': lastName.text.trim(),
        'billing_country': _selectedCountry.countryCode,
        'billing_phone': _internationalPhone(),
        'billing_state': state.text.trim(),
        'billing_city': city.text.trim(),
        'billing_address_1': address.text.trim(),
        'billing_address_2': address2.text.trim(),
        'billing_postcode': postcode.text.trim(),
      });
      if (data['user'] is! Map) throw Exception('لم يتم تأكيد حفظ البيانات على الموقع.');
      final updated = Map<String, dynamic>.from(data['user'] as Map);
      if (!mounted) return;
      _fillMemberFields(updated);
      setState(() {
        user = updated;
        editingProfile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ بياناتك وعنوانك في موقع الجمعية بنجاح.')),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (busy) return;
    if (mode == 'verify') { await verifyEmail(); return; }
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
      final result = await api(current == 'forgot' ? 'forgot-password' :
        current == 'register' ? 'register-start' : current, body: fields);
      if (!mounted) return;
      if (current == 'forgot') {
        setState(() { mode = 'login'; error = 'إذا كان البريد مسجلًا، ستصلك رسالة الاستعادة'; });
      } else if (current == 'register') {
        if (result['verification_required'] != true) {
          throw Exception('لم يطلب الموقع تأكيد البريد. تأكد من تحديث إضافة الحسابات إلى 1.1.14.');
        }
        final pending = (result['email'] ?? email.text.trim()).toString();
        await storage.write(key: 'altaawun_pending_verification_email', value: pending);
        verificationCode.clear();
        password.clear();
        if (!mounted) return;
        setState(() {
          mode = 'verify';
          pendingVerificationEmail = pending;
          verificationNotice = result['email_sent'] == false
              ? 'لم يستطع الموقع إرسال رسالة التحقق. تحقق من بريد WordPress (SMTP)، ثم اضغط إعادة إرسال الرمز.'
              : 'أرسلنا رمزًا من 6 أرقام إلى بريدك. الرمز صالح لمدة 10 دقائق. جميع بياناتك وعنوانك محفوظة بانتظار التأكيد.';
        });
        _beginResendCountdown(result['email_sent'] == false
            ? 0 : ((result['resend_after_seconds'] as num?)?.toInt() ?? 60));
      } else {
        await _completeLogin(result);
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
    if (mounted) setState(() {
      token = null; user = null; orders = []; busy = false; mode = 'login';
      deletionStatus = null; deletionAllowed = null;
    });
  }

  /// Safely diagnose the WordPress account behind this app's Bearer token.
  /// The check never sends a password and cannot modify or delete anything.
  Future<bool> verifyDeletionEligibility() async {
    if (busy || token == null || user == null) return false;
    setState(() { busy = true; deletionStatus = null; deletionAllowed = null; });
    try {
      final info = await api('account-status', bearer: token);
      if (!mounted) return false;
      final currentId = int.tryParse('${user!['id']}');
      final serverId = int.tryParse('${info['account_id']}');
      if (currentId == null || serverId == null || currentId != serverId) {
        setState(() => deletionStatus =
            'تم اكتشاف اختلاف بين الحساب المعروض والحساب المسجل في الخادم. '
            'لم يتم حذف أي شيء. سجّل الخروج ثم ادخل مجددًا.');
        return false;
      }
      final role = (info['role'] ?? 'غير معروف').toString();
      final eligible = info['can_self_delete'] == true;
      setState(() {
        deletionAllowed = eligible;
        deletionStatus = eligible
            ? 'نتيجة الفحص: الخادم يرى الحساب بدور ($role) ويسمح بالحذف. '
              'إذا استمر رفض الحذف فهذا تعارض في مسار الحذف نفسه.'
            : 'نتيجة الفحص: الخادم يرى الحساب بدور ($role) ولا يسمح بحذفه. '
              'قارن هذا الدور مع دور الحساب في WordPress، دون تغيير الصلاحيات.';
      });
      return eligible;
    } catch (e) {
      if (mounted) setState(() => deletionStatus =
          'تعذر فحص صلاحيات الحساب: ${e.toString().replaceFirst('Exception: ', '')}. '
          'لم يتم إجراء أي حذف.');
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteAccount() async {
    if (busy || token == null || user == null) return;
    final currentToken = token!;
    // Confirm the exact user and role the backend sees before the destructive
    // request. This is the same Bearer identity used for account deletion.
    if (!await verifyDeletionEligibility() || !mounted) return;
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
        setState(() {
          error = deletionAllowed == true && message.contains('صلاحيات')
              ? 'تعارض بين فحص الصلاحيات ومسار الحذف: $message'
              : 'لم يُحذف الحساب: $message';
        });
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
      Card(child: ListTile(title: const Text('البريد الإلكتروني'),
        subtitle: Text(user!['email']?.toString() ?? ''))),
      Card(child: ListTile(
        leading: const Icon(Icons.location_on_outlined, color: Color(0xFF075C39)),
        title: const Text('معلوماتي وعنوان الفاتورة'),
        subtitle: Text([
          (user!['billing_phone'] ?? '').toString(),
          (user!['billing_address_1'] ?? '').toString(),
          (user!['billing_city'] ?? '').toString(),
          (user!['billing_state'] ?? '').toString(),
          (user!['billing_country'] ?? '').toString(),
        ].where((entry) => entry.isNotEmpty).join('، ')),
      )),
      OutlinedButton.icon(
        onPressed: busy ? null : () => setState(() {
          _fillMemberFields(user!);
          editingProfile = !editingProfile;
          error = null;
        }),
        icon: const Icon(Icons.edit_outlined),
        label: Text(editingProfile ? 'إغلاق تعديل البيانات' : 'تعديل بياناتي والعنوان'),
      ),
      if (editingProfile) ...[
        const SizedBox(height: 12),
        const Text('يمكنك تصحيح عنوانك أو رقمك بعد تأكيد البريد، وتُحفظ التغييرات في WooCommerce.',
          textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextField(controller: firstName,
          decoration: const InputDecoration(labelText: 'الاسم الأول *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: lastName,
          decoration: const InputDecoration(labelText: 'اسم العائلة *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        InkWell(
          onTap: _selectCountry,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'الدولة ومفتاح الاتصال *',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.arrow_drop_down)),
            child: Text('${_selectedCountry.flagEmoji} ${_selectedCountry.name} (+${_selectedCountry.phoneCode})'),
          ),
        ),
        const SizedBox(height: 10),
        TextField(controller: phone, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'رقم الهاتف *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: state,
          decoration: const InputDecoration(labelText: 'المحافظة / الولاية *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: city,
          decoration: const InputDecoration(labelText: 'المدينة *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: address,
          decoration: const InputDecoration(labelText: 'العنوان *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: address2,
          decoration: const InputDecoration(labelText: 'عنوان إضافي (اختياري)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: postcode,
          decoration: const InputDecoration(labelText: 'الرمز البريدي (اختياري)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : saveProfile,
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ البيانات والعنوان'),
        ),
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
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: busy ? null : deleteAccount,
        icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
        label: const Text('حذف حسابي نهائيًا', style: TextStyle(color: Colors.red)),
      ),
      OutlinedButton.icon(
        onPressed: busy ? null : () { verifyDeletionEligibility(); },
        icon: const Icon(Icons.verified_user_outlined),
        label: const Text('فحص صلاحية حذف الحساب (دون حذف)'),
      ),
      if (deletionStatus != null) Padding(
        padding: const EdgeInsets.all(10),
        child: Text(deletionStatus!, textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF075C39))),
      ),
      const Text(
        'يمكنك حذف حسابك من داخل التطبيق. قد تحتفظ الجمعية بسجلات '
        'التبرعات المطلوبة للمحاسبة وفق سياسة الخصوصية.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ] else ...[
      if (mode == 'verify') ...[
        const Text('تأكيد البريد الإلكتروني',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text('أدخل رمز التحقق المرسل إلى: '
            + (pendingVerificationEmail ?? email.text.trim()),
          textAlign: TextAlign.center),
        const SizedBox(height: 6),
        const Text('الرمز صالح لمدة 10 دقائق. تم حفظ معلومات الاسم والهاتف والعنوان لدى الجمعية حتى تأكيد البريد.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        TextField(
          controller: verificationCode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'رمز التأكيد (6 أرقام)',
            prefixIcon: Icon(Icons.verified_user_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        if (verificationNotice != null) Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(verificationNotice!, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF075C39))),
        ),
        FilledButton.icon(
          onPressed: busy ? null : verifyEmail,
          icon: const Icon(Icons.mark_email_read_outlined),
          label: const Text('تأكيد البريد وتفعيل الحساب'),
        ),
        TextButton(
          onPressed: busy || resendCountdown > 0 ? null : resendVerificationCode,
          child: Text(resendCountdown > 0
              ? 'إعادة إرسال الرمز بعد $resendCountdown ثانية'
              : 'إعادة إرسال رمز التأكيد'),
        ),
        TextButton(
          onPressed: busy ? null : () async {
            await storage.delete(key: 'altaawun_pending_verification_email');
            if (mounted) setState(() {
              mode = 'register';
              pendingVerificationEmail = null;
              verificationNotice = null;
              error = null;
            });
          },
          child: const Text('استخدام بريد إلكتروني آخر'),
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
    ],
  ]);
}
