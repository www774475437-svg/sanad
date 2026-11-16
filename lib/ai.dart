part of 'main.dart';

// =====================================================================
//  الخادم الوسيط والذكاء الاصطناعي
//  الذكاء الاصطناعي يفهم السؤال ويرتّب النقول ويكتب سطر خلاصة فقط؛
//  أما النص المعروض فكلام الشيخ بحروفه.
// =====================================================================

/// رابط الخادم الوسيط (Cloudflare Worker، انظر tools/worker.js). فارغ = معطَّل.
const String kProxyUrl = 'https://wandering-wildflower-5c73.www774475437.workers.dev';

bool get proxyOn => kProxyUrl.isNotEmpty;

/// المتصفح بلا خادم وسيط: البحث محلي من ملفات الموقع.
bool get webLocal => kIsWeb && !proxyOn;

bool get aiReady => proxyOn && app.aiOn && remoteAiEnabled;

Future<Map<String, dynamic>?> _aiPost(String path, Map<String, dynamic> body) async {
  try {
    final r = await http
        .post(Uri.parse('$kProxyUrl$path'),
            headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) return null;
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    return d is Map ? Map<String, dynamic>.from(d) : null;
  } catch (_) {
    return null;
  }
}

/// يستخرج من سؤال المستخدم المسألةَ وكلمات البحث. يرجع null عند أي فشل.
Future<({String issue, List<String> terms})?> aiUnderstand(String question) async {
  if (!await aiQuotaTake()) return null;
  final d = await _aiPost('/ai/understand', {'q': question});
  if (d == null) return null;
  final terms = <String>[];
  final t = d['terms'];
  if (t is List) {
    for (final x in t) {
      final s = stripTashkeel('$x').trim();
      if (s.length >= 2 && !terms.contains(s)) terms.add(s);
    }
  }
  return (issue: asStr(d['issue']).trim(), terms: terms.take(4).toList());
}

/// يرتّب النقول حسب إجابتها للسؤال ويكتب سطر خلاصة منها. يرجع null عند أي فشل.
Future<({List<int> order, String summary})?> aiArrange(
    String question, List<Quote> quotes) async {
  if (!await aiQuotaTake()) return null;
  final d = await _aiPost('/ai/arrange', {
    'q': question,
    'quotes': [
      for (var i = 0; i < quotes.length && i < 6; i++)
        {
          'i': i,
          'title': quotes[i].title,
          'text': quotes[i].text.length > 1200
              ? quotes[i].text.substring(0, 1200)
              : quotes[i].text,
        },
    ],
  });
  if (d == null) return null;
  final order = <int>[];
  final o = d['order'];
  if (o is List) {
    for (final x in o) {
      final n = x is int ? x : int.tryParse('$x');
      if (n != null && n >= 0 && n < quotes.length && !order.contains(n)) {
        order.add(n);
      }
    }
  }
  return (order: order, summary: asStr(d['summary']).trim());
}

class _SummaryBox extends StatelessWidget {
  final String text;
  const _SummaryBox({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text('الخلاصة',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: scheme.primary)),
        ]),
        const SizedBox(height: 6),
        SelectableText(text, style: const TextStyle(fontSize: 16, height: 1.8)),
        const SizedBox(height: 8),
        Text('خلاصة آلية من كلام الشيخ أدناه، وقد تخطئ. المعتمد نصُّ الشيخ نفسه.',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}
