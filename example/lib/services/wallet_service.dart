import 'dart:convert';
import 'dart:io';

import 'package:flutter_libmwc/lib.dart' as mwc_lib;
import 'package:flutter_libmwc/mwc.dart' as mwc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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

// Simple storage wrapper that falls back to SharedPreferences on macOS.
class _StorageService {
  static const _secureStorage = FlutterSecureStorage();
  static bool _useSecureStorage = true;
  
  static Future<void> write({required String key, required String value}) async {
    if (_useSecureStorage) {
      try {
        await _secureStorage.write(key: key, value: value);
        return;
      } catch (e) {
        print('Secure storage failed, falling back to SharedPreferences: $e');
        _useSecureStorage = false;
      }
    }
    
    // Fallback to SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('secure_$key', value);
  }
  
  static Future<String?> read({required String key}) async {
    print('StorageService.read() looking for key: $key');
    
    // Try secure storage first
    if (_useSecureStorage) {
      try {
        final result = await _secureStorage.read(key: key);
        if (result != null) {
          print('Found key "$key" in secure storage');
          return result;
        }
      } catch (e) {
        print('Secure storage read failed, falling back to SharedPreferences: $e');
        _useSecureStorage = false;
      }
    }
    
    // Try SharedPreferences (for fallback data or if secure storage failed).
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = prefs.getString('secure_$key');
      if (result != null) {
        print('Found key "$key" in SharedPreferences as "secure_$key"');
        return result;
      } else {
        print('Key "$key" not found in SharedPreferences');
      }
    } catch (e) {
      print('SharedPreferences read failed: $e');
    }
    
    print('Key "$key" not found in either storage method');
    return null;
  }
  
  static Future<Map<String, String>> readAll() async {
    final result = <String, String>{};
    
    // Try to read from secure storage first.
    if (_useSecureStorage) {
      try {
        final secureData = await _secureStorage.readAll();
        result.addAll(secureData);
      } catch (e) {
        print('Secure storage readAll failed, falling back to SharedPreferences: $e');
        _useSecureStorage = false;
      }
    }
    
    // Also read from SharedPreferences (for fallback data or if secure storage failed).
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('secure_')) {
          final value = prefs.getString(key);
          if (value != null) {
            final actualKey = key.substring(7); // Remove 'secure_' prefix.
            // Only add if not already present from secure storage.
            if (!result.containsKey(actualKey)) {
              result[actualKey] = value;
            }
          }
        }
      }
    } catch (e) {
      print('SharedPreferences readAll failed: $e');
    }
    
    print('StorageService.readAll() found ${result.length} keys: ${result.keys.toList()}');
    return result;
  }
  
  static Future<void> delete({required String key}) async {
    if (_useSecureStorage) {
      try {
        await _secureStorage.delete(key: key);
        return;
      } catch (e) {
        print('Secure storage delete failed, falling back to SharedPreferences: $e');
        _useSecureStorage = false;
      }
    }
    
    // Fallback to SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('secure_$key');
  }
}

class WalletService {
  static const String _configKey = 'wallet_config';
  static const String _currentWalletKey = 'current_wallet';
  static const String _walletHandleKey = 'wallet_handle';
  static const String _mnemonicKey = 'wallet_mnemonic';

  // Centralized node configuration.
  static const String defaultNodeProtocol = 'https';
  static const String defaultNodeHost = 'mwc713.mwc.mw';
  static const int defaultNodePort = 443;
  static const String defaultNodeUrl =
      "$defaultNodeProtocol://$defaultNodeHost:$defaultNodePort";

  // In-memory wallet handle for the current session.
  static String? _currentWalletHandle;

  /// Check network connectivity to MWC node using JSON-RPC API.
  static Future<bool> checkNodeConnectivity({int timeoutSeconds = 10}) async {
    try {
      print('=== Checking Node Connectivity ===');
      print('Testing connection to: $defaultNodeUrl');
      
      // Use JSON-RPC v2 API to get chain tip (get_tip method).
      final uri = Uri.parse('$defaultNodeUrl/v2/foreign');
      final requestBody = json.encode({
        "jsonrpc": "2.0",
        "method": "get_tip",
        "params": [],
        "id": 1
      });
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      ).timeout(Duration(seconds: timeoutSeconds));
      
      print('Node response status: ${response.statusCode}');
      print('Node response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData.containsKey('result')) {
          print('Node connectivity: SUCCESS - Chain tip received');
          return true;
        } else if (responseData.containsKey('error')) {
          print('Node connectivity: API ERROR - ${responseData['error']}');
          return false;
        }
      }
      
