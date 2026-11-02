import 'package:flutter/material.dart';

void main() => runApp(const AltaawunApp());

const _green = Color(0xFF155D50);
const _gold = Color(0xFFD5AC60);
const _cream = Color(0xFFF8F6F0);

class AltaawunApp extends StatelessWidget {
  const AltaawunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'جمعية التعاون الخيرية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _green),
        scaffoldBackgroundColor: _cream,
        appBarTheme: const AppBarTheme(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selected = 0;

  static const titles = [
    'الرئيسية',
    'مدرسة الأيتام',
    'الكفالات',
    'التبرعات',
    'عن الجمعية',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titles[selected])),
      body: SafeArea(
        child: selected == 0 ? _home() : _section(selected),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (value) => setState(() => selected = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.school_outlined), label: 'المدرسة'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'الكفالات'),
          NavigationDestination(icon: Icon(Icons.volunteer_activism_outlined), label: 'التبرع'),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'الجمعية'),
        ],
      ),
    );
  }

  Widget _home() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _green,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.volunteer_activism, color: _gold, size: 42),
            SizedBox(height: 18),
            Text('جمعية التعاون الخيرية',
                style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('معًا نصنع مستقبلًا أفضل لأطفالنا الأيتام',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Text('خدماتنا', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      _service(Icons.school_outlined, 'مدرسة الأيتام', 'التعليم والرعاية والتطوير', 1),
      _service(Icons.favorite_border, 'كفالة يتيم', 'ساهم في دعم طفل محتاج', 2),
      _service(Icons.volunteer_activism_outlined, 'التبرع', 'شارك في صناعة الأثر', 3),
      _service(Icons.info_outline, 'عن الجمعية', 'تعرف على رسالتنا', 4),
    ],
  );

  Widget _service(IconData icon, String title, String subtitle, int index) =>
      Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: CircleAvatar(
            backgroundColor: _green.withValues(alpha: 0.1),
            child: Icon(icon, color: _green),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => setState(() => selected = index),
        ),
      );

  Widget _section(int index) {
    final descriptions = [
      '',
      'مساحة لعرض برامج المدرسة، الأنشطة التعليمية والأخبار.',
      'ستظهر هنا حالات الكفالة المعتمدة بعد مراجعة الجمعية والموافقات اللازمة لحماية خصوصية الأطفال.',
      'سيُفعّل التبرع الإلكتروني بعد إعداد بوابة دفع آمنة والتحقق من متطلبات التشغيل.',
      'جمعية التعاون الخيرية — لخدمة الأيتام ودعم تعليمهم ورعايتهم.',
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              [Icons.home, Icons.school, Icons.favorite, Icons.volunteer_activism, Icons.info][index],
              size: 72,
              color: _green,
            ),
            const SizedBox(height: 20),
            Text(titles[index], style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(descriptions[index], textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            if (index == 4) ...[
              const SizedBox(height: 16),
              const SelectableText('aytamaliraq.com', style: TextStyle(color: _green)),
            ],
          ],
        ),
      ),
    );
  }
}
