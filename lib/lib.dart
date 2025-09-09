import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_libmwc/mwc.dart' as lib_mwc;
import 'package:flutter_libmwc/models/transaction.dart';
import 'package:flutter_libmwc/models/mwcmqs_address.dart';
import 'package:flutter_libmwc/models/payment_proof.dart';
import 'package:mutex/mutex.dart';

class BadMWCHTTPAddressException implements Exception {
  final String? message;

  BadMWCHTTPAddressException({this.message});

  @override
  String toString() {
    return "BadMWCHTTPAddressException: $message";
  }
}

abstract class ListenerManager {
  static Pointer<Void>? pointer;
  static int _messagesReceived = 0;
  static DateTime? _startTime;
  static StreamController<MwcmqsTransaction>? _transactionController;
  
  /// Increment the message count.
  static void incrementMessageCount() {
    _messagesReceived++;
  }
  
  /// Get the current message count.
  static int getMessageCount() {
    return _messagesReceived;
  }
  
  /// Reset the message count.
  static void resetMessageCount() {
    _messagesReceived = 0;
  }
  
  /// Set the start time.
  static void setStartTime(DateTime time) {
    _startTime = time;
  }
  
  /// Get the start time.
  static DateTime? getStartTime() {
    return _startTime;
  }
  
  /// Clear the start time.
  static void clearStartTime() {
    _startTime = null;
  }
  
  /// Initialize the transaction stream.
  static void initializeTransactionStream() {
    _transactionController ??= StreamController<MwcmqsTransaction>.broadcast();
  }
  
  /// Get the transaction stream.
  static Stream<MwcmqsTransaction>? getTransactionStream() {
    return _transactionController?.stream;
  }
  
  /// Add a transaction to the stream.
  static void addTransaction(MwcmqsTransaction transaction) {
    incrementMessageCount();
    _transactionController?.add(transaction);
  }
  
  /// Close the transaction stream.
  static void closeTransactionStream() {
    _transactionController?.close();
    _transactionController = null;
  }
}

abstract class WalletManager {
  static String? _currentWalletHandle;
  
  /// Set the current wallet handle for FFI operations.
  static void setCurrentWalletHandle(String? handle) {
    _currentWalletHandle = handle;
  }
  
  /// Get the current wallet handle for FFI operations.
  static String? getCurrentWalletHandle() {
    return _currentWalletHandle;
  }
  
  /// Clear the current wallet handle.
  static void clearCurrentWalletHandle() {
    _currentWalletHandle = null;
  }
}

///
/// Wrapped up calls to flutter_libmwc.
///
/// Should all be static calls (no state stored in this class).
///
abstract class Libmwc {
  static final Mutex m = Mutex();

  // ==================================================================
  // WALLET MANAGEMENT METHODS
  // ==================================================================

  ///
  /// Get the current wallet handle for FFI operations.
  ///
  static String? getCurrentWalletHandle() {
    return WalletManager.getCurrentWalletHandle();
  }

  ///
  /// Set the current wallet handle for FFI operations.
  ///
  static void setCurrentWalletHandle(String? handle) {
    WalletManager.setCurrentWalletHandle(handle);
  }

  ///
  /// Clear the current wallet handle.
  ///
  static void clearCurrentWalletHandle() {
    WalletManager.clearCurrentWalletHandle();
  }

  ///
  /// Check if a wallet is currently open.
  ///
  static bool isWalletOpen() {
    final handle = getCurrentWalletHandle();
    return handle != null && handle.isNotEmpty;
  }

  // ==================================================================
  // MWCMQS LISTENER MANAGEMENT METHODS
  // ==================================================================

  ///
  /// Increment the MWCMQS message count (call when a message is received).
  ///
  static void incrementMwcmqsMessageCount() {
    ListenerManager.incrementMessageCount();
  }

  ///
  /// Get the current MWCMQS message count.
  ///
  static int getMwcmqsMessageCount() {
    return ListenerManager.getMessageCount();
  }

  ///
  /// Reset the MWCMQS message count
  ///
  static void resetMwcmqsMessageCount() {
    ListenerManager.resetMessageCount();
  }

  ///
  /// Add an incoming transaction to the stream.
  ///
  /// This method should be called when a transaction is received through MWCMQS.
  /// It will automatically increment the message count and emit the transaction
  /// to any listeners on the incomingTransactions stream.
  ///
  static void addIncomingTransaction(MwcmqsTransaction transaction) {
    ListenerManager.addTransaction(transaction);
  }

  // ==================================================================
  // ADDRESS VALIDATION METHODS  
  // ==================================================================

  ///
  /// Check if [address] is a valid mwc address according to libmwc.
  ///
  static bool validateSendAddress({required String address}) {
    final String validate = lib_mwc.validateSendAddress(address);
    if (int.parse(validate) == 1) {
      // Check if address contains a domain
      if (address.contains("@")) {
        return true;
      }
      return false;
    } else {
      return false;
    }
  }

