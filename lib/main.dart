// =====================================================================
//  سَنَد — الإصدار الأول (المرحلة الأولى)
//  كلام الشيخ ابن عثيمين رَحِمَهُ الله بنصّه ومصدره من «تراث»
//  المطوّر: أبو عبد الرحمن الأثري
//
//  هذا الإصدار لا يستعمل الذكاء الاصطناعي ولا يحتاج أي إعداد:
//  يبحث مباشرة في كتب الشيخ الستة على موقع «تراث» وينقل النص كما هو.
// =====================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'norm.dart';
import 'store_stub.dart' if (dart.library.io) 'store_io.dart';

part 'books.dart';
part 'extras.dart';

// ---------------------------------------------------------------------
//  الإعدادات الثابتة
// ---------------------------------------------------------------------

const String kAppName = 'سَنَد';
const String kVersion = '1.3.0';
const int kAuthorId = 57;
const int kBuild = int.fromEnvironment('BUILD', defaultValue: 0);
const String kSiteUrl = 'https://www774475437-svg.github.io/sanad/';
const String kApkUrl =
    'https://github.com/www774475437-svg/sanad/releases/latest/download/sanad.apk';
const String kReleasesApi =
    'https://api.github.com/repos/www774475437-svg/sanad/releases/latest';

/// مسائل مقترحة (عبارات بحث فقط، والجواب من كلام الشيخ نفسه).
const List<String> kTopics = [
  'ما حكم النمص؟',
  'حكم تارك الصلاة',
  'زكاة الحلي',
  'دم الحيض',
  'حكم حلق اللحية',
  'حكم الإسبال',
  'حكم الغناء والمعازف',
  'حكم التصوير',
  'نواقض الإسلام',
  'حكم السحر والسحرة',
  'حكم الذبح لغير الله',
  'حكم التوسل',
  'شروط لا إله إلا الله',
  'حكم الصلاة في المقبرة',
  'حكم الاحتفال بالمولد',
  'حكم صلاة الجماعة',
  'حكم الصلاة بعد العصر',
  'الدماء الطبيعية للنساء',
  'حكم زكاة المال',
  'حكم الربا',
  'حكم التدخين',
  'حكم الحلف بغير الله',
  'أنواع التوحيد',
  'حكم القنوت في الفجر',
  'حكم قراءة القرآن للحائض',
  'حكم الجمع بين الصلاتين',
];

/// موضوعات عامة للاختيار السريع.
const List<String> kTopicChips = [
  'الصلاة',
  'الزكاة',
  'الصيام',
  'الحج',
  'الطهارة',
  'النكاح',
  'التوحيد',
  'الدماء',
];
const String kDeveloper = 'أبو عبد الرحمن الأثري';
const String kTelegram = 'https://t.me/alhsaar4';
const String kScholarIntro = 'قال الشيخ ابن عثيمين رَحِمَهُ الله:';
const String kScholarAgain = 'وقال أيضًا رَحِمَهُ الله:';
const Color kBrand = Color(0xFF0F5F57);
const Color kGold = Color(0xFFC9A227);
const Color kHighlight = Color(0xFFFFF176);

class Book {
  final int id;
  final String title;
  final int pages;
  final int size;
  final int cat;
  const Book(this.id, this.title, {this.pages = 0, this.size = 0, this.cat = 0});
}

Book? bookOf(int id) {
  for (final b in kBooks) {
    if (b.id == id) return b;
  }
  return null;
}

String bookTitleOf(int id) {
  for (final b in kBooks) {
    if (b.id == id) return b.title;
  }
  return '';
}

// ---------------------------------------------------------------------
//  النماذج
// ---------------------------------------------------------------------

class Quote {
  final int bookId;
  final String bookName;
  final String vol;
  final String page;
  final int pageId;
  final String text;
  final String issue;
  final String title; // عنوان المسألة في الكتاب (إن عُرف)

  const Quote({
    required this.bookId,
    required this.bookName,
    required this.vol,
    required this.page,
    required this.pageId,
    required this.text,
    this.issue = '',
    this.title = '',
  });

  /// العنوان الذي يُعرض فوق النقل.
  String get heading => title.isNotEmpty ? title : issue;

  Quote copyWith({String? text, String? title}) => Quote(
        bookId: bookId,
        bookName: bookName,
        vol: vol,
        page: page,
        pageId: pageId,
        text: text ?? this.text,
        issue: issue,
        title: title ?? this.title,
      );

  String get pageLabel {
    final v = vol.trim();
    final p = page.trim();
    if (p.isEmpty) return v;
    if (v.isEmpty || v == '0') return p;
    return '$v/$p';
  }

  String get turathUrl => pageId > 0
      ? 'https://app.turath.io/book/$bookId/$pageId'
      : 'https://app.turath.io/book/$bookId';

  String get key {
    final head = text.length > 40 ? text.substring(0, 40) : text;
    return '$bookId:$pageId:$head';
  }

  Quote withIssue(String newIssue) => Quote(
        bookId: bookId,
        bookName: bookName,
        vol: vol,
        page: page,
        pageId: pageId,
        text: text,
        issue: newIssue,
        title: title,
      );

  Map<String, dynamic> toJson() => {
        'b': bookId,
        'n': bookName,
        'v': vol,
        'p': page,
        'pid': pageId,
        't': text,
        'i': issue,
        if (title.isNotEmpty) 'h': title,
      };

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        bookId: asInt(j['b']),
        bookName: asStr(j['n']),
        vol: asStr(j['v']),
        page: asStr(j['p']),
        pageId: asInt(j['pid']),
        text: asStr(j['t']),
        issue: asStr(j['i']),
        title: asStr(j['h']),
      );
}

class ChatMessage {
  final bool fromUser;
  final String text; // سؤال المستخدم، أو رد السلام
  final List<Quote> quotes;
  final String notice; // مثل: لم أجد للشيخ كلامًا
  final String issue;
  final List<String> terms; // كلمات البحث التي استُعملت

  ChatMessage({
    required this.fromUser,
    this.text = '',
    List<Quote>? quotes,
    this.notice = '',
    this.issue = '',
    List<String>? terms,
  })  : quotes = quotes ?? <Quote>[],
        terms = terms ?? const <String>[];

  Map<String, dynamic> toJson() => {
        'u': fromUser,
        't': text,
        'q': quotes.map((q) => q.toJson()).toList(),
        'n': notice,
        'i': issue,
        if (terms.isNotEmpty) 'k': terms,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        fromUser: j['u'] == true,
        text: asStr(j['t']),
        quotes: asMapList(j['q']).map((m) => Quote.fromJson(m)).toList(),
        notice: asStr(j['n']),
        issue: asStr(j['i']),
        terms: j['k'] is List
            ? (j['k'] as List).map((e) => '$e').toList()
            : const <String>[],
      );
}

class Conversation {
  String id;
  String title;
  bool pinned;
  bool archived;
  int updated;
  List<ChatMessage> messages;

  Conversation({
    required this.id,
    required this.title,
    this.pinned = false,
    this.archived = false,
    required this.updated,
    List<ChatMessage>? messages,
  }) : messages = messages ?? <ChatMessage>[];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'pin': pinned,
        'arc': archived,
        'up': updated,
        'm': messages.map((m) => m.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: asStr(j['id']),
        title: asStr(j['title']),
        pinned: j['pin'] == true,
        archived: j['arc'] == true,
        updated: asInt(j['up']),
        messages:
            asMapList(j['m']).map((m) => ChatMessage.fromJson(m)).toList(),
      );
}

// ---------------------------------------------------------------------
//  أدوات مساعدة
// ---------------------------------------------------------------------

int asInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse('${v ?? ''}'.trim()) ?? 0;
}

String asStr(dynamic v) => v == null ? '' : '$v';

List<Map<String, dynamic>> asMapList(dynamic v) {
  if (v is! List) return <Map<String, dynamic>>[];
  final out = <Map<String, dynamic>>[];
  for (final e in v) {
    if (e is Map) out.add(Map<String, dynamic>.from(e));
  }
  return out;
}

/// يحوّل نص HTML القادم من «تراث» إلى نص عادي مع الحفاظ على الأسطر.
String cleanHtml(String input) {
  var s = input;
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<[^>]*>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
  s = s.replaceAll(RegExp(r'[ \t ]+'), ' ');
  s = s.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
  return s.trim();
}

/// يزيل التشكيل والتطويل لمقارنة النصوص.
String stripTashkeel(String s) =>
    s.replaceAll(RegExp(r'[ً-ٰٟـ]'), '');

/// يقتطع جزءًا من النص حول أول كلمة من كلمات البحث.
String excerptAround(String text, List<String> terms, {int size = 700}) {
  if (text.length <= size) return text;
  final plain = stripTashkeel(text);
  var pos = -1;
  for (final t in terms) {
    final i = plain.indexOf(t);
    if (i >= 0) {
      pos = i;
      break;
    }
  }
  if (pos < 0) return '${text.substring(0, size)}…';
  // نقرّب الموضع إلى النص الأصلي (قد يختلف قليلًا بسبب التشكيل).
  final ratio = pos / math.max(1, plain.length);
  final center = (ratio * text.length).round();
  var start = math.max(0, center - size ~/ 3);
  var end = math.min(text.length, start + size);
  // نبدأ من أول كلمة كاملة.
  final space = text.indexOf(' ', start);
  if (start > 0 && space > 0 && space < start + 30) start = space + 1;
  return '${start > 0 ? '…' : ''}${text.substring(start, end)}${end < text.length ? '…' : ''}';
}

void showToast(BuildContext context, String msg) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg, textAlign: TextAlign.center),
    duration: const Duration(milliseconds: 1300),
    behavior: SnackBarBehavior.floating,
  ));
}

Future<void> openLink(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showToast(context, 'تعذّر فتح الرابط');
}

String quoteLink(Quote q) => Uri.https('www774475437-svg.github.io', '/sanad/', {
      'b': '${q.bookId}',
      'p': '${q.pageId}',
      'n': q.bookName,
      'l': q.pageLabel,
    }).toString();

Future<void> checkForUpdate(BuildContext context, {bool manual = false}) async {
  try {
    final r = await http
        .get(Uri.parse(kReleasesApi),
            headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 15));
    if (!context.mounted) return;
    if (r.statusCode != 200) {
      if (manual) showToast(context, 'تعذّر فحص التحديث');
      return;
    }
    final d = jsonDecode(r.body);
    final tag = asStr(d['tag_name']);
    final n = int.tryParse(tag.split('.').last) ?? 0;
    if (n > kBuild) {
      if (!manual && n == app.promptedUpdate) return;
      app.setPrompted(n);
      final url = asStr(d['html_url']);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('يوجد تحديث جديد'),
          content: const Text('صدرت نسخة أحدث من سَنَد. اضغط «تحميل» ثم ثبّتها فوق النسخة الحالية.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لاحقًا')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                openLink(context, url);
              },
              child: const Text('تحميل'),
            ),
          ],
        ),
      );
    } else if (manual) {
      showToast(context, 'أنت على أحدث نسخة');
    }
  } catch (_) {
    if (manual && context.mounted) showToast(context, 'تعذّر فحص التحديث');
  }
}

String telegramFormat(Quote q) =>
    '📜 ${q.heading.isEmpty ? 'من كلام الشيخ ابن عثيمين' : q.heading}\n\n'
    '▪️ $kScholarIntro\n'
    '«${q.text}،.🌿»\n\n'
    '> [📓${q.bookName} (صـ ${q.pageLabel})]';

String whatsappFormat(Quote q) => '▪ $kScholarIntro\n\n'
    '«${q.text}،.🪶»\n\n'
    '[📓${q.bookName} (${q.pageLabel})]';

String plainFormat(Quote q) =>
    '$kScholarIntro\n«${q.text}»\n[📓${q.bookName} (صـ ${q.pageLabel})]';

// ---------------------------------------------------------------------
//  حالة التطبيق والحفظ في الهاتف
// ---------------------------------------------------------------------

