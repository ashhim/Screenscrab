import 'dart:convert';
import 'dart:typed_data';

enum MessageType {
  hello,
  capabilities,
  frameMetadata,
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
  disconnect,
  error,
}

const int wireMagic = 0x53435242; // SCRB
const int wireVersion = 1;

class WirePacket {
  WirePacket({
    required this.type,
    required this.payload,
    required this.timestampUtc,
    this.flags = 0,
  });

  final MessageType type;
  final Uint8List payload;
  final DateTime timestampUtc;
  final int flags;

  Uint8List encode() {
    final ByteData header = ByteData(24);
    header.setUint32(0, wireMagic, Endian.little);
    header.setUint16(4, wireVersion, Endian.little);
    header.setUint16(6, type.index, Endian.little);
    header.setUint32(8, flags, Endian.little);
    header.setUint32(12, payload.length, Endian.little);
    header.setUint64(16, timestampUtc.microsecondsSinceEpoch, Endian.little);
    return Uint8List.fromList(<int>[
      ...header.buffer.asUint8List(),
      ...payload,
    ]);
  }

  static WirePacket decode(Uint8List bytes) {
    if (bytes.length < 24) {
      throw FormatException('wire packet too small');
    }
    final ByteData header = ByteData.sublistView(bytes, 0, 24);
    if (header.getUint32(0, Endian.little) != wireMagic) {
      throw FormatException('wire magic mismatch');
    }
    if (header.getUint16(4, Endian.little) != wireVersion) {
      throw FormatException('wire version mismatch');
    }
    final int typeIndex = header.getUint16(6, Endian.little);
    if (typeIndex < 0 || typeIndex >= MessageType.values.length) {
      throw FormatException('wire packet type invalid');
    }
    final int payloadLength = header.getUint32(12, Endian.little);
    if (bytes.length < 24 + payloadLength) {
      throw FormatException('wire payload truncated');
    }
    return WirePacket(
      type: MessageType.values[typeIndex],
      payload: Uint8List.sublistView(bytes, 24, 24 + payloadLength),
      timestampUtc: DateTime.fromMicrosecondsSinceEpoch(
        header.getUint64(16, Endian.little),
        isUtc: true,
      ),
      flags: header.getUint32(8, Endian.little),
    );
  }
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
