import 'dart:ffi' as ffi;
import 'dart:convert';

import 'package:screenscrab_shared/screenscrab_shared.dart';

class ScreenscrabEngineBridge {
  Future<void> initialize() async {
    final EngineLibrary? library = EngineLibrary.openDefault();
    if (library == null) {
      return;
    }
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
  int get apiVersion => _bindings == null ? 0 : _bindings!.apiVersion();
  int get protocolVersion => _bindings == null ? 0 : _bindings!.protocolVersion();
  EngineCapabilities? get capabilities {
    if (_bindings == null) {
      return null;
    }
    return EngineCapabilities.fromJson(
      jsonDecode(_bindings!.capabilitiesJson()) as Map<String, dynamic>,
    );
  }
  String? get lastErrorMessage => _bindings == null || _handle == null ? null : _bindings!.lastErrorMessage(_handle!);

  NetworkRuntimeStatus? runtimeStatus() {
    if (_bindings == null || _handle == null) {
      return null;
    }
    final String statusJson = _bindings!.runtimeStatusJson(_handle!);
    return NetworkRuntimeStatus.fromJson(jsonDecode(statusJson) as Map<String, dynamic>);
  }

  Future<void> beginSignIn() async {
    if (_bindings == null || _handle == null) {
      return;
    }
    _bindings!.beginSignIn(_handle!);
  }

  Future<void> refreshRuntime() async {
    if (_bindings == null || _handle == null) {
      return;
    }
    _bindings!.refresh(_handle!);
  }

  Future<void> connectPeer(String peerName, int port) async {
    if (_bindings == null || _handle == null) {
      return;
    }
    _bindings!.connectPeer(_handle!, peerName, port);
  }

  void dispose() {
    if (_bindings != null && _handle != null) {
      _bindings!.destroy(_handle!);
      _handle = null;
    }
    _bindings = null;
  }

  EngineBindings? _bindings;
  ffi.Pointer<ffi.Void>? _handle;
}
