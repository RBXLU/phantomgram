/// dart:ffi binding to the TDLib JSON interface.
///
/// See https://core.telegram.org/tdlib/docs/td__json__client_8h.html
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _CreateClientIdNative = Int32 Function();
typedef _CreateClientId = int Function();
typedef _SendNative = Void Function(Int32, Pointer<Utf8>);
typedef _Send = void Function(int, Pointer<Utf8>);
typedef _ReceiveNative = Pointer<Utf8> Function(Double);
typedef _Receive = Pointer<Utf8> Function(double);
typedef _ExecuteNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _Execute = Pointer<Utf8> Function(Pointer<Utf8>);

class TdJson {
  TdJson._(DynamicLibrary lib)
    : _createClientId = lib.lookupFunction<_CreateClientIdNative, _CreateClientId>('td_create_client_id'),
      _send = lib.lookupFunction<_SendNative, _Send>('td_send'),
      _receive = lib.lookupFunction<_ReceiveNative, _Receive>('td_receive'),
      _execute = lib.lookupFunction<_ExecuteNative, _Execute>('td_execute');

  /// Opens the bundled library. Safe to call from any isolate.
  factory TdJson.open() => TdJson._(_openLibrary());

  final _CreateClientId _createClientId;
  final _Send _send;
  final _Receive _receive;
  final _Execute _execute;

  static DynamicLibrary _openLibrary() {
    if (Platform.isIOS || Platform.isMacOS) {
      return DynamicLibrary.open('tdjson.framework/tdjson');
    }
    if (Platform.isLinux) {
      final override = Platform.environment['TDJSON_PATH'];
      return DynamicLibrary.open(override ?? 'libtdjson.so');
    }
    throw UnsupportedError('TDLib is not bundled for ${Platform.operatingSystem}');
  }

  int createClientId() => _createClientId();

  void send(int clientId, String request) {
    final ptr = request.toNativeUtf8();
    try {
      _send(clientId, ptr);
    } finally {
      malloc.free(ptr);
    }
  }

  /// Blocks for up to [timeout] seconds. Returns null when nothing arrived.
  String? receive(double timeout) {
    final ptr = _receive(timeout);
    // The buffer belongs to TDLib and stays valid only until the next call.
    return ptr == nullptr ? null : ptr.toDartString();
  }

  /// Synchronous requests (logging, parsing helpers). Not every method allows it.
  String? execute(String request) {
    final ptr = request.toNativeUtf8();
    try {
      final result = _execute(ptr);
      return result == nullptr ? null : result.toDartString();
    } finally {
      malloc.free(ptr);
    }
  }
}
