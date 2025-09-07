import 'dart:convert';
import 'dart:io';

import 'package:flutter_libmwc/mwc.dart' as mwc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class WalletResult {
  final bool success;
  final String? walletName;
  final String? error;
  final Map<String, dynamic>? walletInfo;

  WalletResult({
    required this.success,
    this.walletName,
    this.error,
    this.walletInfo,
  });
}

class WalletService {
  static const _storage = FlutterSecureStorage();
  static const String _configKey = 'wallet_config';
  static const String _currentWalletKey = 'current_wallet';
  static const String _walletHandleKey = 'wallet_handle';

  // Centralized node configuration.
  static const String defaultNodeProtocol = 'https';
  static const String defaultNodeHost = 'mwc713.mwc.mw';
  static const int defaultNodePort = 443;
  static const String defaultNodeUrl =
      "$defaultNodeProtocol://$defaultNodeHost:$defaultNodePort";

  // In-memory wallet handle for the current session.
  static String? _currentWalletHandle;

  static Future<String> _getWalletDirectory(String walletName) async {
    if (Platform.isIOS) {
      final directory = await getLibraryDirectory();
      return "${directory.path}/mwc/$walletName/";
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return "${directory.path}/mwc/$walletName/";
    }
  }

  static Map<String, dynamic> _createWalletConfig(
      String walletName, String walletDir) {
    return {
      "wallet_dir": walletDir,
      "check_node_api_http_addr": defaultNodeUrl,
      "chain": "mainnet",
      "account": "default",
      "api_listen_port": defaultNodePort,
      "api_listen_interface": defaultNodeHost,
    };
  }

  /// Create a new MWC wallet.
  static Future<WalletResult> createWallet({
    required String walletName,
    required String password,
    String? customMnemonic,
  }) async {
    try {
      print('=== Creating Wallet Debug Info ===');
      print('Wallet Name: $walletName');
      print('Password Length: ${password.length}');
      print(
          'Custom Mnemonic: ${customMnemonic != null ? "Provided" : "Will generate"}');
      
      // Check if wallet name already exists.
      final availableWallets = await getAvailableWallets();
      if (availableWallets.contains(walletName)) {
        print('ERROR: Wallet name "$walletName" already exists');
        return WalletResult(
          success: false,
          error: 'Wallet "$walletName" already exists. Please choose a different name.',
        );
      }

      final walletDir = await _getWalletDirectory(walletName);
      print('Wallet Directory: $walletDir');

      final config = _createWalletConfig(walletName, walletDir);
      final configJson = json.encode(config);
      print('Config JSON: $configJson');

      // Generate or use provided mnemonic.
      final mnemonic = customMnemonic ?? mwc.walletMnemonic();
      print('Mnemonic Length: ${mnemonic.split(' ').length} words');

      // Check if wallet directory already exists.
      final directory = Directory(walletDir);
      if (await directory.exists()) {
        print('WARNING: Wallet directory already exists: $walletDir');
        // Check if there are any wallet files already present.
        final files = await directory.list().toList();
        if (files.isNotEmpty) {
          print('ERROR: Wallet directory contains existing files - possible duplicate wallet');
          return WalletResult(
            success: false,
            error: 'Wallet "$walletName" already exists. Please choose a different name.',
          );
        }
      }

      // Create the wallet directory.
      await directory.create(recursive: true);
      print('Directory created successfully');

      // Initialize the wallet.
      print('Calling mwc.initWallet...');
      final result = mwc.initWallet(configJson, mnemonic, password, walletName);
      print('Raw result from mwc.initWallet: "$result"');
      print('Result length: ${result.length}');
      print('Result is empty: ${result.isEmpty}');

      // Handle empty response from MWC API.
      if (result.isEmpty) {
        print('Empty response from mwc.initWallet - this indicates an error');
        return WalletResult(
          success: false,
          error:
              'Wallet initialization failed: empty response from MWC library',
        );
      }

      // Try to parse JSON response first.
      try {
        final walletData = json.decode(result);
        print('Parsed JSON wallet data: $walletData');

        if (walletData['error'] != null) {
          print('Error in wallet JSON data: ${walletData['error']}');
          return WalletResult(
            success: false,
            error: walletData['error'].toString(),
          );
        }

        // Check for success status in JSON response
        if (walletData['status'] == 'success') {
          print('Wallet created successfully according to JSON response');
          await _storage.write(
              key: '${_configKey}_$walletName', value: configJson);
          await _storage.write(key: _currentWalletKey, value: walletName);
          print('Wallet configuration stored securely');

          return WalletResult(
            success: true,
            walletName: walletName,
            walletInfo: walletData,
          );
        }

        // JSON response with other data - store config and return.
        await _storage.write(
            key: '${_configKey}_$walletName', value: configJson);
        await _storage.write(key: _currentWalletKey, value: walletName);
        print('Wallet configuration stored securely');

        return WalletResult(
          success: true,
          walletName: walletName,
          walletInfo: walletData,
        );
      } catch (jsonError) {
        print('JSON parsing failed: $jsonError');
        print('Treating non-JSON response as wallet handle');

        // If result contains obvious error keywords, treat as error.
        if (result.toLowerCase().contains('error') ||
            result.toLowerCase().contains('fail')) {
          return WalletResult(
            success: false,
            error: 'Wallet creation failed: $result',
          );
        }

        // Non-JSON, non-error response - assume it's a wallet handle.
        _currentWalletHandle = result;
        print(
            'Wallet handle stored from initWallet: ${result.length} characters');
        print(
            'Wallet handle preview: ${result.length > 50 ? result.substring(0, 50) + '...' : result}');

        await _storage.write(
            key: '${_configKey}_$walletName', value: configJson);
        await _storage.write(key: _currentWalletKey, value: walletName);
        print('Wallet configuration stored securely');

        return WalletResult(
          success: true,
          walletName: walletName,
          walletInfo: {
            'status': 'created',
            'name': walletName,
            'handle_length': result.length
          },
        );
      }
    } catch (e, stackTrace) {
      print('=== Wallet Creation Error ===');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      return WalletResult(
        success: false,
        error: 'Failed to create wallet: $e',
      );
    }
  }

