// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_proof.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentProof _$PaymentProofFromJson(Map<String, dynamic> json) => PaymentProof(
      transactionId: json['transactionId'] as String,
      senderAddress: json['senderAddress'] as String,
      receiverAddress: json['receiverAddress'] as String,
      amount: json['amount'] as int,
      kernelExcess: json['kernelExcess'] as String,
      kernelSignature: json['kernelSignature'] as String,
      message: json['message'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      proofSignature: json['proofSignature'] as String,
    );

Map<String, dynamic> _$PaymentProofToJson(PaymentProof instance) =>
    <String, dynamic>{
      'transactionId': instance.transactionId,
      'senderAddress': instance.senderAddress,
      'receiverAddress': instance.receiverAddress,
      'amount': instance.amount,
      'kernelExcess': instance.kernelExcess,
      'kernelSignature': instance.kernelSignature,
      'message': instance.message,
      'timestamp': instance.timestamp.toIso8601String(),
      'proofSignature': instance.proofSignature,
    };

PaymentProofVerification _$PaymentProofVerificationFromJson(
        Map<String, dynamic> json) =>
    PaymentProofVerification(
      isValid: json['isValid'] as bool,
      kernelFound: json['kernelFound'] as bool,
      signatureValid: json['signatureValid'] as bool,
      amountMatches: json['amountMatches'] as bool,
      errorMessage: json['errorMessage'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$PaymentProofVerificationToJson(
        PaymentProofVerification instance) =>
    <String, dynamic>{
      'isValid': instance.isValid,
      'kernelFound': instance.kernelFound,
      'signatureValid': instance.signatureValid,
      'amountMatches': instance.amountMatches,
      'errorMessage': instance.errorMessage,
      'details': instance.details,
    };

PaymentProofRequest _$PaymentProofRequestFromJson(Map<String, dynamic> json) =>
    PaymentProofRequest(
      transactionId: json['transactionId'] as String,
      message: json['message'] as String?,
      walletHandle: json['walletHandle'] as String?,
    );

Map<String, dynamic> _$PaymentProofRequestToJson(PaymentProofRequest instance) =>
    <String, dynamic>{
      'transactionId': instance.transactionId,
      'message': instance.message,
      'walletHandle': instance.walletHandle,
    };

PaymentProofVerificationRequest _$PaymentProofVerificationRequestFromJson(
        Map<String, dynamic> json) =>
    PaymentProofVerificationRequest(
      proof: PaymentProof.fromJson(json['proof'] as Map<String, dynamic>),
      expectedSender: json['expectedSender'] as String?,
      expectedReceiver: json['expectedReceiver'] as String?,
      expectedAmount: json['expectedAmount'] as int?,
      walletHandle: json['walletHandle'] as String?,
    );

Map<String, dynamic> _$PaymentProofVerificationRequestToJson(
        PaymentProofVerificationRequest instance) =>
    <String, dynamic>{
      'proof': instance.proof.toJson(),
      'expectedSender': instance.expectedSender,
      'expectedReceiver': instance.expectedReceiver,
      'expectedAmount': instance.expectedAmount,
      'walletHandle': instance.walletHandle,
    };