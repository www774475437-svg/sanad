// تخزين الكتب على الهاتف للقراءة والبحث بلا إنترنت (تطبيق الأندرويد).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'norm.dart';

const bool storeSupported = true;

Directory? _root;
final Set<int> _ids = <int>{};

Future<void> storeInit() async {
  final base = await getApplicationSupportDirectory();
  final r = Directory('${base.path}/books');
  if (!await r.exists()) await r.create(recursive: true);
  _root = r;
  _ids.clear();
  await for (final e in r.list()) {
    if (e is Directory) {
      final parts = e.path.split(Platform.pathSeparator);
      final id = int.tryParse(parts.isEmpty ? '' : parts.last);
      if (id != null && await File('${e.path}/ok').exists()) _ids.add(id);
    }
  }
}

bool storeHas(int id) => _ids.contains(id);

Set<int> storeIds() => Set<int>.of(_ids);

Future<String?> storeRead(int id, String name) async {
  final r = _root;
  if (r == null || !_ids.contains(id)) return null;
  try {
    final f = File('${r.path}/$id/$name');
    if (await f.exists()) return await f.readAsString();
  } catch (_) {}
  return null;
}

Future<void> storeDownload(int id, void Function(double) onProgress,
    {int expected = 0}) async {
  final r = _root;
  if (r == null) throw StateError('no storage');
  final dir = Directory('${r.path}/$id');
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);
  final tmp = File('${dir.path}/raw.json');
  final client = http.Client();
  try {
    final req = http.Request(
        'GET', Uri.parse('https://files.turath.io/books-v3/$id.json'));
    req.headers['User-Agent'] =
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36';
    req.headers['Accept'] = 'application/json,*/*';
    final resp = await client.send(req).timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) {
      throw HttpException('HTTP ${resp.statusCode}');
    }
    final cl = resp.contentLength ?? 0;
    final total = cl > 0 ? cl : expected;
    final sink = tmp.openWrite();
    var got = 0;
    try {
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) {
          final f = got / total;
          onProgress(f > 1 ? 0.9 : f * 0.9);
        }
      }
    } finally {
      await sink.close();
    }
    onProgress(0.93);
    await compute(_split, <String>[tmp.path, dir.path]);
    try {
      await tmp.delete();
    } catch (_) {}
    await File('${dir.path}/ok').writeAsString('1');
    _ids.add(id);
    onProgress(1);
  } catch (_) {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
    rethrow;
  } finally {
    client.close();
  }
}

/// يقسّم ملف الكتاب إلى أجزاء صغيرة وملف بحث، في خيط مستقل.
void _split(List<String> a) {
  final d = jsonDecode(File(a[0]).readAsStringSync());
  final dynamic pagesAny = d is Map ? d['pages'] : null;
  final List<dynamic> pages = pagesAny is List ? pagesAny : const <dynamic>[];
  final nb = StringBuffer();
  for (var i = 0; i < pages.length; i += 20) {
    final chunk = <List<String>>[];
    for (var j = i; j < pages.length && j < i + 20; j++) {
      final p = pages[j];
      var raw = '';
      var vol = '';
      var pg = '';
      if (p is Map) {
        raw = '${p['text'] ?? ''}';
        vol = p['vol'] == null ? '' : '${p['vol']}';
        pg = p['page'] == null ? '' : '${p['page']}';
      }
      chunk.add(<String>[vol, pg, raw]);
      nb.writeln(normRaw(raw));
    }
    File('${a[1]}/p_${i ~/ 20}.json').writeAsStringSync(jsonEncode(chunk));
  }
  File('${a[1]}/n.txt').writeAsStringSync(nb.toString());
  final toc = <List<dynamic>>[];
  final dynamic idx = d is Map ? d['indexes'] : null;
  final dynamic hs = idx is Map ? idx['headings'] : null;
  if (hs is List) {
    for (final h in hs) {
      if (h is Map && h['page'] is int) {
        final t = '${h['title'] ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (t.isEmpty) continue;
        toc.add(<dynamic>[h['level'] is int ? h['level'] : 1, h['page'], t]);
      }
    }
    File('${a[1]}/t.json').writeAsStringSync(jsonEncode(toc));
  }
}

Future<void> storeDelete(int id) async {
  final r = _root;
  _ids.remove(id);
  if (r == null) return;
  try {
    final dir = Directory('${r.path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {}
}

Future<int> storeSize(int id) async {
  final r = _root;
  if (r == null || !_ids.contains(id)) return 0;
  var n = 0;
  try {
    await for (final e in Directory('${r.path}/$id').list()) {
      if (e is File) n += await e.length();
    }
  } catch (_) {}
  return n;
}
