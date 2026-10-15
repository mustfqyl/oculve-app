import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/network/oculve_api.dart';

class _IdentityStorage implements FlutterSecureStorage {
  final readGate = Completer<String?>();
  int reads = 0, writes = 0;
  final writeStarted = Completer<void>();
  Completer<void>? writeGate;
  String? saved;
  Future<void> _write(String value) async {
    writes++;
    if (!writeStarted.isCompleted) writeStarted.complete();
    await writeGate?.future;
    saved = value;
  }

  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #read) {
      reads++;
      return readGate.future;
    }
    if (call.memberName == #write) {
      return _write(call.namedArguments[#value] as String);
    }
    return super.noSuchMethod(call);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'simultaneous registration requests share one persistent device identity',
    () async {
      final storage = _IdentityStorage();
      final api = OculveApi(storage: storage);
      addTearDown(api.close);
      final first = api.registrationHeaders();
      final second = api.registrationHeaders();
      storage.readGate.complete(null);
      final values = await Future.wait([first, second]);
      expect(values[0].values.single == values[1].values.single, isTrue);
      expect(storage.reads, 1);
      expect(storage.writes, 1);
      expect(await api.registrationHeaders(), values.first);
      expect(storage.reads, 1);
    },
  );

  test(
    'parallel registration waits until its single identity write finishes',
    () async {
      final storage = _IdentityStorage()..writeGate = Completer<void>();
      final api = OculveApi(storage: storage);
      addTearDown(api.close);
      final first = api.registrationHeaders();
      storage.readGate.complete(null);
      await storage.writeStarted.future;
      var secondDone = false;
      final second = api.registrationHeaders().then((value) {
        secondDone = true;
        return value;
      });
      try {
        await Future<void>.delayed(Duration.zero);
        expect(secondDone, isFalse);
      } finally {
        storage.writeGate!.complete();
      }
      final values = await Future.wait([first, second]);
      expect(values[0].values.single == values[1].values.single, isTrue);
      expect(storage.writes, 1);
    },
  );

  test(
    'concurrent registration reads preserve the existing stored identity',
    () async {
      final storage = _IdentityStorage();
      final api = OculveApi(storage: storage);
      addTearDown(api.close);
      final first = api.registrationHeaders();
      final second = api.registrationHeaders();
      storage.readGate.complete('existing-device-fixture');
      final values = await Future.wait([first, second]);
      expect(values[0].values.single == values[1].values.single, isTrue);
      expect(storage.reads, 1);
      expect(storage.writes, 0);
    },
  );
}