class AppState extends ChangeNotifier {
  SharedPreferences? _p;
  ThemeMode themeMode = ThemeMode.light;
  double fontScale = 1.0;
  List<Conversation> conversations = <Conversation>[];
  List<Quote> favorites = <Quote>[];
  Map<String, dynamic>? lastRead;
  List<String> recents = <String>[];
  int promptedUpdate = 0;
  String palette = 'green';
  Map<String, String> notes = <String, String>{};
  List<Quote> later = <Quote>[];
  bool dailyCard = true;
  String order = 'fatwa';
  Map<String, dynamic> bookPos = <String, dynamic>{};
  List<Map<String, dynamic>> marks = <Map<String, dynamic>>[];
  Map<String, String> folders = <String, String>{};
  List<String> folderNames = <String>[];
  double rSize = 19;
  double rHeight = 1.95;
  bool rAmiri = true;
  String rBg = 'auto';
  int streak = 0;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final p = _p!;
    final t = p.getString('theme') ?? 'light';
    themeMode = t == 'dark'
        ? ThemeMode.dark
        : (t == 'system' ? ThemeMode.system : ThemeMode.light);
    fontScale = p.getDouble('fontScale') ?? 1.0;
    recents = p.getStringList('recents') ?? <String>[];
    promptedUpdate = p.getInt('promptedUpdate') ?? 0;
    palette = p.getString('palette') ?? 'green';
    later = _decode(p.getString('later')).map((m) => Quote.fromJson(m)).toList();
    dailyCard = p.getBool('dailyCard') ?? true;
    order = p.getString('order') ?? 'fatwa';
    marks = _decode(p.getString('marks'));
    folderNames = p.getStringList('folderNames') ?? <String>[];
    rSize = p.getDouble('rSize') ?? 19;
    rHeight = p.getDouble('rHeight') ?? 1.95;
    rAmiri = p.getBool('rAmiri') ?? true;
    rBg = p.getString('rBg') ?? 'auto';
    streak = p.getInt('streak') ?? 0;
    try {
      final bp = jsonDecode(p.getString('bookPos') ?? '{}');
      if (bp is Map) bookPos = Map<String, dynamic>.from(bp);
      final fj = jsonDecode(p.getString('folders') ?? '{}');
      if (fj is Map) {
        fj.forEach((k, v) => folders['$k'] = '$v');
      }
    } catch (_) {}
    try {
      final nj = jsonDecode(p.getString('notes') ?? '{}');
      if (nj is Map) {
        nj.forEach((k, v) => notes['$k'] = '$v');
      }
    } catch (_) {}
    conversations = _decode(p.getString('conversations'))
        .map((m) => Conversation.fromJson(m))
        .toList();
    favorites =
        _decode(p.getString('favorites')).map((m) => Quote.fromJson(m)).toList();
    final lr = p.getString('lastRead');
    if (lr != null) {
      try {
        final d = jsonDecode(lr);
        if (d is Map) lastRead = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
  }

  static List<Map<String, dynamic>> _decode(String? s) {
    if (s == null || s.isEmpty) return <Map<String, dynamic>>[];
    try {
      return asMapList(jsonDecode(s));
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  void saveConversations() {
    _p?.setString(
        'conversations', jsonEncode(conversations.map((c) => c.toJson()).toList()));
    notifyListeners();
  }

  void setTheme(ThemeMode m) {
    themeMode = m;
    _p?.setString(
        'theme',
        m == ThemeMode.dark
            ? 'dark'
            : (m == ThemeMode.system ? 'system' : 'light'));
    notifyListeners();
  }

  void setFontScale(double v) {
    fontScale = v;
    _p?.setDouble('fontScale', v);
    notifyListeners();
  }

  void setPalette(String id) {
    palette = id;
    _p?.setString('palette', id);
    notifyListeners();
  }

  String noteOf(Quote q) => notes[q.key] ?? '';

  void setNote(Quote q, String text) {
    final t = text.trim();
    if (t.isEmpty) {
      notes.remove(q.key);
    } else {
      notes[q.key] = t;
    }
    _p?.setString('notes', jsonEncode(notes));
    notifyListeners();
  }

  bool isLater(Quote q) => later.any((f) => f.key == q.key);

  bool toggleLater(Quote q) {
    final i = later.indexWhere((f) => f.key == q.key);
    final added = i < 0;
    if (added) {
      later.insert(0, q);
    } else {
      later.removeAt(i);
    }
    _p?.setString('later', jsonEncode(later.map((f) => f.toJson()).toList()));
    notifyListeners();
    return added;
  }

  String get _monthKey {
    final n = DateTime.now();
    return 'reads:${n.year}-${n.month}';
  }

  int get monthReads => _p?.getInt(_monthKey) ?? 0;

  void bumpRead() {
    _p?.setInt(_monthKey, monthReads + 1);
    final n = DateTime.now();
    final today = '${n.year}-${n.month}-${n.day}';
    final last = _p?.getString('streakDay') ?? '';
    if (last == today) return;
    final y = n.subtract(const Duration(days: 1));
    streak = last == '${y.year}-${y.month}-${y.day}' ? streak + 1 : 1;
    _p?.setInt('streak', streak);
    _p?.setString('streakDay', today);
  }

  /// عدد الأيام المتتالية التي قرأ فيها (صفر إن انقطع).
  int get streakNow {
    final n = DateTime.now();
    final y = n.subtract(const Duration(days: 1));
    final last = _p?.getString('streakDay') ?? '';
    if (last == '${n.year}-${n.month}-${n.day}' ||
        last == '${y.year}-${y.month}-${y.day}') {
      return streak;
    }
    return 0;
  }

  void setDaily(bool v) {
    dailyCard = v;
    _p?.setBool('dailyCard', v);
    notifyListeners();
  }

  void setOrder(String v) {
    order = v;
    _p?.setString('order', v);
    notifyListeners();
  }

  void setReader({double? size, double? height, bool? amiri, String? bg}) {
    if (size != null) {
      rSize = size;
      _p?.setDouble('rSize', size);
    }
    if (height != null) {
      rHeight = height;
      _p?.setDouble('rHeight', height);
    }
    if (amiri != null) {
      rAmiri = amiri;
      _p?.setBool('rAmiri', amiri);
    }
    if (bg != null) {
      rBg = bg;
      _p?.setString('rBg', bg);
    }
    notifyListeners();
  }

  int posOf(int bookId) {
    final m = bookPos['$bookId'];
    return m is Map ? asInt(m['p']) : 0;
  }

  String posLabelOf(int bookId) {
    final m = bookPos['$bookId'];
    return m is Map ? asStr(m['l']) : '';
  }

  bool isMarked(int bookId, int pageId) =>
      marks.any((m) => asInt(m['b']) == bookId && asInt(m['pid']) == pageId);

  bool toggleMark(int bookId, String bookName, int pageId, String label) {
    final i = marks
        .indexWhere((m) => asInt(m['b']) == bookId && asInt(m['pid']) == pageId);
    final added = i < 0;
    if (added) {
      marks.insert(0, {
        'b': bookId,
        'n': bookName,
        'pid': pageId,
        'l': label,
        'at': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      marks.removeAt(i);
    }
    _p?.setString('marks', jsonEncode(marks));
    notifyListeners();
    return added;
  }

  String folderOf(Quote q) => folders[q.key] ?? '';

  void setFolder(Quote q, String name) {
    if (name.isEmpty) {
      folders.remove(q.key);
    } else {
      folders[q.key] = name;
      if (!folderNames.contains(name)) {
        folderNames.add(name);
        _p?.setStringList('folderNames', folderNames);
      }
    }
    _p?.setString('folders', jsonEncode(folders));
    notifyListeners();
  }

  void addFolder(String name) {
    if (name.isEmpty || folderNames.contains(name)) return;
    folderNames.add(name);
    _p?.setStringList('folderNames', folderNames);
    notifyListeners();
  }

  void removeFolder(String name) {
    folderNames.remove(name);
    folders.removeWhere((k, v) => v == name);
    _p?.setStringList('folderNames', folderNames);
    _p?.setString('folders', jsonEncode(folders));
    notifyListeners();
  }

  void addRecent(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    recents.remove(t);
    recents.insert(0, t);
    if (recents.length > 8) recents = recents.sublist(0, 8);
    _p?.setStringList('recents', recents);
    notifyListeners();
  }

  void clearRecents() {
    recents = <String>[];
    _p?.remove('recents');
    notifyListeners();
  }

  void setPrompted(int n) {
    promptedUpdate = n;
    _p?.setInt('promptedUpdate', n);
  }

  String exportFavorites() => jsonEncode(
      {'sanad': 1, 'favorites': favorites.map((f) => f.toJson()).toList()});

  /// يرجع عدد ما أُضيف، أو -1 عند فشل القراءة.
  int importFavorites(String text) {
    try {
      final d = jsonDecode(text);
      final list = d is Map ? asMapList(d['favorites']) : asMapList(d);
      var n = 0;
      for (final m in list) {
        final q = Quote.fromJson(m);
        if (q.text.isNotEmpty && !isFavorite(q)) {
          favorites.add(q);
          n++;
        }
      }
      _p?.setString(
          'favorites', jsonEncode(favorites.map((f) => f.toJson()).toList()));
      notifyListeners();
      return n;
    } catch (_) {
      return -1;
    }
  }

  bool isFavorite(Quote q) => favorites.any((f) => f.key == q.key);

  /// يرجع true إذا أُضيفت، و false إذا حُذفت.
  bool toggleFavorite(Quote q) {
    final i = favorites.indexWhere((f) => f.key == q.key);
    final added = i < 0;
    if (added) {
      favorites.insert(0, q);
    } else {
      favorites.removeAt(i);
    }
    _p?.setString('favorites', jsonEncode(favorites.map((f) => f.toJson()).toList()));
    notifyListeners();
    return added;
  }

  void setLastRead(int bookId, String bookName, int pageId, String label) {
    lastRead = {'b': bookId, 'n': bookName, 'pid': pageId, 'l': label};
    _p?.setString('lastRead', jsonEncode(lastRead));
    bookPos['$bookId'] = {'p': pageId, 'l': label};
    _p?.setString('bookPos', jsonEncode(bookPos));
    notifyListeners();
  }

  void clearHistory() {
    conversations.clear();
    saveConversations();
  }

  List<Quote>? cached(String query) {
    final s = _p?.getString('c:$query');
    if (s == null) return null;
    try {
      final d = jsonDecode(s);
      if (d is! Map) return null;
      final at = asInt(d['at']);
      if (DateTime.now().millisecondsSinceEpoch - at > 7 * 24 * 3600 * 1000) {
        return null;
      }
      return asMapList(d['q']).map((m) => Quote.fromJson(m)).toList();
    } catch (_) {
      return null;
    }
  }

  void putCache(String query, List<Quote> quotes) {
    _p?.setString(
        'c:$query',
        jsonEncode({
          'at': DateTime.now().millisecondsSinceEpoch,
          'q': quotes.map((q) => q.toJson()).toList(),
        }));
  }
}

final AppState app = AppState();

// ---------------------------------------------------------------------
//  الاتصال بموقع «تراث»
// ---------------------------------------------------------------------

class ApiException implements Exception {
  final bool busy;
  final String detail;
  ApiException(this.detail, {this.busy = false});
  @override
  String toString() => detail;
}

class PageData {
  final String text;
  final String label;
  final bool hasTitle;
  PageData(this.text, this.label, [this.hasTitle = false]);
}

bool _rawHasTitle(String raw) => raw.contains('data-type="title"') ||
    raw.contains("data-type='title'") || raw.contains('data-type=title');

class TurathApi {
  static const String host = 'api.turath.io';
  final http.Client _client = http.Client();

  Future<dynamic> _get(String path, Map<String, String> query) async {
    final uri = Uri.https(host, path, query);
    final http.Response r;
    try {
      r = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException('timeout');
    } catch (e) {
      throw ApiException('network: $e');
    }
    if (r.statusCode == 429) throw ApiException('429', busy: true);
    if (r.statusCode != 200) throw ApiException('HTTP ${r.statusCode}');
    final dynamic body;
    try {
      body = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ApiException('bad json');
    }
    if (body is Map && body['error'] != null) {
      final err = '${body['error']}';
      if (err.contains('rate')) throw ApiException(err, busy: true);
    }
    return body;
  }

  /// يجمع حقول العنصر، ومنها حقل meta إن كان نصًا بصيغة JSON.
  static Map<String, dynamic> flatten(dynamic item) {
    final m = <String, dynamic>{};
    if (item is! Map) return m;
    item.forEach((k, v) => m['$k'] = v);
    final meta = item['meta'];
    Map? metaMap;
    if (meta is Map) {
      metaMap = meta;
    } else if (meta is String && meta.trim().startsWith('{')) {
      try {
        final d = jsonDecode(meta);
        if (d is Map) metaMap = d;
      } catch (_) {}
    }
    metaMap?.forEach((k, v) => m.putIfAbsent('$k', () => v));
    return m;
  }

  static List<dynamic> _items(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      for (final k in const ['data', 'results', 'items']) {
        final v = body[k];
        if (v is List) return v;
      }
    }
    return const <dynamic>[];
  }

  /// يبحث في كل كتب الشيخ بطلب واحد (أو في كتاب واحد إن حُدِّد).
  Future<List<Quote>> searchAuthor(String query, {int? book}) async {
    final params = <String, String>{'q': query, 'ver': '3'};
    if (book != null) {
      params['book'] = '$book';
    } else {
      params['author'] = '$kAuthorId';
    }
    final body = await _get('/search', params);
    final terms = query.split(' ');
    final out = <Quote>[];
    final seen = <String>{};
    for (final it in _items(body)) {
      final m = flatten(it);
      final b = bookOf(asInt(m['book_id']));
      if (b == null) continue; // ليس من كتب الشيخ المعتمدة: يُترك
      if (book != null && b.id != book) continue;
      final pageId = asInt(m['page_id'] ?? m['pg']);
      if (!seen.add('${b.id}:$pageId')) continue;
      var text = cleanHtml(asStr(m['snip']));
      if (text.isEmpty) text = cleanHtml(asStr(m['text']));
      if (text.isEmpty) continue;
      text = excerptAround(text, terms);
      var title = '';
      final hs = m['headings'];
      if (hs is List) {
        for (final h in hs.reversed) {
          final t = '$h'.trim();
          if (t.isNotEmpty) {
            title = t;
            break;
          }
        }
      }
      out.add(Quote(
        bookId: b.id,
        bookName: b.title,
        vol: asStr(m['vol']),
        page: asStr(m['page']),
        pageId: pageId,
        text: text,
        title: title,
      ));
    }
    return out;
  }

  /// [vol, page, rawHtml] للصفحة: من الهاتف إن كان الكتاب منزّلًا، وإلا من «تراث».
  Future<List<String>> rawPage(int bookId, int pg) async {
    if (pg < 1) return <String>['', '', ''];
    if (kIsWeb || storeHas(bookId)) return localIndex.pageData(bookId, pg - 1);
    try {
      final body = await _get('/page', {
        'book_id': '$bookId',
        'pg': '$pg',
        'ver': '3',
      });
      dynamic node = body;
      if (body is Map && body['data'] is Map) node = body['data'];
      final m = flatten(node);
      return <String>[
        asStr(m['vol']).trim(),
        asStr(m['page']).trim(),
        asStr(m['text']),
      ];
    } on ApiException {
      return localIndex.pageData(bookId, pg - 1);
    }
  }

  Future<PageData> page(int bookId, int pg) async {
    final d = await rawPage(bookId, pg);
    if (d[2].isEmpty) return PageData('', '');
    final label = d[1].isEmpty
        ? ''
        : ((d[0].isEmpty || d[0] == '0') ? d[1] : '${d[0]}/${d[1]}');
    return PageData(cleanHtml(d[2]), label, _rawHasTitle(d[2]));
  }

  /// فحص الاتصال: يرجع وصفًا مختصرًا لنتيجة بحث تجريبي.
  Future<String> diagnose() async {
    if (kIsWeb) {
      final lb = await localIndex.page(11224, 5);
      return 'نجح قراءة ملفات الكتب.\nمقتطف: ${lb.text.length > 120 ? lb.text.substring(0, 120) : lb.text}';
    }
    final body = await _get(
        '/search', {'q': 'الصلاة', 'ver': '3', 'author': '$kAuthorId'});
    final items = _items(body);
    final b = StringBuffer('نجح الاتصال بتراث.\nعدد النتائج: ${items.length}\n');
    if (items.isNotEmpty) {
      final m = flatten(items.first);
      b.writeln('الحقول: ${m.keys.join(', ')}');
      b.writeln('book_id: ${m['book_id']}  page_id: ${m['page_id']}');
      final snip = asStr(m['snip']);
      final s = cleanHtml(snip.isEmpty ? asStr(m['text']) : snip);
      b.writeln('مقتطف: ${s.length > 120 ? s.substring(0, 120) : s}');
    }
    b.writeln('الكتب المنزّلة على الهاتف: ${storeIds().length}');
    return b.toString();
  }
}

final TurathApi api = TurathApi();

// ---------------------------------------------------------------------
//  البحث المحلي في ملفات الكتب (يعمل في المتصفح بلا حدّ للطلبات)
// ---------------------------------------------------------------------

/// مجموعات كلمات البحث: كل مجموعة فيها الكلمة ومرادفاتها (موحَّدة).
typedef TermGroups = List<List<String>>;

/// الكتب التي يُبحث في نصها كاملًا في المتصفح (والبقية يُبحث في عناوين مسائلها).
const Set<int> kCoreIds = {
  12293, 9924, 11377, 96334, 14242, 21576, 9260, 7339, 11166, 11224, 31341,
  7470, 21528,
};

/// كتب الفتاوى والأسئلة (تُقدَّم أو تُؤخَّر حسب اختيار المستخدم).
const Set<int> kFatwaIds = {7686, 11377, 7470, 21528, 11069};

bool isFatwaBook(int id) {
  if (kFatwaIds.contains(id)) return true;
  final b = bookOf(id);
  return b != null && b.cat == 22;
}

double catBoost(int bookId) {
  switch (app.order) {
    case 'fatwa':
      return isFatwaBook(bookId) ? 12 : 0;
    case 'sharh':
      return isFatwaBook(bookId) ? 0 : 12;
  }
  return 0;
}

/// مرادفات شائعة: يكتب السائل كلمة ويُبحث معها عن أختها.
const Map<String, List<String>> _kSynonymsRaw = {
  'الحواجب': ['النمص', 'الحاجب'],
  'الحاجب': ['النمص', 'الحواجب'],
  'الحاجبين': ['النمص', 'الحواجب'],
  'حاجبيها': ['النمص', 'الحواجب'],
  'النمص': ['النامصة', 'الحواجب'],
  'التدخين': ['الدخان'],
  'السجائر': ['الدخان', 'التدخين'],
  'الدخان': ['التدخين'],
  'الشيشة': ['الدخان'],
  'الأغاني': ['الغناء', 'المعازف'],
  'الموسيقى': ['المعازف', 'الغناء'],
  'الغناء': ['المعازف', 'الأغاني'],
  'المعازف': ['الغناء', 'الموسيقى'],
  'التلفزيون': ['التلفاز'],
  'التلفاز': ['التلفزيون'],
  'الصور': ['التصوير'],
  'التصوير': ['الصور'],
  'البنك': ['البنوك'],
  'البنوك': ['البنك'],
  'الفوائد': ['الربا'],
  'الباروكة': ['الوصل', 'الشعر المستعار'],
  'المكياج': ['التجمل', 'الزينة'],
  'الدورة': ['الحيض'],
  'الحيض': ['الحائض'],
  'الحائض': ['الحيض'],
  'النفاس': ['النفساء'],
  'اللحية': ['اللحى'],
  'الإسبال': ['المسبل'],
  'الجوال': ['الهاتف'],
  'الموبايل': ['الجوال', 'الهاتف'],
  'العرس': ['الزواج', 'النكاح'],
  'الزواج': ['النكاح'],
  'النكاح': ['الزواج'],
  'الصيام': ['الصوم'],
  'الصوم': ['الصيام'],
  'الأضحية': ['الأضاحي'],
  'السفر': ['المسافر'],
  'المسافر': ['السفر'],
  'الكلب': ['الكلاب'],
  'الخمر': ['المسكر'],
  'المخدرات': ['المسكر', 'الحشيش'],
  'الأظافر': ['الأظفار'],
  'الأظفار': ['الأظافر'],
  'القبور': ['المقابر', 'القبر'],
  'المقابر': ['القبور'],
  'السحر': ['الساحر'],
  'الحسد': ['العين'],
  'الجن': ['الشياطين'],
  'التراويح': ['قيام رمضان'],
  'العيد': ['العيدين'],
  'المولد': ['الموالد'],
  'الوالدين': ['الوالدان', 'بر الوالدين'],
  'الطلاق': ['طلق', 'المطلقة'],
  'الرضاع': ['الرضاعة'],
  'الرضاعة': ['الرضاع'],
};

final Map<String, List<String>> _kSynonyms = {
  for (final e in _kSynonymsRaw.entries) normArabic(e.key): e.value,
};

List<String> synonymsOf(String term) =>
    _kSynonyms[normArabic(term)] ?? const <String>[];

/// جذر مبسّط: يحذف «ال» وأخواتها من أول الكلمة ليطابق صيغًا أكثر.
String needleOf(String n) {
  for (final p in const ['وال', 'بال', 'كال', 'فال']) {
    if (n.startsWith(p) && n.length >= 6) return n.substring(3);
  }
  if (n.startsWith('لل') && n.length >= 5) return n.substring(2);
  if (n.startsWith('ال') && n.length >= 5) return n.substring(2);
  return n;
}

TermGroups groupsOf(List<String> terms) {
  final out = <List<String>>[];
  for (final t in terms) {
    final n = normArabic(t).trim();
    if (n.length < 2) continue;
    final alts = <String>[needleOf(n)];
    for (final s in synonymsOf(t)) {
      final x = needleOf(normArabic(s).trim());
      if (x.length >= 2 && !alts.contains(x)) alts.add(x);
    }
    out.add(alts);
  }
  return out;
}

final Set<int> _kPre = 'والفبكليتمنس'.codeUnits.toSet();
const Set<String> _kSuf = {
  'ه', 'ها', 'هم', 'هن', 'هما', 'ك', 'كم', 'ي', 'نا', 'ا', 'ات', 'ان', 'ين',
  'ون', 'يه', 'يها', 'ته', 'تها', 'تهم', 'ت', 'تي', 'تين', 'تان', 'يون', 'وا',
  'يا', 'يات',
};

bool _isLetter(int c) => c >= 0x0621 && c <= 0x064A;

/// هل الموضع [s..e) كلمة مستقلة؟ (تُقبل سوابق مثل «ال» و«و» ولواحق مثل «ها» و«ات»)
bool _wordAt(String h, int s, int e) {
  var i = s - 1;
  var n = 0;
  while (i >= 0 && n < 4 && _kPre.contains(h.codeUnitAt(i))) {
    i--;
    n++;
  }
  if (i >= 0 && _isLetter(h.codeUnitAt(i))) return false;
  var j = e;
  n = 0;
  while (j < h.length && n < 3 && _isLetter(h.codeUnitAt(j))) {
    j++;
    n++;
  }
  if (j < h.length && _isLetter(h.codeUnitAt(j))) return false;
  return n == 0 || _kSuf.contains(h.substring(e, j));
}

/// أول موضع للكلمة في النص ككلمة مستقلة (لا كجزء من كلمة أخرى)، أو -1.
int wordPos(String hay, String needle, [int from = 0]) {
  var p = hay.indexOf(needle, from);
  while (p >= 0) {
    if (_wordAt(hay, p, p + needle.length)) return p;
    p = hay.indexOf(needle, p + 1);
  }
  return -1;
}

bool hasAny(String hay, List<String> alts) {
  for (final a in alts) {
    if (wordPos(hay, a) >= 0) return true;
  }
  return false;
}

bool matchesAll(String hay, TermGroups g) {
  for (final a in g) {
    if (!hasAny(hay, a)) return false;
  }
  return true;
}

int firstPos(String hay, TermGroups g) {
  var p = -1;
  for (final alts in g) {
    for (final a in alts) {
      final q = wordPos(hay, a);
      if (q >= 0 && (p < 0 || q < p)) p = q;
    }
  }
  return p;
}

/// بدائل إملائية قريبة (س/ص، ت/ط، ذ/ز، ض/ظ) تُجرَّب إن لم توجد نتيجة.
List<List<String>> typoVariants(List<String> terms) {
  const swap = {
    'س': 'ص', 'ص': 'س', 'ت': 'ط', 'ط': 'ت', 'ذ': 'ز', 'ز': 'ذ',
    'ض': 'ظ', 'ظ': 'ض', 'ث': 'س',
  };
  final out = <List<String>>[];
  for (var i = 0; i < terms.length; i++) {
    final t = terms[i];
    for (var j = 0; j < t.length; j++) {
      final r = swap[t[j]];
      if (r == null) continue;
      final v = '${t.substring(0, j)}$r${t.substring(j + 1)}';
      out.add([...terms]..[i] = v);
      if (out.length >= 8) return out;
    }
  }
  return out;
}

/// يقتطع من الصفحة الخام المسألةَ التي فيها كلمات البحث (من عنوانها إلى العنوان التالي).
({String text, String title}) sectionExcerpt(String raw, TermGroups g,
    {String title = '', int size = 1300}) {
  if (raw.isEmpty) return (text: '', title: '');
  final map = <int>[];
  final n = normRaw(raw, map: map);
  var p = -1;
  if (title.isNotEmpty) {
    final nt = normArabic(title);
    p = n.indexOf(nt.length > 24 ? nt.substring(0, 24) : nt);
  }
  if (p < 0) p = firstPos(n, g);
  final rawPos = p >= 0 && p < map.length ? map[p] : 0;
  const tag = '<span data-type="title"';
  var s = raw.lastIndexOf(tag, rawPos);
  var found = '';
  if (s >= 0) {
    final close = raw.indexOf('</span>', s);
    if (close > s) found = cleanHtml(raw.substring(s, close)).trim();
  } else {
    s = 0;
  }
  var e = raw.indexOf(tag, math.max(rawPos, s + 1));
  if (e < 0) e = raw.length;
  final cleaned = cleanHtml(raw.substring(s, e)).trim();
  if (cleaned.length <= size) return (text: cleaned, title: found);
  // إن كانت الكلمة قريبة من أول المسألة نبدأ من أولها ليظهر السؤال.
  final cmap = <int>[];
  final cn = normRaw(cleaned, map: cmap, tags: false);
  final cp = firstPos(cn, g);
  final c = cp >= 0 && cp < cmap.length ? cmap[cp] : 0;
  var start = c < size - 200 ? 0 : math.max(0, c - 250);
  var end = math.min(cleaned.length, start + size);
  if (start > 0) {
    final sp = cleaned.indexOf(' ', start);
    if (sp >= 0 && sp < start + 40) start = sp + 1;
  }
  if (end < cleaned.length) {
    final sp = cleaned.lastIndexOf(' ', end);
    if (sp > start + size ~/ 2) end = sp;
  }
  return (
    text: '${start > 0 ? '…' : ''}${cleaned.substring(start, end).trim()}'
        '${end < cleaned.length ? '…' : ''}',
    title: found,
  );
}

/// يرتّب النقول: ما طابق عنوانُ مسألته السؤالَ أولًا.
List<Quote> rankQuotes(List<Quote> list, TermGroups g) {
  final scored = <MapEntry<Quote, double>>[];
  for (var i = 0; i < list.length; i++) {
    final q = list[i];
    var s = -i * 0.6;
    if (q.title.isNotEmpty && g.isNotEmpty) {
      final t = normArabic(q.title);
      var hit = 0;
      for (final a in g) {
        if (hasAny(t, a)) hit++;
      }
      s += 60.0 * hit / g.length;
      if (hit == g.length) s += 25;
    }
    s += catBoost(q.bookId);
    scored.add(MapEntry(q, s));
  }
  scored.sort((a, b) => b.value.compareTo(a.value));
  return scored.map((e) => e.key).toList();
}

class LocalBook {
  final Book book;
  final List<String> norms;
  const LocalBook(this.book, this.norms);
}

class Headings {
  final List<int> books = <int>[];
  final List<int> pages = <int>[];
  final List<String> titles = <String>[];
  final List<String> norms = <String>[];
}

class TocEntry {
  final int level;
  final int page;
  final String title;
  const TocEntry(this.level, this.page, this.title);
}

/// البيانات المحلية: فهرس عناوين كل الكتب، وملفات بحث نصي، وصفحات الكتب.
/// تُقرأ من الهاتف إن كان الكتاب منزّلًا، وإلا من موقع سَنَد.
class LocalIndex {
  static const int chunkSize = 20;
  final Map<int, Future<LocalBook>> _books = {};
  final Map<String, Future<List<dynamic>>> _chunks = {};
  final Map<int, Future<List<TocEntry>>> _tocs = {};
  Future<Headings>? _heads;
  Headings? headsNow;
  final ValueNotifier<String> status = ValueNotifier<String>('');

  String get _base => '${kSiteUrl}data/';

  Future<String> _getText(String url, {int seconds = 120}) async {
    final r = await http.get(Uri.parse(url)).timeout(Duration(seconds: seconds));
    if (r.statusCode != 200) throw ApiException('HTTP ${r.statusCode}');
    return utf8.decode(r.bodyBytes);
  }

  void forget(int bookId) {
    _books.remove(bookId);
    _tocs.remove(bookId);
    _chunks.removeWhere((k, _) => k.startsWith('$bookId:'));
  }

  Future<LocalBook> _load(Book b) => _books.putIfAbsent(b.id, () => _fetch(b));

  Future<LocalBook> _fetch(Book b) async {
    try {
      var text = await storeRead(b.id, 'n.txt');
      if (text == null) {
        status.value = 'جارٍ تجهيز «${b.title}» للبحث (أول مرة فقط)...';
        text = await _getText('${_base}n${b.id}.txt', seconds: 180);
      }
      final lines = text.split('\n');
      if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
      status.value = '';
      return LocalBook(b, lines);
    } catch (e) {
      _books.remove(b.id);
      status.value = '';
      if (e is ApiException) rethrow;
      throw ApiException('local: $e');
    }
  }

  Future<Headings> headings() => _heads ??= _fetchHeads();

  Future<Headings> _fetchHeads() async {
    try {
      final text = await _getText('${_base}h.txt', seconds: 180);
      final h = Headings();
      for (final line in text.split('\n')) {
        final a = line.indexOf('\t');
        if (a < 0) continue;
        final b = line.indexOf('\t', a + 1);
        if (b < 0) continue;
        final id = int.tryParse(line.substring(0, a));
        final pg = int.tryParse(line.substring(a + 1, b));
        if (id == null || pg == null) continue;
        final t = line.substring(b + 1);
        h.books.add(id);
        h.pages.add(pg);
        h.titles.add(t);
        h.norms.add(normArabic(t));
      }
      headsNow = h;
      return h;
    } catch (e) {
      _heads = null;
      if (e is ApiException) rethrow;
      throw ApiException('local: $e');
    }
  }

  Future<List<TocEntry>> toc(int bookId) =>
      _tocs.putIfAbsent(bookId, () => _fetchToc(bookId));

  Future<List<TocEntry>> _fetchToc(int bookId) async {
    try {
      final text = await storeRead(bookId, 't.json') ??
          await _getText('${_base}t$bookId.json');
      final d = jsonDecode(text);
      final out = <TocEntry>[];
      if (d is List) {
        for (final e in d) {
          if (e is List && e.length >= 3) {
            out.add(TocEntry(asInt(e[0]), asInt(e[1]), asStr(e[2])));
          }
        }
      }
      return out;
    } catch (e) {
      _tocs.remove(bookId);
      if (e is ApiException) rethrow;
      throw ApiException('local: $e');
    }
  }

  Future<List<dynamic>> _chunk(int bookId, int k) {
    if (_chunks.length > 80) _chunks.clear();
    final key = '$bookId:$k';
    return _chunks.putIfAbsent(key, () async {
      try {
        final text = await storeRead(bookId, 'p_$k.json') ??
            await _getText('${_base}p${bookId}_$k.json', seconds: 60);
        final d = jsonDecode(text);
        if (d is! List) throw ApiException('bad chunk');
        return d;
      } catch (e) {
        _chunks.remove(key);
        if (e is ApiException) rethrow;
        throw ApiException('local: $e');
      }
    });
  }

  /// [vol, page, rawHtml] للصفحة ذات الرقم (من 0).
  Future<List<String>> pageData(int bookId, int i) async {
    if (i < 0) return ['', '', ''];
    final ch = await _chunk(bookId, i ~/ chunkSize);
    final j = i % chunkSize;
    if (j >= ch.length) return ['', '', ''];
    final e = ch[j];
    if (e is! List || e.length < 3) return ['', '', ''];
    var pg = '${e[1] ?? ''}';
    if (pg == 'None' || pg == 'null') pg = '';
    return ['${e[0] ?? ''}', pg, '${e[2] ?? ''}'];
  }

  /// كتب البحث النصي الكامل: في التطبيق الكتب المنزّلة، وإلا الكتب الأساسية.
  List<Book> get _fullText {
    final ids = storeIds();
    final list = (!kIsWeb && ids.isNotEmpty)
        ? kBooks.where((b) => ids.contains(b.id)).toList()
        : kBooks.where((b) => kCoreIds.contains(b.id)).toList();
    list.sort((a, b) => a.size.compareTo(b.size));
    return list;
  }

  bool hasFullText(int bookId) => _fullText.any((b) => b.id == bookId);

  Future<void> preload() async {
    try {
      await headings();
    } catch (_) {}
    for (final b in _fullText) {
      try {
        await _load(b);
      } catch (_) {}
    }
  }

  Future<Quote?> quoteAt(Book b, int pageIdx, TermGroups g,
      {String title = ''}) async {
    final d = await pageData(b.id, pageIdx);
    final ex = sectionExcerpt(d[2], g, title: title);
    if (ex.text.isEmpty) return null;
    return Quote(
      bookId: b.id,
      bookName: b.title,
      vol: d[0],
      page: d[1],
      pageId: pageIdx + 1,
      text: ex.text,
      title: title.isNotEmpty ? title : ex.title,
    );
  }

  Future<List<Quote>> searchAll(TermGroups g, {int? onlyBook}) async {
    if (g.isEmpty) return <Quote>[];
    final out = <Quote>[];
    final seen = <String>{};
    Object? lastError;
    var okAny = false;
    // 1) عناوين المسائل في كل الكتب
    try {
      final h = await headings();
      okAny = true;
      final hits = <int>[];
      for (var i = 0; i < h.norms.length; i++) {
        if (onlyBook != null && h.books[i] != onlyBook) continue;
        if (matchesAll(h.norms[i], g)) hits.add(i);
      }
      double score(int i) => catBoost(h.books[i]) - h.norms[i].length / 40.0;
      hits.sort((a, b) => score(b).compareTo(score(a)));
      for (final i in hits.take(onlyBook != null ? 25 : 10)) {
        final b = bookOf(h.books[i]);
        if (b == null) continue;
        if (!seen.add('${b.id}:${h.pages[i]}')) continue;
        try {
          final q = await quoteAt(b, h.pages[i] - 1, g, title: h.titles[i]);
          if (q != null) out.add(q);
        } catch (e) {
          lastError = e;
        }
      }
    } catch (e) {
      lastError = e;
    }
    // 2) النص الكامل
    final books = onlyBook != null
        ? _fullText.where((b) => b.id == onlyBook).toList()
        : _fullText;
    for (final b in books) {
      try {
        final lb = await _load(b);
        okAny = true;
        for (final i in _topPages(lb, g, onlyBook != null ? 20 : 2)) {
          if (!seen.add('${b.id}:${i + 1}')) continue;
          final q = await quoteAt(b, i, g);
          if (q != null) out.add(q);
        }
      } catch (e) {
        lastError = e;
      }
    }
    if (!okAny) throw ApiException('local: $lastError');
    return out;
  }

  List<int> _topPages(LocalBook lb, TermGroups g, int limit) {
    final scored = <MapEntry<int, double>>[];
    for (var i = 0; i < lb.norms.length; i++) {
      final n = lb.norms[i];
      var ok = true;
      var occ = 0;
      var minP = 1 << 30;
      var maxP = -1;
      for (final alts in g) {
        var p = -1;
        var t = '';
        for (final a in alts) {
          final q = wordPos(n, a);
          if (q >= 0 && (p < 0 || q < p)) {
            p = q;
            t = a;
          }
        }
        if (p < 0) {
          ok = false;
          break;
        }
        minP = math.min(minP, p);
        maxP = math.max(maxP, p);
        var c = 1;
        var q = wordPos(n, t, p + t.length);
        while (q >= 0 && c < 6) {
          c++;
          q = wordPos(n, t, q + t.length);
        }
        occ += c;
      }
      if (!ok) continue;
      final spread = g.length > 1 ? (maxP - minP) : 0;
      scored.add(MapEntry(i, occ + 12 / (1 + spread / 150.0)));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  Future<PageData> page(int bookId, int pg) async {
    if (pg < 1) return PageData('', '');
    final d = await pageData(bookId, pg - 1);
    if (d[2].isEmpty) return PageData('', '');
    final label = d[1].isEmpty
        ? ''
        : ((d[0].isEmpty || d[0] == '0') ? d[1] : '${d[0]}/${d[1]}');
    return PageData(cleanHtml(d[2]), label, _rawHasTitle(d[2]));
  }
}

final LocalIndex localIndex = LocalIndex();

// ---------------------------------------------------------------------
//  فهم السؤال (بلا ذكاء اصطناعي) وتكوين الجواب
// ---------------------------------------------------------------------

class ParsedQuestion {
  final bool greeted;
  final List<String> terms;
  final String issue;
  ParsedQuestion(this.greeted, this.terms, this.issue);
}

const Set<String> kStopWords = {
  'ما', 'ماذا', 'هل', 'يجوز', 'يجوزلي', 'حكم', 'الحكم', 'في', 'فى', 'عن',
  'من', 'على', 'علي', 'الى', 'إلى', 'يا', 'شيخ', 'الشيخ', 'شيخنا', 'فضيلة',
  'ابن', 'عثيمين', 'العثيمين', 'رحمه', 'رأي', 'راي', 'قول', 'لو', 'سمحت',
  'أريد', 'اريد', 'أن', 'ان', 'إن', 'هو', 'هي', 'و', 'أو', 'او', 'ثم', 'عند',
  'لي', 'لنا', 'ذلك', 'هذا', 'هذه', 'مع', 'كان', 'كيف', 'لماذا', 'متى',
  'أين', 'اين', 'بارك', 'فيكم', 'فيك', 'جزاكم', 'جزاك', 'خيرا', 'خيرًا',
  'سؤال', 'سؤالي', 'عندي', 'أسأل', 'اسأل', 'بخصوص', 'وما', 'وهل', 'شرعا',
  'شرعًا', 'الشرع', 'الإسلام', 'الاسلام', 'الله', 'تعالى', 'هناك', 'التي',
  'الذي', 'بعض', 'كل', 'قد', 'لا', 'لم', 'لن', 'أم', 'ام', 'اذا', 'إذا',
};

ParsedQuestion parseQuestion(String raw) {
  final greeted = RegExp(r'السلام\s*عليكم').hasMatch(raw);
  var s = raw;
  s = s.replaceAll(RegExp(r'السلام\s*عليكم(\s*و\s*رحمة\s*الله)?(\s*و\s*بركاته)?'), ' ');
  s = s.replaceAll(RegExp(r'[؟?!.,،؛;:«»"()\[\]{}\-_/\\]'), ' ');
  s = stripTashkeel(s);
  final terms = <String>[];
  for (final w in s.split(RegExp(r'\s+'))) {
    final t = w.trim();
    if (t.length < 2) continue;
    if (kStopWords.contains(t)) continue;
    if (!terms.contains(t)) terms.add(t);
  }
  final kept = terms.take(4).toList();
  final topic = kept.join(' ');
  final asksRuling = raw.contains('حكم') || raw.contains('يجوز');
  final issue = topic.isEmpty ? '' : (asksRuling ? 'حكم $topic' : topic);
  return ParsedQuestion(greeted, kept, issue);
}

class AnswerEngine {
  Future<List<Quote>> _search(List<String> terms) async {
    final key = 'v4:${app.order}:${terms.join(' ')}';
    final cached = app.cached(key);
    if (cached != null) return cached;
    final g = groupsOf(terms);
    if (g.isEmpty) return <Quote>[];
    List<Quote> found;
    if (kIsWeb) {
      found = await localIndex.searchAll(g);
    } else {
      try {
        found = await _online(terms, g, null);
      } on ApiException {
        found = await localIndex.searchAll(g);
      }
    }
    found = rankQuotes(found, g).take(10).toList();
    if (found.isNotEmpty) app.putCache(key, found);
    return found;
  }

  /// بحث عبر «تراث» في كل كتب الشيخ، ثم جلب نص المسألة كاملًا لأفضل النتائج.
  Future<List<Quote>> _online(List<String> terms, TermGroups g, int? book) async {
    final queries = <String>[terms.join(' ')];
    for (var i = 0; i < terms.length && queries.length < 3; i++) {
      final syn = synonymsOf(terms[i]);
      if (syn.isEmpty) continue;
      queries.add(([...terms]..[i] = syn.first).join(' '));
    }
    final all = <Quote>[];
    final seen = <String>{};
    ApiException? err;
    var ok = false;
    for (final q in queries) {
      try {
        for (final x in await api.searchAuthor(q, book: book)) {
          if (seen.add('${x.bookId}:${x.pageId}')) all.add(x);
        }
        ok = true;
      } on ApiException catch (e) {
        err = e;
      }
    }
    if (!ok) throw err ?? ApiException('failed');
    final ranked = rankQuotes(all, g);
    final top = ranked.take(book != null ? 20 : 10).toList();
    final full = math.min(top.length, book != null ? 8 : 6);
    final filled = await Future.wait(<Future<Quote>>[
      for (var i = 0; i < full; i++) _fill(top[i], g),
    ]);
    return <Quote>[...filled, ...top.skip(full)];
  }

  Future<Quote> _fill(Quote q, TermGroups g) async {
    if (q.pageId <= 0) return q;
    try {
      final d = await api.rawPage(q.bookId, q.pageId);
      final ex = sectionExcerpt(d[2], g, title: q.title);
      if (ex.text.length > q.text.length) {
        return q.copyWith(
            text: ex.text, title: q.title.isEmpty ? ex.title : q.title);
      }
    } catch (_) {}
    return q;
  }

  /// بحث داخل كتاب واحد.
  Future<List<Quote>> searchInBook(Book b, String raw) async {
    final terms = parseQuestion(raw).terms;
    final g = groupsOf(terms);
    if (g.isEmpty) return <Quote>[];
    if (!kIsWeb && !storeHas(b.id)) {
      try {
        return await _online(terms, g, b.id);
      } on ApiException {
        // نكمل بالبحث المحلي
      }
    }
    return rankQuotes(await localIndex.searchAll(g, onlyBook: b.id), g);
  }

  Future<ChatMessage> answer(String raw) async {
    final q = parseQuestion(raw);
    final greet = q.greeted ? 'وعليكم السلام ورحمة الله وبركاته.' : '';
    if (q.terms.isEmpty) {
      return ChatMessage(
        fromUser: false,
        text: greet,
        notice: 'تفضّل بكتابة سؤالك، مثل: ما حكم النمص؟',
      );
    }
    var terms = q.terms;
    var note = '';
    var quotes = await _search(terms);
    if (quotes.isEmpty) {
      // لعلّه خطأ إملائي: نجرّب بدائل قريبة
      for (final v in typoVariants(terms).take(4)) {
        final r = await _search(v);
        if (r.isNotEmpty) {
          note = 'لم أجد «${terms.join(' ')}»، فبحثتُ عن «${v.join(' ')}».';
          quotes = r;
          terms = v;
          break;
        }
      }
    }
    if (quotes.isEmpty && terms.length > 1) {
      final sorted = [...terms]..sort((a, b) => b.length.compareTo(a.length));
      quotes = await _search([sorted.first]);
      if (quotes.isNotEmpty) terms = [sorted.first];
    }
    return ChatMessage(
      fromUser: false,
      text: greet,
      issue: q.issue,
      terms: terms,
      quotes: quotes.map((x) => x.withIssue(q.issue)).toList(),
      notice: quotes.isEmpty
          ? 'لم أجد للشيخ ابن عثيمين رَحِمَهُ الله كلامًا في هذه المسألة في كتبه المضافة.'
          : note,
    );
  }
}

final AnswerEngine engine = AnswerEngine();

// ---------------------------------------------------------------------
//  التطبيق
// ---------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await app.load();
  } catch (e, st) {
    debugPrint('app.load failed: $e\n$st');
  }
  try {
    await storeInit();
  } catch (e) {
    debugPrint('storeInit failed: $e');
  }
  try {
    runApp(const SanadApp());
  } catch (e, st) {
    runApp(MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText('خطأ: $e\n\n$st',
                textDirection: TextDirection.ltr),
          ),
        ),
      ),
    ));
  }
}

