// توحيد النص العربي للمقارنة والبحث (مشترك بين التطبيق والتخزين المحلي).

int normChar(int c) {
  if ((c >= 0x064B && c <= 0x065F) || c == 0x0670 || c == 0x0640) return -1;
  if (c == 0x0623 || c == 0x0625 || c == 0x0622 || c == 0x0671) return 0x0627;
  if (c == 0x0649) return 0x064A;
  if (c == 0x0629) return 0x0647;
  if (c == 10 || c == 13 || c == 9 || c == 0xA0) return 32;
  return c;
}

/// يوحّد النص للمقارنة: بلا تشكيل ولا تطويل، وتُوحَّد الألف والياء والتاء المربوطة.
/// إن مُرِّرت [map] فتُملأ بموضع كل حرف في النص الأصلي.
String normRaw(String raw, {List<int>? map, bool tags = true}) {
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
    final m = normChar(c);
    if (m < 0) continue;
    sb.writeCharCode(m);
    map?.add(i);
  }
  return sb.toString();
}

String normArabic(String s) => normRaw(s, tags: false);
