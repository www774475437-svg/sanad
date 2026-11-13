part of 'main.dart';

// =====================================================================
//  إضافات الإصدار 1.3: المكتبة، التنزيل بلا إنترنت، القارئ، الفهرس،
//  البحث داخل الكتاب، بطاقة الصورة، المجلدات، علامات الصفحات.
// =====================================================================

String catName(int cat) {
  switch (cat) {
    case 22:
      return 'الفتاوى';
    case 1:
      return 'العقيدة';
    case 3:
    case 4:
      return 'التفسير وعلوم القرآن';
    case 6:
    case 7:
    case 10:
      return 'الحديث وعلومه';
    case 11:
    case 17:
    case 18:
    case 19:
    case 21:
      return 'الفقه وأصوله';
    case 31:
      return 'اللغة العربية';
  }
  return 'الآداب والدعوة والدروس';
}

const List<String> kCatOrder = [
  'الفتاوى',
  'العقيدة',
  'الفقه وأصوله',
  'الحديث وعلومه',
  'التفسير وعلوم القرآن',
  'الآداب والدعوة والدروس',
  'اللغة العربية',
];

Color catColor(int cat) {
  switch (catName(cat)) {
    case 'الفتاوى':
      return const Color(0xFF0F7A6E);
    case 'العقيدة':
      return const Color(0xFF8E6B12);
    case 'الفقه وأصوله':
      return const Color(0xFF2F6DA8);
    case 'الحديث وعلومه':
      return const Color(0xFF7B4FA3);
    case 'التفسير وعلوم القرآن':
      return const Color(0xFFB0562D);
    case 'اللغة العربية':
      return const Color(0xFF5E6B73);
  }
  return const Color(0xFF3E8E5A);
}

String sizeLabel(int bytes) {
  if (bytes >= 1000000) return '${(bytes / 1000000).toStringAsFixed(1)} م.ب';
  return '${math.max(1, bytes ~/ 1000)} ك.ب';
}

/// يظلّل كلمات البحث داخل النص.
List<InlineSpan> highlightSpans(String text, List<String> terms) {
  if (terms.isEmpty || text.isEmpty) return <InlineSpan>[TextSpan(text: text)];
  final needles = <String>{};
  for (final g in groupsOf(terms)) {
    for (final a in g) {
      if (a.length >= 3) needles.add(a);
    }
  }
  if (needles.isEmpty) return <InlineSpan>[TextSpan(text: text)];
  final map = <int>[];
  final n = normRaw(text, map: map, tags: false);
  final ranges = <List<int>>[];
  for (final nd in needles) {
    var p = wordPos(n, nd);
    var count = 0;
    while (p >= 0 && count < 40) {
      final endN = p + nd.length;
      ranges.add(<int>[map[p], endN < map.length ? map[endN] : text.length]);
      count++;
      p = wordPos(n, nd, endN);
    }
  }
  if (ranges.isEmpty) return <InlineSpan>[TextSpan(text: text)];
  ranges.sort((a, b) => a[0].compareTo(b[0]));
  final out = <InlineSpan>[];
  var pos = 0;
  for (final r in ranges) {
    if (r[0] < pos || r[1] <= r[0]) continue;
    if (r[0] > pos) out.add(TextSpan(text: text.substring(pos, r[0])));
    out.add(TextSpan(
      text: text.substring(r[0], r[1]),
      style: const TextStyle(backgroundColor: Color(0x66FFD54F)),
    ));
    pos = r[1];
  }
  if (pos < text.length) out.add(TextSpan(text: text.substring(pos)));
  return out;
}

void openBookAt(BuildContext context, Book b, int pageId,
    {String label = '', String title = ''}) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ReaderScreen(
      quote: Quote(
        bookId: b.id,
        bookName: b.title,
        vol: '',
        page: label,
        pageId: pageId < 1 ? 1 : pageId,
        text: '',
        title: title,
      ),
    ),
  ));
}

// ------------------ كلمات البحث والمسائل المتقاربة ------------------

class _TermsBar extends StatelessWidget {
  final List<String> terms;
  final void Function(String) onAsk;
  const _TermsBar({required this.terms, required this.onAsk});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('كلمات البحث:',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          for (final t in terms)
            InputChip(
              label: Text(t, style: const TextStyle(fontSize: 13)),
              visualDensity: VisualDensity.compact,
              deleteButtonTooltipMessage: 'احذف الكلمة وأعد البحث',
              onDeleted: terms.length > 1
                  ? () => onAsk(terms.where((x) => x != t).join(' '))
                  : null,
            ),
          ActionChip(
            avatar: const Icon(Icons.hub_outlined, size: 16),
            label: const Text('مسائل متقاربة', style: TextStyle(fontSize: 13)),
            visualDensity: VisualDensity.compact,
            onPressed: () => showRelated(context, terms),
          ),
        ],
      ),
    );
  }
}