ThemeData buildTheme(Brightness b, String pal) {
  var scheme = ColorScheme.fromSeed(seedColor: kBrand, brightness: b);
  var bg = b == Brightness.light ? const Color(0xFFF6F8F7) : const Color(0xFF101414);
  if (pal == 'black') {
    scheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFFD4AF37), brightness: Brightness.dark)
        .copyWith(
      primary: const Color(0xFFD4AF37),
      onPrimary: Colors.black,
      surface: const Color(0xFF151515),
      surfaceContainerHighest: const Color(0xFF232323),
      primaryContainer: const Color(0xFF3A3012),
      onPrimaryContainer: const Color(0xFFF3E2A9),
      outlineVariant: const Color(0xFF333333),
    );
    bg = const Color(0xFF0A0A0A);
  } else if (pal == 'paper') {
    scheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF7A5A2E), brightness: Brightness.light)
        .copyWith(
      primary: const Color(0xFF6B4F2A),
      surface: const Color(0xFFFBF6E9),
      surfaceContainerHighest: const Color(0xFFEFE4C8),
      primaryContainer: const Color(0xFFE8D9B0),
      onPrimaryContainer: const Color(0xFF3B2A10),
      outlineVariant: const Color(0xFFD9C9A0),
    );
    bg = const Color(0xFFF3EAD3);
  }
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Amiri',
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
      ),
    ),
  );
}

