import 'dart:convert';

enum MessageType {
  hello,
  sessionStart,
  sessionStop,
  videoFrame,
  audioFrame,
  inputEvent,
  clipboardSync,
  fileOffer,
  fileChunk,
  deviceList,
  ping,
  pong,
  error,
}

class ProtocolEnvelope {
  ProtocolEnvelope({
    required this.type,
    required this.payload,
    required this.timestampUtc,
  });

  final MessageType type;
  final Map<String, Object?> payload;
  final DateTime timestampUtc;

  Map<String, Object?> toJson() => <String, Object?>{
        'type': type.name,
        'payload': payload,
        'timestampUtc': timestampUtc.toIso8601String(),
      };

  String encode() => jsonEncode(toJson());
}

ProtocolEnvelope decodeEnvelope(String encoded) {
  final Map<String, dynamic> json = jsonDecode(encoded) as Map<String, dynamic>;
  return ProtocolEnvelope(
    type: MessageType.values.firstWhere((MessageType value) => value.name == json['type']),
    payload: (json['payload'] as Map).cast<String, Object?>(),
    timestampUtc: DateTime.parse(json['timestampUtc'] as String),
  );
}
