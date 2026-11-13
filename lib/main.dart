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

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------
//  الإعدادات الثابتة
// ---------------------------------------------------------------------

const String kAppName = 'سَنَد';
const String kVersion = '1.1.0';
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
const Color kHighlight = Color(0xFFFFF176);

class Book {
  final int id;
  final String title;
  const Book(this.id, this.title);
}

/// الكتب المعتمدة في الإصدار الأول (بالترتيب الذي يُعرض به الجواب).
const List<Book> kBooks = [
  Book(12293, 'مجموع فتاوى ورسائل العثيمين'),
  Book(9260, 'شرح رياض الصالحين'),
  Book(7339, 'القول المفيد على كتاب التوحيد'),
  Book(11166, 'حكم تارك الصلاة'),
  Book(11224, 'رسالة في زكاة الحلي'),
  Book(31341, 'رسالة في الدماء الطبيعية للنساء'),
];

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

  const Quote({
    required this.bookId,
    required this.bookName,
    required this.vol,
    required this.page,
    required this.pageId,
    required this.text,
    this.issue = '',
  });

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
      );

  Map<String, dynamic> toJson() => {
        'b': bookId,
        'n': bookName,
        'v': vol,
        'p': page,
        'pid': pageId,
        't': text,
        'i': issue,
      };

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        bookId: asInt(j['b']),
        bookName: asStr(j['n']),
        vol: asStr(j['v']),
        page: asStr(j['p']),
        pageId: asInt(j['pid']),
        text: asStr(j['t']),
        issue: asStr(j['i']),
      );
}

class ChatMessage {
  final bool fromUser;
  final String text; // سؤال المستخدم، أو رد السلام
  final List<Quote> quotes;
  final String notice; // مثل: لم أجد للشيخ كلامًا
  final String issue;

  ChatMessage({
    required this.fromUser,
    this.text = '',
    List<Quote>? quotes,
    this.notice = '',
    this.issue = '',
  }) : quotes = quotes ?? <Quote>[];

  Map<String, dynamic> toJson() => {
        'u': fromUser,
        't': text,
        'q': quotes.map((q) => q.toJson()).toList(),
        'n': notice,
        'i': issue,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        fromUser: j['u'] == true,
        text: asStr(j['t']),
        quotes: asMapList(j['q']).map((m) => Quote.fromJson(m)).toList(),
        notice: asStr(j['n']),
        issue: asStr(j['i']),
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
    '📜 ${q.issue.isEmpty ? 'من كلام الشيخ ابن عثيمين' : q.issue}\n\n'
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
  PageData(this.text, this.label);
}

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

  /// يبحث في كتاب واحد ويرجع حتى [limit] نتائج.
  Future<List<Quote>> searchBook(Book book, String query, List<String> terms,
      {int limit = 3}) async {
    final body = await _get('/search', {
      'q': query,
      'ver': '3',
      'book': '${book.id}',
    });
    final out = <Quote>[];
    final seenPages = <int>{};
    for (final it in _items(body)) {
      final m = flatten(it);
      final bid = asInt(m['book_id']);
      if (bid != 0 && bid != book.id) continue; // نتيجة من كتاب آخر: تُترك
      final pageId = asInt(m['page_id'] ?? m['pg'] ?? m['id']);
      if (pageId > 0 && !seenPages.add(pageId)) continue;
      var text = cleanHtml(asStr(m['snip']));
      if (text.isEmpty) text = cleanHtml(asStr(m['text']));
      if (text.isEmpty) continue;
      text = excerptAround(text, terms);
      out.add(Quote(
        bookId: book.id,
        bookName: book.title,
        vol: asStr(m['vol']),
        page: asStr(m['page']),
        pageId: pageId,
        text: text,
      ));
      if (out.length >= limit) break;
    }
    return out;
  }

