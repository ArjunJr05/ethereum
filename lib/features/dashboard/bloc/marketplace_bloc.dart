import 'dart:async';
import 'dart:developer';
import 'package:bloc/bloc.dart';
import 'package:ethereum/blockchain_service.dart';
import 'package:ethereum/listening.dart';
import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
part 'marketplace_event.dart';
part 'marketplace_state.dart';

class MarketplaceBloc extends Bloc<MarketplaceEvent, MarketplaceState> {
  final BlockchainService _blockchainService = BlockchainService();
  bool _isInitialized = false; 
  late EthereumAddress _userAddress;
  int _uploadedImagesCount = 0;

  MarketplaceBloc() : super(MarketplaceInitial()) {
    on<MarketplaceFetchDataEvent>(_onFetchData);
    on<MarketplaceIssueCreditEvent>(_onIssueCredit);
    on<MarketplaceListCreditEvent>(_onListCredit);
    on<MarketplaceBuyCreditEvent>(_onBuyCredit);
    on<MarketplaceCancelListingEvent>(_onCancelListing);
    on<MarketplaceEarnCreditFromImageEvent>(_onEarnCreditFromImage);
    on<MarketplaceFetchTransactionHistoryEvent>(_onFetchTransactionHistory);
    on<MarketplaceRegisterUserEvent>(_onRegisterUser);
  }