void showRelated(BuildContext context, List<String> terms) {
  final g = groupsOf(terms);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.7,
      child: FutureBuilder<Headings>(
        future: localIndex.headings(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('تعذّر تحميل فهرس المسائل، حاول مرة أخرى.'),
            ));
          }
          final h = snap.data;
          if (h == null) return const Center(child: CircularProgressIndicator());
          final hits = <int>[];
          for (var i = 0; i < h.norms.length; i++) {
            var any = false;
            for (final a in g) {
              if (hasAny(h.norms[i], a)) {
                any = true;
                break;
              }
            }
            if (any) hits.add(i);
          }
          double score(int i) {
            var s = catBoost(h.books[i]) - h.norms[i].length / 60.0;
            if (matchesAll(h.norms[i], g)) s += 20;
            return s;
          }

          hits.sort((a, b) => score(b).compareTo(score(a)));
          final top = hits.take(40).toList();
          if (top.isEmpty) {
            return const Center(child: Text('لا توجد مسائل متقاربة.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: top.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, k) {
              final i = top[k];
              final b = bookOf(h.books[i]);
              return ListTile(
                dense: true,
                title: Text(h.titles[i],
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: Text(b?.title ?? ''),
                trailing: const Icon(Icons.chevron_left),
                onTap: b == null
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        openBookAt(context, b, h.pages[i], title: h.titles[i]);
                      },
              );
            },
          );
        },
      ),
    ),
  );
}

// ------------------ تنزيل الكتب للقراءة بلا إنترنت ------------------

class DownloadManager extends ChangeNotifier {
  final Map<int, double> progress = <int, double>{};
  final List<Book> _queue = <Book>[];
  bool _running = false;
  String lastError = '';

  bool get busy => _running;
  int get pending => progress.length;

  void add(Book b) {
    if (!storeSupported || storeHas(b.id) || progress.containsKey(b.id)) return;
    progress[b.id] = 0;
    _queue.add(b);
    notifyListeners();
    _run();
  }

  void addAll() {
    final list = [...kBooks]..sort((a, b) => a.size.compareTo(b.size));
    for (final b in list) {
      add(b);
    }
  }

  /// يوقف ما لم يبدأ بعد (الكتاب الجاري يكتمل).
  void stop() {
    for (final b in _queue) {
      progress.remove(b.id);
    }
    _queue.clear();
    notifyListeners();
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    lastError = '';
    while (_queue.isNotEmpty) {
      final b = _queue.removeAt(0);
      var shown = 0.0;
      try {
        await storeDownload(b.id, (f) {
          if (f - shown >= 0.03 || f >= 1) {
            shown = f;
            progress[b.id] = f;
            notifyListeners();
          }
        }, expected: b.size);
        localIndex.forget(b.id);
      } catch (_) {
        lastError = 'تعذّر تنزيل «${b.title}». تحقّق من الاتصال ثم أعد المحاولة.';
      }
      progress.remove(b.id);
      notifyListeners();
    }
    _running = false;
    notifyListeners();
  }

  Future<void> remove(Book b) async {
    await storeDelete(b.id);
    localIndex.forget(b.id);
    notifyListeners();
  }

  Future<void> removeAll() async {
    for (final id in storeIds()) {
      await storeDelete(id);
      localIndex.forget(id);
    }
    notifyListeners();
  }
}

final DownloadManager downloads = DownloadManager();

