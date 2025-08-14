import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:ethereum/listening.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

class CreditTransaction {
  final BigInt transactionId;
  final EthereumAddress buyer;
  final EthereumAddress seller;
  final BigInt amount;
  final BigInt totalPrice;
  final DateTime timestamp;

  CreditTransaction({
    required this.transactionId,
    required this.buyer,
    required this.seller,
    required this.amount,
    required this.totalPrice,
    required this.timestamp,
  });

  factory CreditTransaction.fromTuple(List<dynamic> tuple) {
    return CreditTransaction(
      transactionId: tuple[0] as BigInt,
      buyer: tuple[1] as EthereumAddress,
      seller: tuple[2] as EthereumAddress,
      amount: tuple[3] as BigInt,
      totalPrice: tuple[4] as BigInt,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (tuple[5] as BigInt).toInt() * 1000,
      ),
    );
  }
}

class BlockchainService {
  late Web3Client _web3client;
  late ContractAbi _abiCode;
  late EthereumAddress _contractAddress;
  late EthPrivateKey _credentials;
  late http.Client _httpClient;

  late DeployedContract _deployedContract;
  
  ContractFunction? _issue;
  ContractFunction? _listCredits;
  ContractFunction? _buyCredits;
  ContractFunction? _balanceOf;
  ContractFunction? _setApprovalForAll;
  ContractFunction? _isApprovedForAll;
  ContractFunction? _cancelListing;
  ContractFunction? _earnCreditForAction;
  ContractFunction? _getMarketplaceStats;
  ContractFunction? _getListing;
  ContractFunction? _getActiveListingIds;
  ContractFunction? _getUserTransactionIds;
  ContractFunction? _getUserActiveListings;
  ContractFunction? _getCarbonCreditBalance;
  ContractFunction? _transactions;
  ContractFunction? _register;
  ContractFunction? _isRegistered;

  final String _contractAddressHex = "0xc4392C0c3d54057800083D704d07e2314E15a2fa"; // UPDATE THIS
  final String _rpcUrl = "http://10.137.29.236:7545"; // UPDATE THIS
  final String _socketUrl = "ws://10.137.29.236:7545"; // UPDATE THIS
  String _privateKey = "0x16544717e5e59395f0c5f12c1ac9dded55062d390f9848310215d7f49f1b6775"; // UPDATE THIS

  EthPrivateKey getCredentials() => _credentials;
  EthereumAddress getContractAddress() => _contractAddress;
  EthereumAddress getUserAddress() => _credentials.address;

  void setPrivateKey(String privateKey) {
    _privateKey = privateKey;
    _credentials = EthPrivateKey.fromHex(_privateKey);
  }

  ContractFunction? _safeGetFunction(String functionName) {
    try {
      return _deployedContract.function(functionName);
    } catch (e) {
      debugPrint("Function '$functionName' not found in contract ABI: $e");
      return null;
    }
  }

  // Enhanced HTTP client with better connection management
  http.Client _createHttpClient() {
    return http.Client();
  }

  // Connection health check
  Future<bool> _checkConnection() async {
    try {
      final response = await _httpClient.post(
        Uri.parse(_rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'eth_blockNumber',
          'params': [],
          'id': 1,
        }),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Connection check failed: $e");
      return false;
    }
  }

  // Reconnect logic
  Future<void> _reconnectIfNeeded() async {
    if (!await _checkConnection()) {
      debugPrint("Connection lost, attempting to reconnect...");
      _httpClient.close();
      _httpClient = _createHttpClient();
      
      // Recreate Web3Client
      _web3client = Web3Client(
        _rpcUrl,
        _httpClient,
        socketConnector: () => IOWebSocketChannel.connect(_socketUrl).cast<String>(),
      );
      
      await Future.delayed(const Duration(seconds: 2));
      
      if (!await _checkConnection()) {
        throw Exception("Failed to reconnect to blockchain node");
      }
      
      debugPrint("Successfully reconnected to blockchain node");
    }
  }

