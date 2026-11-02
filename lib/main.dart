import 'package:flutter/material.dart';

void main() => runApp(const AltaawunApp());

const green = Color(0xFF00642D);
const deepGreen = Color(0xFF004521);
const red = Color(0xFFB70922);
const ivory = Color(0xFFF8F8F5);

class AltaawunApp extends StatelessWidget {
  const AltaawunApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'جمعية التعاون الخيرية',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: ivory,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      appBarTheme: const AppBarTheme(backgroundColor: green, foregroundColor: Colors.white, centerTitle: true),
    ),
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox()),
    home: const SplashScreen(),
  );
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(builder: (context, constraints) => Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .43, .74, 1],
            colors: [Color(0xFF79D6F1), Color(0xFFF9FAF1), Color(0xFF80BD7C), deepGreen],
          ),
        )),
        Positioned(top: constraints.maxHeight * .39, left: 0, right: 0,
          height: constraints.maxHeight * .40,
          child: const _SchoolIllustration()),
        Positioned(top: constraints.maxHeight * .67, left: -30, right: -30,
          child: Transform.rotate(angle: -.10, child: Container(
            height: 26, decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [green, Colors.white, red, Colors.white, green]),
            ),
          )),
        ),
        SafeArea(child: Column(children: [
          SizedBox(height: constraints.maxHeight * .07),
          const _Emblem(size: 116),
          const SizedBox(height: 15),
          const FittedBox(fit: BoxFit.scaleDown, child: Text(
            'جمعية التعاون الخيرية',
            style: TextStyle(color: deepGreen, fontSize: 30, fontWeight: FontWeight.w900),
          )),
          const SizedBox(height: 8),
          const Text('مدرسة الأيتام وكفالتهم',
            style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('www.aytamaliraq.com',
            style: TextStyle(color: green, fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CharityShell())),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: deepGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              icon: const Icon(Icons.login),
              label: const Text('الدخول إلى التطبيق',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          )),
          const SizedBox(height: 17),
          const Text('معًا .. نصنع لهم مستقبلًا أفضل',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 26),
        ])),
      ],
    )),
  );
}

class _SchoolIllustration extends StatelessWidget {
  const _SchoolIllustration();
  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned.fill(child: CustomPaint(painter: _SchoolPainter())),
    const Positioned(left: 15, bottom: 22,
      child: Icon(Icons.park, color: Color(0xFF318D45), size: 86)),
    const Positioned(right: 8, bottom: 20,
      child: Icon(Icons.park, color: Color(0xFF318D45), size: 96)),
    const Positioned(left: 55, right: 55, bottom: 8,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        Icon(Icons.backpack, color: Color(0xFF194A75), size: 48),
        Icon(Icons.backpack, color: Color(0xFF194A75), size: 52),
        Icon(Icons.backpack, color: Color(0xFF194A75), size: 46),
        Icon(Icons.backpack, color: Color(0xFF194A75), size: 50),
      ])),
  ]);
}

class _SchoolPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final wall = Paint()..color = const Color(0xFFF0D7AE);
    final outline = Paint()..color = const Color(0xFFCAAC81);
    canvas.drawRect(Rect.fromLTWH(w * .10, h * .20, w * .80, h * .52), wall);
    canvas.drawRect(Rect.fromLTWH(w * .28, h * .11, w * .44, h * .61), wall);
    canvas.drawRect(Rect.fromLTWH(w * .26, h * .10, w * .48, h * .035), outline);
    for (var i = 0; i < 7; i++) {
      final x = w * (.16 + i * .115);
      canvas.drawRect(Rect.fromLTWH(x, h * .33, w * .062, h * .13),
        Paint()..color = const Color(0xFF74B5D0));
    }
    canvas.drawRect(Rect.fromLTWH(w * .44, h * .43, w * .12, h * .29),
      Paint()..color = const Color(0xFF5E8B96));
    canvas.drawRect(Rect.fromLTWH(w * .47, h * .17, w * .06, h * .09),
      Paint()..color = red);
    canvas.drawRect(Rect.fromLTWH(w * .08, h * .71, w * .84, h * .025),
      Paint()..color = const Color(0xFFB9C49C));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Emblem extends StatelessWidget {
  final double size;
  const _Emblem({this.size = 48});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(size * .24),
      border: Border.all(color: green, width: 2),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 12)],
    ),
    child: Icon(Icons.mosque_rounded, size: size * .67, color: red),
  );
}

class CharityShell extends StatefulWidget {
  const CharityShell({super.key});
  @override
  State<CharityShell> createState() => _CharityShellState();
}