ThemeMode effectiveThemeMode() {
  if (app.palette == 'black') return ThemeMode.dark;
  if (app.palette == 'paper') return ThemeMode.light;
  return app.themeMode;
}

/// ألوان الواجهة العلوية حسب النمط: (بداية التدرج، نهايته، لون النص).
(Color, Color, Color) heroColors() {
  switch (app.palette) {
    case 'black':
      return (const Color(0xFF1C1C1C), const Color(0xFF050505), const Color(0xFFD4AF37));
    case 'paper':
      return (const Color(0xFF6B4F2A), const Color(0xFF8C6A39), const Color(0xFFFFF8E1));
    default:
      return (const Color(0xFF0B4A44), const Color(0xFF11766B), Colors.white);
  }
}

class GeoPatternPainter extends CustomPainter {
  final Color color;
  const GeoPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 44.0;
    var row = 0;
    for (var y = 0.0; y < size.height + step; y += step) {
      final shift = row.isOdd ? step / 2 : 0.0;
      for (var x = -step; x < size.width + step; x += step) {
        _star(canvas, Offset(x + shift, y), step * 0.42, p);
      }
      row++;
    }
  }

  void _star(Canvas c, Offset o, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      final rad = i.isEven ? r : r * 0.62;
      final pt = Offset(o.dx + rad * math.cos(a), o.dy + rad * math.sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant GeoPatternPainter old) => old.color != color;
}

