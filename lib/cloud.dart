part of 'main.dart';

// =====================================================================
//  الحساب والمزامنة (Firebase Auth + Firestore)
//  البيانات تبقى محفوظة على الهاتف دائمًا؛ السحابة نسخة إضافية تُدمج عند الاستعادة.
//  كل دالة هنا تفشل بهدوء إن لم يكن Firebase جاهزًا (مثلًا في نسخة المتصفح).
// =====================================================================

bool cloudReady = false;

/// إعدادات يغيّرها المطور من الخانة وتصل للجميع دون تحديث التطبيق (config/app).
Map<String, dynamic> remoteConfig = <String, dynamic>{};

bool get remoteAiEnabled => remoteConfig['aiEnabled'] != false;

int get remoteAiLimit => (remoteConfig['aiDailyLimit'] as num?)?.toInt() ?? 50;

Future<void> cloudLoadConfig() async {
  if (!cloudReady) return;
  try {
    final s = await FirebaseFirestore.instance
        .collection('config')
        .doc('app')
        .get()
        .timeout(const Duration(seconds: 4));
    remoteConfig = s.data() ?? <String, dynamic>{};
  } catch (e) {
    debugPrint('config load failed: $e');
  }
}

Future<void> cloudSaveConfig(Map<String, dynamic> data) async {
  await FirebaseFirestore.instance
      .collection('config')
      .doc('app')
      .set(data, SetOptions(merge: true));
  remoteConfig = {...remoteConfig, ...data};
}

/// يحسب سؤال الذكاء الاصطناعي لليوم على هذا الجهاز. يرجع false عند تجاوز الحد.
/// ملاحظة: العد محلي على الجهاز، والتقييد الصارم يكون لاحقًا على الخادم.
Future<bool> aiQuotaTake() async {
  final p = await SharedPreferences.getInstance();
  final today = DateTime.now().toIso8601String().substring(0, 10);
  if (p.getString('aiDay') != today) {
    await p.setString('aiDay', today);
    await p.setInt('aiCount', 0);
  }
  final n = p.getInt('aiCount') ?? 0;
  if (n >= remoteAiLimit) return false;
  await p.setInt('aiCount', n + 1);
  return true;
}

Future<void> cloudInit() async {
  if (kIsWeb) return;
  try {
    await Firebase.initializeApp();
    cloudReady = true;
    await cloudLoadConfig();
  } catch (e) {
    debugPrint('firebase init failed: $e');
  }
}

User? get cloudUser => cloudReady ? FirebaseAuth.instance.currentUser : null;

Stream<User?> cloudAuthChanges() =>
    cloudReady ? FirebaseAuth.instance.authStateChanges() : const Stream<User?>.empty();

/// يرجع null عند النجاح، أو رسالة خطأ مفهومة.
/// يرجع null عند النجاح، أو رسالة خطأ مفهومة.
Future<String?> cloudSignIn(String email, String password, {bool create = false}) async {
  if (!cloudReady) return 'الحساب غير متاح الآن';
  try {
    final auth = FirebaseAuth.instance;
    if (create) {
      final cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
      await cred.user?.sendEmailVerification();
      return 'أرسلنا رابط التفعيل إلى بريدك. فعّله ثم ادخل من جديد';
    }
    await auth.signInWithEmailAndPassword(email: email, password: password);
    await cloudAcceptInvite();
    final u = auth.currentUser;
    if (u != null && !u.emailVerified) {
      await auth.signOut();
      return 'فعّل بريدك أولًا، ثم ادخل من جديد';
    }
    return null;
  } on FirebaseAuthException catch (e) {
    return e.message ?? e.code;
  } catch (e) {
    return '$e';
  }
}

Future<void> cloudSignOut() async {
  if (!cloudReady) return;
  await FirebaseAuth.instance.signOut();
}

/// عدد المحادثات الأخيرة التي تُرفع. المحادثات مرتبة من الأحدث.
const int kCloudConvLimit = 5;

int _clampConv(int n) => math.max(1, math.min(10, n));

const String kRoleDev = 'developer';

/// دور الحساب الحالي: developer أو admin أو editor، أو '' إن لم يكن مشرفًا.
Future<String> cloudRole() async {
  final u = cloudUser;
  if (u == null) return '';
  try {
    final s = await FirebaseFirestore.instance.collection('admins').doc(u.uid).get();
    return s.exists ? '${s.data()?['role'] ?? ''}' : '';
  } catch (_) {
    return '';
  }
}