  ///
  /// Fetch the mnemonic for a new wallet (Only used in the example app)
  /// 
  /// Returns the mnemonic string for wallet recovery.
  /// Throws an Exception if the mnemonic cannot be retrieved or is empty.
  ///
  //Function is used in _getMnemonicList()
  // wrap in mutex? -> would need to be Future<String>
  static String getMnemonic() {
    try {
      String mnemonic = lib_mwc.walletMnemonic();
      if (mnemonic.isEmpty) {
        throw Exception("Error getting mnemonic, returned empty string");
      }
      return mnemonic;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<String> _initLogs(
    ({
      String config,
    }) data,
  ) async {
    try {
      final String mnemonic = lib_mwc.initLogs(data.config);
      if (mnemonic.isEmpty) {
        throw Exception("Error getting mnemonic, returned empty string");
      }
      return mnemonic;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<String> initLogs({
    required String config,
  }) async {
    return await m.protect(() async {
      try {
        return await compute(
          _initLogs,
          (
            config: config,
          ),
        );
      } catch (e) {
        throw ("Error init logs : ${e.toString()}");
      }
    });
  }

  // Private function wrapper for compute
  static Future<String> _initializeWalletWrapper(
    ({
      String config,
      String mnemonic,
      String password,
      String name,
    }) data,
  ) async {
    final String initWalletStr = lib_mwc.initWallet(
      data.config,
      data.mnemonic,
      data.password,
      data.name,
    );
    return initWalletStr;
  }

  ///
  /// Create a new MWC wallet.
  /// 
  /// Creates a new wallet with the specified configuration, mnemonic, password, and name.
  /// Returns a status message upon successful creation.
  /// Throws an Exception if wallet creation fails.
  ///
  static Future<String> initializeNewWallet({
    required String config,
    required String mnemonic,
    required String password,
    required String name,
  }) async {
    return await m.protect(() async {
      try {
        final result = await compute(
          _initializeWalletWrapper,
          (
            config: config,
            mnemonic: mnemonic,
            password: password,
            name: name,
          ),
        );
        
        // Set the current wallet handle for future operations.
        WalletManager.setCurrentWalletHandle(result);
        
        return result;
      } catch (e) {
        throw ("Error creating new wallet : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function wrapper for wallet balances
  ///
  static Future<String> _walletBalancesWrapper(
    ({String wallet, int refreshFromNode, int minimumConfirmations}) data,
  ) async {
    return lib_mwc.getWalletInfo(
        data.wallet, data.refreshFromNode, data.minimumConfirmations);
  }

  ///
  /// Get balance information for the currently open wallet
  ///
  static Future<
          ({
            double awaitingFinalization,
            double pending,
            double spendable,
            double total
          })>
      getWalletBalances(
          {required String wallet,
          required int refreshFromNode,
          required int minimumConfirmations}) async {
    return await m.protect(() async {
      try {
        String balances = await compute(_walletBalancesWrapper, (
          wallet: wallet,
          refreshFromNode: refreshFromNode,
          minimumConfirmations: minimumConfirmations,
        ));

        //If balances is valid json return, else return error
        if (balances.toUpperCase().contains("ERROR")) {
          throw Exception(balances);
        }
        var jsonBalances = json.decode(balances);
        //Return balances as record
        ({
          double spendable,
          double pending,
          double total,
          double awaitingFinalization
        }) balancesRecord = (
          spendable: jsonBalances['amount_currently_spendable'],
          pending: jsonBalances['amount_awaiting_finalization'],
          total: jsonBalances['total'],
          awaitingFinalization: jsonBalances['amount_awaiting_finalization'],
        );
        return balancesRecord;
      } catch (e) {
        throw ("Error getting wallet info : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function wrapper for scanning output function
  ///
  static Future<String> _scanOutputsWrapper(
    ({String wallet, int startHeight, int numberOfBlocks}) data,
  ) async {
    return lib_mwc.scanOutPuts(
      data.wallet,
      data.startHeight,
      data.numberOfBlocks,
    );
  }

  ///
  /// Scan MWC outputs
  ///
  static Future<int> scanOutputs({
    required String wallet,
    required int startHeight,
    required int numberOfBlocks,
  }) async {
    try {
      final result = await m.protect(() async {
        return await compute(
          _scanOutputsWrapper,
          (
            wallet: wallet,
            startHeight: startHeight,
            numberOfBlocks: numberOfBlocks,
          ),
        );
      });
      final response = int.tryParse(result);
      if (response == null) {
        throw Exception(result);
      }
      return response;
    } catch (e) {
      throw ("Libmwc.scanOutputs failed: ${e.toString()}");
    }
  }

  ///
  /// Private function wrapper for create transactions
  ///
  static Future<String> _createTransactionWrapper(
    ({
      String wallet,
      int amount,
      String address,
      int secretKeyIndex,
      String mwcmqsConfig,
      int minimumConfirmations,
      String note,
    }) data,
  ) async {
    return lib_mwc.createTransaction(
        data.wallet,
        data.amount,
        data.address,
        data.secretKeyIndex,
        data.mwcmqsConfig,
        data.minimumConfirmations,
        data.note);
  }

  ///
  /// Create an MWC transaction
  ///
  static Future<({String slateId, String commitId})> createTransaction({
    required String wallet,
    required int amount,
    required String address,
    required int secretKeyIndex,
    required String mwcmqsConfig,
    required int minimumConfirmations,
    required String note,
  }) async {
    return await m.protect(() async {
      try {
        String result = await compute(_createTransactionWrapper, (
          wallet: wallet,
          amount: amount,
          address: address,
          secretKeyIndex: secretKeyIndex,
          mwcmqsConfig: mwcmqsConfig,
          minimumConfirmations: minimumConfirmations,
          note: note,
        ));

        if (result.toUpperCase().contains("ERROR")) {
          throw Exception("Error creating transaction ${result.toString()}");
        }

        //Decode sent tx and return Slate Id
        final slate0 = jsonDecode(result);
        final slate = jsonDecode(slate0[0] as String);
        final part1 = jsonDecode(slate[0] as String);
        final part2 = jsonDecode(slate[1] as String);

        List<dynamic>? outputs = part2['tx']?['body']?['outputs'] as List;
        String? commitId =
            (outputs.isEmpty) ? '' : outputs[0]['commit'] as String;

        ({String slateId, String commitId}) data = (
          slateId: part1[0]['tx_slate_id'],
          commitId: commitId,
        );

        return data;
      } catch (e) {
        throw ("Error creating mwc transaction : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function wrapper for get transactions
  ///
  static Future<String> _getTransactionsWrapper(
    ({
      String wallet,
      int refreshFromNode,
    }) data,
  ) async {
    return lib_mwc.getTransactions(
      data.wallet,
      data.refreshFromNode,
    );
  }

  ///
  ///
  ///
  static Future<List<Transaction>> getTransactions({
    required String wallet,
    required int refreshFromNode,
  }) async {
    return await m.protect(() async {
      try {
        var result = await compute(_getTransactionsWrapper, (
          wallet: wallet,
          refreshFromNode: refreshFromNode,
        ));

        if (result.toUpperCase().contains("ERROR")) {
          throw Exception(
              "Error getting mwc transactions ${result.toString()}");
        }

//Parse the returned data as an mwcTransaction
        List<Transaction> finalResult = [];
        var jsonResult = json.decode(result) as List;

        for (var tx in jsonResult) {
          Transaction itemTx = Transaction.fromJson(tx);
          finalResult.add(itemTx);
        }
        return finalResult;
      } catch (e) {
        throw ("Error getting mwc transactions : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function for cancel transaction function
  ///
  static Future<String> _cancelTransactionWrapper(
    ({
      String wallet,
      String transactionId,
    }) data,
  ) async {
    return lib_mwc.cancelTransaction(
      data.wallet,
      data.transactionId,
    );
  }

  ///
  /// Cancel current mwc transaction
  ///
  /// returns an empty String on success, error message on failure
  static Future<String> cancelTransaction({
    required String wallet,
    required String transactionId,
  }) async {
    return await m.protect(() async {
      try {
        return await compute(_cancelTransactionWrapper, (
          wallet: wallet,
          transactionId: transactionId,
        ));
      } catch (e) {
        throw ("Error canceling mwc transaction : ${e.toString()}");
      }
    });
  }

  static Future<int> _chainHeightWrapper(
    ({
      String config,
    }) data,
  ) async {
    return lib_mwc.getChainHeight(data.config);
  }

  static Future<int> getChainHeight({
    required String config,
  }) async {
    return await m.protect(() async {
      try {
        return await compute(_chainHeightWrapper, (config: config,));
      } catch (e) {
        throw ("Error getting chain height : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function for address info function
  ///
  static Future<String> _addressInfoWrapper(
    ({
      String wallet,
      int index
    }) data,
  ) async {
    return lib_mwc.getAddressInfo(
      data.wallet,
      data.index,
    );
  }

  ///
  /// get mwc address info
  ///
  static Future<String> getAddressInfo({
    required String wallet,
    required int index,
  }) async {
    return await m.protect(() async {
      try {
        return await compute(_addressInfoWrapper, (
          wallet: wallet,
          index: index
        ));
      } catch (e) {
        throw ("Error getting address info : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function for getting transaction fees
  ///
  static Future<String> _transactionFeesWrapper(
    ({
      String wallet,
      int amount,
      int minimumConfirmations,
    }) data,
  ) async {
    return lib_mwc.getTransactionFees(
      data.wallet,
      data.amount,
      data.minimumConfirmations,
    );
  }

  ///
  /// get transaction fees for mwc
  ///
  static Future<({int fee, bool strategyUseAll, int total})>
      getTransactionFees({
    required String wallet,
    required int amount,
    required int minimumConfirmations,
    required int available,
  }) async {
    return await m.protect(() async {
      try {
        String fees = await compute(_transactionFeesWrapper, (
          wallet: wallet,
          amount: amount,
          minimumConfirmations: minimumConfirmations,
        ));

        if (available == amount) {
          if (fees.contains("Required")) {
            var splits = fees.split(" ");
            Decimal required = Decimal.zero;
            Decimal available = Decimal.zero;
            for (int i = 0; i < splits.length; i++) {
              var word = splits[i];
              if (word == "Required:") {
                required = Decimal.parse(splits[i + 1].replaceAll(",", "").replaceAll("\"", ""));
              } else if (word == "Available:") {
                available = Decimal.parse(splits[i + 1].replaceAll(",", "").replaceAll("\"", ""));
              }
            }
            int largestSatoshiFee =
                ((required - available) * Decimal.fromInt(1000000000))
                    .toBigInt()
                    .toInt();
            var amountSending = amount - largestSatoshiFee;
            //Get fees for this new amount
            fees = await compute(_transactionFeesWrapper, (
              wallet: wallet,
              amount: amountSending,
              minimumConfirmations: minimumConfirmations,
            ));
          }
        }

        if (fees.toUpperCase().contains("ERROR")) {
          //Check if the error is an
          //Throw the returned error
          throw Exception(fees);
        }
        var decodedFees = json.decode(fees);
        var feeItem = decodedFees[0];
        ({
          bool strategyUseAll,
          int total,
          int fee,
        }) feeRecord = (
          strategyUseAll: feeItem['selection_strategy_is_use_all'],
          total: feeItem['total'],
          fee: feeItem['fee'],
        );
        return feeRecord;
      } catch (e) {
        throw (e.toString());
      }
    });
  }

  ///
  /// Private function wrapper for recover wallet function
  ///
  static Future<String> _recoverWalletWrapper(
    ({
      String config,
      String password,
      String mnemonic,
      String name,
    }) data,
  ) async {
    return lib_mwc.recoverWallet(
      data.config,
      data.password,
      data.mnemonic,
      data.name,
    );
  }

  ///
  /// Recover an mwc wallet using a mnemonic
  ///
  static Future<void> recoverWallet(
      {required String config,
      required String password,
      required String mnemonic,
      required String name}) async {
    try {
      await compute(_recoverWalletWrapper, (
        config: config,
        password: password,
        mnemonic: mnemonic,
        name: name,
      ));
    } catch (e) {
      throw (e.toString());
    }
  }

  ///
  /// Private function wrapper for delete wallet function
  ///
  static Future<String> _deleteWalletWrapper(
    ({
      String wallet,
      String config,
    }) data,
  ) async {
    return lib_mwc.deleteWallet(
      data.wallet,
      data.config,
    );
  }

  ///
  /// Delete an mwc wallet
  ///
  static Future<String> deleteWallet({
    required String wallet,
    required String config,
  }) async {
    try {
      return await compute(_deleteWalletWrapper, (
        wallet: wallet,
        config: config,
      ));
    } catch (e) {
      throw ("Error deleting wallet : ${e.toString()}");
    }
  }

  ///
  /// Private function wrapper for open wallet function
  ///
  static Future<String> _openWalletWrapper(
    ({
      String config,
      String password,
    }) data,
  ) async {
    return lib_mwc.openWallet(
      data.config,
      data.password,
    );
  }

  ///
  /// Open an mwc wallet
  ///
  static Future<String> openWallet({
    required String config,
    required String password,
  }) async {
    try {
      final result = await compute(_openWalletWrapper, (
        config: config,
        password: password,
      ));
      
      // Set the current wallet handle for future operations
      WalletManager.setCurrentWalletHandle(result);
      
      return result;
    } catch (e) {
      throw ("Error opening wallet : ${e.toString()}");
    }
  }

  ///
  /// Private function for txHttpSend function
  ///
  static Future<String> _txHttpSendWrapper(
    ({
      String wallet,
      int selectionStrategyIsAll,
      int minimumConfirmations,
      String message,
      int amount,
      String address,
    }) data,
  ) async {
    return lib_mwc.txHttpSend(
      data.wallet,
      data.selectionStrategyIsAll,
      data.minimumConfirmations,
      data.message,
      data.amount,
      data.address,
    );
  }

  ///
  ///
  ///
  static Future<({String commitId, String slateId})> txHttpSend({
    required String wallet,
    required int selectionStrategyIsAll,
    required int minimumConfirmations,
    required String message,
    required int amount,
    required String address,
  }) async {
    try {
      var result = await compute(_txHttpSendWrapper, (
        wallet: wallet,
        selectionStrategyIsAll: selectionStrategyIsAll,
        minimumConfirmations: minimumConfirmations,
        message: message,
        amount: amount,
        address: address,
      ));
      if (result.toUpperCase().contains("ERROR")) {
        throw Exception("Error creating transaction ${result.toString()}");
      }

      //Decode sent tx and return Slate Id
      final slate0 = jsonDecode(result);
      final slate = jsonDecode(slate0[0] as String);
      final part1 = jsonDecode(slate[0] as String);
      final part2 = jsonDecode(slate[1] as String);

      ({String slateId, String commitId}) data = (
        slateId: part1[0]['tx_slate_id'],
        commitId: part2['tx']['body']['outputs'][0]['commit'],
      );

      return data;
    } catch (e) {
      throw ("Error sending tx HTTP : ${e.toString()}");
    }
  }

  static void startMwcMqsListener({
    required String wallet,
    required String mwcmqsConfig,
  }) {
    try {
      ListenerManager.pointer =
          lib_mwc.mwcMqsListenerStart(wallet, mwcmqsConfig);
      
      // Reset and initialize listener state.
      ListenerManager.resetMessageCount();
      ListenerManager.setStartTime(DateTime.now());
      ListenerManager.initializeTransactionStream();
    } catch (e) {
      throw ("Error starting wallet listener ${e.toString()}");
    }
  }

  static void stopMwcMqsListener() {
    if (ListenerManager.pointer != null) {
      lib_mwc.mwcMqsListenerStop(ListenerManager.pointer!);
      ListenerManager.pointer = null;
      ListenerManager.clearStartTime();
      ListenerManager.closeTransactionStream();
    }
  }

  // ==================================================================
  // ENHANCED MWCMQS API METHODS
  // ==================================================================

  ///
  /// Private function wrapper for MWCMQS address generation
  ///
  static Future<String> _generateMwcmqsAddressWrapper(
    ({String wallet, int index}) data,
  ) async {
    return lib_mwc.getAddressInfo(data.wallet, data.index);
  }

  ///
  /// Generate MWCMQS address for current wallet
  ///
  static Future<MwcmqsAddress> generateMwcmqsAddress({
    required String wallet,
    int index = 0,
  }) async {
    return await m.protect(() async {
      try {
        String addressResult = await compute(_generateMwcmqsAddressWrapper, (
          wallet: wallet,
          index: index,
        ));

        if (addressResult.toUpperCase().contains("ERROR")) {
          throw Exception("Error generating MWCMQS address: $addressResult");
        }

        // Parse the address from the result
        // The Rust function returns the full MWCMQS address
        return MwcmqsAddress.parse(addressResult, index: index);
      } catch (e) {
        throw ("Error generating MWCMQS address: ${e.toString()}");
      }
    });
  }

  ///
  /// Get current MWCMQS address (using index 0)
  ///
  static Future<MwcmqsAddress> getCurrentMwcmqsAddress({
    required String wallet,
  }) async {
    return await generateMwcmqsAddress(wallet: wallet, index: 0);
  }

  ///
  /// Validate MWCMQS address format
  ///
  static bool validateMwcmqsAddress(String address) {
    return MwcmqsAddress.isValid(address);
  }

  ///
  /// Private function wrapper for MWCMQS transaction sending
  ///
  static Future<String> _sendViaMwcmqsWrapper(
    ({
      String wallet,
      String mwcmqsAddress,
      int amount,
      String message,
      int secretKeyIndex,
      String mwcmqsConfig,
      int minimumConfirmations,
    }) data,
  ) async {
    return lib_mwc.createTransaction(
        data.wallet,
        data.amount,
        data.mwcmqsAddress,
        data.secretKeyIndex,
        data.mwcmqsConfig,
        data.minimumConfirmations,
        data.message);
  }

  ///
  /// Send transaction via MWCMQS
  ///
  static Future<({String slateId, String commitId})> sendViaMwcmqs({
    required String wallet,
    required String mwcmqsAddress,
    required int amount,
    String message = "",
    int secretKeyIndex = 0,
    required String mwcmqsConfig,
    int minimumConfirmations = 10,
  }) async {
    return await m.protect(() async {
      try {
        String result = await compute(_sendViaMwcmqsWrapper, (
          wallet: wallet,
          mwcmqsAddress: mwcmqsAddress,
          amount: amount,
          message: message,
          secretKeyIndex: secretKeyIndex,
          mwcmqsConfig: mwcmqsConfig,
          minimumConfirmations: minimumConfirmations,
        ));

        if (result.toUpperCase().contains("ERROR")) {
          throw Exception("Error sending via MWCMQS: $result");
        }

        // Decode sent tx and return Slate Id (same format as existing createTransaction)
        final slate0 = jsonDecode(result);
        final slate = jsonDecode(slate0[0] as String);
        final part1 = jsonDecode(slate[0] as String);
        final part2 = jsonDecode(slate[1] as String);

        List<dynamic>? outputs = part2['tx']?['body']?['outputs'] as List;
        String? commitId =
            (outputs.isEmpty) ? '' : outputs[0]['commit'] as String;

        ({String slateId, String commitId}) data = (
          slateId: part1[0]['tx_slate_id'],
          commitId: commitId,
        );

        return data;
      } catch (e) {
        throw ("Error sending via MWCMQS: ${e.toString()}");
      }
    });
  }

  ///
  /// Start MWCMQS listener with configuration
  ///
  static Future<void> startMwcmqsListener({
    required String wallet,
    MwcmqsConfig config = const MwcmqsConfig(),
  }) async {
    try {
      final configString = config.toConfigString();
      ListenerManager.pointer =
          lib_mwc.mwcMqsListenerStart(wallet, configString);
      
      // Reset and initialize listener state.
      ListenerManager.resetMessageCount();
      ListenerManager.setStartTime(DateTime.now());
      ListenerManager.initializeTransactionStream();
    } catch (e) {
      throw ("Error starting MWCMQS listener: ${e.toString()}");
    }
  }

  ///
  /// Stop MWCMQS listener.
  ///
  static Future<void> stopMwcmqsListener() async {
    if (ListenerManager.pointer != null) {
      lib_mwc.mwcMqsListenerStop(ListenerManager.pointer!);
      ListenerManager.pointer = null;
      ListenerManager.clearStartTime();
      ListenerManager.closeTransactionStream();
    }
  }

  ///
  /// Get MWCMQS listener status.
  ///
  static Future<MwcmqsListenerStatus> getMwcmqsListenerStatus({
    MwcmqsConfig config = const MwcmqsConfig(),
  }) async {
    final isRunning = ListenerManager.pointer != null;
    
    return MwcmqsListenerStatus(
      isRunning: isRunning,
      config: config,
      messagesReceived: ListenerManager.getMessageCount(),
      startTime: isRunning ? ListenerManager.getStartTime() : null,
    );
  }

  ///
  /// Get stream of incoming MWCMQS transactions.
  ///
  /// Returns a broadcast stream that emits MwcmqsTransaction objects when
  /// transactions are received through the MWCMQS listener.
  /// 
  /// Note: The listener must be started first using startMwcmqsListener().
  /// To manually add transactions to the stream (e.g., from Rust callbacks),
  /// use addIncomingTransaction().
  ///
  static Stream<MwcmqsTransaction>? get incomingTransactions {
    return ListenerManager.getTransactionStream();
  }

  // ==================================================================
  // FILE-BASED TRANSACTION METHODS
  // ==================================================================

  ///
  /// Create slate and save to file.
  ///
  static Future<({String slateId, String filePath})> createSlateToFile({
    required String wallet,
    required String filePath,
    required int amount,
    String message = "",
    int minimumConfirmations = 10,
    bool selectionStrategyIsUseAll = false,
  }) async {
    return await m.protect(() async {
      try {
        // First create the slate using the existing tx_create function
        final createResult = await lib_mwc.txCreate(
          wallet,
          amount,
          minimumConfirmations,
          selectionStrategyIsUseAll,
          message,
        );

        if (createResult.toUpperCase().contains("ERROR")) {
          throw Exception("Error creating slate: $createResult");
        }

        // Parse the slate JSON from the result
        final slateJson = createResult;
        
        // Write the slate to file
        await _writeSlateToFile(filePath, slateJson);

        // Extract slate ID from the result
        final slateData = jsonDecode(slateJson);
        final slateId = slateData['id'] as String;

        return (slateId: slateId, filePath: filePath);
      } catch (e) {
        throw ("Error creating slate to file: ${e.toString()}");
      }
    });
  }

  ///
  /// Load slate from file and receive
  ///
  static Future<({String slateId, String? outputPath})> receiveSlateFromFile({
    required String wallet,
    required String inputPath,
    String? outputPath,
    String message = "",
  }) async {
    return await m.protect(() async {
      try {
        // Read the slate from file
        final slateJson = await _readSlateFromFile(inputPath);
        
        // Process the slate using the existing tx_receive function
        final receiveResult = await lib_mwc.txReceive(
          wallet,
          slateJson,
          message,
        );

        if (receiveResult.toUpperCase().contains("ERROR")) {
          throw Exception("Error receiving slate: $receiveResult");
        }

        // If output path is specified, write the updated slate
        if (outputPath != null) {
          await _writeSlateToFile(outputPath, receiveResult);
        }

        // Extract slate ID from the result
        final slateData = jsonDecode(receiveResult);
        final slateId = slateData['id'] as String;

        return (slateId: slateId, outputPath: outputPath);
      } catch (e) {
        throw ("Error receiving slate from file: ${e.toString()}");
      }
    });
  }

  ///
  /// Load received slate from file and finalize
  ///
  static Future<({String slateId, String? outputPath})> finalizeSlateFromFile({
    required String wallet,
    required String inputPath,
    String? outputPath,
  }) async {
    return await m.protect(() async {
      try {
        // Read the slate from file
        final slateJson = await _readSlateFromFile(inputPath);
        
        // Finalize the slate using the existing tx_finalize function
        final finalizeResult = await lib_mwc.txFinalize(
          wallet,
          slateJson,
        );

        if (finalizeResult.toUpperCase().contains("ERROR")) {
          throw Exception("Error finalizing slate: $finalizeResult");
        }

        // Extract slate ID from the original slate (finalize returns success message)
        final slateData = jsonDecode(slateJson);
        final slateId = slateData['id'] as String;

        // If output path is specified, write finalization status
        if (outputPath != null) {
          await _writeSlateToFile(outputPath, finalizeResult);
        }

        return (slateId: slateId, outputPath: outputPath);
      } catch (e) {
        throw ("Error finalizing slate from file: ${e.toString()}");
      }
    });
  }

  ///
  /// Encode slate to slatepack file
  ///
  static Future<void> encodeSlatepackToFile({
    required String slateJson,
    required String outputPath,
    String? recipientAddress,
    bool encrypt = false,
  }) async {
    try {
      // Encode the slatepack.
      final encodeResult = await encodeSlatepack(
        slateJson: slateJson,
        recipientAddress: recipientAddress,
        encrypt: encrypt,
      );

      // Write slatepack to file.
      await _writeSlateToFile(outputPath, encodeResult.slatepack);
    } catch (e) {
      throw ("Error encoding slatepack to file: ${e.toString()}");
    }
  }

  ///
  /// Decode slatepack from file.
  ///
  static Future<({
    String slateJson,
    bool wasEncrypted,
    String? senderAddress,
    String? recipientAddress,
  })> decodeSlatepackFromFile({
    required String inputPath,
    String? walletHandle,
  }) async {
    try {
      // Read slatepack from file.
      final slatepackString = await _readSlateFromFile(inputPath);
      
      // Decode the slatepack using unified function.
      return await decodeSlatepack(
        slatepack: slatepackString,
        walletHandle: walletHandle,
      );
    } catch (e) {
      throw ("Error decoding slatepack from file: ${e.toString()}");
    }
  }

  // ==================================================================
  // PRIVATE FILE I/O HELPER METHODS
  // ==================================================================

  ///
  /// Write slate data to file with proper formatting
  ///
  static Future<void> _writeSlateToFile(String filePath, String content) async {
    try {
      final file = File(filePath);
      
      // Ensure the directory exists
      await file.parent.create(recursive: true);
      
      // Pretty-print JSON if it's valid JSON, otherwise write as-is
      String formattedContent = content;
      try {
        final jsonData = jsonDecode(content);
        formattedContent = const JsonEncoder.withIndent('  ').convert(jsonData);
      } catch (e) {
        // If not valid JSON, write as-is (e.g., slatepack strings)
      }
      
      await file.writeAsString(formattedContent);
    } catch (e) {
      throw ("Error writing slate to file $filePath: ${e.toString()}");
    }
  }

  ///
  /// Read slate data from file
  ///
  static Future<String> _readSlateFromFile(String filePath) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw Exception("File does not exist: $filePath");
      }
      
      return await file.readAsString();
    } catch (e) {
      throw ("Error reading slate from file $filePath: ${e.toString()}");
    }
  }

  ///
  /// Validate slate file exists and is readable
  ///
  static Future<bool> validateSlateFile(String filePath) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        return false;
      }
      
      // Try to read and parse the content
      final content = await file.readAsString();
      
      // Check if it's valid JSON (slate) or slatepack format
      if (content.contains('BEGINSLATEPACK') || content.startsWith('{')) {
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  ///
  /// Get slate file metadata information
  ///
  static Future<Map<String, dynamic>> getSlateFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw Exception("File does not exist: $filePath");
      }
      
      final stat = await file.stat();
      final content = await file.readAsString();
      
      // Determine file type
      String fileType = 'unknown';
      Map<String, dynamic>? slateData;
      
      if (content.contains('BEGINSLATEPACK')) {
        fileType = 'slatepack';
      } else if (content.startsWith('{')) {
        try {
          slateData = jsonDecode(content);
          fileType = 'slate';
        } catch (e) {
          fileType = 'json';
        }
      }
      
      return {
        'filePath': filePath,
        'fileType': fileType,
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
        'isValid': fileType != 'unknown',
        'slateId': slateData?['id'],
        'amount': slateData?['amount'],
        'fee': slateData?['fee'],
      };
    } catch (e) {
      throw ("Error getting slate file info: ${e.toString()}");
    }
  }

  // ==================================================================
  // PAYMENT PROOF METHODS
  // ==================================================================

  ///
  /// Private function wrapper for payment proof generation
  ///
  static Future<String> _generatePaymentProofWrapper(
    ({String wallet, String transactionId, String message}) data,
  ) async {
    return lib_mwc.generatePaymentProof(
      data.wallet,
      data.transactionId,
      data.message,
    );
  }

  ///
  /// Generate payment proof for a completed transaction
  ///
  static Future<PaymentProof> generatePaymentProof({
    required String wallet,
    required String transactionId,
    String message = "",
  }) async {
    return await m.protect(() async {
      try {
        String proofResult = await compute(_generatePaymentProofWrapper, (
          wallet: wallet,
          transactionId: transactionId,
          message: message,
        ));

        final proofResponse = jsonDecode(proofResult);
        
        if (proofResponse['success'] != true) {
          throw Exception("Error generating payment proof: ${proofResponse['error']}");
        }

        // Extract the proof data and create PaymentProof object
        final proofData = proofResponse['proof'];
        
        return PaymentProof(
          transactionId: proofData['transactionId'],
          senderAddress: proofData['senderAddress'],
          receiverAddress: proofData['receiverAddress'],
          amount: proofData['amount'],
          kernelExcess: proofData['kernelExcess'],
          kernelSignature: proofData['kernelSignature'],
          message: proofData['message'],
          timestamp: DateTime.parse(proofData['timestamp']),
          proofSignature: proofData['proofSignature'],
        );
      } catch (e) {
        throw ("Error generating payment proof: ${e.toString()}");
      }
    });
  }

  ///
  /// Private function wrapper for payment proof verification
  ///
  static Future<String> _verifyPaymentProofWrapper(
    ({String wallet, String proofJson}) data,
  ) async {
    return lib_mwc.verifyPaymentProof(
      data.wallet,
      data.proofJson,
    );
  }

  ///
  /// Verify a payment proof
  ///
  static Future<PaymentProofVerification> verifyPaymentProof({
    required String wallet,
    required PaymentProof proof,
    String? expectedSender,
    String? expectedReceiver,
    int? expectedAmount,
  }) async {
    return await m.protect(() async {
      try {
        // Convert proof to JSON for Rust layer
        final proofJson = jsonEncode(proof.toJson());
        
        String verificationResult = await compute(_verifyPaymentProofWrapper, (
          wallet: wallet,
          proofJson: proofJson,
        ));

        final verificationResponse = jsonDecode(verificationResult);
        
        // Check expected values if provided
        bool amountMatches = true;
        if (expectedAmount != null) {
          amountMatches = proof.amount == expectedAmount;
        }
        
        bool senderMatches = true;
        if (expectedSender != null) {
          senderMatches = proof.senderAddress == expectedSender;
        }
        
        bool receiverMatches = true;
        if (expectedReceiver != null) {
          receiverMatches = proof.receiverAddress == expectedReceiver;
        }
        
        final allMatches = amountMatches && senderMatches && receiverMatches;
        
        return PaymentProofVerification(
          isValid: verificationResponse['isValid'] && allMatches,
          kernelFound: verificationResponse['kernelFound'],
          signatureValid: verificationResponse['signatureValid'],
          amountMatches: amountMatches,
          errorMessage: verificationResponse['errorMessage'],
          details: {
            'senderMatches': senderMatches,
            'receiverMatches': receiverMatches,
            'expectedAmount': expectedAmount,
            'expectedSender': expectedSender,
            'expectedReceiver': expectedReceiver,
          },
        );
      } catch (e) {
        return PaymentProofVerification.failure("Error verifying payment proof: ${e.toString()}");
      }
    });
  }

  ///
  /// Export payment proof to file
  ///
  static Future<void> exportPaymentProof({
    required PaymentProof proof,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      
      // Ensure the directory exists
      await file.parent.create(recursive: true);
      
      // Pretty-print the proof JSON
      final proofJson = const JsonEncoder.withIndent('  ').convert(proof.toJson());
      
      await file.writeAsString(proofJson);
    } catch (e) {
      throw ("Error exporting payment proof to file $filePath: ${e.toString()}");
    }
  }

  ///
  /// Import payment proof from file
  ///
  static Future<PaymentProof> importPaymentProof({
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw Exception("File does not exist: $filePath");
      }
      
      final proofJson = await file.readAsString();
      final proofData = jsonDecode(proofJson);
      
      return PaymentProof.fromJson(proofData);
    } catch (e) {
      throw ("Error importing payment proof from file $filePath: ${e.toString()}");
    }
  }

  // ==================================================================
  // SLATEPACK METHODS
  // ==================================================================

  ///
  /// Encode slate as slatepack with optional encryption
  ///
  /// Parameters:
  /// - slateJson: The slate data in JSON format
  /// - recipientAddress: Optional recipient address for encryption
  /// - encrypt: Whether to encrypt the slatepack (requires recipientAddress and wallet)
  /// - wallet: Wallet handle for encryption context (uses current if null)
  ///
  /// Returns a record with the slatepack string, encryption status, and recipient address
  ///
  static Future<({String slatepack, bool wasEncrypted, String? recipientAddress})> encodeSlatepack({
    required String slateJson,
    String? recipientAddress,
    bool encrypt = false,
    String? wallet,
  }) async {
    print('=== Slatepack Encoding Debug ===');
    print('encrypt: $encrypt');
    print('recipientAddress: $recipientAddress');
    print('wallet parameter: ${wallet != null ? 'provided' : 'null'}');
    
    try {
      String slatepackResult;
      
      if (encrypt && recipientAddress != null) {
        // For encrypted slatepacks, we need wallet context and use the enhanced function
        if (wallet == null) {
          print('Attempting to get current wallet handle for encryption...');
          wallet = WalletManager.getCurrentWalletHandle();
          print('Current wallet handle: ${wallet != null ? 'found (${wallet.length} chars)' : 'null'}');
        }
        
        if (wallet == null) {
          print('ERROR: No wallet context available for encryption');
          throw Exception("Wallet context required for encrypted slatepacks");
        }
        
        print('Using enhanced encoding with wallet context for encryption');
        print('Wallet handle: $wallet');
        
        // The wallet handle should already be in JSON format [handle, secret_key]
        // If it's not, we need to format it correctly
        String walletData = wallet;
        if (!wallet.startsWith('[') || !wallet.contains(',')) {
          // Handle case where wallet is just a raw integer handle
          try {
            int walletHandle = int.parse(wallet);
            walletData = '[$walletHandle, null]';
            print('Converted raw wallet handle to JSON format: $walletData');
          } catch (e) {
            print('ERROR: Could not parse wallet handle: $e');
            throw Exception("Invalid wallet handle format");
          }
        } else {
          print('Wallet handle already in JSON format: $walletData');
        }
        
        print('Calling lib_mwc.encodeSlatepackEnhanced...');
        slatepackResult = await lib_mwc.encodeSlatepackEnhanced(
          walletData,
          slateJson,
          recipientAddress,
        );
      } else {
        // For unencrypted slatepacks, use the basic function
        print('Using basic encoding (no encryption)');
        print('Calling lib_mwc.encodeSlatepack...');
        slatepackResult = await lib_mwc.encodeSlatepack(
          slateJson,
          null,
        );
      }

      print('FFI result length: ${slatepackResult.length}');
      print('FFI result preview: ${slatepackResult.length > 100 ? slatepackResult.substring(0, 100) + '...' : slatepackResult}');

      if (slatepackResult.toUpperCase().contains("ERROR")) {
        print('ERROR in FFI result: $slatepackResult');
        throw Exception("Error encoding slatepack: $slatepackResult");
      }

      final result = (
        slatepack: slatepackResult,
        wasEncrypted: encrypt && recipientAddress != null,
        recipientAddress: encrypt ? recipientAddress : null,
      );
      
      print('Successfully encoded slatepack. Encrypted: ${result.wasEncrypted}');
      return result;
    } catch (e) {
      print('ERROR in encodeSlatepack: ${e.toString()}');
      print('Stack trace: ${StackTrace.current}');
      throw ("Error encoding slatepack: ${e.toString()}");
    }
  }

  ///
  /// Decode slatepack with automatic encryption detection
  ///
  /// Parameters:
  /// - slatepack: The slatepack string to decode
  /// - walletHandle: Optional wallet handle for decryption context
  ///
  /// Returns a record with the decoded slate JSON, encryption status, and addresses
  ///
  static Future<({
    String slateJson,
    bool wasEncrypted,
    String? senderAddress,
    String? recipientAddress,
  })> decodeSlatepack({
    required String slatepack,
    String? walletHandle,
  }) async {
    try {
      // Use the existing decodeSlatepack function
      final decodeResult = await lib_mwc.decodeSlatepack(slatepack);

      if (decodeResult.toUpperCase().contains("ERROR")) {
        throw Exception("Error decoding slatepack: $decodeResult");
      }

      final decodeResponse = jsonDecode(decodeResult);
      
      final wasEncrypted = decodeResponse['sender'] != null || decodeResponse['recipient'] != null;
      
      return (
        slateJson: decodeResponse['slate_json'] as String,
        wasEncrypted: wasEncrypted,
        senderAddress: decodeResponse['sender'] as String?,
        recipientAddress: decodeResponse['recipient'] as String?,
      );
    } catch (e) {
      throw ("Error decoding slatepack: ${e.toString()}");
    }
  }

  ///
  /// Create and encode slatepack in one operation
  ///
  static Future<({
    String slatepack,
    String slateId,
    bool wasEncrypted,
  })> createAndEncodeSlatepack({
    required String wallet,
    required int amount,
    String? recipientAddress,
    bool encrypt = false,
    String message = "",
    int minimumConfirmations = 10,
    bool selectionStrategyIsUseAll = false,
  }) async {
    return await m.protect(() async {
      try {
        // First create the slate
        final createResult = await lib_mwc.txCreate(
          wallet,
          amount,
          minimumConfirmations,
          selectionStrategyIsUseAll,
          message,
        );

        if (createResult.toUpperCase().contains("ERROR")) {
          throw Exception("Error creating slate: $createResult");
        }

        // Extract slate ID
        final slateData = jsonDecode(createResult);
        final slateId = slateData['id'] as String;

        // Encode as slatepack
        final encodeResult = await encodeSlatepack(
          slateJson: createResult,
          recipientAddress: recipientAddress,
          encrypt: encrypt,
        );

        return (
          slatepack: encodeResult.slatepack,
          slateId: slateId,
          wasEncrypted: encodeResult.wasEncrypted,
        );
      } catch (e) {
        throw ("Error creating and encoding slatepack: ${e.toString()}");
      }
    });
  }

  ///
  /// Receive and decode slatepack in one operation
  ///
  static Future<({
    String slatepack,
    String slateId,
    bool wasEncrypted,
    String? senderAddress,
  })> receiveAndEncodeSlatepack({
    required String wallet,
    required String inputSlatepack,
    String message = "",
    String? walletHandle,
  }) async {
    return await m.protect(() async {
      try {
        // First decode the slatepack
        final decodeResult = await decodeSlatepack(
          slatepack: inputSlatepack,
          walletHandle: walletHandle,
        );

        // Process the slate
        final receiveResult = await lib_mwc.txReceive(
          wallet,
          decodeResult.slateJson,
          message,
        );

        if (receiveResult.toUpperCase().contains("ERROR")) {
          throw Exception("Error receiving slate: $receiveResult");
        }

        // Extract slate ID
        final slateData = jsonDecode(receiveResult);
        final slateId = slateData['id'] as String;

        // Re-encode as slatepack (maintain encryption if it was encrypted)
        final reencodeResult = await encodeSlatepack(
          slateJson: receiveResult,
          recipientAddress: decodeResult.senderAddress, // Send back to original sender
          encrypt: decodeResult.wasEncrypted,
        );

        return (
          slatepack: reencodeResult.slatepack,
          slateId: slateId,
          wasEncrypted: decodeResult.wasEncrypted,
          senderAddress: decodeResult.senderAddress,
        );
      } catch (e) {
        throw ("Error receiving and encoding slatepack: ${e.toString()}");
      }
    });
  }

  ///
  /// Check if a slatepack is encrypted
  ///
  static Future<bool> isSlatepackEncrypted(String slatepack) async {
    try {
      // Try to decode and check metadata
      final decodeResult = await decodeSlatepack(slatepack: slatepack);
      return decodeResult.wasEncrypted;
    } catch (e) {
      // If we can't decode it at all, assume it might be encrypted
      // and we don't have the right keys
      return true;
    }
  }

  ///
  /// Get slatepack metadata without fully decoding
  ///
  static Future<Map<String, dynamic>> getSlatepackInfo(String slatepack) async {
    try {
      final decodeResult = await decodeSlatepack(slatepack: slatepack);
      
      // Extract basic slate info
      final slateData = jsonDecode(decodeResult.slateJson);
      
      return {
        'isEncrypted': decodeResult.wasEncrypted,
        'senderAddress': decodeResult.senderAddress,
        'recipientAddress': decodeResult.recipientAddress,
        'slateId': slateData['id'],
        'amount': slateData['amount'],
        'fee': slateData['fee'],
        'participants': slateData['num_participants'],
        'version': slateData['version_info']?['version'],
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'isEncrypted': null,
        'canDecode': false,
      };
    }
  }
}
