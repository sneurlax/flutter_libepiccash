import 'package:json_annotation/json_annotation.dart';

part 'payment_proof.g.dart';

/// Payment proof for cryptographic transaction verification.
@JsonSerializable()
class PaymentProof {
  /// Transaction ID that this proof is for.
  final String transactionId;
  
  /// Sender's MWCMQS address.
  final String senderAddress;
  
  /// Receiver's MWCMQS address.
  final String receiverAddress;
  
  /// Transaction amount in nano MWC.
  final int amount;
  
  /// Kernel excess for this transaction.
  final String kernelExcess;
  
  /// Kernel signature for verification.
  final String kernelSignature;
  
  /// Optional message attached to the proof.
  final String? message;
  
  /// Timestamp when proof was generated.
  final DateTime timestamp;
  
  /// Cryptographic signature of the proof.
  final String proofSignature;

  const PaymentProof({
    required this.transactionId,
    required this.senderAddress,
    required this.receiverAddress,
    required this.amount,
    required this.kernelExcess,
    required this.kernelSignature,
    this.message,
    required this.timestamp,
    required this.proofSignature,
  });

  /// Create PaymentProof from JSON.
  factory PaymentProof.fromJson(Map<String, dynamic> json) => 
      _$PaymentProofFromJson(json);

  /// Convert PaymentProof to JSON.
  Map<String, dynamic> toJson() => _$PaymentProofToJson(this);

  /// Convert amount from nano MWC to MWC.
  double get amountInMwc => amount / 1000000000.0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentProof && other.transactionId == transactionId;
  }

  @override
  int get hashCode => transactionId.hashCode;
}

/// Result of payment proof verification.
@JsonSerializable()
class PaymentProofVerification {
  /// Whether the proof is cryptographically valid.
  final bool isValid;
  
  /// Whether the kernel was found on the blockchain.
  final bool kernelFound;
  
  /// Whether the cryptographic signature is valid.
  final bool signatureValid;
  
  /// Whether the amount matches expectation (if provided).
  final bool amountMatches;
  
  /// Error message if verification failed.
  final String? errorMessage;
  
  /// Additional verification details.
  final Map<String, dynamic>? details;

  const PaymentProofVerification({
    required this.isValid,
    required this.kernelFound,
    required this.signatureValid,
    required this.amountMatches,
    this.errorMessage,
    this.details,
  });

  /// Create PaymentProofVerification from JSON.
  factory PaymentProofVerification.fromJson(Map<String, dynamic> json) => 
      _$PaymentProofVerificationFromJson(json);

  /// Convert PaymentProofVerification to JSON.
  Map<String, dynamic> toJson() => _$PaymentProofVerificationToJson(this);

  /// Create a successful verification result.
  factory PaymentProofVerification.success({
    required bool kernelFound,
    required bool signatureValid,
    required bool amountMatches,
    Map<String, dynamic>? details,
  }) {
    return PaymentProofVerification(
      isValid: kernelFound && signatureValid && amountMatches,
      kernelFound: kernelFound,
      signatureValid: signatureValid,
      amountMatches: amountMatches,
      details: details,
    );
  }

  /// Create a failed verification result.
  factory PaymentProofVerification.failure(String errorMessage) {
    return PaymentProofVerification(
      isValid: false,
      kernelFound: false,
      signatureValid: false,
      amountMatches: false,
      errorMessage: errorMessage,
    );
  }
}

/// Payment proof generation request.
@JsonSerializable()
class PaymentProofRequest {
  /// Transaction ID to generate proof for.
  final String transactionId;
  
  /// Optional message to include in proof.
  final String? message;
  
  /// Wallet handle for the operation.
  final String? walletHandle;

  const PaymentProofRequest({
    required this.transactionId,
    this.message,
    this.walletHandle,
  });

  /// Create PaymentProofRequest from JSON.
  factory PaymentProofRequest.fromJson(Map<String, dynamic> json) => 
      _$PaymentProofRequestFromJson(json);

  /// Convert PaymentProofRequest to JSON.
  Map<String, dynamic> toJson() => _$PaymentProofRequestToJson(this);
}

/// Payment proof verification request.
@JsonSerializable()
class PaymentProofVerificationRequest {
  /// The proof to verify.
  final PaymentProof proof;
  
  /// Expected sender address (optional).
  final String? expectedSender;
  
  /// Expected receiver address (optional) .
  final String? expectedReceiver;
  
  /// Expected amount in nano MWC (optional).
  final int? expectedAmount;
  
  /// Wallet handle for the operation.
  final String? walletHandle;

  const PaymentProofVerificationRequest({
    required this.proof,
    this.expectedSender,
    this.expectedReceiver,
    this.expectedAmount,
    this.walletHandle,
  });

  /// Create PaymentProofVerificationRequest from JSON.
  factory PaymentProofVerificationRequest.fromJson(Map<String, dynamic> json) => 
      _$PaymentProofVerificationRequestFromJson(json);

  /// Convert PaymentProofVerificationRequest to JSON.
  Map<String, dynamic> toJson() => _$PaymentProofVerificationRequestToJson(this);
}
