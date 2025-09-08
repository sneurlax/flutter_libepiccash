import 'package:json_annotation/json_annotation.dart';

part 'mwcmqs_address.g.dart';

/// MWCMQS address model for MWC Message Queue System communication.
@JsonSerializable()
class MwcmqsAddress {
  /// The full MWCMQS address (e.g., "gTesT7...@mwcmqs.mwc.mw:443").
  final String address;
  
  /// The public key part of the address.
  final String publicKey;
  
  /// The domain part (e.g., "mwcmqs.mwc.mw").
  final String domain;
  
  /// The port number (default: 443).
  final int port;
  
  /// The derivation index used to generate this address.
  final int index;
  
  /// Whether this is a mainnet address (starts with 'g') or floonet (starts with 'x').
  final bool isMainnet;

  const MwcmqsAddress({
    required this.address,
    required this.publicKey,
    required this.domain,
    required this.port,
    required this.index,
    required this.isMainnet,
  });

  /// Create MwcmqsAddress from JSON.
  factory MwcmqsAddress.fromJson(Map<String, dynamic> json) => 
      _$MwcmqsAddressFromJson(json);

  /// Convert MwcmqsAddress to JSON.
  Map<String, dynamic> toJson() => _$MwcmqsAddressToJson(this);

  /// Parse an MWCMQS address string.
  /// Accepts formats:
  /// - "publicKey@domain:port"
  /// - "mwcmqs://publicKey@domain:port"
  /// - "publicKey" (defaults to mwcmqs.mwc.mw:443)
  /// - "mwcmqs://publicKey" (defaults to mwcmqs.mwc.mw:443)
  factory MwcmqsAddress.parse(String addressString, {int index = 0}) {
    String raw = addressString.trim();
    // Strip optional scheme
    const scheme = 'mwcmqs://';
    if (raw.startsWith(scheme)) {
      raw = raw.substring(scheme.length);
    }

    String publicKey;
    String domain = 'mwcmqs.mwc.mw';
    int port = 443;

    if (raw.contains('@')) {
      final parts = raw.split('@');
      if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
        throw ArgumentError('Invalid MWCMQS address format: $addressString');
      }
      publicKey = parts[0];
      final domainPort = parts[1].split(':');
      domain = domainPort[0];
      if (domainPort.length > 1) {
        final parsed = int.tryParse(domainPort[1]);
        port = parsed ?? 443;
      }
    } else {
      // Public key only; use defaults
      publicKey = raw;
    }

    // Determine mainnet in a more robust way
    bool isMainnet = publicKey.startsWith('g');
    if (!isMainnet) {
      if (publicKey.startsWith('x')) {
        isMainnet = false;
      } else {
        isMainnet = domain.contains('mwc.mw');
      }
    }

    return MwcmqsAddress(
      address: addressString,
      publicKey: publicKey,
      domain: domain,
      port: port,
      index: index,
      isMainnet: isMainnet,
    );
  }

  /// Validate MWCMQS address format.
  static bool isValid(String address) {
    try {
      parse(address);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  String toString() => address;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MwcmqsAddress && other.address == address;
  }

  @override
  int get hashCode => address.hashCode;
}

/// MWCMQS configuration for connecting to message queue servers.
@JsonSerializable()
class MwcmqsConfig {
  /// Primary MWCMQS domain (default: "mwcmqs.mwc.mw").
  final String domain;
  
  /// MWCMQS port (default: 443).
  final int port;
  
  /// Auto-start listener on wallet open.
  final bool autoStart;
  
  /// Address derivation index.
  final int derivationIndex;
  
  /// Whether to use TLS/SSL.
  final bool useTls;

  const MwcmqsConfig({
    this.domain = 'mwcmqs.mwc.mw',
    this.port = 443,
    this.autoStart = false,
    this.derivationIndex = 0,
    this.useTls = true,
  });

  /// Create MwcmqsConfig from JSON.
  factory MwcmqsConfig.fromJson(Map<String, dynamic> json) => 
      _$MwcmqsConfigFromJson(json);

  /// Convert MwcmqsConfig to JSON.
  Map<String, dynamic> toJson() => _$MwcmqsConfigToJson(this);

  /// Create configuration string for Rust layer.
  String toConfigString() {
    return '{"mwcmqs_domain":"$domain","mwcmqs_port":$port,"mwcmqs_derive_index":$derivationIndex}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MwcmqsConfig &&
        other.domain == domain &&
        other.port == port &&
        other.autoStart == autoStart &&
        other.derivationIndex == derivationIndex &&
        other.useTls == useTls;
  }

  @override
  int get hashCode {
    return Object.hash(domain, port, autoStart, derivationIndex, useTls);
  }
}

/// MWCMQS listener status information.
@JsonSerializable()
class MwcmqsListenerStatus {
  /// Whether the listener is currently running.
  final bool isRunning;
  
  /// Current MWCMQS address being listened on.
  final MwcmqsAddress? address;
  
  /// Configuration being used.
  final MwcmqsConfig config;
  
  /// Number of messages received.
  final int messagesReceived;
  
  /// Last error message, if any.
  final String? lastError;
  
  /// Listener start time.
  final DateTime? startTime;

  const MwcmqsListenerStatus({
    required this.isRunning,
    this.address,
    required this.config,
    this.messagesReceived = 0,
    this.lastError,
    this.startTime,
  });

  /// Create MwcmqsListenerStatus from JSON.
  factory MwcmqsListenerStatus.fromJson(Map<String, dynamic> json) => 
      _$MwcmqsListenerStatusFromJson(json);

  /// Convert MwcmqsListenerStatus to JSON.
  Map<String, dynamic> toJson() => _$MwcmqsListenerStatusToJson(this);
}

/// MWCMQS transaction information.
@JsonSerializable()
class MwcmqsTransaction {
  /// The slate JSON data.
  final String slateJson;
  
  /// Sender's MWCMQS address.
  final String? senderAddress;
  
  /// Recipient's MWCMQS address.
  final String recipientAddress;
  
  /// Transaction message.
  final String? message;
  
  /// When the transaction was received.
  final DateTime receivedAt;

  const MwcmqsTransaction({
    required this.slateJson,
    this.senderAddress,
    required this.recipientAddress,
    this.message,
    required this.receivedAt,
  });

  /// Create MwcmqsTransaction from JSON.
  factory MwcmqsTransaction.fromJson(Map<String, dynamic> json) => 
      _$MwcmqsTransactionFromJson(json);

  /// Convert MwcmqsTransaction to JSON.
  Map<String, dynamic> toJson() => _$MwcmqsTransactionToJson(this);
}
