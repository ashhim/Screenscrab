import 'dart:ffi' as ffi;
import 'dart:convert';

import 'package:screenscrab_shared/screenscrab_shared.dart';

class ScreenscrabEngineBridge {
  Future<void> initialize() async {
    if (_library != null) {
      return;
    }
    final EngineLibrary? library = EngineLibrary.openDefault();
    if (library == null) {
      return;
    }
    _library = library;
    _bindings = library.bind();
    _handle = _bindings!.create();
  }

  EngineRuntimeStatus? currentStatus() {
    if (_bindings == null || _handle == null) {
      return null;
    }
    final String statusJson = _bindings!.statusJson(_handle!);
    return EngineRuntimeStatus.fromJson(jsonDecode(statusJson) as Map<String, dynamic>);
  }

  Future<void> startHost(String deviceName) async {
    if (_bindings == null || _handle == null) {
      return;
    }
    _bindings!.startHost(_handle!, deviceName);
  }

  Future<void> startClient(String address, int port) async {
    if (_bindings == null || _handle == null) {
      return;
    }
    _bindings!.startClient(_handle!, address, port);
  }

  Future<void> stop() async {
    if (_bindings == null || _handle == null) {
      return;
    }
    _bindings!.stop(_handle!);
  }

  String? get version => _bindings == null ? null : _bindings!.version();
  String? get lastErrorMessage => _bindings == null || _handle == null ? null : _bindings!.lastErrorMessage(_handle!);

  void dispose() {
    if (_bindings != null && _handle != null) {
      _bindings!.destroy(_handle!);
      _handle = null;
    }
    _bindings = null;
    _library = null;
  }

  EngineLibrary? _library;
  EngineBindings? _bindings;
  ffi.Pointer<ffi.Void>? _handle;
}
