import 'package:shared_preferences/shared_preferences.dart';
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
        Image.asset(
          'assets/welcome_background-2.png',
          fit: BoxFit.fill,
          errorBuilder: (_, __, ___) => const ColoredBox(color: deepGreen),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const CharityShell())),
                    icon: const Icon(Icons.login, size: 27),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('الدخول إلى التطبيق',
                        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00652A),
                      foregroundColor: Colors.white,
                      elevation: 6,
                      side: const BorderSide(color: Color(0xFFFFD66A), width: 2.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(36)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003B1D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD66A), width: 1),
                  ),
                  child: const Text(
                    'معًا .. نصنع لهم مستقبلًا أفضل',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
    child: ClipRRect(borderRadius: BorderRadius.circular(size * .22), child: Image.asset('assets/welcome_background-2.png', fit: BoxFit.cover, alignment: const Alignment(0, -.82), errorBuilder: (_, __, ___) => Icon(Icons.volunteer_activism, size: size * .67, color: red))),
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
  static const _defaultCategoryOrder = [2, 1, 3, 5, 4, 6];
  static const _categoryLabels = {
    2: 'المدرسة والتعليم', 1: 'كفالة الأيتام',
    3: 'التبرعات والمساهمات', 5: 'الصور والفيديوهات',
    4: 'الأخبار والأنشطة', 6: 'عن الجمعية',
  };
  static const _categoryIcons = {
    2: Icons.school, 1: Icons.groups, 3: Icons.volunteer_activism,
    5: Icons.photo_library, 4: Icons.article, 6: Icons.menu_book,
  };
  List<int> categoryOrder = List.of(_defaultCategoryOrder);
  Set<int> hiddenCategories = {};
  Map<int, String> customCategories = {};
  int? customPage;
  String _labelFor(int id) => customCategories[id] ?? _categoryLabels[id] ?? 'تصنيف';

  @override
  void initState() {
    super.initState();
    _loadCategorySettings();
  }

  Future<void> _loadCategorySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('home_category_order');
    final parsed = savedOrder?.map(int.tryParse).whereType<int>().toList();
    final savedHidden = prefs.getStringList('home_category_hidden') ?? [];
    final savedCustom = prefs.getStringList('home_custom_categories') ?? [];
    final custom = <int, String>{};
    for (final item in savedCustom) {
      final separator = item.indexOf('|');
      if (separator < 0) continue;
      final id = int.tryParse(item.substring(0, separator));
      final name = item.substring(separator + 1).trim();
      if (id != null && id >= 100 && name.isNotEmpty) custom[id] = name;
    }
    if (!mounted) return;
    setState(() {
      customCategories = custom;
      final valid = {..._defaultCategoryOrder, ...custom.keys};
      if (parsed != null && parsed.toSet().length == parsed.length &&
          parsed.toSet().containsAll(valid) && valid.containsAll(parsed)) {
        categoryOrder = parsed;
      } else {
        categoryOrder = [..._defaultCategoryOrder, ...custom.keys];
      }
      hiddenCategories = savedHidden.map(int.tryParse).whereType<int>()
          .where(valid.contains).toSet();
    });
  }

  Future<void> _saveCategorySettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('home_category_order',
        categoryOrder.map((id) => '$id').toList());
    await prefs.setStringList('home_category_hidden',
        hiddenCategories.map((id) => '$id').toList());
    await prefs.setStringList('home_custom_categories',
        customCategories.entries.map((e) => '${e.key}|${e.value}').toList());
  }

  Future<void> _addCategory(StateSetter refreshSheet) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة تصنيف جديد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(hintText: 'اسم التصنيف'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('إضافة')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null || name.isEmpty) return;
    final id = customCategories.keys.fold<int>(99, (max, x) => x > max ? x : max) + 1;
    refreshSheet(() {
      customCategories[id] = name;
      categoryOrder.add(id);
    });
    setState(() {});
    await _saveCategorySettings();
  }

  void _openCustomCategory(int id) {
    setState(() { customPage = id; page = 0; });
  }

  void _manageCategories() {
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refreshSheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .76,
            child: Column(children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('إدارة تصنيفات الصفحة الرئيسية',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const Text('اسحب علامة الترتيب، أو أخفِ التصنيف بالمفتاح'),
              TextButton.icon(
                onPressed: () => _addCategory(refreshSheet),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('إضافة تصنيف جديد'),
              ),
              Expanded(child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: categoryOrder.length,
                onReorder: (oldIndex, newIndex) {
                  refreshSheet(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = categoryOrder.removeAt(oldIndex);
                    categoryOrder.insert(newIndex, item);
                  });
                  setState(() {});
                  _saveCategorySettings();
                },
                itemBuilder: (context, index) {
                  final id = categoryOrder[index];
                  return ListTile(
                    key: ValueKey(id),
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, color: green)),
                    title: Text(_labelFor(id)),
                    subtitle: customCategories.containsKey(id) ? const Text('تصنيف مخصص') : null,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (customCategories.containsKey(id))
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: red),
                          onPressed: () {
                            refreshSheet(() {
                              categoryOrder.remove(id);
                              customCategories.remove(id);
                              hiddenCategories.remove(id);
                            });
                            setState(() {});
                            _saveCategorySettings();
                          },
                        ),
                      Switch(
                      value: !hiddenCategories.contains(id),
                      onChanged: (visible) {
                        refreshSheet(() {
                          if (visible) {
                            hiddenCategories.remove(id);
                          } else {
                            hiddenCategories.add(id);
                          }
                        });
                        setState(() {});
                        _saveCategorySettings();
                      },
                    ),
                    ]),
                  );
                },
              )),
              Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                TextButton(
                  onPressed: () {
                    refreshSheet(() {
                      categoryOrder = [..._defaultCategoryOrder, ...customCategories.keys];
                      hiddenCategories.clear();
                    });
                    setState(() {});
                    _saveCategorySettings();
                  },
                  child: const Text('استعادة الترتيب الافتراضي'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('تم'),
                ),
              ])),
            ]),
          ),
        ),
      ),
    );
  }

  void go(int value) => setState(() { page = value; customPage = null; });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 86,
      backgroundColor: Colors.white,
      foregroundColor: deepGreen,
      leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer())),
      title: page == 0 ? const Column(mainAxisSize: MainAxisSize.min, children: [
        _Emblem(size: 38),
        Text('جمعية التعاون الخيرية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        Text('مدرسة الأيتام وكفالتهم', style: TextStyle(fontSize: 10)),
      ]) : Text(names[page], style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      actions: page == 0 ? [IconButton(onPressed: () {}, icon: const Badge(label: Text('3'), child: Icon(Icons.notifications, color: green)))] : null,
    ),
    drawer: Drawer(child: SafeArea(child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(24), color: green,
        child: const Column(children: [_Emblem(size: 76), SizedBox(height: 12),
          Text('جمعية التعاون الخيرية', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold))])),
      ListTile(
        leading: const Icon(Icons.tune, color: green),
        title: const Text('إدارة التصنيفات'),
        subtitle: const Text('ترتيب وإظهار وإخفاء أقسام الصفحة الرئيسية'),
        onTap: () { Navigator.pop(context); _manageCategories(); },
      ),
      Expanded(child: ListView(children: [
        for (var i = 0; i < names.length; i++)
          ListTile(
            leading: Icon(_icons[i], color: green), title: Text(names[i]),
            onTap: () { Navigator.pop(context); go(i); },
          ),
      ])),
    ]))),
    body: customPage != null ? _customSection(customPage!) : page == 0 ? _home() : _section(),
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

  Widget _customSection(int id) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      TextButton.icon(
        onPressed: () => go(0),
        icon: const Icon(Icons.arrow_forward),
        label: const Text('العودة إلى الرئيسية'),
      ),
      const SizedBox(height: 30),
      const Icon(Icons.folder_open, size: 86, color: green),
      const SizedBox(height: 18),
      Text(_labelFor(id), textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: deepGreen)),
      const SizedBox(height: 12),
      const Text('هذا التصنيف جاهز للعرض. يمكن ربط محتواه لاحقًا بموقع الجمعية.',
          textAlign: TextAlign.center),
    ],
  );

  Widget _home() => ListView(padding: EdgeInsets.zero, children: [
    SizedBox(height: 260, child: Stack(fit: StackFit.expand, children: [
      Image.asset(
        'assets/home_hero.jpg',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF194B2F), Color(0xFF00642D)]))),
      ),
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [Colors.transparent, Color(0xE8004C29)]))),
      Positioned(top: 28, right: 18, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('بكفالتك\nنمنحهم\nمستقبلًا أفضل',
            style: TextStyle(fontSize: 29, color: Colors.white, fontWeight: FontWeight.w900, height: 1.3)),
        ],
      )),
      Positioned(bottom: 18, right: 18, child: FilledButton.icon(
        onPressed: () => go(1),
        style: FilledButton.styleFrom(backgroundColor: green, side: const BorderSide(color: Colors.white)),
        icon: const Icon(Icons.favorite_border), label: const Text('كفالة يتيم',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      )),
    ])),
    Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      GridView.count(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3, mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: .93,
        children: [
          for (final id in categoryOrder)
            if (!hiddenCategories.contains(id))
              _shortcut(_categoryIcons[id] ?? Icons.folder_outlined, _labelFor(id), id,
                  color: (id == 3 || id == 4) ? red : green),
        ],
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('أحدث الأخبار', style: TextStyle(color: deepGreen, fontSize: 22, fontWeight: FontWeight.w900)),
        TextButton(onPressed: () => go(4), child: const Text('عرض الكل')),
      ]),
      Card(child: ListTile(
        leading: const Icon(Icons.article, color: green, size: 35),
        title: const Text('أخبار وأنشطة الجمعية', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('تابع أحدث أخبار وأنشطة الجمعية'),
        onTap: () => go(4),
      )),
    ])),
  ]);

  Widget _shortcut(IconData icon, String title, int destination, {Color color = green}) =>
    Material(color: Colors.white, borderRadius: BorderRadius.circular(14),
      child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => destination >= 100 ? _openCustomCategory(destination) : go(destination),
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