/// شاشة افتتاحية قصيرة متحركة.
class SplashGate extends StatefulWidget {
  final Widget child;
  const SplashGate({super.key, required this.child});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _fade = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _fade = true);
    });
    Future<void>.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _gone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = heroColors();
    return Stack(children: [
      widget.child,
      if (!_gone)
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _fade,
            child: AnimatedOpacity(
              opacity: _fade ? 0 : 1,
              duration: const Duration(milliseconds: 550),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.$1, c.$2],
                  ),
                ),
                child: Stack(children: [
                  Positioned.fill(
                    child: CustomPaint(
                        painter: GeoPatternPainter(color: Colors.white.withOpacity(0.06))),
                  ),
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.85, end: 1.0),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutBack,
                      builder: (context, v, child) =>
                          Transform.scale(scale: v, child: child),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(kAppName,
                            style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: c.$3,
                                decoration: TextDecoration.none)),
                        const SizedBox(height: 8),
                        Container(width: 90, height: 2, color: kGold),
                        const SizedBox(height: 10),
                        Text('كلام العلماء بنصّه ومصدره',
                            style: TextStyle(
                                fontSize: 16,
                                color: c.$3.withOpacity(0.9),
                                decoration: TextDecoration.none,
                                fontWeight: FontWeight.normal)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

class SanadApp extends StatelessWidget {
  const SanadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => MaterialApp(
        title: 'سند',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildTheme(Brightness.light, app.palette),
        darkTheme: buildTheme(Brightness.dark, app.palette),
        themeMode: effectiveThemeMode(),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(app.fontScale)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const SplashGate(child: HomeScreen()),
      ),
    );
  }
}