  /// يبحث في كل الكتب المعتمدة بالترتيب.
  Future<List<Quote>> searchAll(String query, List<String> terms) async {
    final all = <Quote>[];
    var failures = 0;
    for (final b in kBooks) {
      try {
        all.addAll(await searchBook(b, query, terms));
      } on ApiException catch (e) {
        if (e.busy) rethrow;
        failures++;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (failures == kBooks.length) throw ApiException('all failed');
    return all;
  }

  Future<PageData> page(int bookId, int pg) async {
    if (kIsWeb) return localIndex.page(bookId, pg);
    final body = await _get('/page', {
      'book_id': '$bookId',
      'pg': '$pg',
      'ver': '3',
    });
    dynamic node = body;
    if (body is Map && body['data'] is Map) node = body['data'];
    final m = flatten(node);
    final text = cleanHtml(asStr(m['text']));
    final vol = asStr(m['vol']).trim();
    final pageNo = asStr(m['page']).trim();
    final label = pageNo.isEmpty
        ? ''
        : ((vol.isEmpty || vol == '0') ? pageNo : '$vol/$pageNo');
    return PageData(text, label);
  }

  /// فحص الاتصال: يرجع وصفًا مختصرًا لنتيجة بحث تجريبي.
  Future<String> diagnose() async {
    if (kIsWeb) {
      final lb = await localIndex.page(11224, 5);
      return 'نجح قراءة ملفات الكتب مباشرة من تراث.\nمقتطف: ${lb.text.length > 120 ? lb.text.substring(0, 120) : lb.text}';
    }
    final body =
        await _get('/search', {'q': 'الصلاة', 'ver': '3', 'book': '12293'});
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
    return b.toString();
  }
}

final TurathApi api = TurathApi();

// ---------------------------------------------------------------------
//  البحث المحلي في ملفات الكتب (يعمل في المتصفح بلا حدّ للطلبات)
// ---------------------------------------------------------------------

int _nc(int c) {
  if ((c >= 0x064B && c <= 0x065F) || c == 0x0670 || c == 0x0640) return -1;
  if (c == 0x0623 || c == 0x0625 || c == 0x0622 || c == 0x0671) return 0x0627;
  if (c == 0x0649) return 0x064A;
  if (c == 0x0629) return 0x0647;
  if (c == 10 || c == 13 || c == 9 || c == 0xA0) return 32;
  return c;
}

/// يوحّد النص للمقارنة: بلا تشكيل ولا تطويل، وتُوحَّد الألف والياء والتاء المربوطة.
/// إن مُرِّرت [map] فتُملأ بموضع كل حرف في النص الأصلي.
String _normRaw(String raw, {List<int>? map, bool tags = true}) {
  final sb = StringBuffer();
  var inTag = false;
  for (var i = 0; i < raw.length; i++) {
    final c = raw.codeUnitAt(i);
    if (tags) {
      if (c == 60) {
        inTag = true;
        continue;
      }
      if (inTag) {
        if (c == 62) inTag = false;
        continue;
      }
    }
    final m = _nc(c);
    if (m < 0) continue;
    sb.writeCharCode(m);
    map?.add(i);
  }
  return sb.toString();
}

String normArabic(String s) => _normRaw(s, tags: false);

class LocalPage {
  final String vol;
  final String page;
  final String raw;
  final String norm;
  const LocalPage(this.vol, this.page, this.raw, this.norm);
}

class LocalBook {
  final Book book;
  final List<LocalPage> pages;
  const LocalBook(this.book, this.pages);
}

class LocalIndex {
  final Map<int, Future<LocalBook>> _books = {};
  final ValueNotifier<String> status = ValueNotifier<String>('');
  int _done = 0;

  Future<LocalBook> _load(Book b) =>
      _books.putIfAbsent(b.id, () => _fetch(b));

  Future<LocalBook> _fetch(Book b) async {
    if (status.value.isEmpty) {
      status.value = 'جارٍ تجهيز كتب الشيخ (أول مرة فقط)... $_done/${kBooks.length}';
    }
    try {
      final r = await http
          .get(Uri.https('files.turath.io', '/books-v3/${b.id}.json'))
          .timeout(const Duration(seconds: 180));
      if (r.statusCode != 200) throw ApiException('HTTP ${r.statusCode}');
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      final list = d is Map ? d['pages'] : null;
      if (list is! List) throw ApiException('bad book file');
      final pages = <LocalPage>[];
      for (var i = 0; i < list.length; i++) {
        final p = list[i];
        final raw = p is Map ? asStr(p['text']) : '';
        var pg = p is Map ? asStr(p['page']) : '';
        if (pg == 'None' || pg == 'null') pg = '';
        pages.add(LocalPage(
            p is Map ? asStr(p['vol']) : '', pg, raw, _normRaw(raw)));
        if (i % 600 == 599) await Future<void>.delayed(Duration.zero);
      }
      _done++;
      status.value = _done >= kBooks.length
          ? ''
          : 'جارٍ تجهيز كتب الشيخ (أول مرة فقط)... $_done/${kBooks.length}';
      return LocalBook(b, pages);
    } on ApiException {
      _books.remove(b.id);
      status.value = '';
      rethrow;
    } catch (e) {
      _books.remove(b.id);
      status.value = '';
      throw ApiException('local: $e');
    }
  }

  Future<void> preload() async {
    try {
      await Future.wait(kBooks.map(_load));
    } catch (_) {}
  }

  Future<List<Quote>> searchAll(List<String> terms, {int perBook = 3}) async {
    final nt = terms.map(normArabic).where((t) => t.isNotEmpty).toList();
    if (nt.isEmpty) return <Quote>[];
    final books = await Future.wait(kBooks.map(_load));
    final out = <Quote>[];
    for (final lb in books) {
      out.addAll(_searchBook(lb, nt, perBook));
    }
    return out;
  }

  List<Quote> _searchBook(LocalBook lb, List<String> nt, int limit) {
    final scored = <MapEntry<int, double>>[];
    for (var i = 0; i < lb.pages.length; i++) {
      final n = lb.pages[i].norm;
      var ok = true;
      var occ = 0;
      var minP = 1 << 30;
      var maxP = -1;
      for (final t in nt) {
        final p = n.indexOf(t);
        if (p < 0) {
          ok = false;
          break;
        }
        minP = math.min(minP, p);
        maxP = math.max(maxP, p);
        var c = 1;
        var q = n.indexOf(t, p + t.length);
        while (q >= 0 && c < 6) {
          c++;
          q = n.indexOf(t, q + t.length);
        }
        occ += c;
      }
      if (!ok) continue;
      final spread = nt.length > 1 ? (maxP - minP) : 0;
      scored.add(MapEntry(i, occ + 12 / (1 + spread / 150.0)));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    final out = <Quote>[];
    for (final e in scored.take(limit)) {
      final q = _extract(lb, e.key, nt);
      if (q != null) out.add(q);
    }
    return out;
  }

  Quote? _extract(LocalBook lb, int i, List<String> nt) {
    final pg = lb.pages[i];
    final raw = pg.raw;
    final map = <int>[];
    final n = _normRaw(raw, map: map);
    var p = -1;
    for (final t in nt) {
      final q = n.indexOf(t);
      if (q >= 0 && (p < 0 || q < p)) p = q;
    }
    final rawPos = p >= 0 && p < map.length ? map[p] : 0;
    const tag = '<span data-type="title"';
    var s = raw.lastIndexOf(tag, rawPos);
    if (s < 0) s = 0;
    var e = raw.indexOf(tag, rawPos);
    if (e < 0) e = raw.length;
    final text = _excerpt(cleanHtml(raw.substring(s, e)), nt);
    if (text.isEmpty) return null;
    return Quote(
      bookId: lb.book.id,
      bookName: lb.book.title,
      vol: pg.vol,
      page: pg.page,
      pageId: i + 1,
      text: text,
    );
  }

  String _excerpt(String cleaned, List<String> nt, {int size = 1300}) {
    if (cleaned.length <= size) return cleaned;
    final map = <int>[];
    final n = _normRaw(cleaned, map: map, tags: false);
    var p = -1;
    for (final t in nt) {
      final q = n.indexOf(t);
      if (q >= 0 && (p < 0 || q < p)) p = q;
    }
    final c = p >= 0 && p < map.length ? map[p] : 0;
    var start = math.max(0, c - 250);
    var end = math.min(cleaned.length, start + size);
    if (start > 0) {
      final sp = cleaned.indexOf(' ', start);
      if (sp >= 0 && sp < start + 40) start = sp + 1;
    }
    if (end < cleaned.length) {
      final sp = cleaned.lastIndexOf(' ', end);
      if (sp > start + size ~/ 2) end = sp;
    }
    return '${start > 0 ? '…' : ''}${cleaned.substring(start, end).trim()}'
        '${end < cleaned.length ? '…' : ''}';
  }

  Future<PageData> page(int bookId, int pg) async {
    final b = kBooks.firstWhere((x) => x.id == bookId,
        orElse: () => throw ApiException('unknown book'));
    final lb = await _load(b);
    if (pg < 1 || pg > lb.pages.length) return PageData('', '');
    final p = lb.pages[pg - 1];
    final label = p.page.isEmpty
        ? ''
        : ((p.vol.isEmpty || p.vol == '0') ? p.page : '${p.vol}/${p.page}');
    return PageData(cleanHtml(p.raw), label);
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
  'شرعًا', 'الشرع', 'الإسلام', 'الاسلام',
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
  Future<List<Quote>> _search(String query, List<String> terms) async {
    final cached = app.cached(query);
    if (cached != null) return cached;
    List<Quote> found;
    if (kIsWeb) {
      found = await localIndex.searchAll(terms);
    } else {
      try {
        found = await api.searchAll(query, terms);
      } on ApiException {
        found = await localIndex.searchAll(terms);
      }
    }
    if (found.isNotEmpty) app.putCache(query, found);
    return found;
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
    var quotes = await _search(q.terms.join(' '), q.terms);
    if (quotes.isEmpty && q.terms.length > 1) {
      final sorted = [...q.terms]..sort((a, b) => b.length.compareTo(a.length));
      quotes = await _search(sorted.first, [sorted.first]);
    }
    return ChatMessage(
      fromUser: false,
      text: greet,
      issue: q.issue,
      quotes: quotes.map((x) => x.withIssue(q.issue)).toList(),
      notice: quotes.isEmpty
          ? 'لم أجد للشيخ ابن عثيمين رَحِمَهُ الله كلامًا في هذه المسألة في الكتب المضافة حاليًا.'
          : '',
    );
  }
}

final AnswerEngine engine = AnswerEngine();

// ---------------------------------------------------------------------
//  التطبيق
// ---------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  runApp(const SanadApp());
}

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: kBrand, brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        b == Brightness.light ? const Color(0xFFF6F8F7) : const Color(0xFF101414),
  );
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
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: app.themeMode,
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(app.fontScale)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const HomeScreen(),
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  Future<void> _startup() async {
    if (!mounted) return;
    final q = Uri.base.queryParameters;
    final b = int.tryParse(q['b'] ?? '');
    if (b != null) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(
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
      localIndex.preload();
    } else {
      checkForUpdate(context);
    }
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

  Widget _inputBar() {
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
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(Icons.menu_book_rounded, size: 44, color: scheme.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(kAppName,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary)),
        const SizedBox(height: 6),
        Text('كلام الشيخ ابن عثيمين رَحِمَهُ الله بنصّه ومصدره',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 4),
        Text('ينقل كلام العلماء ولا يفتي من عنده',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 22),
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
          borderRadius: BorderRadius.circular(18),
        ),
        child: SelectableText(text, style: const TextStyle(fontSize: 16, height: 1.6)),
      ),
    );
  }
}

