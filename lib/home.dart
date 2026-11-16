part of 'main.dart';

// =====================================================================
//  الإصدار 1.5: الصفحة الرئيسية النظيفة، زر المزايا، حركة البحث،
//  أزرار الجواب، المسائل الموسمية، النسخة الاحتياطية، الترحيب.
// =====================================================================

/// الشهر واليوم الهجريان (حساب تقريبي قد يختلف يومًا عن الرؤية).
(int, int) hijriMonthDay(DateTime d) {
  final a = (14 - d.month) ~/ 12;
  final y = d.year + 4800 - a;
  final m = d.month + 12 * a - 3;
  final jd = d.day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
  var l = jd - 1948440 + 10632;
  final n = (l - 1) ~/ 10631;
  l = l - 10631 * n + 354;
  final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
      (l ~/ 5670) * ((43 * l) ~/ 15238);
  l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
  final month = (24 * l) ~/ 709;
  final day = l - (709 * month) ~/ 24;
  return (month, day);
}

/// مسائل الموسم بحسب الشهر الهجري (فارغة في غير المواسم).
List<String> seasonalTopics([DateTime? now]) {
  final h = hijriMonthDay(now ?? DateTime.now());
  switch (h.$1) {
    case 1:
      return const ['صيام عاشوراء', 'فضل شهر الله المحرم'];
    case 7:
      return const ['صيام رجب', 'العمرة في رجب'];
    case 8:
      return const ['صيام شعبان', 'ليلة النصف من شعبان', 'قضاء رمضان'];
    case 9:
      return const ['مفطرات الصيام', 'صيام المسافر', 'صلاة التراويح', 'زكاة الفطر'];
    case 10:
      return const ['صيام ست من شوال', 'قضاء رمضان'];
    case 12:
      return const ['الأضحية', 'صيام يوم عرفة', 'صفة الحج', 'التكبير في عشر ذي الحجة'];
  }
  return const <String>[];
}

/// أربع مسائل تُعرض تحت مربع السؤال: الموسمية أولًا ثم مسألة اليوم وأخواتها.
List<String> homeSuggestions() {
  final out = <String>[...seasonalTopics().take(2)];
  final day = DateTime.now().difference(DateTime(2024)).inDays;
  var i = 0;
  while (out.length < 4 && i < kTopics.length) {
    final t = kTopics[(day + i * 7) % kTopics.length];
    if (!out.contains(t)) out.add(t);
    i++;
  }
  return out;
}

class _EmptyState extends StatelessWidget {
  final void Function(String) onAsk;
  final Widget input;
  const _EmptyState({required this.onAsk, required this.input});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lr = app.lastRead;
    final tips = app.dailyCard ? homeSuggestions() : const <String>[];
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Text('سند',
                  style: TextStyle(
                      fontSize: 46,
                      height: 1.2,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0,
                      color: scheme.primary)),
              const SizedBox(height: 6),
              const Text('كلام العلماء بنصّه ومصدره',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
              const SizedBox(height: 22),
              input,
              if (tips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tips)
                      ActionChip(
                        label: Text(t, style: const TextStyle(fontSize: 13)),
                        visualDensity: VisualDensity.compact,
                        shape: StadiumBorder(
                            side: BorderSide(color: scheme.outlineVariant)),
                        onPressed: () => onAsk(t),
                      ),
                  ],
                ),
              ],
              if (lr != null) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  icon: const Icon(Icons.bookmark_outline, size: 18),
                  label: Text('أكمل القراءة: ${asStr(lr['n'])}، صـ ${asStr(lr['l'])}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
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
              ],
              const SizedBox(height: 28),
              Text('ينقل كلام الشيخ ابن عثيمين رَحِمَهُ الله من كتبه، ولا يفتي من عنده.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------ زر المزايا ------------------

void showToolsSheet(BuildContext context, void Function(String) onAsk) {
  void go(BuildContext ctx, Widget w) {
    Navigator.pop(ctx);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
  }

  final majmu = bookOf(12293);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      Widget item(IconData icon, String title, String sub, VoidCallback onTap) =>
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: scheme.primary),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
            onTap: onTap,
          );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            item(Icons.local_library_outlined, 'كتب الشيخ',
                '${kBooks.length} كتابًا: اقرأ وتصفّح وابحث داخلها',
                () => go(ctx, const LibraryScreen())),
            if (majmu != null)
              item(Icons.format_list_bulleted, 'فهرس الفتاوى',
                  'تصفّح مسائل مجموع الفتاوى بالأبواب',
                  () => go(ctx, TocScreen(book: majmu))),
            item(Icons.star_outline, 'المحفوظات',
                'المفضلة والمجلدات وعلامات الصفحات',
                () => go(ctx, const FavoritesScreen())),
            item(Icons.casino_outlined, 'مسألة عشوائية', 'مسألة من المسائل المشهورة',
                () {
              Navigator.pop(ctx);
              onAsk(kTopics[math.Random().nextInt(kTopics.length)]);
            }),
            item(Icons.help_outline, 'طريقة الاستخدام', 'شرح قصير بالخطوات',
                () => go(ctx, const HowToScreen())),
            item(Icons.settings_outlined, 'الإعدادات',
                'المظهر والخط والبحث والنسخة الاحتياطية',
                () => go(ctx, const SettingsScreen())),
          ]),
        ),
      );
    },
  );
}