  /// Open an existing MWC wallet.
  static Future<WalletResult> openWallet({
    required String walletName,
    required String password,
  }) async {
    try {
      print('=== Opening Wallet Debug Info ===');
      print('Wallet Name: $walletName');
      print('Password Length: ${password.length}');

      // Retrieve stored configuration.
      final configJson = await _storage.read(key: '${_configKey}_$walletName');
      if (configJson == null) {
        print('Error: Wallet configuration not found for $walletName');
        return WalletResult(
          success: false,
          error:
              'Wallet configuration not found. Please check if the wallet exists.',
        );
      }
      print('Config found: $configJson');

      // Open the wallet.
      print('Calling mwc.openWallet...');
      final result = mwc.openWallet(configJson, password);
      print('Raw result from mwc.openWallet: "$result"');
      print('Result length: ${result.length}');

      // Handle empty response from MWC API.
      if (result.isEmpty) {
        print(
            'Empty response from mwc.openWallet - this may indicate an error');
        return WalletResult(
          success: false,
          error: 'Failed to open wallet: empty response from MWC library',
        );
      }

      // Store the wallet handle for subsequent operations.
      _currentWalletHandle = result;
      print('Wallet handle stored: ${result.length} characters');

      await _storage.write(key: _currentWalletKey, value: walletName);
      return WalletResult(
        success: true,
        walletName: walletName,
        walletInfo: {'status': 'opened', 'name': walletName, 'handle': result},
      );
    } catch (e, stackTrace) {
      print('=== Wallet Opening Error ===');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      return WalletResult(
        success: false,
        error: 'Failed to open wallet: $e',
      );
    }
  }