Future<bool> confirmDialog(BuildContext context, String title, String body,
    {String ok = 'نعم'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body, style: const TextStyle(height: 1.7)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

// ---------------------------------------------------------------------
//  المكتبة
// ---------------------------------------------------------------------

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Widget _offlineCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final have = storeIds().length;
    final total = kBooks.fold<int>(0, (a, b) => a + b.size);
    final used = kBooks
        .where((b) => storeHas(b.id))
        .fold<int>(0, (a, b) => a + b.size);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.download_for_offline_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('القراءة والبحث بلا إنترنت',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              'اختياري: نزّل الكتب إلى هاتفك لتقرأها وتبحث فيها دون اتصال. '
              'ومع الاتصال يبقى البحث عبر الإنترنت لأنه أقوى.',
              style: TextStyle(
                  fontSize: 13, height: 1.6, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text('المنزَّل: $have من ${kBooks.length} كتابًا'
                '${have > 0 ? ' (نحو ${sizeLabel(used)})' : ''}'),
            if (downloads.busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              Text('جارٍ التنزيل... بقي ${downloads.pending} كتابًا. يمكنك متابعة استعمال التطبيق.',
                  style: const TextStyle(fontSize: 13)),
            ],
            if (downloads.lastError.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(downloads.lastError,
                  style: TextStyle(fontSize: 13, color: scheme.error)),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (!downloads.busy && have < kBooks.length)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.download, size: 18),
                  label: Text('تنزيل كل الكتب (نحو ${sizeLabel(total)})'),
                  onPressed: () async {
                    final ok = await confirmDialog(
                        context,
                        'تنزيل كل الكتب',
                        'سيُنزَّل ${kBooks.length} كتابًا بحجم نحو ${sizeLabel(total)}، '
                            'ويحتاج مساحة مماثلة تقريبًا في الهاتف. يُفضَّل الاتصال بالواي فاي.\n\n'
                            'ويمكنك بدل ذلك تنزيل كتاب واحد من صفحته.',
                        ok: 'ابدأ التنزيل');
                    if (ok) downloads.addAll();
                  },
                ),
              if (downloads.busy)
                OutlinedButton.icon(
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('إيقاف'),
                  onPressed: downloads.stop,
                ),
              if (!downloads.busy && have > 0)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('حذف كل المنزَّل'),
                  onPressed: () async {
                    final ok = await confirmDialog(context, 'حذف الكتب المنزَّلة',
                        'ستُحذف الكتب من الهاتف لتوفير المساحة، ويبقى التطبيق يعمل بالإنترنت.',
                        ok: 'حذف');
                    if (ok) await downloads.removeAll();
                  },
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Book b) {
    final scheme = Theme.of(context).colorScheme;
    final pos = app.posOf(b.id);
    final pr = downloads.progress[b.id];
    final parts = <String>['${b.pages} صفحة', sizeLabel(b.size)];
    if (storeHas(b.id)) parts.add('منزَّل');
    if (pos > 1 && b.pages > 0) {
      parts.add('قرأتَ ${(pos * 100 / b.pages).clamp(1, 100).round()}٪');
    }
    return ListTile(
      leading: Icon(Icons.menu_book_outlined, color: catColor(b.cat)),
      title: Text(b.title),
      subtitle: Text(parts.join(' · '),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      trailing: pr != null
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, value: pr > 0 ? pr : null))
          : const Icon(Icons.chevron_left),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => BookScreen(book: b))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('كتب الشيخ ابن عثيمين')),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[downloads, app, _filter]),
        builder: (context, _) {
          final f = normArabic(_filter.text.trim());
          final list = f.isEmpty
              ? kBooks
              : kBooks.where((b) => normArabic(b.title).contains(f)).toList();
          final children = <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: TextField(
                controller: _filter,
                decoration: InputDecoration(
                  hintText: 'ابحث عن كتاب بالاسم (${kBooks.length} كتابًا)',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (storeSupported && f.isEmpty) _offlineCard(context),
          ];
          for (final c in kCatOrder) {
            final books = list.where((b) => catName(b.cat) == c).toList();
            if (books.isEmpty) continue;
            children.add(_SectionTitle('$c (${books.length})'));
            children.addAll(books.map((b) => _tile(context, b)));
          }
          if (list.isEmpty) {
            children.add(const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('لا يوجد كتاب بهذا الاسم.')),
            ));
          }
          return ListView(
              padding: const EdgeInsets.only(bottom: 24), children: children);
        },
      ),
    );
  }
}

// ------------------ صفحة الكتاب ------------------