// ---------------------------------------------------------------------
//  الشاشة الرئيسية (المحادثة)
// ---------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _input = TextEditingController();
  final TextEditingController _drawerSearch = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Conversation? _conv;
  bool _loading = false;
  String? _error;
  String? _pending;
  int _animateFrom = -1; // رقم أحدث رسالة تظهر بالتدريج

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  Future<void> _startup() async {
    if (!mounted) return;
    final q = Uri.base.queryParameters;
    final b = int.tryParse(q['b'] ?? '');
    final view = q['v'] ?? '';
    final vb = bookOf(b ?? 0);
    if (view == 'lib') {
      Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LibraryScreen()));
    } else if (view == 'book' && vb != null) {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => BookScreen(book: vb)));
    } else if (view == 'toc' && vb != null) {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => TocScreen(book: vb)));
    } else if (view == 'card' && vb != null) {
      _openCard(vb, int.tryParse(q['p'] ?? '') ?? 1);
    } else if (b != null) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(
          jumpToStart: true,
          quote: Quote(
            bookId: b,
            bookName: q['n'] ?? bookTitleOf(b),
            vol: '',
            page: q['l'] ?? '',
            pageId: int.tryParse(q['p'] ?? '') ?? 0,
            text: '',
          ),
        ),
      ));
    } else if ((q['q'] ?? '').trim().isNotEmpty) {
      _send(q['q']);
    }
    if (kIsWeb) {
      Future<void>.delayed(const Duration(seconds: 3), localIndex.preload);
    } else {
      checkForUpdate(context);
    }
  }

  Future<void> _openCard(Book b, int pg) async {
    try {
      final quote = await localIndex.quoteAt(b, pg - 1, const <List<String>>[]);
      if (quote == null || !mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ShareCardScreen(quote: quote)));
    } catch (_) {}
  }

  @override
  void dispose() {
    _input.dispose();
    _drawerSearch.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 400,
            duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      }
    });
  }

  String _titleFrom(String raw) {
    final p = parseQuestion(raw);
    final t = p.issue.isNotEmpty ? p.issue : raw.trim();
    return t.length > 40 ? '${t.substring(0, 40)}…' : t;
  }

  Future<void> _send([String? preset]) async {
    final raw = (preset ?? _input.text).trim();
    if (raw.isEmpty || _loading) return;
    app.addRecent(raw);
    _input.clear();
    FocusScope.of(context).unfocus();
    final now = DateTime.now().millisecondsSinceEpoch;
    var c = _conv;
    if (c == null) {
      c = Conversation(id: '$now', title: _titleFrom(raw), updated: now);
      app.conversations.insert(0, c);
      _conv = c;
    }
    c.messages.add(ChatMessage(fromUser: true, text: raw));
    c.updated = now;
    app.saveConversations();
    setState(() {
      _loading = true;
      _error = null;
      _pending = raw;
    });
    _scrollDown();
    await _answer(raw);
  }

  Future<void> _answer(String raw) async {
    try {
      final reply = await engine.answer(raw);
      if (!mounted) return;
      final c = _conv;
      if (c == null) return;
      c.messages.add(reply);
      c.updated = DateTime.now().millisecondsSinceEpoch;
      app.saveConversations();
      setState(() {
        _loading = false;
        _pending = null;
        _animateFrom = c.messages.length - 1;
      });
      _scrollDown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = (e is ApiException && e.busy)
            ? 'تعذّر الاتصال بالخادم، حاول مرة أخرى بعد قليل'
            : 'تعذّر الاتصال بالخادم، حاول مرة أخرى';
      });
    }
  }

  void _retry() {
    final p = _pending;
    if (p == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _answer(p);
  }

  void _newChat() {
    setState(() {
      _conv = null;
      _error = null;
      _pending = null;
      _loading = false;
      _animateFrom = -1;
    });
  }

  void _openConversation(Conversation c) {
    Navigator.of(context).pop();
    setState(() {
      _conv = c;
      _error = null;
      _loading = false;
      _animateFrom = -1;
    });
    _scrollDown();
  }

  void _replyTo(String issue) {
    _input.text = 'بخصوص «$issue»: ';
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
  }

  // ------------------ القائمة الجانبية (المحادثات) ------------------

  Widget _buildDrawer() {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: StatefulBuilder(builder: (context, setLocal) {
          final q = _drawerSearch.text.trim();
          bool match(Conversation c) {
            if (q.isEmpty) return true;
            if (c.title.contains(q)) return true;
            return c.messages.any((m) =>
                m.text.contains(q) ||
                m.issue.contains(q) ||
                m.quotes.any((x) => x.text.contains(q)));
          }

          final list = app.conversations.where(match).toList()
            ..sort((a, b) {
              if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
              return b.updated.compareTo(a.updated);
            });
          final active = list.where((c) => !c.archived).toList();
          final archived = list.where((c) => c.archived).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Row(children: [
                  Text('المحادثات',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _newChat();
                    },
                    icon: const Icon(Icons.add_comment_outlined, size: 20),
                    label: const Text('محادثة جديدة'),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _drawerSearch,
                  onChanged: (_) => setLocal(() {}),
                  decoration: InputDecoration(
                    hintText: 'ابحث في المحادثات',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  children: [
                    if (active.isEmpty && archived.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('لا توجد محادثات بعد',
                            textAlign: TextAlign.center),
                      ),
                    ...active.map((c) => _conversationTile(c, setLocal)),
                    if (archived.isNotEmpty)
                      ExpansionTile(
                        leading: const Icon(Icons.archive_outlined),
                        title: Text('المؤرشفة (${archived.length})'),
                        children:
                            archived.map((c) => _conversationTile(c, setLocal)).toList(),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('كتب الشيخ'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const LibraryScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('عن الشيخ'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const AboutSheikhScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('عن سند'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen()));
                },
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _conversationTile(Conversation c, StateSetter setLocal) {
    final selected = identical(c, _conv);
    return ListTile(
      selected: selected,
      leading: Icon(c.pinned ? Icons.push_pin : Icons.chat_bubble_outline,
          size: 20),
      title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => _openConversation(c),
      onLongPress: () => _conversationMenu(c, setLocal),
    );
  }

  Future<void> _conversationMenu(Conversation c, StateSetter setLocal) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(c.pinned ? Icons.push_pin_outlined : Icons.push_pin),
            title: Text(c.pinned ? 'إلغاء التثبيت' : 'تثبيت في الأعلى'),
            onTap: () => Navigator.pop(ctx, 'pin'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('إعادة التسمية'),
            onTap: () => Navigator.pop(ctx, 'rename'),
          ),
          ListTile(
            leading: Icon(c.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
            title: Text(c.archived ? 'إخراج من الأرشيف' : 'أرشفة'),
            onTap: () => Navigator.pop(ctx, 'archive'),
          ),
          ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: const Text('نسخ المحادثة كاملة'),
            onTap: () => Navigator.pop(ctx, 'copy'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('حذف', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'pin':
        c.pinned = !c.pinned;
        app.saveConversations();
        break;
      case 'archive':
        c.archived = !c.archived;
        app.saveConversations();
        break;
      case 'rename':
        final name = await _askText('إعادة تسمية المحادثة', c.title);
        if (name != null && name.trim().isNotEmpty) {
          c.title = name.trim();
          app.saveConversations();
        }
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: _conversationText(c)));
        if (mounted) showToast(context, 'تم النسخ');
        break;
      case 'delete':
        final ok = await _confirm('حذف المحادثة', 'هل تريد حذف «${c.title}»؟');
        if (ok) {
          app.conversations.remove(c);
          if (identical(_conv, c)) _newChat();
          app.saveConversations();
        }
        break;
    }
    setLocal(() {});
    if (mounted) setState(() {});
  }

  String _conversationText(Conversation c) {
    final b = StringBuffer();
    for (final m in c.messages) {
      if (m.fromUser) {
        b.writeln('السؤال: ${m.text}\n');
        continue;
      }
      if (m.text.isNotEmpty) b.writeln(m.text);
      for (var i = 0; i < m.quotes.length; i++) {
        final q = m.quotes[i];
        b.writeln(i == 0 ? kScholarIntro : kScholarAgain);
        b.writeln('«${q.text}»');
        b.writeln('[📓${q.bookName} (صـ ${q.pageLabel})]\n');
      }
      if (m.notice.isNotEmpty) b.writeln('${m.notice}\n');
    }
    b.writeln('— من تطبيق سند');
    return b.toString();
  }

  Future<String?> _askText(String title, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('حفظ')),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String body) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نعم')),
        ],
      ),
    );
    return r == true;
  }

  // ------------------ بناء الشاشة ------------------

  @override
  Widget build(BuildContext context) {
    final c = _conv;
    final messages = c?.messages ?? <ChatMessage>[];
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(kAppName, style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'محادثة جديدة',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _newChat,
          ),
          IconButton(
            tooltip: 'المفضلة',
            icon: const Icon(Icons.star_outline),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const FavoritesScreen())),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      onDrawerChanged: (open) {
        if (open) setState(() {});
      },
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty && !_loading
                  ? _EmptyState(onAsk: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: messages.length + 1,
                      itemBuilder: (context, i) {
                        if (i == messages.length) return _statusArea();
                        final m = messages[i];
                        return m.fromUser
                            ? _UserBubble(text: m.text)
                            : _BotAnswer(
                                message: m,
                                animate: i >= _animateFrom && _animateFrom >= 0,
                                onReply: _replyTo,
                                onAsk: _send,
                              );
                      },
                    ),
            ),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _statusArea() {
    if (_loading) return const SearchingIndicator();
    final err = _error;
    if (err != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(children: [
          Text(err, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ]),
      );
    }
    return const SizedBox(height: 8);
  }

  Widget _suggestions() {
    final t = normArabic(_input.text.trim());
    if (t.length < 2) return const SizedBox.shrink();
    final pool = <String>[...app.recents, ...kTopics];
    final seen = <String>{};
    final out = <String>[];
    for (final x in pool) {
      if (x != _input.text.trim() && normArabic(x).contains(t) && seen.add(x)) {
        out.add(x);
      }
      if (out.length >= 4) break;
    }
    final heads = localIndex.headsNow;
    if (heads != null && t.length >= 3 && out.length < 4) {
      final needle = needleOf(t);
      for (var i = 0; i < heads.norms.length && out.length < 4; i++) {
        final title = heads.titles[i];
        if (title.length <= 60 && heads.norms[i].contains(needle) && seen.add(title)) {
          out.add(title);
        }
      }
    }
    if (out.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Wrap(
        spacing: 8,
        runSpacing: 0,
        children: out
            .map((x) => ActionChip(
                  avatar: const Icon(Icons.search, size: 16),
                  label: Text(x),
                  onPressed: () => _send(x),
                ))
            .toList(),
      ),
    );
  }

  Widget _inputBar() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [_suggestions(), _inputRow()],
      );

  Widget _inputRow() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: scheme.outlineVariant, width: 0.5)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: 'اكتب سؤالك، مثل: ما حكم النمص؟',
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _loading ? null : () => _send(),
          icon: const Icon(Icons.send_rounded),
        ),
      ]),
    );
  }
}

