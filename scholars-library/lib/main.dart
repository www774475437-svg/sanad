import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const ScholarsApp());
}

// ألوان الهوية: ورق دافئ وبنّي محروق
const Color kBg = Color(0xFFF7F4EE);
const Color kCard = Color(0xFFF0ECE4);
const Color kLine = Color(0xFFE0D9CC);
const Color kInk = Color(0xFF1E1B16);
const Color kMuted = Color(0xFF7B746A);
const Color kAccent = Color(0xFF8C4A2F);

class Scholar {
  final String name;
  const Scholar(this.name);
}

// قائمة العلماء في الدفعة الأولى (تُضاف كتبهم لاحقًا من تراث)
const List<Scholar> kScholars = [
  Scholar('ابن القيم'),
  Scholar('ابن تيمية'),
  Scholar('ابن رجب'),
  Scholar('مقبل الوادعي'),
  Scholar('ابن عثيمين'),
  Scholar('ابن باز'),
  Scholar('صالح الفوزان'),
  Scholar('الألباني'),
];

class ScholarsApp extends StatelessWidget {
  const ScholarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مكتبة العلماء السلفية',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kAccent, surface: kBg),
        scaffoldBackgroundColor: kBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          foregroundColor: kInk,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<String> _titles = [
    'مكتبة العلماء السلفية',
    'البحث',
    'الكتب الصوتية',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: const [
          ScholarsTab(),
          PlaceholderTab(text: 'البحث في كتب جميع العلماء سيُضاف في الدفعة القادمة.'),
          PlaceholderTab(text: 'الكتب الصوتية ستُضاف لاحقًا.'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'العلماء',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'البحث',
          ),
          NavigationDestination(
            icon: Icon(Icons.headphones_outlined),
            label: 'الصوتيات',
          ),
        ],
      ),
    );
  }
}

class ScholarsTab extends StatelessWidget {
  const ScholarsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: kScholars.length,
      itemBuilder: (context, i) {
        final scholar = kScholars[i];
        return Card(
          color: kCard,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: const BorderSide(color: kLine),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text(
              scholar.name,
              style: const TextStyle(fontWeight: FontWeight.w700, color: kInk, fontSize: 18),
            ),
            trailing: const Icon(Icons.chevron_left, color: kMuted),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ScholarPage(scholar: scholar)),
              );
            },
          ),
        );
      },
    );
  }
}

class ScholarPage extends StatelessWidget {
  final Scholar scholar;
  const ScholarPage({super.key, required this.scholar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(scholar.name)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'كتب ${scholar.name} ستظهر هنا بعد إضافتها من تراث.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted, height: 1.8, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class PlaceholderTab extends StatelessWidget {
  final String text;
  const PlaceholderTab({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kMuted, height: 1.8, fontSize: 16),
        ),
      ),
    );
  }
}
