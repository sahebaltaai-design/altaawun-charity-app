import 'package:flutter/material.dart';

void main() => runApp(const CharityApp());

const forest = Color(0xFF124D43);
const gold = Color(0xFFC99B48);
const background = Color(0xFFF7F5F0);

class CharityApp extends StatelessWidget {
  const CharityApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'جمعية التعاون الخيرية',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(seedColor: forest),
      appBarTheme: const AppBarTheme(backgroundColor: forest, foregroundColor: Colors.white),
    ),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: const CharityHome(),
  );
}

class CharityHome extends StatefulWidget {
  const CharityHome({super.key});
  @override
  State<CharityHome> createState() => _CharityHomeState();
}

class _CharityHomeState extends State<CharityHome> {
  int tab = 0;
  final titles = const ['الرئيسية', 'مدرسة الأيتام', 'الكفالات', 'التبرعات', 'عن الجمعية'];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(titles[tab]), centerTitle: true),
    body: IndexedStack(index: tab, children: [
      _dashboard(),
      _school(),
      _sponsorship(),
      _donations(),
      _about(),
    ]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (index) => setState(() => tab = index),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.school_outlined), label: 'المدرسة'),
        NavigationDestination(icon: Icon(Icons.favorite_outline), label: 'الكفالات'),
        NavigationDestination(icon: Icon(Icons.volunteer_activism_outlined), label: 'تبرع'),
        NavigationDestination(icon: Icon(Icons.info_outline), label: 'الجمعية'),
      ],
    ),
  );

  Widget _dashboard() => ListView(padding: const EdgeInsets.all(18), children: [
    Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [forest, Color(0xFF20705E)]),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.auto_awesome, color: gold, size: 38),
        const SizedBox(height: 18),
        const Text('معًا نرسم مستقبلًا مشرقًا', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        const Text('التعليم والرعاية والكفالة لأطفالنا الأيتام', style: TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black87),
          onPressed: () => setState(() => tab = 2),
          child: const Text('اكتشف برنامج الكفالة'),
        ),
      ]),
    ),
    const SizedBox(height: 26),
    const Text('مجالات العطاء', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    const SizedBox(height: 10),
    _tile(Icons.school_outlined, 'مدرسة الأيتام', 'تعليم ورعاية وتنمية مهارات', 1),
    _tile(Icons.favorite_outline, 'برنامج الكفالة', 'دعم مستمر وكرامة محفوظة', 2),
    _tile(Icons.volunteer_activism_outlined, 'المساهمة بالتبرعات', 'قريبًا عبر بوابة دفع آمنة', 3),
  ]);

  Widget _tile(IconData icon, String title, String subtitle, int index) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(backgroundColor: forest.withValues(alpha: .09), child: Icon(icon, color: forest)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => setState(() => tab = index),
    ),
  );

  Widget _page(IconData icon, String heading, String description, List<Widget> extra) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const SizedBox(height: 16),
      Center(child: CircleAvatar(radius: 43, backgroundColor: forest.withValues(alpha: .10), child: Icon(icon, color: forest, size: 44))),
      const SizedBox(height: 22),
      Text(heading, textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Text(description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.7)),
      const SizedBox(height: 24),
      ...extra,
    ],
  );

  Widget _school() => _page(Icons.school_outlined, 'مدرسة الأيتام',
    'بيئة تعليمية آمنة تدعم الأطفال علميًا وتربويًا وتمنحهم فرصًا أفضل للمستقبل.', [
      _info('البرامج التعليمية', 'ستُعرض البرامج المعتمدة بعد إدخال بيانات المدرسة.'),
      _info('الأنشطة والأخبار', 'ستُنشر الأخبار والأنشطة من لوحة إدارة الجمعية.'),
    ]);

  Widget _sponsorship() => _page(Icons.favorite_outline, 'كفالة الأيتام',
    'ساهم في دعم التعليم والرعاية والاحتياجات الأساسية عبر برنامج كفالة شفاف.', [
      _info('حالات الكفالة', 'ستظهر الحالات بعد اعتمادها من الجمعية. لن تُنشر بيانات الأطفال الحساسة أو صورهم دون موافقات مناسبة.'),
      _info('متابعة الكفالة', 'سيُتاح للكافل متابعة حالة مساهمته بعد بناء نظام الحسابات الآمن.'),
    ]);

  Widget _donations() => _page(Icons.volunteer_activism_outlined, 'التبرعات الإلكترونية',
    'نعمل على تجهيز التبرع من العراق وخارجه باستخدام مزوّد دفع معتمد.', [
      _info('الدفع غير مفعّل حاليًا', 'لن نجمع أرقام البطاقات أو أي بيانات مالية داخل هذه النسخة التجريبية.'),
      _info('الإيصالات', 'ستُضاف إيصالات التبرع وسجل العمليات بعد ربط نظام الدفع.'),
    ]);

  Widget _about() => _page(Icons.info_outline, 'جمعية التعاون الخيرية',
    'نسعى إلى دعم الأيتام ورعايتهم وتعليمهم بالشراكة مع أهل الخير.', [
      _info('الموقع الإلكتروني', 'aytamaliraq.com'),
      _info('تنويه', 'هذه نسخة تطوير أولية، والمحتوى التشغيلي يخضع لاعتماد الجمعية.'),
    ]);

  Widget _info(String title, String detail) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(18), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: forest)),
        const SizedBox(height: 8),
        Text(detail, style: const TextStyle(fontSize: 15, height: 1.6)),
      ],
    )),
  );
}