class _BotAnswer extends StatelessWidget {
  final ChatMessage message;
  final bool animate;
  final void Function(String issue) onReply;
  const _BotAnswer(
      {required this.message, required this.animate, required this.onReply});

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
        child: QuoteCard(quote: q, intro: i == 0 ? kScholarIntro : kScholarAgain),
      ));
    }
    if (message.notice.isNotEmpty) {
      parts.add(_NoticeBox(text: message.notice));
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
  const QuoteCard({super.key, required this.quote, this.intro = kScholarIntro});

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
        ]),
      ),
    );
    if (choice == null) return;
    final text = choice == 'tg'
        ? telegramFormat(quote)
        : (choice == 'wa'
            ? whatsappFormat(quote)
            : (choice == 'nt' ? stripTashkeel(plainFormat(quote)) : plainFormat(quote)));
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showToast(context, 'تم النسخ');
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quote.issue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(quote.issue,
                  style: TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.bold)),
            ),
          Text(intro,
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SelectableText(
            '«${quote.text}»',
            style: const TextStyle(fontSize: 17, height: 1.9),
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
                    avatar: Icon(Icons.menu_book_outlined, size: 18, color: scheme.primary),
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
          Row(
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
            ],
          ),
        ],
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

class ReaderScreen extends StatefulWidget {
  final Quote quote;
  const ReaderScreen({super.key, required this.quote});
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int _pg;
  late String _label;
  String _text = '';
  bool _loading = true;
  bool _failed = false;
  double _size = 19;