      print('Node connectivity: FAILED (status: ${response.statusCode})');
      return false;
    } catch (e) {
      print('Node connectivity: ERROR - $e');
      
      // Fallback: try simple HTTP connectivity test.
      try {
        print('Trying fallback connectivity test...');
        final uri = Uri.parse(defaultNodeUrl);
        final response = await http.get(uri).timeout(Duration(seconds: 5));
        if (response.statusCode < 500) {
          print('Fallback connectivity: SUCCESS (HTTP reachable)');
          return true;
        }
      } catch (fallbackError) {
        print('Fallback connectivity: FAILED - $fallbackError');
      }
      
      return false;
    }
  }

  /// Validate network connectivity before operations requiring node access.
  static Future<bool> _validateNodeConnectivity() async {
    final isConnected = await checkNodeConnectivity();
    if (!isConnected) {
      print('WARNING: Node connectivity check failed - operations may not work properly');
    }
    return isConnected;
  }

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
          await _StorageService.write(
              key: '${_configKey}_$walletName', value: configJson);
          await _StorageService.write(key: _currentWalletKey, value: walletName);
          await _StorageService.write(
              key: '${_mnemonicKey}_$walletName', value: mnemonic);
          print('Wallet configuration and mnemonic stored securely');

          return WalletResult(
            success: true,
            walletName: walletName,
            walletInfo: walletData,
          );
        }

        // JSON response with other data - store config and return.
        await _StorageService.write(
            key: '${_configKey}_$walletName', value: configJson);
        await _StorageService.write(key: _currentWalletKey, value: walletName);
        await _StorageService.write(
            key: '${_mnemonicKey}_$walletName', value: mnemonic);
        print('Wallet configuration and mnemonic stored securely');

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
        // Also set it in the main library's WalletManager for unified access
        mwc_lib.Libmwc.setCurrentWalletHandle(result);
        print(
            'Wallet handle stored from initWallet: ${result.length} characters');
        print(
            'Wallet handle preview: ${result.length > 50 ? result.substring(0, 50) + '...' : result}');

        await _StorageService.write(
            key: '${_configKey}_$walletName', value: configJson);
        await _StorageService.write(key: _currentWalletKey, value: walletName);
        await _StorageService.write(
            key: '${_mnemonicKey}_$walletName', value: mnemonic);
        print('Wallet configuration and mnemonic stored securely');

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
      final configJson = await _StorageService.read(key: '${_configKey}_$walletName');
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

      // Check if the result is an error message instead of a wallet handle
      if (result.toLowerCase().contains('error')) {
        print('mwc.openWallet returned an error: $result');
        return WalletResult(
          success: false,
          error: 'Failed to open wallet: $result',
        );
      }

      // Store the wallet handle for subsequent operations.
      _currentWalletHandle = result;
      // Also set it in the main library's WalletManager for unified access
      mwc_lib.Libmwc.setCurrentWalletHandle(result);
      print('Wallet handle stored: ${result.length} characters');

      await _StorageService.write(key: _currentWalletKey, value: walletName);
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
        await _StorageService.write(
            key: '${_configKey}_$walletName', value: configJson);
        await _StorageService.write(key: _currentWalletKey, value: walletName);
        await _StorageService.write(
            key: '${_mnemonicKey}_$walletName', value: mnemonic);
        print('Wallet configuration and mnemonic stored securely');

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
        // Also set it in the main library's WalletManager for unified access
        mwc_lib.Libmwc.setCurrentWalletHandle(result);
        print(
            'Wallet handle stored from recoverWallet: ${result.length} characters');
        print(
            'Wallet handle preview: ${result.length > 50 ? result.substring(0, 50) + '...' : result}');

        await _StorageService.write(
            key: '${_configKey}_$walletName', value: configJson);
        await _StorageService.write(key: _currentWalletKey, value: walletName);
        await _StorageService.write(
            key: '${_mnemonicKey}_$walletName', value: mnemonic);
        print('Wallet configuration and mnemonic stored securely');

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
    int refreshFromNode = 1,  // Changed default to 1 (enable blockchain refresh).
    int minimumConfirmations = 10,
  }) async {
    try {
      print('=== Getting Wallet Info Debug ===');
      print('Wallet Name: $walletName');
      print('Refresh From Node: $refreshFromNode');
      print('Minimum Confirmations: $minimumConfirmations');

      // Validate wallet state first.
      if (!await _validateWalletState(walletName)) {
        print('Wallet state validation failed');
        return {'error': 'Wallet not opened or invalid state. Please open the wallet first.'};
      }

      // Check network connectivity if refreshing from node.
      if (refreshFromNode > 0) {
        final networkOk = await _validateNodeConnectivity();
        if (!networkOk) {
          print('WARNING: Network connectivity issues detected - proceeding with cached data only');
          // Fall back to local data only.
          refreshFromNode = 0;
        }
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
      
      // Add network status to response.
      decoded['network_refreshed'] = refreshFromNode > 0;
      decoded['node_url'] = defaultNodeUrl;
      
      return decoded;
    } catch (e, stackTrace) {
      print('=== Wallet Info Error ===');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      return {'error': 'Failed to get wallet info: $e'};
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
    int refreshFromNode = 1,  // Changed default to 1 (enable blockchain refresh).
  }) async {
    try {
      print('=== Getting Wallet Transactions Debug ===');
      print('Wallet Name: $walletName, Refresh From Node: $refreshFromNode');

      // Validate wallet state first.
      if (!await _validateWalletState(walletName)) {
        print('Wallet state validation failed');
        return null;
      }

      // Check network connectivity if refreshing from node.
      if (refreshFromNode > 0) {
        final networkOk = await _validateNodeConnectivity();
        if (!networkOk) {
          print('WARNING: Network connectivity issues detected - proceeding with cached data only');
          // Fall back to local data only
          refreshFromNode = 0;
        }
      }

      print('Using wallet handle, calling mwc.getTransactions...');
      final result = await mwc.getTransactions(_currentWalletHandle!,
          refreshFromNode);
      print('Raw transaction result: "$result"');

      final data = json.decode(result);
      print('Decoded transaction data: $data');

      if (data is List) {
        final transactions = List<Map<String, dynamic>>.from(data);
        print('Found ${transactions.length} transactions');
        return transactions;
      }
      print('No transactions found or invalid data format');
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

      final configJson = await _StorageService.read(key: '${_configKey}_$walletName');
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

  /// Scan wallet outputs with improved automatic scanning.
  static Future<bool> scanWalletOutputs(
    String walletName, {
    int startHeight = 0,
    int numberOfBlocks = 1000,
  }) async {
    try {
      print('=== Scanning Wallet Outputs Debug ===');
      print(
          'Wallet Name: $walletName, Start Height: $startHeight, Blocks: $numberOfBlocks');

      // Validate wallet state first.
      if (!await _validateWalletState(walletName)) {
        print('Wallet state validation failed');
        return false;
      }

      // Check network connectivity before scanning.
      final networkOk = await _validateNodeConnectivity();
      if (!networkOk) {
        print('ERROR: Network connectivity required for wallet scanning');
        return false;
      }

      print('Using wallet handle, calling mwc.scanOutPuts...');
      await mwc.scanOutPuts(_currentWalletHandle!, startHeight, numberOfBlocks);
      print('Scan outputs completed successfully');
      return true;
    } catch (e, stackTrace) {
      print('=== Scan Outputs Error ===');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      return false;
    }
  }

  /// Perform comprehensive wallet scan from genesis or restoration point.
  static Future<bool> performComprehensiveScan(String walletName) async {
    try {
      print('=== Performing Comprehensive Wallet Scan ===');
      
      // Get current chain height to determine scan range.
      final chainHeight = await getChainHeight(walletName);
      if (chainHeight == null || chainHeight <= 0) {
        print('WARNING: Unable to get chain height, using default scan range');
        return await scanWalletOutputs(walletName, startHeight: 0, numberOfBlocks: 10000);
      }

      print('Current chain height: $chainHeight');
      
      // Scan the entire blockchain history in chunks.
      const int chunkSize = 5000;
      int currentHeight = 0;
      
      while (currentHeight < chainHeight) {
        final remainingBlocks = chainHeight - currentHeight;
        final blocksToScan = remainingBlocks < chunkSize ? remainingBlocks : chunkSize;
        
        print('Scanning blocks $currentHeight to ${currentHeight + blocksToScan}');
        
        final success = await scanWalletOutputs(
          walletName,
          startHeight: currentHeight,
          numberOfBlocks: blocksToScan,
        );
        
        if (!success) {
          print('ERROR: Scan failed at height $currentHeight');
          return false;
        }
        
        currentHeight += blocksToScan;
      }
      
      print('Comprehensive scan completed successfully');
      return true;
    } catch (e, stackTrace) {
      print('=== Comprehensive Scan Error ===');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      return false;
    }
  }

  /// Get current wallet name.
  static Future<String?> getCurrentWallet() async {
    return await _StorageService.read(key: _currentWalletKey);
  }

  /// Check if there is a wallet open (has current wallet handle).
  static Future<bool> hasOpenWallet() async {
    return _currentWalletHandle != null && _currentWalletHandle!.isNotEmpty;
  }

  /// True if a wallet is currently open and a handle is available.
  static bool get isWalletOpen =>
      _currentWalletHandle != null && _currentWalletHandle!.isNotEmpty;

  /// Returns the current wallet handle as a String.
  /// Throws if no wallet is currently open.
  static String getWalletString() {
    final handle = _currentWalletHandle;
    if (handle == null || handle.isEmpty) {
      throw Exception('Wallet is not open');
    }
    return handle;
  }

  /// Validate wallet is properly opened and ready for operations
  static Future<bool> _validateWalletState(String walletName) async {
    print('=== Validating Wallet State ===');
    print('Wallet Name: $walletName');
    print('Has Handle: ${_currentWalletHandle != null}');
    
    if (_currentWalletHandle == null || _currentWalletHandle!.isEmpty) {
      print('ERROR: No wallet handle - wallet not opened');
      return false;
    }
    
    final currentWallet = await getCurrentWallet();
    if (currentWallet != walletName) {
      print('ERROR: Current wallet mismatch - expected: $walletName, current: $currentWallet');
      return false;
    }
    
    print('Wallet state validation: SUCCESS');
    return true;
  }

  /// Attempt to automatically open wallet if not already open.
  static Future<bool> _ensureWalletOpen(String walletName) async {
    if (await _validateWalletState(walletName)) {
      return true; // Already open and valid
    }
    
    print('=== Attempting Auto-Open Wallet ===');
    print('Wallet needs to be opened: $walletName');
    
    // Check if we have stored config for this wallet.
    final configJson = await _StorageService.read(key: '${_configKey}_$walletName');
    if (configJson == null) {
      print('ERROR: No stored config found for wallet: $walletName');
      return false;
    }
    
    // For now, we can't auto-open without password.
    // This would require storing encrypted passwords or prompting user.
    print('WARNING: Wallet requires password to open - auto-open not possible');
    return false;
  }
  
  /// Get the current wallet handle for use with FFI operations.
  /// Returns null if no wallet is currently open.
  static String? getCurrentWalletHandle() {
    return _currentWalletHandle;
  }

  /// List available wallets.
  static Future<List<String>> getAvailableWallets() async {
    try {
      print('=== Getting Available Wallets ===');
      final allKeys = await _StorageService.readAll();
      print('All storage keys: ${allKeys.keys.toList()}');
      
      final configKeys = allKeys.keys.where((key) => key.startsWith('${_configKey}_')).toList();
      print('Config keys found: $configKeys');
      
      final walletKeys = configKeys
          .map((key) => key.substring('${_configKey}_'.length))
          .toList();
      
      print('Wallet names from config: $walletKeys');
      
      // Filter to only include wallets whose directories actually exist.
      final existingWallets = <String>[];
      for (final walletName in walletKeys) {
        final walletDir = await _getWalletDirectory(walletName);
        final directory = Directory(walletDir);
        if (await directory.exists()) {
          print('Wallet directory exists: $walletDir');
          existingWallets.add(walletName);
        } else {
          print('Wallet directory does not exist: $walletDir - removing from list');
          // Optionally clean up the orphaned config.
          await _StorageService.delete(key: '${_configKey}_$walletName');
          await _StorageService.delete(key: '${_mnemonicKey}_$walletName');
        }
      }
      
      print('Available wallets (with existing directories): $existingWallets');
      return existingWallets;
    } catch (e) {
      print('Error in getAvailableWallets: $e');
      return [];
    }
  }

  /// Delete a wallet.
  static Future<bool> deleteWallet(String walletName) async {
    try {
      final configJson = await _StorageService.read(key: '${_configKey}_$walletName');
      if (configJson != null) {
        // Delete from Rust backend.
        await mwc.deleteWallet(walletName, configJson);
      }

      // Remove from secure storage.
      await _StorageService.delete(key: '${_configKey}_$walletName');
      await _StorageService.delete(key: '${_mnemonicKey}_$walletName');

      final currentWallet = await getCurrentWallet();
      if (currentWallet == walletName) {
        await _StorageService.delete(key: _currentWalletKey);
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

  /// Get the stored mnemonic for a wallet.
  static Future<String?> getWalletMnemonic(String walletName) async {
    try {
      return await _StorageService.read(key: '${_mnemonicKey}_$walletName');
    } catch (e) {
      print('Error retrieving mnemonic for wallet $walletName: $e');
      return null;
    }
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