/// بعد التحقق من البريد، إن كان هذا البريد مدعوًا كمشرف يُضاف الحساب إلى admins.
Future<void> cloudAcceptInvite() async {
  final u = cloudUser;
  if (u == null || !u.emailVerified || u.email == null) return;
  final db = FirebaseFirestore.instance;
  final email = u.email!.toLowerCase();
  try {
    final inv = await db.collection('invites').doc(email).get();
    if (!inv.exists) return;
    final role = '${inv.data()?['role'] ?? ''}';
    if (role != 'admin' && role != 'editor') return;
    final batch = db.batch();
    batch.set(db.collection('admins').doc(u.uid), {'role': role, 'email': email});
    batch.delete(db.collection('invites').doc(email));
    await batch.commit();
  } catch (e) {
    debugPrint('accept invite failed: $e');
  }
}

/// (للمطور) دعوة بريد ليصبح مشرفًا أو محرّرًا.
Future<String?> cloudInvite(String email, String role) async {
  final e = email.trim().toLowerCase();
  if (!e.contains('@') || !e.contains('.')) return 'البريد غير صحيح';
  try {
    await FirebaseFirestore.instance.collection('invites').doc(e).set({
      'role': role,
      'at': FieldValue.serverTimestamp(),
    });
    return null;
  } catch (err) {
    return '$err';
  }
}

Future<List<({String id, String role, String email})>> cloudListAdmins() async {
  final q = await FirebaseFirestore.instance.collection('admins').get();
  return [
    for (final d in q.docs)
      (id: d.id, role: '${d.data()['role'] ?? ''}', email: '${d.data()['email'] ?? ''}')
  ];
}

Future<List<({String email, String role})>> cloudListInvites() async {
  final q = await FirebaseFirestore.instance.collection('invites').get();
  return [for (final d in q.docs) (email: d.id, role: '${d.data()['role'] ?? ''}')];
}

Future<void> cloudRemoveAdmin(String uid) async {
  await FirebaseFirestore.instance.collection('admins').doc(uid).delete();
}

Future<void> cloudDeleteInvite(String email) async {
  await FirebaseFirestore.instance.collection('invites').doc(email).delete();
}

/// عدد المحادثات المرفوعة (من 1 إلى 10)، ويُحفظ على الهاتف.
Future<int> cloudConvLimit() async {
  final p = await SharedPreferences.getInstance();
  return _clampConv(p.getInt('cloudConvLimit') ?? kCloudConvLimit);
}

Future<void> cloudSetConvLimit(int n) async {
  final p = await SharedPreferences.getInstance();
  await p.setInt('cloudConvLimit', _clampConv(n));
}

/// نسخة خفيفة: المفضلة والمجلدات والملاحظات وآخر المحادثات فقط.
/// لا تُرفع الكتب المنزَّلة ولا الملفات ولا العلامات.
Future<String> cloudBackupText() async {
  final n = await cloudConvLimit();
  return jsonEncode({
    'sanad': 2,
    'favorites': app.favorites.map((f) => f.toJson()).toList(),
    'conversations': app.conversations.take(n).map((c) => c.toJson()).toList(),
    'notes': app.notes,
    'folders': app.folders,
    'folderNames': app.folderNames,
  });
}

/// يرفع النسخة الخفيفة إلى المستند الخاص بالمستخدم.
Future<String?> cloudPush() async {
  final u = cloudUser;
  if (u == null) return 'سجّل الدخول أولًا';
  try {
    await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
      'backup': await cloudBackupText(),
      'updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return null;
  } catch (e) {
    return '$e';
  }
}

/// يسحب النسخة السحابية ويدمجها مع ما على الهاتف. يرجع عدد ما أُضيف، أو -1 عند الفشل.
Future<int> cloudPull() async {
  final u = cloudUser;
  if (u == null) return -1;
  try {
    final s = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final text = s.data()?['backup'];
    if (text is! String || text.isEmpty) return 0;
    return app.importAll(text);
  } catch (e) {
    debugPrint('cloudPull failed: $e');
    return -1;
  }
}

// ---------------------------------------------------------------------
//  واجهة الحساب في الإعدادات
// ---------------------------------------------------------------------

