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
class NetworkPeer {
  const NetworkPeer({
    required this.nodeId,
    required this.name,
    required this.address,
    required this.platform,
    required this.online,
    required this.latencyMs,
    required this.quality,
  });

  final String nodeId;
  final String name;
  final String address;
  final String platform;
  final bool online;
  final int latencyMs;
  final int quality;

  factory NetworkPeer.fromJson(Map<String, dynamic> json) {
    return NetworkPeer(
      nodeId: (json['nodeId'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      platform: (json['platform'] as String?) ?? '',
      online: json['online'] as bool? ?? false,
      latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 0,
      quality: (json['quality'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class NetworkRuntimeStatus {
  const NetworkRuntimeStatus({
    required this.started,
    required this.signedIn,
    required this.accountEmail,
    required this.tailnetName,
    required this.deviceName,
    required this.deviceId,
    required this.tailscaleIp,
    required this.peerCount,
    required this.loginUrl,
    required this.lastErrorMessage,
    required this.peers,
  });

  final bool started;
  final bool signedIn;
  final String accountEmail;
  final String tailnetName;
  final String deviceName;
  final String deviceId;
  final String tailscaleIp;
  final int peerCount;
  final String loginUrl;
  final String lastErrorMessage;
  final List<NetworkPeer> peers;

  factory NetworkRuntimeStatus.fromJson(Map<String, dynamic> json) {
    final List<dynamic> peerList = json['peers'] as List<dynamic>? ?? <dynamic>[];
    return NetworkRuntimeStatus(
      started: json['started'] as bool? ?? false,
      signedIn: json['signedIn'] as bool? ?? false,
      accountEmail: (json['accountEmail'] as String?) ?? '',
      tailnetName: (json['tailnetName'] as String?) ?? '',
      deviceName: (json['deviceName'] as String?) ?? '',
      deviceId: (json['deviceId'] as String?) ?? '',
      tailscaleIp: (json['tailscaleIp'] as String?) ?? '',
      peerCount: (json['peerCount'] as num?)?.toInt() ?? peerList.length,
      loginUrl: (json['loginUrl'] as String?) ?? '',
      lastErrorMessage: (json['lastErrorMessage'] as String?) ?? '',
      peers: peerList
          .whereType<Map<String, dynamic>>()
          .map(NetworkPeer.fromJson)
          .toList(),
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
