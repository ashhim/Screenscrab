import 'package:meta/meta.dart';

enum AppMode { host, client }

enum ConnectionStateValue { disconnected, connecting, connected, reconnecting, error }

enum MonitorSelectionMode { primary, specific, all }

@immutable
class EngineRuntimeStatus {
  const EngineRuntimeStatus({
    required this.apiVersion,
    required this.protocolVersion,
    required this.mode,
    required this.transportState,
    required this.engineLoaded,
    required this.sessionActive,
    required this.tailscaleReachable,
    required this.captureActive,
    required this.inputEnabled,
    required this.clipboardEnabled,
    required this.audioEnabled,
    required this.monitorIndex,
    required this.port,
    required this.framesSent,
    required this.endpoint,
    required this.encoder,
    required this.lastError,
    required this.lastErrorMessage,
  });

  final int apiVersion;
  final int protocolVersion;
  final String mode;
  final String transportState;
  final bool engineLoaded;
  final bool sessionActive;
  final bool tailscaleReachable;
  final bool captureActive;
  final bool inputEnabled;
  final bool clipboardEnabled;
  final bool audioEnabled;
  final int monitorIndex;
  final int port;
  final int framesSent;
  final String endpoint;
  final String encoder;
  final int lastError;
  final String lastErrorMessage;

  factory EngineRuntimeStatus.fromJson(Map<String, dynamic> json) {
    return EngineRuntimeStatus(
      apiVersion: (json['apiVersion'] as num?)?.toInt() ?? 1,
      protocolVersion: (json['protocolVersion'] as num?)?.toInt() ?? 1,
      mode: (json['mode'] as String?) ?? 'stopped',
      transportState: (json['transportState'] as String?) ?? 'offline',
      engineLoaded: json['engineLoaded'] as bool? ?? false,
      sessionActive: json['sessionActive'] as bool? ?? false,
      tailscaleReachable: json['tailscaleReachable'] as bool? ?? false,
      captureActive: json['captureActive'] as bool? ?? false,
      inputEnabled: json['inputEnabled'] as bool? ?? false,
      clipboardEnabled: json['clipboardEnabled'] as bool? ?? false,
      audioEnabled: json['audioEnabled'] as bool? ?? false,
      monitorIndex: (json['monitorIndex'] as num?)?.toInt() ?? 0,
      port: (json['port'] as num?)?.toInt() ?? 4545,
      framesSent: (json['framesSent'] as num?)?.toInt() ?? 0,
      endpoint: (json['endpoint'] as String?) ?? '',
      encoder: (json['encoder'] as String?) ?? 'none',
      lastError: (json['lastError'] as num?)?.toInt() ?? 0,
      lastErrorMessage: (json['lastErrorMessage'] as String?) ?? '',
    );
  }
}

@immutable
class EngineCapabilities {
  const EngineCapabilities({
    required this.capture,
    required this.encode,
    required this.transport,
    required this.input,
    required this.clipboard,
    required this.fileTransfer,
    required this.audio,
    required this.multiMonitor,
    required this.lockedScreen,
    required this.hostMode,
    required this.clientMode,
  });

  final bool capture;
  final bool encode;
  final bool transport;
  final bool input;
  final bool clipboard;
  final bool fileTransfer;
  final bool audio;
  final bool multiMonitor;
  final bool lockedScreen;
  final bool hostMode;
  final bool clientMode;

  factory EngineCapabilities.fromJson(Map<String, dynamic> json) {
    bool readFlag(String key) => json[key] as bool? ?? false;
    return EngineCapabilities(
      capture: readFlag('capture'),
      encode: readFlag('encode'),
      transport: readFlag('transport'),
      input: readFlag('input'),
      clipboard: readFlag('clipboard'),
      fileTransfer: readFlag('fileTransfer'),
      audio: readFlag('audio'),
      multiMonitor: readFlag('multiMonitor'),
      lockedScreen: readFlag('lockedScreen'),
      hostMode: readFlag('hostMode'),
      clientMode: readFlag('clientMode'),
    );
  }
}

@immutable
class DeviceEndpoint {
  const DeviceEndpoint({
    required this.deviceId,
    required this.name,
    required this.address,
    required this.mode,
    required this.lastSeenUtc,
  });

  final String deviceId;
  final String name;
  final String address;
  final AppMode mode;
  final DateTime lastSeenUtc;
}

@immutable
class TransferItem {
  const TransferItem({
    required this.id,
    required this.fileName,
    required this.sizeBytes,
    required this.progress,
  });

  final String id;
  final String fileName;
  final int sizeBytes;
  final double progress;
}

@immutable
class SessionStatus {
  const SessionStatus({
    required this.connectionState,
    required this.remoteName,
    required this.latencyMs,
    required this.monitorIndex,
    required this.audioEnabled,
    required this.clipboardEnabled,
  });

  final ConnectionStateValue connectionState;
  final String remoteName;
  final int latencyMs;
  final int monitorIndex;
  final bool audioEnabled;
  final bool clipboardEnabled;
}