class _CharityShellState extends State<CharityShell> {
  int page = 0;
  final names = const ['الرئيسية', 'كفالة الأيتام', 'المدرسة والتعليم', 'التبرعات والمساهمات', 'الأخبار والأنشطة', 'الصور والفيديوهات', 'عن الجمعية'];
  void go(int value) => setState(() => page = value);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer())),
      title: page == 0 ? const Column(children: [
        Text('جمعية التعاون الخيرية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Text('مدرسة الأيتام وكفالتهم', style: TextStyle(fontSize: 11)),
      ]) : Text(names[page], style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      actions: page == 0 ? [const Padding(padding: EdgeInsets.all(6), child: _Emblem(size: 40))] : null,
    ),
    drawer: Drawer(child: SafeArea(child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(24), color: green,
        child: const Column(children: [_Emblem(size: 76), SizedBox(height: 12),
          Text('جمعية التعاون الخيرية', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold))])),
      Expanded(child: ListView(children: [
        for (var i = 0; i < names.length; i++)
          ListTile(
            leading: Icon(_icons[i], color: green), title: Text(names[i]),
            onTap: () { Navigator.pop(context); go(i); },
          ),
      ])),
    ]))),
    body: page == 0 ? _home() : _section(),
    bottomNavigationBar: NavigationBar(
      height: 72,
      selectedIndex: [0, 1, 4, 3, 6].indexOf(page) < 0 ? 0 : [0, 1, 4, 3, 6].indexOf(page),
      onDestinationSelected: (index) => go([0, 1, 4, 3, 6][index]),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.favorite_border), label: 'تبرع'),
        NavigationDestination(icon: Icon(Icons.article_outlined), label: 'الأخبار'),
        NavigationDestination(icon: Icon(Icons.volunteer_activism_outlined), label: 'المزيد'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
      ],
    ),
  );

  static const _icons = [
    Icons.home, Icons.favorite, Icons.school, Icons.volunteer_activism,
    Icons.article, Icons.photo_library, Icons.menu_book,
  ];

  Widget _home() => ListView(padding: const EdgeInsets.all(12), children: [
    Container(
      height: 230, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF00542B), Color(0xFF087D3D)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Spacer(),
        const Text('بكفالتك\nنمنحهم\nمستقبلًا أفضل',
          style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w900, height: 1.25)),
        const Spacer(),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
          onPressed: () => go(1), icon: const Icon(Icons.favorite_border), label: const Text('كفالة يتيم'),
        ),
      ]),
    ),
    const SizedBox(height: 14),
    GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3, mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: .95,
      children: [
        _shortcut(Icons.school, 'المدرسة\nوالتعليم', 2),
        _shortcut(Icons.groups, 'كفالة الأيتام', 1),
        _shortcut(Icons.volunteer_activism, 'التبرعات\nوالمساهمات', 3, color: red),
        _shortcut(Icons.photo_library, 'الصور\nوالفيديوهات', 5),
        _shortcut(Icons.article, 'الأخبار\nوالأنشطة', 4, color: red),
        _shortcut(Icons.menu_book, 'عن الجمعية', 6),
      ],
    ),
    const SizedBox(height: 20),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('أحدث الأخبار', style: TextStyle(color: deepGreen, fontSize: 21, fontWeight: FontWeight.w900)),
      TextButton(onPressed: () => go(4), child: const Text('عرض الكل')),
    ]),
    Card(child: ListTile(
      leading: const Icon(Icons.article, color: green, size: 35),
      title: const Text('أخبار وأنشطة الجمعية', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('ستظهر آخر الأخبار المنشورة بعد ربط الموقع'),
      onTap: () => go(4),
    )),
  ]);

  Widget _shortcut(IconData icon, String title, int destination, {Color color = green}) =>
    Material(color: Colors.white, borderRadius: BorderRadius.circular(14),
      child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => go(destination),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(height: 9),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ])));

  Widget _section() {
    final descriptions = [
      '',
      'كن سببًا في سعادة يتيم. الكفالة ليست مالًا فقط، بل هي رعاية واهتمام ومستقبل مشرق.',
      'نوفر لأبنائنا بيئة تعليمية آمنة ومتكاملة لبناء مستقبلهم.',
      'ساهم في دعم برامج الجمعية عبر وسائل تبرع موثوقة.',
      'تابع آخر الأخبار والأنشطة والمبادرات.',
      'صور وفيديوهات أنشطة المدرسة والجمعية.',
      'جمعية التعاون الخيرية — مدرسة الأيتام وكفالتهم.',
    ];
    return ListView(padding: const EdgeInsets.all(18), children: [
      Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [deepGreen, green]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(child: Icon(_icons[page], size: 85, color: Colors.white)),
      ),
      const SizedBox(height: 18),
      Text(names[page], textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 25, color: deepGreen, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      Text(descriptions[page], textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.7)),
      const SizedBox(height: 18),
      if (page == 1) ...[
        _feature(Icons.description_outlined, 'تقرير دوري عن حالة اليتيم'),
        _feature(Icons.auto_stories_outlined, 'متابعة تطوره الدراسي'),
        _feature(Icons.shield_outlined, 'خصوصية وأمان بيانات الأطفال'),
        const SizedBox(height: 8),
        _disabledAction('كفالة الآن — قريبًا'),
      ] else if (page == 2) ...[
        _feature(Icons.menu_book, 'مناهج دراسية'),
        _feature(Icons.groups, 'أنشطة طلابية'),
        _feature(Icons.school, 'المرافق والمدرسون'),
        _feature(Icons.photo_library, 'الصور والفيديوهات'),
      ] else if (page == 3) ...[
        _feature(Icons.lock_outline, 'سيُربط الدفع ببوابة آمنة بعد اعتمادها'),
        _disabledAction('التبرع الإلكتروني — قريبًا'),
      ] else if (page == 6) ...[
        _feature(Icons.language, 'www.aytamaliraq.com'),
      ] else ...[
        _feature(Icons.info_outline, 'سيظهر المحتوى المعتمد بعد ربط لوحة إدارة الجمعية'),
      ],
    ]);
  }

  Widget _feature(IconData icon, String text) => Card(
    child: ListTile(leading: Icon(icon, color: green), title: Text(text)),
  );
  Widget _disabledAction(String text) => FilledButton(
    onPressed: null, child: Padding(padding: const EdgeInsets.all(10), child: Text(text)),
  );
}
