import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

typedef _CreateNative = ffi.Pointer<ffi.Void> Function();
typedef _DestroyNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _StartHostNative = ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Char>);
typedef _StartHostDart = int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Char>);
typedef _StartClientNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
  ffi.Uint16,
);
typedef _StartClientDart = int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Char>, int);
typedef _StopNative = ffi.Int32 Function(ffi.Pointer<ffi.Void>);
typedef _LastErrorNative = ffi.Int32 Function(ffi.Pointer<ffi.Void>);
typedef _StatusNative = ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Void>);
typedef _VersionNative = ffi.Pointer<ffi.Char> Function();
typedef _MessageNative = ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Void>);
typedef _VersionValueNative = ffi.Uint32 Function();
typedef _CapabilitiesNative = ffi.Pointer<ffi.Char> Function();

@immutable
class EngineLibrary {
  const EngineLibrary(this.library);

  final ffi.DynamicLibrary library;

  static EngineLibrary? openDefault() {
    if (!Platform.isWindows) {
      return null;
    }
    final List<String> candidates = <String>[
      'screencrab_engine.dll',
      'engine/windows/out/screencrab_engine.dll',
      '${Directory.current.path}\\screencrab_engine.dll',
      '${Directory.current.path}\\engine\\windows\\out\\screencrab_engine.dll',
      '${File(Platform.resolvedExecutable).parent.path}\\screencrab_engine.dll',
    ];
    for (final String path in candidates) {
      final File file = File(path);
      if (file.existsSync()) {
        return EngineLibrary(ffi.DynamicLibrary.open(file.path));
      }
    }
    return null;
  }

  EngineBindings bind() {
    final ffi.Pointer<ffi.Void> Function() create =
        library.lookupFunction<_CreateNative, ffi.Pointer<ffi.Void> Function()>('screencrab_engine_create');
    final void Function(ffi.Pointer<ffi.Void>) destroy =
        library.lookupFunction<_DestroyNative, void Function(ffi.Pointer<ffi.Void>)>('screencrab_engine_destroy');
    final int Function(ffi.Pointer<ffi.Void>, String) startHost = (ffi.Pointer<ffi.Void> handle, String deviceName) {
      final ffi.Pointer<ffi.Char> nativeName = _toNativeCharPointer(deviceName);
      try {
        return library.lookupFunction<_StartHostNative, _StartHostDart>(
          'screencrab_engine_start_host',
        )(handle, nativeName);
      } finally {
        malloc.free(nativeName.cast<ffi.Uint8>());
      }
    };
    final int Function(ffi.Pointer<ffi.Void>, String, int) startClient =
        (ffi.Pointer<ffi.Void> handle, String address, int port) {
      final ffi.Pointer<ffi.Char> nativeAddress = _toNativeCharPointer(address);
      try {
        return library.lookupFunction<_StartClientNative, _StartClientDart>(
          'screencrab_engine_start_client',
        )(handle, nativeAddress, port);
      } finally {
        malloc.free(nativeAddress.cast<ffi.Uint8>());
      }
    };
    final int Function(ffi.Pointer<ffi.Void>) stop =
        library.lookupFunction<_StopNative, int Function(ffi.Pointer<ffi.Void>)>('screencrab_engine_stop');
    final int Function(ffi.Pointer<ffi.Void>) lastError =
        library.lookupFunction<_LastErrorNative, int Function(ffi.Pointer<ffi.Void>)>('screencrab_engine_last_error');
    final String Function() version =
        () => library.lookupFunction<_VersionNative, ffi.Pointer<ffi.Char> Function()>('screencrab_engine_version')().cast<Utf8>().toDartString();
    final int Function() apiVersion = library.lookupFunction<_VersionValueNative, int Function()>('screencrab_engine_api_version');
    final int Function() protocolVersion =
        library.lookupFunction<_VersionValueNative, int Function()>('screencrab_engine_protocol_version');
    final String Function() capabilitiesJson =
        () => library.lookupFunction<_CapabilitiesNative, ffi.Pointer<ffi.Char> Function()>('screencrab_engine_capabilities_json')().cast<Utf8>().toDartString();
    final String Function(ffi.Pointer<ffi.Void>) statusJson = (ffi.Pointer<ffi.Void> handle) {
      final ffi.Pointer<ffi.Char> ptr =
          library.lookupFunction<_StatusNative, ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Void>)>(
        'screencrab_engine_status_json',
      )(handle);
      return ptr.cast<Utf8>().toDartString();
    };
    final String Function(ffi.Pointer<ffi.Void>) lastErrorMessage =
        (ffi.Pointer<ffi.Void> handle) => library
            .lookupFunction<_MessageNative, ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Void>)>(
              'screencrab_engine_last_error_message',
            )(handle)
            .cast<Utf8>()
            .toDartString();
    return EngineBindings(
      create: create,
      destroy: destroy,
      startHost: startHost,
      startClient: startClient,
      stop: stop,
      lastError: lastError,
      version: version,
      apiVersion: apiVersion,
      protocolVersion: protocolVersion,
      capabilitiesJson: capabilitiesJson,
      statusJson: statusJson,
      lastErrorMessage: lastErrorMessage,
    );
  }

  ffi.Pointer<ffi.Char> _toNativeCharPointer(String value) {
    final List<int> encoded = utf8.encode(value);
    final ffi.Pointer<ffi.Uint8> buffer = malloc<ffi.Uint8>(encoded.length + 1);
    for (var i = 0; i < encoded.length; i++) {
      buffer[i] = encoded[i];
    }
    buffer[encoded.length] = 0;
    return buffer.cast<ffi.Char>();
  }
}

@immutable
class EngineBindings {
  const EngineBindings({
    required this.create,
    required this.destroy,
    required this.startHost,
    required this.startClient,
    required this.stop,
    required this.lastError,
    required this.version,
    required this.apiVersion,
    required this.protocolVersion,
    required this.capabilitiesJson,
    required this.statusJson,
    required this.lastErrorMessage,
  });

  final ffi.Pointer<ffi.Void> Function() create;
  final void Function(ffi.Pointer<ffi.Void>) destroy;
  final int Function(ffi.Pointer<ffi.Void>, String) startHost;
  final int Function(ffi.Pointer<ffi.Void>, String, int) startClient;
  final int Function(ffi.Pointer<ffi.Void>) stop;
  final int Function(ffi.Pointer<ffi.Void>) lastError;
  final String Function() version;
  final int Function() apiVersion;
  final int Function() protocolVersion;
  final String Function() capabilitiesJson;
  final String Function(ffi.Pointer<ffi.Void>) statusJson;
  final String Function(ffi.Pointer<ffi.Void>) lastErrorMessage;
}
