import 'package:meta/meta.dart';

enum AppMode { host, client }

enum ConnectionStateValue { disconnected, connecting, connected, reconnecting, error }

enum MonitorSelectionMode { primary, specific, all }

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
