import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:tdjson_native/tdjson_native.dart';

typedef TdObject = Map<String, dynamic>;

class TdError implements Exception {
  TdError(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'TdError($code): $message';
}

/// Async wrapper over one TDLib client.
///
/// Requests are matched to responses through `@extra`; everything else is an
/// update and goes to [updates]. `td_receive` blocks, so it runs in its own
/// isolate and forwards raw JSON strings back here.
class TdClient {
  TdClient._(this._td, this._clientId);

  final TdJson _td;
  final int _clientId;
  final _pending = <String, Completer<TdObject>>{};
  final _updates = StreamController<TdObject>.broadcast(sync: true);
  Isolate? _receiver;
  ReceivePort? _port;
  int _nextExtra = 0;
  bool _closed = false;

  /// Latest authorization state, for listeners that subscribe late.
  TdObject? authorizationState;

  Stream<TdObject> get updates => _updates.stream;

  /// Filters [updates] by `@type`.
  Stream<TdObject> on(String type) => updates.where((u) => u['@type'] == type);

  static Future<TdClient> start({int logVerbosity = 1}) async {
    final td = TdJson.open();
    td.execute(jsonEncode({'@type': 'setLogVerbosityLevel', 'new_verbosity_level': logVerbosity}));
    final client = TdClient._(td, td.createClientId());
    await client._startReceiver();
    // Any request makes TDLib actually create the client and start emitting
    // updateAuthorizationState.
    unawaited(client.send({'@type': 'getOption', 'name': 'version'}).then((_) {}, onError: (_) {}));
    return client;
  }

  Future<void> _startReceiver() async {
    final port = ReceivePort();
    _port = port;
    _receiver = await Isolate.spawn(_receiveLoop, port.sendPort, debugName: 'tdlib-receive');
    port.listen((message) {
      if (message is String) _dispatch(message);
    });
  }

  void _dispatch(String raw) {
    final TdObject obj;
    try {
      obj = jsonDecode(raw) as TdObject;
    } catch (_) {
      return;
    }
    final extra = obj.remove('@extra');
    obj.remove('@client_id');
    if (extra is String) {
      final completer = _pending.remove(extra);
      if (completer != null) {
        if (obj['@type'] == 'error') {
          completer.completeError(TdError(obj['code'] as int? ?? 0, obj['message'] as String? ?? ''));
        } else {
          completer.complete(obj);
        }
        return;
      }
    }
    if (obj['@type'] == 'updateAuthorizationState') {
      authorizationState = obj['authorization_state'] as TdObject;
    }
    _updates.add(obj);
  }

  /// Sends [request] and waits for its response. Throws [TdError].
  Future<TdObject> send(TdObject request, {Duration? timeout}) {
    if (_closed) return Future.error(StateError('TDLib client is closed'));
    final extra = 'r${_nextExtra++}';
    final completer = Completer<TdObject>();
    _pending[extra] = completer;
    _td.send(_clientId, jsonEncode({...request, '@extra': extra}));
    if (timeout == null) return completer.future;
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(extra);
        throw TimeoutException('${request['@type']} timed out', timeout);
      },
    );
  }

  /// Fire-and-forget: errors are swallowed.
  void post(TdObject request) {
    send(request).then((_) {}, onError: (_) {});
  }

  Future<void> close() async {
    if (_closed) return;
    final done = on('updateAuthorizationState')
        .where((u) => (u['authorization_state'] as Map)['@type'] == 'authorizationStateClosed')
        .first
        .timeout(const Duration(seconds: 10), onTimeout: () => const {});
    post({'@type': 'close'});
    await done;
    // `done` completes synchronously inside the update dispatch; leave it
    // before closing the controller that is still firing.
    await Future<void>.delayed(Duration.zero);
    _closed = true;
    _receiver?.kill(priority: Isolate.immediate);
    _port?.close();
    for (final c in _pending.values) {
      c.completeError(StateError('TDLib client is closed'));
    }
    _pending.clear();
    await _updates.close();
  }
}

void _receiveLoop(SendPort out) {
  final td = TdJson.open();
  while (true) {
    final raw = td.receive(1.0);
    if (raw != null) out.send(raw);
  }
}

// Small helpers for building and reading TDLib objects.

TdObject formattedText(String text) => {'@type': 'formattedText', 'text': text, 'entities': <dynamic>[]};

TdObject boolOption(bool value) => {'@type': 'optionValueBoolean', 'value': value};

const TdObject chatListMain = {'@type': 'chatListMain'};
const TdObject chatListArchive = {'@type': 'chatListArchive'};

/// Stable key for a TDLib ChatList object.
String chatListKey(Map list) => switch (list['@type']) {
  'chatListMain' => 'main',
  'chatListArchive' => 'archive',
  'chatListFolder' => 'folder:${list['chat_folder_id']}',
  final other => '$other',
};