  String _getReadableError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('not registered')) {
      return 'Your account is not registered in the marketplace. Please register first to list credits.';
    } else if (errorStr.contains('connection closed') || 
        errorStr.contains('connection refused') ||
        errorStr.contains('failed to connect')) {
      return 'Cannot connect to blockchain network. Please check if Ganache is running and accessible.';
    } else if (errorStr.contains('timeout')) {
      return 'Operation timed out. The blockchain network might be slow or unreachable.';
    } else if (errorStr.contains('insufficient funds')) {
      return 'Insufficient funds to complete this transaction.';
    } else if (errorStr.contains('gas')) {
      return 'Transaction failed due to gas issues. Please try again.';
    } else if (errorStr.contains('revert')) {
      return 'Transaction was rejected by the smart contract. Please check your inputs.';
    } else {
      return 'Blockchain operation failed: ${error.toString()}';
    }
  }

  Future<void> _onRegisterUser(MarketplaceRegisterUserEvent event, Emitter<MarketplaceState> emit) async {
    try {
      emit(MarketplaceLoading());
      
      final txHash = await _blockchainService.registerUser();
      log('User registered successfully: $txHash');
      
      await Future.delayed(const Duration(seconds: 2));
      add(MarketplaceFetchDataEvent());
    } catch (e, stackTrace) {
      log("Error registering user: ${e.toString()}", error: e, stackTrace: stackTrace);
      emit(MarketplaceError(_getReadableError(e)));
    }
  }

  Future<void> _onFetchData(MarketplaceFetchDataEvent event, Emitter<MarketplaceState> emit) async {
    emit(MarketplaceLoading());
    try {
      if (!_isInitialized) {
        await _blockchainService.init();
        _userAddress = _blockchainService.getUserAddress();
        _isInitialized = true;
        log("Blockchain service initialized. User address: ${_userAddress.hex}");
      }

      final results = await Future.wait([
        _blockchainService.getActiveListings(),
        _blockchainService.getCarbonCreditBalance(_userAddress),
        _blockchainService.getEthBalance(_userAddress),
        _blockchainService.getMarketplaceStats(),
        _blockchainService.isUserRegistered(_userAddress),
      ]);

      final listings = results[0] as List<Listing>;
      final carbonCreditBalance = results[1] as BigInt;
      final ethBalance = results[2] as EtherAmount;
      final stats = results[3] as Map<String, BigInt>;
      final isRegistered = results[4] as bool;

      log("Data fetched: ${listings.length} listings, ${carbonCreditBalance} credits, ${ethBalance.getValueInUnit(EtherUnit.ether)} ETH, registered: $isRegistered");

      emit(MarketplaceLoaded(
        listings: listings, 
        carbonCreditBalance: carbonCreditBalance,
        ethBalance: ethBalance,
        userAddress: _userAddress,
        uploadedImagesCount: _uploadedImagesCount,
        marketplaceStats: stats,
        isUserRegistered: isRegistered,
      ));
    } catch (e, stackTrace) {
      log("Error fetching data: ${e.toString()}", error: e, stackTrace: stackTrace);
      emit(MarketplaceError(_getReadableError(e)));
    }
  }

  Future<void> _onFetchTransactionHistory(MarketplaceFetchTransactionHistoryEvent event, Emitter<MarketplaceState> emit) async {
    try {
      final transactions = await _blockchainService.getUserTransactionHistory();
      
      if (state is MarketplaceLoaded) {
        final currentState = state as MarketplaceLoaded;
        emit(currentState.copyWith(transactionHistory: transactions));
      }
    } catch (e, stackTrace) {
      log("Error fetching transaction history: ${e.toString()}", error: e, stackTrace: stackTrace);
      emit(MarketplaceError(_getReadableError(e)));
    }
  }
  
  Future<void> _onIssueCredit(MarketplaceIssueCreditEvent event, Emitter<MarketplaceState> emit) async {
    try {
      emit(MarketplaceLoading());
      final txHash = await _blockchainService.issueCredits(event.to, event.amount);
      log('Test credits issued successfully: $txHash');
      
      await Future.delayed(const Duration(seconds: 2));
      add(MarketplaceFetchDataEvent());
    } catch (e, stackTrace) {
      log("Error issuing test credit: ${e.toString()}", error: e, stackTrace: stackTrace);
      emit(MarketplaceError(_getReadableError(e)));
    }
  }

  Future<void> _onEarnCreditFromImage(MarketplaceEarnCreditFromImageEvent event, Emitter<MarketplaceState> emit) async {
    try {
      emit(MarketplaceLoading());
      
      _uploadedImagesCount++;
      log('Processing image upload #$_uploadedImagesCount');
      
      final txHash = await _blockchainService.earnCreditForImage(event.imagePath);
      log('Credit earned from image upload. Tx: $txHash');
      
      log('Waiting for transaction to be mined...');
      await Future.delayed(const Duration(seconds: 5));
      
      try {
        final newBalance = await _blockchainService.getCarbonCreditBalance(_userAddress);
        log('New carbon credit balance after image upload: $newBalance');
      } catch (e) {
        log('Could not verify new balance: $e');
      }
      
      emit(MarketplaceImageUploadSuccess(
        message: "Image uploaded successfully! You earned 1 credit. Total images uploaded: $_uploadedImagesCount",
        uploadedImagesCount: _uploadedImagesCount,
      ));
      
      await Future.delayed(const Duration(seconds: 1));
      add(MarketplaceFetchDataEvent());
    } catch (e, stackTrace) {
      log("Error earning credit from image: ${e.toString()}", error: e, stackTrace: stackTrace);
      _uploadedImagesCount--;
      emit(MarketplaceError(_getReadableError(e)));
    }
  }

  Future<void> _onListCredit(MarketplaceListCreditEvent event, Emitter<MarketplaceState> emit) async {
    try {
      emit(MarketplaceLoading());
      
      // Add pre-transaction validation
      final currentBalance = await _blockchainService.getCarbonCreditBalance(_userAddress);
      if (event.amount > currentBalance) {
        emit(MarketplaceError('Insufficient credits. You have $currentBalance credits.'));
        return;
      }
      
      final ethBalance = await _blockchainService.getEthBalance(_userAddress);
      if (ethBalance.getValueInUnit(EtherUnit.ether) < 0.001) {
        emit(MarketplaceError('Insufficient ETH for gas fees. Please add some ETH to your wallet.'));
        return;
      }
      
      log('Listing ${event.amount} credits for ${event.price} wei...');
      
      final txHash = await _blockchainService.listCredits(
        event.amount, 
        event.price, 
        event.description,
      );
      log('Credits listed successfully: $txHash');
      
      await Future.delayed(const Duration(seconds: 2));
      add(MarketplaceFetchDataEvent());
    } catch (e, stackTrace) {
      log("Error listing credit: ${e.toString()}", error: e, stackTrace: stackTrace);
      emit(MarketplaceError(_getReadableError(e)));
    }
  }

  Future<void> _onBuyCredit(MarketplaceBuyCreditEvent event, Emitter<MarketplaceState> emit) async {
    try {
      emit(MarketplaceLoading());
      
      // Add pre-transaction validation
      final ethBalance = await _blockchainService.getEthBalance(_userAddress);
      final requiredEth = EtherAmount.inWei(event.price);
      
      if (ethBalance.getInWei < requiredEth.getInWei) {
        emit(MarketplaceError('Insufficient ETH. You need ${requiredEth.getValueInUnit(EtherUnit.ether)} ETH but only have ${ethBalance.getValueInUnit(EtherUnit.ether)} ETH.'));
        return;
      }
      
      final txHash = await _blockchainService.buyCredits(event.listingId, event.price);
      log('Credits bought successfully: $txHash');
      
      await Future.delayed(const Duration(seconds: 2));
      add(MarketplaceFetchDataEvent());
    } catch (e, stackTrace) {
      log("Error buying credit: ${e.toString()}", error: e, stackTrace: stackTrace);
      emit(MarketplaceError(_getReadableError(e)));
    }
  }

  Future<void> _onCancelListing(MarketplaceCancelListingEvent event, Emitter<MarketplaceState> emit) async {
    try {
      emit(MarketplaceLoading());
      
      final txHash = await _blockchainService.cancelListing(event.listingId);
      log('Listing cancelled successfully: $txHash');
      
      await Future.delayed(const Duration(seconds: 2));
      add(MarketplaceFetchDataEvent());
    } catch (e, stackTrace) {
      log("Error cancelling listing: ${e.toString()}", error: e, stackTrace: stackTrace);
      emit(MarketplaceError(_getReadableError(e)));
    }
  }

  @override
  Future<void> close() {
    _blockchainService.dispose();
    return super.close();
  }
}