  Future<void> init([String? privateKey]) async {
    try {
      if (privateKey != null) {
        _privateKey = privateKey;
      }

      _httpClient = _createHttpClient();

      _web3client = Web3Client(
        _rpcUrl,
        _httpClient,
        socketConnector: () => IOWebSocketChannel.connect(_socketUrl).cast<String>(),
      );

      // Test connection first
      if (!await _checkConnection()) {
        throw Exception("Cannot connect to blockchain node at $_rpcUrl. Please ensure Ganache is running.");
      }

      final abiFile = await rootBundle.loadString('build/contracts/CarbonCreditMarketplace.json');
      final jsonDecoded = jsonDecode(abiFile);
      
      _abiCode = ContractAbi.fromJson(jsonEncode(jsonDecoded['abi']), 'CarbonCreditMarketplace');
      _contractAddress = EthereumAddress.fromHex(_contractAddressHex); 
      _credentials = EthPrivateKey.fromHex(_privateKey);

      _deployedContract = DeployedContract(_abiCode, _contractAddress);

      _issue = _safeGetFunction('issue');
      _listCredits = _safeGetFunction('listCredits');
      _buyCredits = _safeGetFunction('buyCredits');
      _balanceOf = _safeGetFunction('balanceOf');
      _setApprovalForAll = _safeGetFunction('setApprovalForAll');
      _isApprovedForAll = _safeGetFunction('isApprovedForAll');
      _cancelListing = _safeGetFunction('cancelListing');
      _earnCreditForAction = _safeGetFunction('earnCreditForAction');
      _getMarketplaceStats = _safeGetFunction('getMarketplaceStats');
      _getListing = _safeGetFunction('getListing');
      _getActiveListingIds = _safeGetFunction('getActiveListingIds');
      _getUserTransactionIds = _safeGetFunction('getUserTransactionIds');
      _getUserActiveListings = _safeGetFunction('getUserActiveListings');
      _getCarbonCreditBalance = _safeGetFunction('getCarbonCreditBalance');
      _transactions = _safeGetFunction('transactions'); 
      _register = _safeGetFunction('register');
      _isRegistered = _safeGetFunction('isRegistered'); 

      debugPrint("Blockchain service initialized successfully");
      if (_balanceOf == null) {
        throw Exception("Critical function 'balanceOf' not found in contract");
      }
      
    } catch (e) {
      debugPrint("Error initializing blockchain service: $e");
      rethrow;
    }
  }