Widget cloudSettingsSection(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _SectionTitle('الحساب والسحابة'),
      if (!cloudReady)
        const ListTile(
          leading: Icon(Icons.cloud_off_outlined),
          title: Text('السحابة غير متاحة الآن'),
        )
      else
        StreamBuilder<User?>(
          stream: cloudAuthChanges(),
          initialData: cloudUser,
          builder: (ctx, snap) {
            final u = snap.data;
            if (u == null) {
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('تسجيل الدخول'),
                subtitle: const Text('لحفظ المفضلة والملاحظات وآخر المحادثات'),
                onTap: () => showDialog<void>(
                    context: context, builder: (_) => const _CloudLoginDialog()),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(u.email ?? 'حساب'),
                  subtitle: const Text('مسجّل الدخول'),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('نسخ إلى السحابة'),
                  subtitle: const Text('المفضلة والمجلدات والملاحظات وآخر المحادثات فقط'),
                  onTap: () => _cloudPushTap(context),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('استعادة من السحابة'),
                  subtitle: const Text('تُدمج مع ما على الهاتف دون حذف'),
                  onTap: () => _cloudPullTap(context),
                ),
                ListTile(
                  leading: const Icon(Icons.format_list_numbered),
                  title: const Text('عدد المحادثات المرفوعة'),
                  subtitle: FutureBuilder<int>(
                    future: cloudConvLimit(),
                    builder: (c, s) => Text('آخر ${s.data ?? kCloudConvLimit} محادثات'),
                  ),
                  onTap: () => _cloudLimitTap(context),
                ),
                FutureBuilder<bool>(
                  future: cloudRole(),
                  builder: (c, s) => (s.data ?? '').isNotEmpty
                      ? ListTile(
                          leading: const Icon(Icons.admin_panel_settings_outlined),
                          title: const Text('المطور / الإدارة'),
                          subtitle: const Text('لوحة للمشرف فقط'),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const _AdminPage())),
                        )
                      : const SizedBox.shrink(),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('تسجيل الخروج'),
                  onTap: () async {
                    await cloudSignOut();
                    if (context.mounted) showToast(context, 'تم تسجيل الخروج');
                  },
                ),
              ],
            );
          },
        ),
    ],
  );
}

Future<void> _cloudPushTap(BuildContext context) async {
  showToast(context, 'جارٍ النسخ...');
  final err = await cloudPush();
  if (!context.mounted) return;
  showToast(context, err ?? 'تم النسخ إلى السحابة');
}

Future<void> _cloudPullTap(BuildContext context) async {
  final n = await cloudPull();
  if (!context.mounted) return;
  showToast(
      context,
      n < 0
          ? 'تعذّرت الاستعادة، تحقق من الاتصال'
          : n == 0
              ? 'لا توجد نسخة في السحابة بعد'
              : 'أُضيف $n عنصر من السحابة');
}

Future<void> _cloudLimitTap(BuildContext context) async {
  final cur = await cloudConvLimit();
  if (!context.mounted) return;
  final n = await showDialog<int>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('عدد المحادثات المرفوعة'),
      children: [
        for (var i = 1; i <= 10; i++)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, i),
            child: Text(i == cur ? '$i  ✓' : '$i'),
          ),
      ],
    ),
  );
  if (n == null) return;
  await cloudSetConvLimit(n);
  if (context.mounted) showToast(context, 'سيُرفع آخر $n محادثات');
}

class _CloudLoginDialog extends StatefulWidget {
  const _CloudLoginDialog();
  @override
  State<_CloudLoginDialog> createState() => _CloudLoginState();
}

class _CloudLoginState extends State<_CloudLoginDialog> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _create = false;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final err = await cloudSignIn(_email.text.trim(), _pass.text, create: _create);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = false;
      _err = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_create ? 'إنشاء حساب' : 'تسجيل الدخول'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
          ),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور'),
          ),
          TextButton(
            onPressed: () => setState(() => _create = !_create),
            child: Text(_create ? 'لدي حساب' : 'إنشاء حساب جديد'),
          ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_err!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _busy ? null : _go,
          child: Text(_create ? 'إنشاء' : 'دخول'),
        ),
      ],
    );
  }
}

