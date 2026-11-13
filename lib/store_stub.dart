// نسخة المتصفح: لا تخزين للكتب على الجهاز.

const bool storeSupported = false;

Future<void> storeInit() async {}

bool storeHas(int id) => false;

Set<int> storeIds() => <int>{};

Future<String?> storeRead(int id, String name) async => null;

Future<void> storeDownload(int id, void Function(double) onProgress,
    {int expected = 0}) async {
  throw UnsupportedError('web');
}

Future<void> storeDelete(int id) async {}

Future<int> storeSize(int id) async => 0;