// ------------------ عناصر شاشة المحادثة ------------------

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    final c = heroColors();
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [c.$1, c.$2],
          ),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: CustomPaint(
                painter: GeoPatternPainter(color: Colors.white.withOpacity(0.07))),
          ),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(kAppName,
                  style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: c.$3)),
              const SizedBox(height: 6),
              Container(width: 70, height: 2, color: kGold),
              const SizedBox(height: 8),
              Text('كلام العلماء بنصّه ومصدره',
                  style: TextStyle(fontSize: 15, color: c.$3.withOpacity(0.92))),
              const SizedBox(height: 2),
              Text('ينقل ولا يفتي من عنده',
                  style: TextStyle(fontSize: 12, color: c.$3.withOpacity(0.7))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final void Function(String) onAsk;
  const _EmptyState({required this.onAsk});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lr = app.lastRead;
    final today = kTopics[DateTime.now().difference(DateTime(2024)).inDays % kTopics.length];
    final recents = app.recents.take(6).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _Hero(),
        const SizedBox(height: 20),
        if (app.dailyCard)
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onAsk(today),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Icon(Icons.wb_sunny_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مسألة اليوم',
                        style: TextStyle(
                            color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(today, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Text('اختر موضوعًا',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            ...kTopicChips
                .map((s) => ActionChip(label: Text(s), onPressed: () => onAsk(s))),
            ActionChip(
              avatar: const Icon(Icons.casino_outlined, size: 18),
              label: const Text('مسألة عشوائية'),
              onPressed: () => onAsk(kTopics[math.Random().nextInt(kTopics.length)]),
            ),
          ],
        ),
        if (recents.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('آخر ما بحثتَ عنه',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(width: 6),
              InkWell(
                onTap: app.clearRecents,
                child: Text('مسح',
                    style: TextStyle(color: scheme.primary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: recents
                .map((s) => ActionChip(
                      avatar: const Icon(Icons.history, size: 16),
                      label: Text(s),
                      onPressed: () => onAsk(s),
                    ))
                .toList(),
          ),
        ],
        if (lr != null) ...[
          const SizedBox(height: 22),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.bookmark_outline, size: 18),
              label: Text('أكمل القراءة: ${asStr(lr['n'])}، صـ ${asStr(lr['l'])}',
                  style: const TextStyle(fontSize: 13)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ReaderScreen(
                  quote: Quote(
                    bookId: asInt(lr['b']),
                    bookName: asStr(lr['n']),
                    vol: '',
                    page: asStr(lr['l']),
                    pageId: asInt(lr['pid']),
                    text: '',
                  ),
                ),
              )),
            ),
          ),
        ],
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(18),
            topEnd: Radius.circular(18),
            bottomEnd: Radius.circular(18),
            bottomStart: Radius.circular(4),
          ),
        ),
        child: SelectableText(text,
            style: TextStyle(
                fontSize: 16, height: 1.6, color: scheme.onPrimaryContainer)),
      ),
    );
  }
}

class _BotAnswer extends StatelessWidget {
  final ChatMessage message;
  final bool animate;
  final void Function(String issue) onReply;
  final void Function(String question) onAsk;
  const _BotAnswer(
      {required this.message,
      required this.animate,
      required this.onReply,
      required this.onAsk});

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    if (message.text.isNotEmpty) {
      parts.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(message.text, style: const TextStyle(fontSize: 16)),
      ));
    }
    for (var i = 0; i < message.quotes.length; i++) {
      final q = message.quotes[i];
      parts.add(Dismissible(
        key: ValueKey('reply-${q.key}-$i'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          onReply(q.issue.isEmpty ? q.bookName : q.issue);
          return false;
        },
        background: const Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(Icons.reply),
          ),
        ),
        child: QuoteCard(
            quote: q,
            intro: i == 0 ? kScholarIntro : kScholarAgain,
            terms: message.terms),
      ));
    }
    if (message.notice.isNotEmpty) {
      parts.add(_NoticeBox(text: message.notice));
    }
    if (message.terms.isNotEmpty && message.quotes.isNotEmpty) {
      parts.add(_TermsBar(terms: message.terms, onAsk: onAsk));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < parts.length; i++)
            animate ? FadeIn(delayMs: i * 260, child: parts[i]) : parts[i],
        ],
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  final String text;
  const _NoticeBox({required this.text});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A3420) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(height: 1.6)),
    );
  }
}

/// بطاقة كلام الشيخ مع المصدر والأزرار.
class QuoteCard extends StatelessWidget {
  final Quote quote;
  final String intro;
  final List<String> terms;
  const QuoteCard(
      {super.key,
      required this.quote,
      this.intro = kScholarIntro,
      this.terms = const <String>[]});

  Future<void> _copyMenu(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('نسخ بتنسيق تيليجرام'),
            onTap: () => Navigator.pop(ctx, 'tg'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('نسخ بتنسيق واتساب'),
            onTap: () => Navigator.pop(ctx, 'wa'),
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('نسخ عادي مع المصدر'),
            onTap: () => Navigator.pop(ctx, 'plain'),
          ),
          ListTile(
            leading: const Icon(Icons.format_clear),
            title: const Text('نسخ بدون تشكيل'),
            onTap: () => Navigator.pop(ctx, 'nt'),
          ),
          if (quote.title.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: const Text('نسخ المسألة كاملة (العنوان والجواب)'),
              onTap: () => Navigator.pop(ctx, 'full'),
            ),
        ]),
      ),
    );
    if (choice == null) return;
    final text = choice == 'full'
        ? '${quote.title}\n\n${plainFormat(quote)}'
        : choice == 'tg'
        ? telegramFormat(quote)
        : (choice == 'wa'
            ? whatsappFormat(quote)
            : (choice == 'nt' ? stripTashkeel(plainFormat(quote)) : plainFormat(quote)));
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showToast(context, 'تم النسخ');
  }

  Future<void> _editNote(BuildContext context) async {
    final ctrl = TextEditingController(text: app.noteOf(quote));
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ملاحظتي (خاصة بك)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'اكتب ملاحظتك هنا'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (res != null) app.setNote(quote, res);
  }

  Future<void> _report(BuildContext context) async {
    final t = 'بلاغ عن خطأ في سَنَد\n'
        'الكتاب: ${quote.bookName}\n'
        'الصفحة: ${quote.pageLabel}\n'
        'الرابط: ${quote.turathUrl}\n'
        'وصف الخطأ: ';
    await Clipboard.setData(ClipboardData(text: t));
    if (!context.mounted) return;
    showToast(context, 'نُسخ نص البلاغ، الصقه في محادثة المطور');
    openLink(context, kTelegram);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, color: kGold),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quote.heading.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(quote.heading,
                  style: TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.bold, height: 1.6)),
            ),
          Row(children: [
            Expanded(
              child: Text(intro,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ),
            Tooltip(
              message: 'النقل بنصّه من الكتاب، وليس تلخيصًا',
              triggerMode: TooltipTriggerMode.tap,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified_outlined, size: 15, color: scheme.primary),
                const SizedBox(width: 3),
                Text('بنصّه', style: TextStyle(fontSize: 11, color: scheme.primary)),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          SelectableText.rich(
            TextSpan(children: [
              const TextSpan(text: '«'),
              ...highlightSpans(quote.text, terms),
              const TextSpan(text: '»'),
            ]),
            style: const TextStyle(fontFamily: 'Amiri', fontSize: 20, height: 2.0),
            contextMenuBuilder: (context, state) {
              final value = state.textEditingValue;
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: state.contextMenuAnchors,
                buttonItems: [
                  ContextMenuButtonItem(
                    label: 'نسخ مع المصدر',
                    onPressed: () {
                      final sel = value.selection;
                      var t = (sel.isValid && !sel.isCollapsed)
                          ? sel.textInside(value.text)
                          : value.text;
                      t = t.replaceAll('«', '').replaceAll('»', '').trim();
                      Clipboard.setData(ClipboardData(
                          text: '«$t»\n[📓${quote.bookName} (صـ ${quote.pageLabel})]'));
                      ContextMenuController.removeAny();
                      showToast(context, 'تم النسخ');
                    },
                  ),
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.selectAll,
                    onPressed: () => state.selectAll(SelectionChangedCause.toolbar),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ActionChip(
                    avatar: Icon(Icons.menu_book_outlined,
                        size: 18, color: catColor(bookOf(quote.bookId)?.cat ?? 0)),
                    label: Text(
                      '${quote.bookName} (صـ ${quote.pageLabel})',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => ReaderScreen(quote: quote)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ListenableBuilder(
            listenable: app,
            builder: (context, _) {
              final n = app.noteOf(quote);
              if (n.isEmpty) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('ملاحظتي: $n', style: const TextStyle(height: 1.6)),
              );
            },
          ),
          Wrap(
            children: [
              IconButton(
                tooltip: 'نسخ',
                icon: const Icon(Icons.copy_outlined, size: 20),
                onPressed: () => _copyMenu(context),
              ),
              ListenableBuilder(
                listenable: app,
                builder: (context, _) {
                  final fav = app.isFavorite(quote);
                  return IconButton(
                    tooltip: 'حفظ',
                    icon: Icon(fav ? Icons.star : Icons.star_outline,
                        size: 20, color: fav ? const Color(0xFFC99A06) : null),
                    onPressed: () {
                      final added = app.toggleFavorite(quote);
                      showToast(context, added ? 'تم الحفظ' : 'أُزيلت من المفضلة');
                    },
                  );
                },
              ),
              IconButton(
                tooltip: 'مشاركة كصورة',
                icon: const Icon(Icons.image_outlined, size: 20),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => ShareCardScreen(quote: quote))),
              ),
              IconButton(
                tooltip: 'فتح في تراث',
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () => openLink(context, quote.turathUrl),
              ),
              IconButton(
                tooltip: 'نسخ رابط للمشاركة',
                icon: const Icon(Icons.link, size: 20),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: quoteLink(quote)));
                  if (context.mounted) showToast(context, 'تم نسخ الرابط');
                },
              ),
              IconButton(
                tooltip: 'إبلاغ عن خطأ',
                icon: const Icon(Icons.flag_outlined, size: 20),
                onPressed: () => _report(context),
              ),
              ListenableBuilder(
                listenable: app,
                builder: (context, _) => IconButton(
                  tooltip: 'للقراءة لاحقًا',
                  icon: Icon(
                      app.isLater(quote) ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                      color: app.isLater(quote) ? scheme.primary : null),
                  onPressed: () {
                    final added = app.toggleLater(quote);
                    showToast(context, added ? 'أُضيف للقراءة لاحقًا' : 'أُزيل من القراءة لاحقًا');
                  },
                ),
              ),
              ListenableBuilder(
                listenable: app,
                builder: (context, _) => IconButton(
                  tooltip: 'ملاحظتي',
                  icon: Icon(
                      app.noteOf(quote).isEmpty ? Icons.edit_note : Icons.sticky_note_2,
                      size: 22,
                      color: app.noteOf(quote).isEmpty ? null : scheme.primary),
                  onPressed: () => _editNote(context),
                ),
              ),
            ],
          ),
        ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// «جارٍ البحث في كتب الشيخ ابن عثيمين...» مع عدسة متحركة.
class SearchingIndicator extends StatefulWidget {
  const SearchingIndicator({super.key});
  @override
  State<SearchingIndicator> createState() => _SearchingIndicatorState();
}

class _SearchingIndicatorState extends State<SearchingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value * 2 * math.pi;
            return Transform.translate(
              offset: Offset(math.cos(t) * 4, math.sin(t) * 4),
              child: child,
            );
          },
          child: Icon(Icons.search, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ValueListenableBuilder<String>(
            valueListenable: localIndex.status,
            builder: (context, st, _) => Text(
                st.isEmpty ? 'جارٍ البحث في كتب الشيخ ابن عثيمين...' : st,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ),
      ]),
    );
  }
}