/// لوحة المطور والإدارة: تظهر فقط لمن له مستند في admins.
/// المطور وحده يضيف المشرفين ويحذفهم.
class _AdminPage extends StatefulWidget {
  const _AdminPage();
  @override
  State<_AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<_AdminPage> {
  String _role = '';
  bool _loaded = false;
  late Future<List<({String id, String role, String email})>> _admins;
  late Future<List<({String email, String role})>> _invites;

  @override
  void initState() {
    super.initState();
    _admins = cloudListAdmins();
    _invites = cloudListInvites();
    cloudRole().then((r) {
      if (!mounted) return;
      setState(() {
        _role = r;
        _loaded = true;
      });
    });
  }

  void _reload() {
    setState(() {
      _admins = cloudListAdmins();
      _invites = cloudListInvites();
    });
  }

  Future<void> _addDialog() async {
    final ok = await showDialog<bool>(
        context: context, builder: (_) => const _InviteDialog());
    if (ok == true) _reload();
  }

  String _roleName(String r) => r == 'developer'
      ? 'المطور'
      : r == 'editor'
          ? 'محرّر'
          : 'مشرف كامل';

  @override
  Widget build(BuildContext context) {
    final isDev = _role == kRoleDev;
    final me = cloudUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('المطور / الإدارة')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: Text(isDev ? 'أنت المطور' : 'أنت ${_roleName(_role)}'),
                    subtitle: Text(cloudUser?.email ?? ''),
                  ),
                ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.auto_awesome),
                        title: const Text('الذكاء الاصطناعي'),
                        subtitle: const Text('إيقافه يُخفيه عن الجميع فورًا'),
                        value: remoteAiEnabled,
                        onChanged: (v) async {
                          await cloudSaveConfig({'aiEnabled': v});
                          if (!mounted) return;
                          setState(() {});
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.format_list_numbered),
                        title: const Text('الحد اليومي للأسئلة'),
                        subtitle: Text('$remoteAiLimit سؤال لكل مستخدم يوميًا'),
                        onTap: () async {
                          final v = await _askLimit(context);
                          if (v == null) return;
                          await cloudSaveConfig({'aiDailyLimit': v});
                          if (!mounted) return;
                          setState(() {});
                        },
                      ),
                    ]),
                  ),
                if (isDev) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _addDialog,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('إضافة مشرف'),
                  ),
                  const SizedBox(height: 16),
                  const Text('المشرفون', style: TextStyle(fontWeight: FontWeight.bold)),
                  FutureBuilder<List<({String id, String role, String email})>>(
                    future: _admins,
                    builder: (c, s) {
                      if (!s.hasData) return const LinearProgressIndicator();
                      final list = s.data!;
                      if (list.isEmpty) return const Text('لا يوجد مشرفون بعد');
                      return Column(children: [
                        for (final a in list)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_outline),
                            title: Text(a.email.isEmpty ? a.id : a.email),
                            subtitle: Text(_roleName(a.role)),
                            trailing: a.id == me || a.role == kRoleDev
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await cloudRemoveAdmin(a.id);
                                      if (context.mounted) showToast(context, 'أُزيل المشرف');
                                      _reload();
                                    },
                                  ),
                          ),
                      ]);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('دعوات بانتظار التفعيل',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  FutureBuilder<List<({String email, String role})>>(
                    future: _invites,
                    builder: (c, s) {
                      if (!s.hasData) return const LinearProgressIndicator();
                      final list = s.data!;
                      if (list.isEmpty) return const Text('لا توجد دعوات');
                      return Column(children: [
                        for (final v in list)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.mail_outline),
                            title: Text(v.email),
                            subtitle: Text(_roleName(v.role)),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () async {
                                await cloudDeleteInvite(v.email);
                                _reload();
                              },
                            ),
                          ),
                      ]);
                    },
                  ),
                ],
              ],
            ),
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();
  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _email = TextEditingController();
  String _role = 'admin';
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final err = await cloudInvite(_email.text, _role);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() => _err = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مشرف'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'بريد المشرف'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'admin', label: Text('مشرف كامل')),
              ButtonSegment(value: 'editor', label: Text('محرّر')),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_err!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          const SizedBox(height: 8),
          const Text(
            'يصبح مشرفًا بعد أن يسجّل بهذا البريد ويفعّله.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _go, child: const Text('دعوة')),
      ],
    );
  }
}

Future<int?> _askLimit(BuildContext context) async {
  final ctrl = TextEditingController(text: '$remoteAiLimit');
  final v = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('الحد اليومي للأسئلة'),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'عدد الأسئلة يوميًا'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            final n = int.tryParse(ctrl.text.trim());
            Navigator.pop(ctx, (n != null && n >= 0 && n <= 1000) ? n : null);
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return v;
}
