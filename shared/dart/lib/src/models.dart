import 'package:meta/meta.dart';

enum AppMode { host, client }

enum ConnectionStateValue { disconnected, connecting, connected, reconnecting, error }

enum MonitorSelectionMode { primary, specific, all }

@immutable
class EngineRuntimeStatus {
  const EngineRuntimeStatus({
    required this.apiVersion,
    required this.mode,
    required this.engineLoaded,
    required this.sessionActive,
    required this.tailscaleReachable,
    required this.captureReady,
    required this.audioReady,
    required this.monitorIndex,
    required this.lastError,
    required this.lastErrorMessage,
  });

  final int apiVersion;
  final String mode;
  final bool engineLoaded;
  final bool sessionActive;
  final bool tailscaleReachable;
  final bool captureReady;
  final bool audioReady;
  final int monitorIndex;
  final int lastError;
  final String lastErrorMessage;

  factory EngineRuntimeStatus.fromJson(Map<String, dynamic> json) {
    return EngineRuntimeStatus(
      apiVersion: (json['apiVersion'] as num?)?.toInt() ?? 1,
      mode: (json['mode'] as String?) ?? 'stopped',
      engineLoaded: json['engineLoaded'] as bool? ?? false,
      sessionActive: json['sessionActive'] as bool? ?? false,
      tailscaleReachable: json['tailscaleReachable'] as bool? ?? false,
      captureReady: json['captureReady'] as bool? ?? false,
      audioReady: json['audioReady'] as bool? ?? false,
      monitorIndex: (json['monitorIndex'] as num?)?.toInt() ?? 0,
      lastError: (json['lastError'] as num?)?.toInt() ?? 0,
      lastErrorMessage: (json['lastErrorMessage'] as String?) ?? '',
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
