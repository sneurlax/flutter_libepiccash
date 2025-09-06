/*
 * Slate data models for MWC wallet operations
 *
 * Copyright (c) 2025 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 */

/// Represents the result of creating a transaction slate
class SlateResult {
  final String slateJson;
  final bool success;
  final String? error;

  SlateResult({
    required this.slateJson,
    required this.success,
    this.error,
  });

  factory SlateResult.fromJson(Map<String, dynamic> json) {
    return SlateResult(
      slateJson: json['slate_json'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slate_json': slateJson,
      'success': success,
      if (error != null) 'error': error,
    };
  }
}

/// Represents a slatepack with metadata
class SlatepackResult {
  final String slatepackString;
  final bool encrypted;
  final String? sender;
  final String? recipient;
  final bool success;
  final String? error;

  SlatepackResult({
    required this.slatepackString,
    required this.encrypted,
    this.sender,
    this.recipient,
    required this.success,
    this.error,
  });

  factory SlatepackResult.fromJson(Map<String, dynamic> json) {
    return SlatepackResult(
      slatepackString: json['slatepack_string'] as String? ?? '',
      encrypted: json['encrypted'] as bool? ?? false,
      sender: json['sender'] as String?,
      recipient: json['recipient'] as String?,
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slatepack_string': slatepackString,
      'encrypted': encrypted,
      if (sender != null) 'sender': sender,
      if (recipient != null) 'recipient': recipient,
      'success': success,
      if (error != null) 'error': error,
    };
  }
}

/// Represents the result of decoding a slatepack
class SlatepackDecodeResult {
  final String slateJson;
  final String? sender;
  final String? recipient;
  final bool success;
  final String? error;

  SlatepackDecodeResult({
    required this.slateJson,
    this.sender,
    this.recipient,
    required this.success,
    this.error,
  });

  factory SlatepackDecodeResult.fromJson(Map<String, dynamic> json) {
    return SlatepackDecodeResult(
      slateJson: json['slate_json'] as String? ?? '',
      sender: json['sender'] as String?,
      recipient: json['recipient'] as String?,
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slate_json': slateJson,
      if (sender != null) 'sender': sender,
      if (recipient != null) 'recipient': recipient,
      'success': success,
      if (error != null) 'error': error,
    };
  }
}

/// Parameters for creating a transaction slate
class CreateSlateRequest {
  final int amount; // in nano MWC
  final int minimumConfirmations;
  final bool selectionStrategyIsUseAll;
  final String note;

  CreateSlateRequest({
    required this.amount,
    required this.minimumConfirmations,
    required this.selectionStrategyIsUseAll,
    required this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'minimum_confirmations': minimumConfirmations,
      'selection_strategy_is_use_all': selectionStrategyIsUseAll,
      'note': note,
    };
  }
}

/// Parameters for receiving a slate
class ReceiveSlateRequest {
  final String slateJson;
  final String? message;

  ReceiveSlateRequest({
    required this.slateJson,
    this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'slate_json': slateJson,
      if (message != null) 'message': message,
    };
  }
}

/// Parameters for finalizing a slate
class FinalizeSlateRequest {
  final String slateJson;

  FinalizeSlateRequest({
    required this.slateJson,
  });

  Map<String, dynamic> toJson() {
    return {
      'slate_json': slateJson,
    };
  }
}

/// Parameters for encoding a slatepack
class EncodeSlatepackRequest {
  final String slateJson;
  final String? recipientAddress; // null for unencrypted

  EncodeSlatepackRequest({
    required this.slateJson,
    this.recipientAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'slate_json': slateJson,
      if (recipientAddress != null) 'recipient_address': recipientAddress,
    };
  }
}

/// Parameters for decoding a slatepack
class DecodeSlatepackRequest {
  final String slatepackString;

  DecodeSlatepackRequest({
    required this.slatepackString,
  });

  Map<String, dynamic> toJson() {
    return {
      'slatepack_string': slatepackString,
    };
  }
}