/// يُظهر العنصر بالتدريج.
class FadeIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const FadeIn({super.key, required this.child, this.delayMs = 0});
  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: const Duration(milliseconds: 320),
      child: AnimatedSlide(
        offset: _show ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------
//  صفحة القراءة (مع التظليل بالأصفر)
// ---------------------------------------------------------------------

// ---------------------------------------------------------------------
//  الإعدادات
// ---------------------------------------------------------------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _testing = false;

  Future<void> _diagnose() async {
    setState(() => _testing = true);
    String result;
    try {
      result = await api.diagnose();
    } catch (e) {
      result = 'تعذّر الاتصال بالخادم.\nالتفاصيل: $e';
    }
    if (!mounted) return;
    setState(() => _testing = false);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('فحص الاتصال بتراث'),
        content: SingleChildScrollView(child: SelectableText(result)),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result));
              Navigator.pop(ctx);
            },
            child: const Text('نسخ النتيجة'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسنًا')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          children: [
            const _SectionTitle('نمط الألوان'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'green', label: Text('أخضر وذهبي')),
                  ButtonSegment(value: 'black', label: Text('أسود وذهبي')),
                  ButtonSegment(value: 'paper', label: Text('ورقي')),
                ],
                selected: {app.palette},
                onSelectionChanged: (v) => app.setPalette(v.first),
              ),
            ),
            if (app.palette != 'green')
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text('هذا النمط له وضعه الخاص، واختيار فاتح/داكن أدناه يعمل مع النمط الأخضر.',
                    style: TextStyle(fontSize: 12)),
              ),
            const _SectionTitle('المظهر'),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              groupValue: app.themeMode,
              onChanged: (v) => app.setTheme(v ?? ThemeMode.light),
              title: const Text('فاتح'),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              groupValue: app.themeMode,
              onChanged: (v) => app.setTheme(v ?? ThemeMode.dark),
              title: const Text('داكن (الوضع الليلي)'),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              groupValue: app.themeMode,
              onChanged: (v) => app.setTheme(v ?? ThemeMode.system),
              title: const Text('تلقائي حسب الهاتف'),
            ),
            const _SectionTitle('حجم الخط'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0.9, label: Text('صغير')),
                  ButtonSegment(value: 1.0, label: Text('متوسط')),
                  ButtonSegment(value: 1.2, label: Text('كبير')),
                  ButtonSegment(value: 1.45, label: Text('أكبر')),
                ],
                selected: {app.fontScale},
                onSelectionChanged: (s) => app.setFontScale(s.first),
              ),
            ),
            const _SectionTitle('الصفحة الرئيسية والبحث'),
            SwitchListTile(
              secondary: const Icon(Icons.wb_sunny_outlined),
              title: const Text('مسألة اليوم'),
              subtitle: const Text('مسألة جديدة كل يوم في الصفحة الرئيسية'),
              value: app.dailyCard,
              onChanged: app.setDaily,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('ترتيب النتائج'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'fatwa', label: Text('الفتاوى أولًا')),
                  ButtonSegment(value: 'sharh', label: Text('الشروح أولًا')),
                  ButtonSegment(value: 'any', label: Text('الأنسب')),
                ],
                selected: {app.order},
                onSelectionChanged: (s) => app.setOrder(s.first),
              ),
            ),
            const _SectionTitle('البيانات'),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('حذف كل المحادثات'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حذف كل المحادثات'),
                    content: const Text('لا يمكن التراجع عن هذا. هل أنت متأكد؟'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('إلغاء')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('حذف')),
                    ],
                  ),
                );
                if (ok == true) {
                  app.clearHistory();
                  if (context.mounted) showToast(context, 'تم الحذف');
                }
              },
            ),
            ListTile(
              leading: _testing
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_tethering),
              title: const Text('فحص الاتصال بتراث'),
              subtitle: const Text('إن ظهرت مشكلة، انسخ النتيجة وأرسلها للمطور'),
              onTap: _testing ? null : _diagnose,
            ),
            ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: const Text('فحص التحديث'),
              subtitle: Text('الإصدار $kVersion'),
              onTap: () => checkForUpdate(context, manual: true),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('نسخ احتياطي للمفضلة'),
              subtitle: const Text('ينسخ المفضلة إلى الحافظة لتحفظها في ملاحظة'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: app.exportFavorites()));
                if (context.mounted) showToast(context, 'تم نسخ المفضلة');
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('تصدير المفضلة ملفًا'),
              subtitle: const Text('ملف تحفظه أو ترسله لنفسك'),
              onTap: () async {
                try {
                  final bytes = Uint8List.fromList(utf8.encode(app.exportFavorites()));
                  await Share.shareXFiles([
                    XFile.fromData(bytes,
                        mimeType: 'application/json', name: 'sanad-favorites.json'),
                  ]);
                } catch (_) {
                  if (context.mounted) showToast(context, 'تعذّر تصدير الملف');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_for_offline_outlined),
              title: const Text('استرجاع المفضلة'),
              subtitle: const Text('الصق النسخة المنسوخة ثم اضغط هنا'),
              onTap: () async {
                final d = await Clipboard.getData('text/plain');
                final n = app.importFavorites(d?.text ?? '');
                if (context.mounted) {
                  showToast(context, n < 0 ? 'لم أجد نسخة صالحة في الحافظة' : 'أُضيف $n نقل');
                }
              },
            ),
            const _SectionTitle('الموقع والتطبيق'),
            if (kIsWeb)
              ListTile(
                leading: const Icon(Icons.add_to_home_screen),
                title: const Text('تثبيت على الشاشة الرئيسية'),
                subtitle: const Text('اختياري، ليعمل كأنه تطبيق'),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تثبيت سَنَد'),
                    content: const Text(
                      'آيفون (سفاري): اضغط زر المشاركة ثم «إضافة إلى الشاشة الرئيسية».\n\n'
                      'أندرويد (كروم): اضغط القائمة ⋮ ثم «تثبيت التطبيق» أو «إضافة إلى الشاشة الرئيسية».',
                      style: TextStyle(height: 1.8),
                    ),
                    actions: [
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx), child: const Text('حسنًا')),
                    ],
                  ),
                ),
              ),
            if (kIsWeb)
              ListTile(
                leading: const Icon(Icons.android),
                title: const Text('حمّل تطبيق الأندرويد'),
                onTap: () => openLink(context, kApkUrl),
              ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: const Text('رمز QR للموقع'),
              onTap: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('رمز QR'),
                  content: SizedBox(
                    width: 240,
                    height: 240,
                    child: QrImageView(data: kSiteUrl, backgroundColor: Colors.white),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: kSiteUrl));
                        Navigator.pop(ctx);
                      },
                      child: const Text('نسخ الرابط'),
                    ),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('شارك سَنَد مع صديق'),
              onTap: () async {
                const msg = 'سَنَد: كلام الشيخ ابن عثيمين رَحِمَهُ الله بنصّه ومصدره من كتبه.\n$kSiteUrl';
                try {
                  await Share.share(msg);
                } catch (_) {
                  await Clipboard.setData(const ClipboardData(text: msg));
                  if (context.mounted) showToast(context, 'تم نسخ الرسالة');
                }
              },
            ),
            const _SectionTitle('عن التطبيق'),
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: const Text('قرأتَ هذا الشهر'),
              subtitle: Text('${app.monthReads} صفحة'),
            ),
            ListTile(
              leading: const Icon(Icons.local_fire_department_outlined),
              title: const Text('أيام القراءة المتتالية'),
              subtitle: Text('${app.streakNow} يوم'),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('كيف أستخدم التطبيق؟'),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const HowToScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('عن الشيخ'),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutSheikhScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('عن سند'),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.telegram),
              title: const Text('تواصل مع المطور'),
              onTap: () => openLink(context, kTelegram),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(text,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold)),
      );
}

// ---------------------------------------------------------------------
//  عن سند
// ---------------------------------------------------------------------

class AboutSheikhScreen extends StatelessWidget {
  const AboutSheikhScreen({super.key});

  Widget _item(BuildContext context, String title, String body) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(fontFamily: 'Amiri', fontSize: 18, height: 1.9)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عن الشيخ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Hero(),
          const SizedBox(height: 16),
          _item(context, 'الاسم',
              'أبو عبد الله محمد بن صالح بن محمد العثيمين الوهيبي التميمي رَحِمَهُ الله.'),
          _item(context, 'المولد',
              'وُلد ليلة السابع والعشرين من رمضان سنة 1347هـ في عنيزة، إحدى مدن القصيم في المملكة العربية السعودية.'),
          _item(context, 'طلبه للعلم',
              'حفظ القرآن صغيرًا، وتتلمذ على الشيخ عبد الرحمن بن ناصر السعدي، واتصل بالشيخ عبد العزيز بن باز وقرأ عليه.'),
          _item(context, 'التدريس',
              'باشر التعليم منذ سنة 1370هـ، وكان أستاذًا في كلية الشريعة بفرع جامعة الإمام محمد بن سعود الإسلامية بالقصيم، وعضوًا في هيئة كبار العلماء.'),
          _item(context, 'وفاته',
              'توفي رَحِمَهُ الله يوم الأربعاء 15 شوال 1421هـ، الموافق 10 يناير 2001م، ودُفن بمكة المكرمة.'),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'ترجمة موجزة مأخوذة من مواقع علمية معروفة، وللاستزادة يُرجع إلى كتب التراجم وسيرته.',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('عن سند')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Text(kAppName,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          const Center(child: Text('الإصدار $kVersion')),
          const SizedBox(height: 20),
          const Text('منهج التطبيق',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            'سند ينقل كلام العلماء بنصّه كما هو في كتبهم، مع اسم الكتاب والجزء والصفحة، '
            'ولا يفتي من عنده. والمسائل الخاصة يُسأل عنها أهل العلم مباشرة.',
            style: TextStyle(height: 1.8),
          ),
          const SizedBox(height: 18),
          const Text('الكتب المعتمدة حاليًا',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          ...kBooks.map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• ${b.title}'),
              )),
          const SizedBox(height: 8),
          const Text('المصدر: موقع «تراث» (app.turath.io)'),
          const SizedBox(height: 18),
          const Text('المطوّر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(kDeveloper),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => openLink(context, kTelegram),
            icon: const Icon(Icons.telegram),
            label: const Text('تواصل مع المطور'),
          ),
        ],
      ),
    );
  }
}