  /// Restore a wallet from mnemonic.
  static Future<WalletResult> restoreWallet({
    required String walletName,
    required String password,
    required String mnemonic,
  }) async {
    try {
      print('=== Restoring Wallet Debug Info ===');
      print('Wallet Name: $walletName');
      print('Password Length: ${password.length}');
      print('Mnemonic Length: ${mnemonic.split(' ').length} words');

      final walletDir = await _getWalletDirectory(walletName);
      final config = _createWalletConfig(walletName, walletDir);
      final configJson = json.encode(config);
      print('Config JSON: $configJson');

      // Create the wallet directory.
      await Directory(walletDir).create(recursive: true);
      print('Directory created successfully');

      // Restore the wallet.
      print('Calling mwc.recoverWallet...');
      final result =
          mwc.recoverWallet(configJson, password, mnemonic, walletName);
      print('Raw result from mwc.recoverWallet: "$result"');
      print('Result length: ${result.length}');

      // Handle empty response from MWC API.
      if (result.isEmpty) {
        print(
            'Empty response from mwc.recoverWallet - this indicates an error');
        return WalletResult(
          success: false,
          error: 'Wallet recovery failed: empty response from MWC library',
        );
      }

      // Try to parse JSON response first.
      try {
        final walletData = json.decode(result);
        print('Parsed JSON wallet data: $walletData');

        if (walletData['error'] != null) {
          print('Error in wallet JSON data: ${walletData['error']}');
          return WalletResult(
            success: false,
            error: walletData['error'].toString(),
          );
        }

        // JSON response with success - store config and return.
        await _storage.write(
            key: '${_configKey}_$walletName', value: configJson);
        await _storage.write(key: _currentWalletKey, value: walletName);
        print('Wallet configuration stored securely');

        return WalletResult(
          success: true,
          walletName: walletName,
          walletInfo: walletData,
        );
      } catch (jsonError) {
        print('JSON parsing failed: $jsonError');
        print('Treating non-JSON response as wallet handle');

        // If result contains obvious error keywords, treat as error.
        if (result.toLowerCase().contains('error') ||
            result.toLowerCase().contains('fail')) {
          return WalletResult(
            success: false,
            error: 'Failed to restore wallet: $result',
          );
        }

        // Non-JSON, non-error response - assume it's a wallet handle.
        _currentWalletHandle = result;
        print(
            'Wallet handle stored from recoverWallet: ${result.length} characters');
        print(
            'Wallet handle preview: ${result.length > 50 ? result.substring(0, 50) + '...' : result}');

        await _storage.write(
            key: '${_configKey}_$walletName', value: configJson);
        await _storage.write(key: _currentWalletKey, value: walletName);
        print('Wallet configuration stored securely');

        return WalletResult(
          success: true,
          walletName: walletName,
          walletInfo: {
            'status': 'restored',
            'name': walletName,
            'handle_length': result.length
          },
        );
      }
    } catch (e, stackTrace) {
      print('=== Wallet Restoration Error ===');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      return WalletResult(
        success: false,
        error: 'Failed to restore wallet: $e',
      );
    }
  }

  /// Get wallet information and balance.
  static Future<Map<String, dynamic>?> getWalletInfo(
    String walletName, {
    int refreshFromNode = 0,
    int minimumConfirmations = 10,
  }) async {
    try {
      print('=== Getting Wallet Info Debug ===');
      print('Wallet Name: $walletName');
      print('Refresh From Node: $refreshFromNode');
      print('Minimum Confirmations: $minimumConfirmations');

      // Check if we have a wallet handle.
      if (_currentWalletHandle == null) {
        print('No wallet handle available - wallet may not be opened');
        return {'error': 'Wallet not opened. Please open the wallet first.'};
      }

      print('Using wallet handle, calling mwc.getWalletInfo...');
      final result = await mwc.getWalletInfo(
        _currentWalletHandle!,
        refreshFromNode,
        minimumConfirmations,
      );
      print('Raw result from mwc.getWalletInfo: "$result"');

      final decoded = json.decode(result);
      print('Decoded wallet info: $decoded');
      return decoded;
    } catch (e, stackTrace) {
      print('=== Wallet Info Error ===');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      return null;
    }
  }

  /// Get wallet address information.
  static Future<String?> getWalletAddress(String walletName,
      {int index = 0}) async {
    try {
      print('=== Getting Wallet Address Debug ===');
      print('Wallet Name: $walletName, Index: $index');

      // Check if we have a wallet handle.
      if (_currentWalletHandle == null) {
        print('No wallet handle available - wallet may not be opened');
        return null;
      }

      print(
          'Using wallet handle (length: ${_currentWalletHandle!.length}), calling mwc.getAddressInfo...');
      print(
          'Wallet handle preview: ${_currentWalletHandle!.length > 50 ? _currentWalletHandle!.substring(0, 50) + '...' : _currentWalletHandle!}');
      final result = mwc.getAddressInfo(
          _currentWalletHandle!, index); // Use wallet handle instead of config.
      print('Address result: "$result"');
      return result;
    } catch (e, stackTrace) {
      print('=== Wallet Address Error ===');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      return null;
    }
  }

