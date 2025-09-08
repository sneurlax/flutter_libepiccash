// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mwcmqs_address.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MwcmqsAddress _$MwcmqsAddressFromJson(Map<String, dynamic> json) =>
    MwcmqsAddress(
      address: json['address'] as String,
      publicKey: json['publicKey'] as String,
      domain: json['domain'] as String,
      port: json['port'] as int,
      index: json['index'] as int,
      isMainnet: json['isMainnet'] as bool,
    );

Map<String, dynamic> _$MwcmqsAddressToJson(MwcmqsAddress instance) =>
    <String, dynamic>{
      'address': instance.address,
      'publicKey': instance.publicKey,
      'domain': instance.domain,
      'port': instance.port,
      'index': instance.index,
      'isMainnet': instance.isMainnet,
    };

MwcmqsConfig _$MwcmqsConfigFromJson(Map<String, dynamic> json) => MwcmqsConfig(
      domain: json['domain'] as String? ?? 'mwcmqs.mwc.mw',
      port: json['port'] as int? ?? 443,
      autoStart: json['autoStart'] as bool? ?? false,
      derivationIndex: json['derivationIndex'] as int? ?? 0,
      useTls: json['useTls'] as bool? ?? true,
    );

Map<String, dynamic> _$MwcmqsConfigToJson(MwcmqsConfig instance) =>
    <String, dynamic>{
      'domain': instance.domain,
      'port': instance.port,
      'autoStart': instance.autoStart,
      'derivationIndex': instance.derivationIndex,
      'useTls': instance.useTls,
    };

MwcmqsListenerStatus _$MwcmqsListenerStatusFromJson(Map<String, dynamic> json) =>
    MwcmqsListenerStatus(
      isRunning: json['isRunning'] as bool,
      address: json['address'] == null
          ? null
          : MwcmqsAddress.fromJson(json['address'] as Map<String, dynamic>),
      config: MwcmqsConfig.fromJson(json['config'] as Map<String, dynamic>),
      messagesReceived: json['messagesReceived'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      startTime: json['startTime'] == null
          ? null
          : DateTime.parse(json['startTime'] as String),
    );

Map<String, dynamic> _$MwcmqsListenerStatusToJson(
        MwcmqsListenerStatus instance) =>
    <String, dynamic>{
      'isRunning': instance.isRunning,
      'address': instance.address?.toJson(),
      'config': instance.config.toJson(),
      'messagesReceived': instance.messagesReceived,
      'lastError': instance.lastError,
      'startTime': instance.startTime?.toIso8601String(),
    };

MwcmqsTransaction _$MwcmqsTransactionFromJson(Map<String, dynamic> json) =>
    MwcmqsTransaction(
      slateJson: json['slateJson'] as String,
      senderAddress: json['senderAddress'] as String?,
      recipientAddress: json['recipientAddress'] as String,
      message: json['message'] as String?,
      receivedAt: DateTime.parse(json['receivedAt'] as String),
    );

Map<String, dynamic> _$MwcmqsTransactionToJson(MwcmqsTransaction instance) =>
    <String, dynamic>{
      'slateJson': instance.slateJson,
      'senderAddress': instance.senderAddress,
      'recipientAddress': instance.recipientAddress,
      'message': instance.message,
      'receivedAt': instance.receivedAt.toIso8601String(),
    };