class BookScreen extends StatelessWidget {
  final Book book;
  const BookScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final b = book;
    return Scaffold(
      appBar: AppBar(title: Text(b.title, overflow: TextOverflow.ellipsis)),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[downloads, app]),
        builder: (context, _) {
          final pos = app.posOf(b.id);
          final pr = downloads.progress[b.id];
          final has = storeHas(b.id);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: catColor(b.cat).withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.menu_book, color: catColor(b.cat)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(b.title,
                            style: const TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.5)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text('للشيخ محمد بن صالح العثيمين رَحِمَهُ الله',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text('${catName(b.cat)} · ${b.pages} صفحة · ${sizeLabel(b.size)}',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant)),
                    if (pos > 1 && b.pages > 0) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                            minHeight: 6, value: (pos / b.pages).clamp(0.0, 1.0).toDouble()),
                      ),
                      const SizedBox(height: 4),
                      Text('قرأتَ ${(pos * 100 / b.pages).clamp(1, 100).round()}٪ من الكتاب',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (pos > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.bookmark_outline),
                    label: Text('أكمل من حيث توقفت (صـ ${app.posLabelOf(b.id)})'),
                    onPressed: () =>
                        openBookAt(context, b, pos, label: app.posLabelOf(b.id)),
                  ),
                ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('اقرأ من أول الكتاب'),
                onPressed: () => openBookAt(context, b, 1, label: '1'),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.format_list_bulleted),
                    title: const Text('فهرس الكتاب'),
                    subtitle: const Text('تصفّح الأبواب والمسائل'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => TocScreen(book: b))),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.manage_search),
                    title: const Text('ابحث داخل هذا الكتاب'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => BookSearchScreen(book: b))),
                  ),
                  if (storeSupported) const Divider(height: 1),
                  if (storeSupported)
                    ListTile(
                      leading: Icon(has
                          ? Icons.offline_pin_outlined
                          : Icons.download_for_offline_outlined),
                      title: Text(has
                          ? 'الكتاب منزَّل على هاتفك'
                          : (pr != null
                              ? 'جارٍ التنزيل... ${(pr * 100).round()}٪'
                              : 'تنزيل للقراءة بلا إنترنت')),
                      subtitle: Text(has
                          ? 'اضغط للحذف وتوفير المساحة'
                          : 'الحجم نحو ${sizeLabel(b.size)}'),
                      trailing: pr != null
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5))
                          : null,
                      onTap: pr != null
                          ? null
                          : () async {
                              if (has) {
                                final ok = await confirmDialog(context, 'حذف الكتاب',
                                    'سيُحذف «${b.title}» من الهاتف، ويبقى متاحًا بالإنترنت.',
                                    ok: 'حذف');
                                if (ok) await downloads.remove(b);
                              } else {
                                downloads.add(b);
                              }
                            },
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: const Text('فتح الكتاب في «تراث»'),
                    onTap: () =>
                        openLink(context, 'https://app.turath.io/book/${b.id}'),
                  ),
                ]),
              ),
              if (downloads.lastError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(downloads.lastError,
                      style: TextStyle(color: scheme.error, fontSize: 13)),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------ فهرس الكتاب ------------------

class TocScreen extends StatefulWidget {
  final Book book;
  const TocScreen({super.key, required this.book});
  @override
  State<TocScreen> createState() => _TocScreenState();
}

class _TocScreenState extends State<TocScreen> {
  late Future<List<TocEntry>> _future;
  final TextEditingController _filter = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = localIndex.toc(widget.book.id);
    _filter.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('الفهرس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(widget.book.title,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
      body: FutureBuilder<List<TocEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('تعذّر تحميل الفهرس.'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _future = localIndex.toc(widget.book.id);
                  }),
                  child: const Text('إعادة المحاولة'),
                ),
              ]),
            );
          }
          final all = snap.data;
          if (all == null) return const Center(child: CircularProgressIndicator());
          if (all.isEmpty) {
            return const Center(child: Text('لا يوجد فهرس لهذا الكتاب.'));
          }
          final f = normArabic(_filter.text.trim());
          final list = f.isEmpty
              ? all
              : all.where((e) => normArabic(e.title).contains(f)).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _filter,
                decoration: InputDecoration(
                  hintText: 'ابحث في العناوين (${all.length})',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final e = list[i];
                  final lvl = (e.level - 1).clamp(0, 4);
                  return InkWell(
                    onTap: () => openBookAt(context, widget.book, e.page,
                        title: e.title),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          16.0 + (f.isEmpty ? lvl * 14.0 : 0), 10, 16, 10),
                      child: Text(
                        e.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          height: 1.6,
                          fontWeight: lvl == 0 ? FontWeight.bold : FontWeight.normal,
                          color: lvl == 0 ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ------------------ البحث داخل كتاب ------------------

class BookSearchScreen extends StatefulWidget {
  final Book book;
  const BookSearchScreen({super.key, required this.book});
  @override
  State<BookSearchScreen> createState() => _BookSearchScreenState();
}

class _BookSearchScreenState extends State<BookSearchScreen> {
  final TextEditingController _input = TextEditingController();
  Future<List<Quote>>? _future;
  List<String> _terms = const <String>[];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _go() {
    final raw = _input.text.trim();
    if (raw.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _terms = parseQuestion(raw).terms;
      _future = engine.searchInBook(widget.book, raw);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titlesOnly = kIsWeb && !localIndex.hasFullText(widget.book.id);
    return Scaffold(
      appBar: AppBar(
        title: Text('بحث في: ${widget.book.title}',
            style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _go(),
                decoration: InputDecoration(
                  hintText: 'اكتب كلمة أو مسألة',
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _go, icon: const Icon(Icons.search)),
          ]),
        ),
        if (titlesOnly)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('البحث في هذا الكتاب من المتصفح يكون في عناوين مسائله.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
        Expanded(
          child: _future == null
              ? const SizedBox.shrink()
              : FutureBuilder<List<Quote>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return const Center(
                          child: Text('تعذّر الاتصال بالخادم، حاول مرة أخرى'));
                    }
                    final list = snap.data ?? <Quote>[];
                    if (list.isEmpty) {
                      return const Center(child: Text('لا توجد نتائج في هذا الكتاب.'));
                    }
                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        for (final q in list)
                          QuoteCard(quote: q, intro: kScholarIntro, terms: _terms),
                      ],
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------
//  القارئ
// ---------------------------------------------------------------------

class ReaderScreen extends StatefulWidget {
  final Quote quote;
  final bool jumpToStart;
  const ReaderScreen({super.key, required this.quote, this.jumpToStart = false});
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int _pg;
  late String _label;
  String _text = '';
  bool _loading = true;
  bool _failed = false;
  bool _focus = false;

  Book? get _book => bookOf(widget.quote.bookId);

  @override
  void initState() {
    super.initState();
    _pg = widget.quote.pageId;
    _label = widget.quote.pageLabel;
    if (widget.jumpToStart || widget.quote.text.isNotEmpty) {
      _toStart();
    } else {
      _load();
    }
  }

  /// يرجع من صفحة النص إلى أول المسألة (أقرب عنوان قبلها) ليرى القارئ السؤال.
  Future<void> _toStart() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      var pg = widget.quote.pageId;
      for (var i = 0; i < 12 && pg >= 1; i++) {
        final d = await api.page(widget.quote.bookId, pg);
        if (d.text.isEmpty || d.hasTitle || pg == 1) break;
        pg--;
      }
      if (mounted) _pg = pg < 1 ? 1 : pg;
    } catch (_) {
      if (mounted) _pg = widget.quote.pageId;
    }
    if (mounted) _load();
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
        app.bumpRead();
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

  void _go(int delta) => _jump(_pg + delta);

  void _jump(int page) {
    final max = _book?.pages ?? 0;
    if (page < 1 || (max > 0 && page > max)) return;
    _pg = page;
    _load();
  }

  /// يبحث عن موضع كلام الشيخ في الصفحة ليظلّله.
  TextRange? _findHighlight() {
    if (_pg != widget.quote.pageId) return null;
    final q = widget.quote.text.replaceAll('…', '').trim();
    if (q.length < 12) return null;
    final full = _text.indexOf(q);
    if (full >= 0) return TextRange(start: full, end: full + q.length);
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

  (Color?, Color?) _colors() {
    switch (app.rBg) {
      case 'sepia':
        return (const Color(0xFFF4ECD8), const Color(0xFF3B2F1E));
      case 'night':
        return (const Color(0xFF0C0C0C), const Color(0xFFC9C9C9));
    }
    return (null, null);
  }

  Future<void> _askPage() async {
    final ctrl = TextEditingController();
    final max = _book?.pages ?? 0;
    final r = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اذهب إلى صفحة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: max > 0 ? 'رقم من 1 إلى $max' : 'رقم الصفحة',
            helperText: 'الرقم هنا تسلسل صفحات الكتاب كله',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
              child: const Text('اذهب')),
        ],
      ),
    );
    if (r != null && mounted) _jump(r);
  }

  void _settingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListenableBuilder(
        listenable: app,
        builder: (ctx, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('حجم الخط'),
                Slider(
                  min: 14,
                  max: 34,
                  divisions: 10,
                  value: app.rSize.clamp(14, 34).toDouble(),
                  onChanged: (v) => app.setReader(size: v),
                ),
                const Text('المسافة بين الأسطر'),
                Slider(
                  min: 1.4,
                  max: 2.6,
                  divisions: 6,
                  value: app.rHeight.clamp(1.4, 2.6).toDouble(),
                  onChanged: (v) => app.setReader(height: v),
                ),
                const SizedBox(height: 4),
                const Text('لون الصفحة'),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'auto', label: Text('عادي')),
                    ButtonSegment(value: 'sepia', label: Text('دافئ')),
                    ButtonSegment(value: 'night', label: Text('ليلي')),
                  ],
                  selected: {app.rBg},
                  onSelectionChanged: (s) => app.setReader(bg: s.first),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الخط الأميري'),
                  value: app.rAmiri,
                  onChanged: (v) => app.setReader(amiri: v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quote;
    final b = _book;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final colors = _colors();
        final marked = app.isMarked(q.bookId, _pg);
        final total = b?.pages ?? 0;
        return Scaffold(
          backgroundColor: colors.$1,
          appBar: _focus
              ? null
              : AppBar(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.bookName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
                      Text('صـ $_label',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'علامة على الصفحة',
                      icon: Icon(marked ? Icons.bookmark : Icons.bookmark_border,
                          color: marked ? kGold : null),
                      onPressed: _pg <= 0
                          ? null
                          : () {
                              final added = app.toggleMark(
                                  q.bookId, q.bookName, _pg, _label);
                              showToast(context,
                                  added ? 'وُضعت علامة على الصفحة' : 'أُزيلت العلامة');
                            },
                    ),
                    IconButton(
                      tooltip: 'الخط واللون',
                      icon: const Icon(Icons.text_format),
                      onPressed: _settingsSheet,
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        switch (v) {
                          case 'toc':
                            if (b != null) {
                              Navigator.of(context).push(MaterialPageRoute<void>(
                                  builder: (_) => TocScreen(book: b)));
                            }
                            break;
                          case 'goto':
                            _askPage();
                            break;
                          case 'focus':
                            setState(() => _focus = true);
                            break;
                          case 'link':
                            Clipboard.setData(ClipboardData(
                                text: quoteLink(Quote(
                              bookId: q.bookId,
                              bookName: q.bookName,
                              vol: '',
                              page: _label,
                              pageId: _pg,
                              text: '',
                            ))));
                            showToast(context, 'تم نسخ رابط الصفحة');
                            break;
                          case 'turath':
                            openLink(
                                context,
                                _pg > 0
                                    ? 'https://app.turath.io/book/${q.bookId}/$_pg'
                                    : q.turathUrl);
                            break;
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'toc', child: Text('فهرس الكتاب')),
                        PopupMenuItem(value: 'goto', child: Text('اذهب إلى صفحة')),
                        PopupMenuItem(value: 'focus', child: Text('وضع التركيز')),
                        PopupMenuItem(value: 'link', child: Text('نسخ رابط الصفحة')),
                        PopupMenuItem(value: 'turath', child: Text('فتح في تراث')),
                      ],
                    ),
                  ],
                ),
          floatingActionButton: _focus
              ? FloatingActionButton.small(
                  tooltip: 'إنهاء وضع التركيز',
                  onPressed: () => setState(() => _focus = false),
                  child: const Icon(Icons.fullscreen_exit),
                )
              : null,
          body: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v.abs() < 400 || _loading || _pg <= 0) return;
                _go(v > 0 ? 1 : -1);
              },
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_failed ? _fallback(scheme) : _pageBody(scheme, colors.$2)),
            ),
          ),
          bottomNavigationBar: (_pg > 0 && !_focus)
              ? SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (total > 0)
                      LinearProgressIndicator(
                          minHeight: 2, value: (_pg / total).clamp(0.0, 1.0).toDouble()),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'الصفحة السابقة',
                            onPressed: _loading ? null : () => _go(-1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: _askPage,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  total > 0
                                      ? 'صـ $_label  ·  ${(_pg * 100 / total).clamp(0, 100).round()}٪'
                                      : 'صـ $_label',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'الصفحة التالية',
                            onPressed: _loading ? null : () => _go(1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                        ],
                      ),
                    ),
                  ]),
                )
              : null,
        );
      },
    );
  }

  Widget _pageBody(ColorScheme scheme, Color? ink) {
    final style = TextStyle(
        fontFamily: app.rAmiri ? 'Amiri' : null,
        fontSize: app.rSize,
        height: app.rHeight,
        color: ink ?? scheme.onSurface);
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
    final hasQuote = widget.quote.text.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasQuote && widget.quote.pageId > 0 && _pg != widget.quote.pageId)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.format_quote, size: 18),
                  label: const Text('اذهب إلى موضع النص المنقول'),
                  onPressed: () => _jump(widget.quote.pageId),
                ),
              ),
            ),
          SelectableText.rich(TextSpan(children: [span])),
        ],
      ),
    );
  }

  Widget _fallback(ColorScheme scheme) {
    final q = widget.quote;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _NoticeBox(
            text: 'تعذّر تحميل الصفحة الآن. تحقّق من الاتصال، أو افتح الصفحة في «تراث».'),
        const SizedBox(height: 16),
        if (q.text.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kHighlight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText('«${q.text}»',
                style: const TextStyle(
                    fontFamily: 'Amiri', fontSize: 19, height: 1.9, color: Colors.black)),
          ),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            onPressed: _load,
          ),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('فتح في تراث'),
            onPressed: () => openLink(context, q.turathUrl),
          ),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------