// ------------------ حركة البحث ------------------

class SearchingIndicator extends StatefulWidget {
  const SearchingIndicator({super.key});
  @override
  State<SearchingIndicator> createState() => _SearchingIndicatorState();
}

class _SearchingIndicatorState extends State<SearchingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 5400))
        ..repeat();

  static const _lines = [
    'أفهم سؤالك...',
    'أبحث في كتب الشيخ ابن عثيمين...',
    'أرتّب النقول...',
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          final line = _lines[(v * _lines.length).floor() % _lines.length];
          return Row(children: [
            SizedBox(
              width: 46,
              height: 22,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 3; i++)
                    Builder(builder: (_) {
                      final w = (math.sin((v * 9 - i * 0.22) * 2 * math.pi) + 1) / 2;
                      return Container(
                        width: 7 + 5 * w,
                        height: 7 + 5 * w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(kGold, scheme.primary, w)!
                              .withOpacity(0.45 + 0.55 * w),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: localIndex.status,
                builder: (context, st, _) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Align(
                    key: ValueKey(st.isEmpty ? line : st),
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(st.isEmpty ? line : st,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ------------------ أزرار تحت الجواب ------------------

class _AnswerActions extends StatelessWidget {
  final ChatMessage message;
  final void Function(String) onAsk;
  const _AnswerActions({required this.message, required this.onAsk});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final key = '${message.issue}|${message.quotes.first.key}';
    Widget btn(IconData icon, String tip, VoidCallback onTap, {Color? color}) =>
        IconButton(
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          iconSize: 19,
          color: color ?? scheme.onSurfaceVariant,
          icon: Icon(icon),
          onPressed: onTap,
        );
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final v = app.voteOf(key);
        return Row(children: [
          btn(Icons.copy_all_outlined, 'نسخ الجواب كاملًا', () async {
            final b = StringBuffer();
            if (message.summary.isNotEmpty) b.writeln('${message.summary}\n');
            b.write(message.quotes.map(plainFormat).join('\n\n———\n\n'));
            await Clipboard.setData(ClipboardData(text: b.toString()));
            if (context.mounted) showToast(context, 'تم نسخ الجواب');
          }),
          btn(v == 1 ? Icons.thumb_up : Icons.thumb_up_outlined, 'جواب مفيد', () {
            app.setVote(key, 1);
          }, color: v == 1 ? scheme.primary : null),
          btn(v == -1 ? Icons.thumb_down : Icons.thumb_down_outlined, 'لم يُجب سؤالي',
              () {
            app.setVote(key, -1);
            if (app.voteOf(key) == -1) {
              showToast(context, 'شكرًا. جرّب حذف كلمة من كلمات البحث أو «مسائل متقاربة».');
            }
          }, color: v == -1 ? scheme.error : null),
          if (message.terms.isNotEmpty)
            btn(Icons.refresh, 'إعادة البحث', () => onAsk(message.terms.join(' '))),
        ]);
      },
    );
  }
}

// ------------------ النسخة الاحتياطية ------------------

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  Future<void> _export(BuildContext context) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(app.exportAll()));
      await Share.shareXFiles(<XFile>[
        XFile.fromData(bytes, mimeType: 'application/json', name: 'sanad-backup.json'),
      ]);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: app.exportAll()));
      if (context.mounted) {
        showToast(context, 'تعذّر حفظ الملف، فنُسخت النسخة إلى الحافظة');
      }
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = (data?.text ?? '').trim();
      if (!context.mounted) return;
      if (text.isEmpty) {
        showToast(context, 'انسخ محتوى ملف النسخة أولًا ثم اضغط هنا');
        return;
      }
      final n = app.importAll(text);
      showToast(
          context,
          n < 0
              ? 'المنسوخ ليس نسخة احتياطية من سَنَد'
              : (n == 0 ? 'كل ما في النسخة موجود عندك' : 'تمت الاستعادة: أُضيف $n عنصرًا'));
    } catch (_) {
      if (context.mounted) showToast(context, 'تعذّرت قراءة الحافظة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('النسخة الاحتياطية')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Text(
                'تشمل المفضلة والمحادثات والملاحظات والمجلدات وعلامات الصفحات.',
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.6)),
          ),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('نسخ إلى ملف'),
                subtitle: const Text('احفظ الملف أو أرسله لنفسك'),
                onTap: () => _export(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('استعادة نسخة'),
                subtitle: const Text('افتح ملف النسخة وانسخ محتواه كله، ثم اضغط هنا'),
                onTap: () => _restore(context),
              ),
              const Divider(height: 1),
              const ListTile(
                enabled: false,
                leading: Icon(Icons.cloud_outlined),
                title: Text('نسخ إلى الحساب'),
                subtitle: Text('ستتوفر قريبًا إن شاء الله'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ------------------ الترحيب وما الجديد ------------------

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _i = 0;

  static const _pages = <(IconData, String, String)>[
    (Icons.edit_note, 'اسأل بكلماتك', 'اكتب مسألتك بعبارة قصيرة، مثل: حكم النمص. ويبحث «سند» في كتب الشيخ ابن عثيمين رَحِمَهُ الله.'),
    (Icons.format_quote, 'الجواب كلام الشيخ بنصّه', 'يُعرض كلام الشيخ كما هو في كتابه، ومعه اسم الكتاب ورقم الصفحة. «سند» ينقل ولا يفتي من عنده.'),
    (Icons.menu_book_outlined, 'اقرأ واحفظ وشارك', 'افتح الصفحة في الكتاب، واحفظ النقل في مجلداتك، وشاركه نصًّا أو صورة. وكل المزايا في زر «+» بجانب مربع السؤال.'),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _i == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('تخطٍّ')),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                        color: scheme.primaryContainer, shape: BoxShape.circle),
                    child: Icon(_pages[i].$1, size: 46, color: scheme.primary),
                  ),
                  const SizedBox(height: 28),
                  Text(_pages[i].$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(_pages[i].$3,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16, height: 1.8, color: scheme.onSurfaceVariant)),
                ]),
              ),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var k = 0; k < _pages.length; k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: k == _i ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: k == _i ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (last) {
                    Navigator.pop(context);
                  } else {
                    _pc.nextPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(last ? 'ابدأ' : 'التالي'),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

void showWhatsNew(BuildContext context) {
  const items = [
    'صفحة رئيسية أبسط: مربع السؤال وتحته أربع مسائل مقترحة.',
    'زر «+» بجانب مربع السؤال يجمع المزايا: الكتب، الفهرس، المحفوظات، الإعدادات.',
    'خط جديد للواجهة، وحركة أوضح أثناء البحث.',
    'أزرار صغيرة تحت الجواب: نسخ الجواب كاملًا، مفيد، غير مفيد، إعادة البحث.',
    'المظهر حسب الوقت: داكن ليلًا وفاتح نهارًا.',
    'نسخة احتياطية كاملة إلى ملف، واستعادتها.',
    'مسائل موسمية تظهر في مواسمها (رمضان، ذو الحجة، عاشوراء).',
  ];
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('الجديد في سَنَد $kVersion'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final t in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t, style: const TextStyle(height: 1.6))),
                ]),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسنًا')),
      ],
    ),
  );
}