  // Enhanced method execution with retry logic
  Future<T> _executeWithRetry<T>(Future<T> Function() operation, {int maxRetries = 3}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        debugPrint("Attempt ${attempt + 1} failed: $e");
        
        if (e.toString().contains('Connection closed') || 
            e.toString().contains('Connection refused') ||
            e.toString().contains('SocketException')) {
          
          if (attempt < maxRetries - 1) {
            await _reconnectIfNeeded();
            await Future.delayed(Duration(seconds: attempt + 1));
            continue;
          }
        }
        
        if (attempt == maxRetries - 1) {
          rethrow;
        }
      }
    }
    throw Exception("Operation failed after $maxRetries attempts");
  }
  
  Future<List<Listing>> getActiveListings() async {
    return await _executeWithRetry(() async {
      if (_getActiveListingIds == null || _getListing == null) {
        debugPrint("Optimized listing functions are not available in this contract's ABI.");
        return <Listing>[];
      }
      
      try {
        // 1. Fetch the list of all active listing IDs
        final idResult = await _web3client.call(
          contract: _deployedContract,
          function: _getActiveListingIds!,
          params: [],
        );
        
        final listingIds = (idResult[0] as List<dynamic>).cast<BigInt>();
        if (listingIds.isEmpty) {
          return <Listing>[];
        }
    
        log("Found ${listingIds.length} active listings. Fetching details in batches...");
    
        final List<Listing> allListings = [];
        const batchSize = 10; // Process 10 listings at a time
    
        // 2. Loop through the IDs in small batches
        for (int i = 0; i < listingIds.length; i += batchSize) {
          final end = (i + batchSize > listingIds.length) ? listingIds.length : i + batchSize;
          final batchIds = listingIds.sublist(i, end);
    
          // 3. Fetch details for just the current batch
          final batchFutures = batchIds.map((id) => _web3client.call(
            contract: _deployedContract,
            function: _getListing!,
            params: [id],
          )).toList();
    
          final listingsData = await Future.wait(batchFutures);
          
          // 4. Add the fetched batch to the main list
          allListings.addAll(listingsData.map((data) => Listing.fromSimplifiedTuple(data[0])));
          log("Fetched batch ${i ~/ batchSize + 1}, total listings loaded: ${allListings.length}");
        }
        
        return allListings;
    
      } catch (e) {
        debugPrint("Error getting active listings with optimized function: $e");
        return <Listing>[];
      }
    });
  }

  Future<List<Listing>> getCurrentUserListings() async {
    return await _executeWithRetry(() async {
      if (_getUserActiveListings == null || _getListing == null) {
        debugPrint("User listings functions are not available in this contract's ABI.");
        return <Listing>[];
      }
      
      try {
        final idResult = await _web3client.call(
          contract: _deployedContract,
          function: _getUserActiveListings!,
          params: [getUserAddress()],
        );
        
        final listingIds = (idResult[0] as List<dynamic>).cast<BigInt>();
        if (listingIds.isEmpty) {
          return <Listing>[];
        }

        final futures = listingIds.map((id) => _web3client.call(
          contract: _deployedContract,
          function: _getListing!,
          params: [id],
        ));
        
        final results = await Future.wait(futures);
        return results.map((data) => Listing.fromSimplifiedTuple(data[0])).toList();
      } catch (e) {
        debugPrint("Error getting user listings: $e");
        return <Listing>[];
      }
    });
  }

  Future<List<CreditTransaction>> getUserTransactionHistory() async {
    return await _executeWithRetry(() async {
      if (_getUserTransactionIds == null || _transactions == null) {
        return <CreditTransaction>[];
      }
      
      try {
        final idResult = await _web3client.call(
          contract: _deployedContract,
          function: _getUserTransactionIds!,
          params: [getUserAddress()],
        );
        
        final transactionIds = (idResult[0] as List<dynamic>).cast<BigInt>();
        if (transactionIds.isEmpty) return <CreditTransaction>[];
        
        final futures = transactionIds.map((id) => _web3client.call(
          contract: _deployedContract,
          function: _transactions!,
          params: [id],
        ));
        
        final results = await Future.wait(futures);
        return results.map((data) => CreditTransaction.fromTuple(data)).toList();
      } catch (e) {
        debugPrint("Error getting transaction history: $e");
        return <CreditTransaction>[];
      }
    });
  }

  // Check if user is registered
  Future<bool> isUserRegistered([EthereumAddress? address]) async {
    return await _executeWithRetry(() async {
      if (_isRegistered == null) {
        // If the contract doesn't have registration, assume all users are registered
        return true;
      }
      
      try {
        final result = await _web3client.call(
          contract: _deployedContract,
          function: _isRegistered!,
          params: [address ?? getUserAddress()],
        );
        return result.first as bool;
      } catch (e) {
        debugPrint("Error checking registration status: $e");
        // If checking fails, assume user needs registration
        return false;
      }
    });
  }

  // Register user in the contract
  Future<String> registerUser() async {
    return await _executeWithRetry(() async {
      if (_register == null) {
        throw Exception("User registration not supported by this contract version");
      }
      
      final registerTx = await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
          function: _register!,
          parameters: [],
        ),
        chainId: 1337,
      );
      await _waitForTransactionConfirmationWithRetry(registerTx);
      return registerTx;
    });
  }

  // Enhanced listCredits with registration check
  Future<String> listCredits(BigInt amount, BigInt price, String description) async {
    return await _executeWithRetry(() async {
      if (_listCredits == null || _isApprovedForAll == null || _setApprovalForAll == null) {
        throw Exception("Credit listing not supported by this contract version");
      }
      
      // Check if user is registered first
      final isRegistered = await isUserRegistered();
      if (!isRegistered) {
        debugPrint("User not registered, registering now...");
        try {
          final registerTx = await registerUser();
          debugPrint("User registered successfully: $registerTx");
        } catch (registerError) {
          throw Exception("Registration failed: ${registerError.toString()}. You need to be registered before listing credits.");
        }
      }
      
      final isApproved = await _web3client.call(
        contract: _deployedContract,
        function: _isApprovedForAll!,
        params: [getUserAddress(), getContractAddress()],
      ).then((result) => result.first as bool);

      if (!isApproved) {
        debugPrint("Contract not approved. Sending approval transaction...");
        final approvalTx = await _web3client.sendTransaction(
          _credentials,
          Transaction.callContract(
            contract: _deployedContract,
            function: _setApprovalForAll!,
            parameters: [getContractAddress(), true],
          ),
          chainId: 1337,
        );
        await _waitForTransactionConfirmationWithRetry(approvalTx);
      }

      final listTx = await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
          function: _listCredits!,
          parameters: [amount, price, description],
        ),
        chainId: 1337,
      );
      await _waitForTransactionConfirmationWithRetry(listTx);
      return listTx;
    });
  }

  Future<String> buyCredits(BigInt listingId, BigInt price) async {
    return await _executeWithRetry(() async {
      if (_buyCredits == null) {
        throw Exception("Credit buying not supported by this contract version");
      }
      final buyTx = await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
          function: _buyCredits!,
          parameters: [listingId],
          value: EtherAmount.inWei(price),
        ),
        chainId: 1337,
      );
      await _waitForTransactionConfirmationWithRetry(buyTx);
      return buyTx;
    });
  }

  Future<String> cancelListing(BigInt listingId) async {
    return await _executeWithRetry(() async {
      if (_cancelListing == null) {
        throw Exception("Listing cancellation not supported by this contract version");
      }
      final cancelTx = await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
          function: _cancelListing!,
          parameters: [listingId],
        ),
        chainId: 1337,
      );
      await _waitForTransactionConfirmationWithRetry(cancelTx);
      return cancelTx;
    });
  }

  Future<String> earnCreditForImage(String imagePath) async {
    return await _executeWithRetry(() async {
      if (_earnCreditForAction == null) {
        throw Exception("Credit earning not supported by this contract version");
      }
      final result = await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
          function: _earnCreditForAction!,
          parameters: [],
        ),
        chainId: 1337,
      );
      await _waitForTransactionConfirmationWithRetry(result);
      return result;
    });
  }

  Future<String> issueCredits(EthereumAddress to, BigInt amount) async {
    return await _executeWithRetry(() async {
      if (_issue == null) {
        throw Exception("Credit issuance not supported by this contract version");
      }
      final result = await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
          function: _issue!,
          parameters: [to, amount, Uint8List(0)],
        ),
        chainId: 1337,
      );
      await _waitForTransactionConfirmationWithRetry(result);
      return result;
    });
  }

  Future<BigInt> getCarbonCreditBalance(EthereumAddress owner) async {
    return await _executeWithRetry(() async {
      if (_getCarbonCreditBalance != null) {
        final result = await _web3client.call(
          contract: _deployedContract,
          function: _getCarbonCreditBalance!,
          params: [owner],
        );
        return result.first as BigInt;
      } else if (_balanceOf != null) {
        final result = await _web3client.call(
          contract: _deployedContract,
          function: _balanceOf!,
          params: [owner, BigInt.from(0)], // CARBON_CREDIT_ID = 0
        );
        return result.first as BigInt;
      }
      return BigInt.zero;
    });
  }

  Future<EtherAmount> getEthBalance([EthereumAddress? address]) async {
    return await _executeWithRetry(() async {
      return await _web3client.getBalance(address ?? getUserAddress());
    });
  }

  Future<Map<String, BigInt>> getMarketplaceStats() async {
    return await _executeWithRetry(() async {
      if (_getMarketplaceStats == null) {
        return {
          'activeListings': BigInt.zero,
          'totalTransactions': BigInt.zero,
          'totalCreditsTraded': BigInt.zero,
        };
      }
      
      try {
        final result = await _web3client.call(
          contract: _deployedContract,
          function: _getMarketplaceStats!,
          params: [],
        );
        
        return {
          'activeListings': result[0] as BigInt,
          'totalTransactions': result[1] as BigInt,
          'totalCreditsTraded': result[2] as BigInt,
        };
      } catch (e) {
        debugPrint("Error getting marketplace stats: $e");
        return {
          'activeListings': BigInt.zero,
          'totalTransactions': BigInt.zero,
          'totalCreditsTraded': BigInt.zero,
        };
      }
    });
  }
  
  Future<void> _waitForTransactionConfirmationWithRetry(String txHash, {
    Duration timeout = const Duration(seconds: 120),
    Duration pollInterval = const Duration(seconds: 5),
  }) async {
    final completer = Completer<void>();
    final stopwatch = Stopwatch()..start();

    Timer.periodic(pollInterval, (timer) async {
      try {
        final receipt = await _web3client.getTransactionReceipt(txHash);
        if (receipt != null) {
          if (receipt.status ?? false) {
            timer.cancel();
            completer.complete();
          } else {
            timer.cancel();
            completer.completeError(Exception("Transaction failed (status is false)"));
          }
        } else if (stopwatch.elapsed > timeout) {
          timer.cancel();
          completer.completeError(TimeoutException("Transaction confirmation timed out"));
        }
      } catch (e) {
        if (e.toString().contains('Connection closed') || 
            e.toString().contains('Connection refused')) {
          // Try to reconnect and continue polling
          try {
            await _reconnectIfNeeded();
          } catch (reconnectError) {
            timer.cancel();
            completer.completeError(reconnectError);
          }
        } else {
          timer.cancel();
          completer.completeError(e);
        }
      }
    });

    return completer.future;
  }

  void dispose() {
    _web3client.dispose();
    _httpClient.close();
  }
}