  /// Get wallet transactions
  static Future<List<Map<String, dynamic>>?> getWalletTransactions(
    String walletName, {
    int refreshFromNode = 0,
  }) async {
    try {
      print('=== Getting Wallet Transactions Debug ===');
      print('Wallet Name: $walletName, Refresh From Node: $refreshFromNode');

      // Check if we have a wallet handle.
      if (_currentWalletHandle == null) {
        print('No wallet handle available - wallet may not be opened');
        return null;
      }

      print('Using wallet handle, calling mwc.getTransactions...');
      final result = await mwc.getTransactions(_currentWalletHandle!,
          refreshFromNode); // Use wallet handle instead of config.
      print('Raw transaction result: "$result"');

      final data = json.decode(result);
      print('Decoded transaction data: $data');

      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e, stackTrace) {
      print('=== Wallet Transactions Error ===');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      return null;
    }
  }

  /// Get chain height for sync status.
  static Future<int?> getChainHeight(String walletName) async {
    try {
      print('=== Getting Chain Height Debug ===');
      print('Wallet Name: $walletName');

      final configJson = await _storage.read(key: '${_configKey}_$walletName');
      if (configJson == null) {
        print('Config not found for wallet: $walletName');
        return null;
      }

      print('Config found, calling mwc.getChainHeight...');
      final height = mwc.getChainHeight(configJson);
      print('Chain height result: $height');

      // Check if height is -1 (error state).
      if (height == -1) {
        print('Chain height returned error state (-1), likely network issue');
        return null;
      }

      return height;
    } catch (e, stackTrace) {
      print('=== Chain Height Error ===');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      return null;
    }
  }

  /// Scan wallet outputs.
  static Future<bool> scanWalletOutputs(
    String walletName, {
    int startHeight = 0,
    int numberOfBlocks = 100,
  }) async {
    try {
      print('=== Scanning Wallet Outputs Debug ===');
      print(
          'Wallet Name: $walletName, Start Height: $startHeight, Blocks: $numberOfBlocks');

      // Check if we have a wallet handle.
      if (_currentWalletHandle == null) {
        print('No wallet handle available - wallet may not be opened');
        return false;
      }

      print('Using wallet handle, calling mwc.scanOutPuts...');
      await mwc.scanOutPuts(_currentWalletHandle!, startHeight,
          numberOfBlocks); // Use wallet handle instead of config.
      print('Scan outputs completed successfully');
      return true;
    } catch (e, stackTrace) {
      print('=== Scan Outputs Error ===');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      return false;
    }
  }

  /// Get current wallet name.
  static Future<String?> getCurrentWallet() async {
    return await _storage.read(key: _currentWalletKey);
  }

  /// Check if there is a wallet open (has current wallet handle).
  static Future<bool> hasOpenWallet() async {
    return _currentWalletHandle != null && _currentWalletHandle!.isNotEmpty;
  }

  /// List available wallets.
  static Future<List<String>> getAvailableWallets() async {
    try {
      final allKeys = await _storage.readAll();
      final walletKeys = allKeys.keys
          .where((key) => key.startsWith('${_configKey}_'))
          .map((key) => key.substring('${_configKey}_'.length))
          .toList();
      return walletKeys;
    } catch (e) {
      return [];
    }
  }

  /// Delete a wallet.
  static Future<bool> deleteWallet(String walletName) async {
    try {
      final configJson = await _storage.read(key: '${_configKey}_$walletName');
      if (configJson != null) {
        // Delete from Rust backend.
        await mwc.deleteWallet(walletName, configJson);
      }

      // Remove from secure storage.
      await _storage.delete(key: '${_configKey}_$walletName');

      final currentWallet = await getCurrentWallet();
      if (currentWallet == walletName) {
        await _storage.delete(key: _currentWalletKey);
      }

      // Delete wallet directory.
      final walletDir = await _getWalletDirectory(walletName);
      final directory = Directory(walletDir);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate mnemonic phrase.
  static bool validateMnemonic(String mnemonic) {
    final words = mnemonic.trim().split(RegExp(r'\s+'));
    return words.length >= 12 && words.length <= 24;
  }

  /// Initialize logging (call once at app startup).
  static Future<void> initializeLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logConfig = {
        "log_level": "Debug",
        "log_file_path": "${directory.path}/mwc_logs/",
      };
      mwc.initLogs(json.encode(logConfig));
    } catch (e) {
      print('Failed to initialize logs: $e');
    }
  }
}