//  المحفوظات: المفضلة بمجلدات، القراءة لاحقًا، علامات الصفحات
// ---------------------------------------------------------------------

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _folder = ''; // فارغ = الكل

  Widget _empty(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );

  Future<String?> _askName() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مجلد جديد'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'مثل: الطهارة، الصلاة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('إنشاء')),
        ],
      ),
    );
  }

  Future<void> _pickFolder(Quote q) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final n in app.folderNames)
            ListTile(
              leading: Icon(app.folderOf(q) == n ? Icons.folder : Icons.folder_outlined),
              title: Text(n),
              onTap: () => Navigator.pop(ctx, 'f:$n'),
            ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('مجلد جديد'),
            onTap: () => Navigator.pop(ctx, 'new'),
          ),
          if (app.folderOf(q).isNotEmpty)
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('إخراج من المجلد'),
              onTap: () => Navigator.pop(ctx, 'none'),
            ),
        ]),
      ),
    );
    if (choice == null) return;
    if (choice == 'none') {
      app.setFolder(q, '');
    } else if (choice == 'new') {
      final name = await _askName();
      if (name != null && name.isNotEmpty) app.setFolder(q, name);
    } else {
      app.setFolder(q, choice.substring(2));
    }
  }

  Widget _favorites() {
    if (app.favorites.isEmpty) {
      return _empty('لم تحفظ شيئًا بعد.\nاضغط النجمة تحت أي نقل لحفظه هنا.');
    }
    if (_folder.isNotEmpty && !app.folderNames.contains(_folder)) _folder = '';
    final items = _folder.isEmpty
        ? app.favorites
        : app.favorites.where((q) => app.folderOf(q) == _folder).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(spacing: 6, runSpacing: 0, children: [
          ChoiceChip(
            label: Text('الكل (${app.favorites.length})'),
            selected: _folder.isEmpty,
            onSelected: (_) => setState(() => _folder = ''),
          ),
          for (final n in app.folderNames)
            GestureDetector(
              onLongPress: () async {
                final ok = await confirmDialog(context, 'حذف المجلد',
                    'سيُحذف المجلد «$n» فقط، وتبقى النقول في المفضلة.',
                    ok: 'حذف');
                if (ok) app.removeFolder(n);
              },
              child: ChoiceChip(
                avatar: const Icon(Icons.folder_outlined, size: 16),
                label: Text(n),
                selected: _folder == n,
                onSelected: (_) => setState(() => _folder = n),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.create_new_folder_outlined, size: 16),
            label: const Text('مجلد'),
            onPressed: () async {
              final name = await _askName();
              if (name != null && name.isNotEmpty && !app.folderNames.contains(name)) {
                app.addFolder(name);
                setState(() => _folder = name);
              }
            },
          ),
        ]),
        if (app.folderNames.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text('اضغط مطولًا على المجلد لحذفه.',
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        if (items.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              label: Text('نسخ الكل في رسالة واحدة (${items.length})'),
              onPressed: () async {
                final text = items.map(plainFormat).join('\n\n———\n\n');
                await Clipboard.setData(ClipboardData(text: text));
                if (mounted) showToast(context, 'تم نسخ ${items.length} نقل');
              },
            ),
          ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('هذا المجلد فارغ.')),
          ),
        for (final q in items) ...[
          QuoteCard(quote: q),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextButton.icon(
                icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                label: Text(app.folderOf(q).isEmpty
                    ? 'أضف إلى مجلد'
                    : 'المجلد: ${app.folderOf(q)}'),
                onPressed: () => _pickFolder(q),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _later() {
    if (app.later.isEmpty) {
      return _empty('لا شيء هنا.\nاضغط علامة الحفظ تحت أي نقل لتقرأه لاحقًا.');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: app.later.map((q) => QuoteCard(quote: q)).toList(),
    );
  }

  Widget _marks() {
    if (app.marks.isEmpty) {
      return _empty('لا توجد علامات.\nاضغط علامة الصفحة أعلى القارئ لتعود إليها لاحقًا.');
    }
    return ListView.separated(
      itemCount: app.marks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = app.marks[i];
        final d = DateTime.fromMillisecondsSinceEpoch(asInt(m['at']));
        return ListTile(
          leading: const Icon(Icons.bookmark, color: kGold),
          title: Text(asStr(m['n'])),
          subtitle: Text('صـ ${asStr(m['l'])} · ${d.year}/${d.month}/${d.day}'),
          trailing: IconButton(
            tooltip: 'حذف العلامة',
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => app.toggleMark(
                asInt(m['b']), asStr(m['n']), asInt(m['pid']), asStr(m['l'])),
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ReaderScreen(
              quote: Quote(
                bookId: asInt(m['b']),
                bookName: asStr(m['n']),
                vol: '',
                page: asStr(m['l']),
                pageId: asInt(m['pid']),
                text: '',
              ),
            ),
          )),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('محفوظاتي'),
          bottom: const TabBar(tabs: [
            Tab(text: 'المفضلة'),
            Tab(text: 'لاحقًا'),
            Tab(text: 'علامات الصفحات'),
          ]),
        ),
        body: ListenableBuilder(
          listenable: app,
          builder: (context, _) =>
              TabBarView(children: [_favorites(), _later(), _marks()]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
//  بطاقة الصورة للمشاركة
// ---------------------------------------------------------------------

class ShareCardScreen extends StatefulWidget {
  final Quote quote;
  const ShareCardScreen({super.key, required this.quote});
  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final GlobalKey _key = GlobalKey();
  String _style = 'green';
  bool _busy = false;

  (Color, Color, Color, Color) _palette() {
    switch (_style) {
      case 'black':
        return (
          const Color(0xFF1A1A1A),
          const Color(0xFF050505),
          const Color(0xFFF1E6C0),
          const Color(0xFFD4AF37)
        );
      case 'paper':
        return (
          const Color(0xFFFBF3DC),
          const Color(0xFFF0E2BC),
          const Color(0xFF3B2A10),
          const Color(0xFF8C6A39)
        );
    }
    return (
      const Color(0xFF0B4A44),
      const Color(0xFF11766B),
      Colors.white,
      const Color(0xFFE7C65A)
    );
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final ro = _key.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) throw StateError('no boundary');
      final ui.Image img = await ro.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('no data');
      final bytes = data.buffer.asUint8List();
      await Share.shareXFiles(<XFile>[
        XFile.fromData(bytes, mimeType: 'image/png', name: 'sanad.png'),
      ]);
    } catch (_) {
      if (mounted) showToast(context, 'تعذّرت مشاركة الصورة على هذا الجهاز');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quote;
    final c = _palette();
    var text = q.text;
    if (text.length > 900) {
      final cutAt = text.lastIndexOf(' ', 900);
      text = '${text.substring(0, cutAt > 500 ? cutAt : 900)}…';
    }
    final card = RepaintBoundary(
      key: _key,
      child: Container(
        width: 380,
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
                painter: GeoPatternPainter(color: c.$3.withOpacity(0.06))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (q.heading.isNotEmpty) ...[
                  Text(q.heading,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          height: 1.6,
                          color: c.$4)),
                  const SizedBox(height: 10),
                  Center(child: Container(width: 60, height: 2, color: c.$4)),
                  const SizedBox(height: 14),
                ],
                Text(kScholarIntro,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.$3.withOpacity(0.85))),
                const SizedBox(height: 8),
                Text('«$text»',
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                        fontFamily: 'Amiri', fontSize: 18, height: 1.95, color: c.$3)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.$3.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.$4.withOpacity(0.5)),
                  ),
                  child: Text('${q.bookName} (صـ ${q.pageLabel})',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: c.$3)),
                ),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(kAppName,
                      style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: c.$4)),
                  const SizedBox(width: 8),
                  Text('كلام العلماء بنصّه ومصدره',
                      style: TextStyle(fontSize: 11, color: c.$3.withOpacity(0.7))),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('مشاركة كصورة')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'green', label: Text('أخضر')),
              ButtonSegment(value: 'black', label: Text('أسود')),
              ButtonSegment(value: 'paper', label: Text('ورقي')),
            ],
            selected: {_style},
            onSelectionChanged: (s) => setState(() => _style = s.first),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.noScaling),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(18), child: card),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.share),
                label: const Text('مشاركة الصورة'),
                onPressed: _busy ? null : _share,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------