  @override
  void initState() {
    super.initState();
    _pg = widget.quote.pageId;
    _label = widget.quote.pageLabel;
    _load();
  }

  Future<void> _load() async {
    if (_pg <= 0) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final p = await api.page(widget.quote.bookId, _pg);
      if (!mounted) return;
      setState(() {
        _text = p.text;
        if (p.label.isNotEmpty) _label = p.label;
        _failed = p.text.isEmpty;
        _loading = false;
      });
      if (!_failed) {
        app.setLastRead(widget.quote.bookId, widget.quote.bookName, _pg, _label);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _go(int delta) {
    final next = _pg + delta;
    if (next < 1) return;
    _pg = next;
    _load();
  }

  /// يبحث عن موضع كلام الشيخ في الصفحة ليظلّله.
  TextRange? _findHighlight() {
    if (_pg != widget.quote.pageId) return null;
    var q = widget.quote.text.replaceAll('…', '').trim();
    if (q.length < 12) return null;
    final full = _text.indexOf(q);
    if (full >= 0) return TextRange(start: full, end: full + q.length);
    // نجرّب قطعة من أول النص ثم من وسطه.
    final probeLen = math.min(30, q.length);
    final probes = <String>[
      q.substring(0, probeLen),
      q.substring(q.length ~/ 2 - probeLen ~/ 2, q.length ~/ 2 + probeLen ~/ 2),
    ];
    for (var i = 0; i < probes.length; i++) {
      final at = _text.indexOf(probes[i]);
      if (at >= 0) {
        final start = i == 0 ? at : math.max(0, at - q.length ~/ 2);
        final end = math.min(_text.length, start + q.length);
        return TextRange(start: start, end: end);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = widget.quote;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.bookName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
            Text('صـ $_label',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تصغير الخط',
            icon: const Icon(Icons.text_decrease),
            onPressed: () => setState(() => _size = math.max(14, _size - 2)),
          ),
          IconButton(
            tooltip: 'تكبير الخط',
            icon: const Icon(Icons.text_increase),
            onPressed: () => setState(() => _size = math.min(32, _size + 2)),
          ),
          IconButton(
            tooltip: 'فتح في تراث',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openLink(context,
                _pg > 0 ? 'https://app.turath.io/book/${q.bookId}/$_pg' : q.turathUrl),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_failed ? _fallback(scheme) : _pageBody(scheme)),
      bottomNavigationBar: _pg > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _loading ? null : () => _go(-1),
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('الصفحة السابقة'),
                    ),
                    TextButton.icon(
                      onPressed: _loading ? null : () => _go(1),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('الصفحة التالية'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _pageBody(ColorScheme scheme) {
    final style = TextStyle(fontSize: _size, height: 1.95, color: scheme.onSurface);
    final r = _findHighlight();
    final InlineSpan span;
    if (r == null) {
      span = TextSpan(text: _text, style: style);
    } else {
      span = TextSpan(style: style, children: [
        TextSpan(text: _text.substring(0, r.start)),
        TextSpan(
          text: _text.substring(r.start, r.end),
          style: const TextStyle(backgroundColor: kHighlight, color: Colors.black),
        ),
        TextSpan(text: _text.substring(r.end)),
      ]);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: SelectableText.rich(TextSpan(children: [span])),
    );
  }

  Widget _fallback(ColorScheme scheme) {
    final q = widget.quote;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _NoticeBox(text: 'تعذّر تحميل الصفحة كاملة الآن. هذا هو النص المنقول، ويمكنك فتح الصفحة في «تراث».'),
        const SizedBox(height: 16),
        if (q.text.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kHighlight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText('«${q.text}»',
                style: TextStyle(fontSize: _size, height: 1.9, color: Colors.black)),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => openLink(context, q.turathUrl),
          icon: const Icon(Icons.open_in_new),
          label: const Text('فتح الصفحة في تراث'),
        ),
        const SizedBox(height: 8),
        if (_pg > 0)
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
//  كتب الشيخ
// ---------------------------------------------------------------------

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كتب الشيخ ابن عثيمين')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: kBooks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final b = kBooks[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(b.title),
              subtitle: const Text('ابدأ القراءة من أول الكتاب'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ReaderScreen(
                  quote: Quote(
                    bookId: b.id,
                    bookName: b.title,
                    vol: '',
                    page: '1',
                    pageId: 1,
                    text: '',
                  ),
                ),
              )),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------
//  المفضلة
// ---------------------------------------------------------------------

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (app.favorites.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('لم تحفظ شيئًا بعد.\nاضغط النجمة تحت أي فتوى لحفظها هنا.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: app.favorites.map((q) => QuoteCard(quote: q)).toList(),
          );
        },
      ),
    );
  }
}

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
                ],
                selected: {app.fontScale},
                onSelectionChanged: (s) => app.setFontScale(s.first),
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
            const _SectionTitle('عن التطبيق'),
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