//  كيف أستخدم التطبيق
// ---------------------------------------------------------------------

class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const steps = <(IconData, String, String)>[
      (Icons.edit_outlined, 'اكتب سؤالك', 'اكتب المسألة بكلمات قليلة واضحة، مثل: حكم النمص. ثم اضغط زر الإرسال.'),
      (Icons.format_quote, 'اقرأ كلام الشيخ بنصّه', 'يظهر كلام الشيخ منقولًا من كتبه كما هو، وفوقه عنوان المسألة، وتحته اسم الكتاب ورقم الصفحة.'),
      (Icons.menu_book_outlined, 'افتح الصفحة في الكتاب', 'اضغط اسم الكتاب تحت النقل لتقرأ المسألة من أولها داخل التطبيق.'),
      (Icons.close, 'حسّن البحث', 'تحت الجواب تظهر كلمات البحث. احذف الكلمة غير المقصودة بضغطة فيُعاد البحث، أو اضغط «مسائل متقاربة».'),
      (Icons.star_outline, 'احفظ وشارك', 'النجمة للحفظ، وزر الصورة لمشاركة النقل صورةً، وزر النسخ بتنسيق تيليجرام أو واتساب.'),
      (Icons.local_library_outlined, 'تصفّح كتب الشيخ', 'من القائمة الجانبية افتح «كتب الشيخ»، ثم اختر كتابًا لتقرأه أو تتصفح فهرسه أو تبحث داخله.'),
      (Icons.download_for_offline_outlined, 'بلا إنترنت', 'في تطبيق الأندرويد يمكنك تنزيل الكتب من «كتب الشيخ» لتقرأ وتبحث دون اتصال.'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('كيف أستخدم التطبيق؟')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(steps[i].$1, size: 20, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}. ${steps[i].$2}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(steps[i].$3, style: const TextStyle(height: 1.7)),
                    ],
                  ),
                ),
              ]),
            ),
          const _NoticeBox(
              text: 'سَنَد ينقل كلام الشيخ ولا يفتي من عنده. وما أشكل عليك فاسأل عنه أهل العلم.'),
        ],
      ),
    );
  }
}
