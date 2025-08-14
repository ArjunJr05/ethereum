part of 'marketplace_bloc.dart';

@immutable
sealed class MarketplaceState {}

final class MarketplaceInitial extends MarketplaceState {}

class MarketplaceLoading extends MarketplaceState {}

class MarketplaceError extends MarketplaceState {
  final String message;
  MarketplaceError(this.message);
}

class MarketplaceLoaded extends MarketplaceState {
  final List<Listing> listings;
  final BigInt carbonCreditBalance;
  final EtherAmount ethBalance;
  final EthereumAddress userAddress;
  final int uploadedImagesCount;
  final Map<String, BigInt> marketplaceStats;
  final List<CreditTransaction>? transactionHistory;
  final bool isUserRegistered; // Added registration status

  MarketplaceLoaded({
    required this.listings,
    required this.carbonCreditBalance,
    required this.ethBalance,
    required this.userAddress,
    required this.uploadedImagesCount,
    this.marketplaceStats = const {},
    this.transactionHistory,
    this.isUserRegistered = false, // Added with default value
  });

  MarketplaceLoaded copyWith({
    List<Listing>? listings,
    BigInt? carbonCreditBalance,
    EtherAmount? ethBalance,
    EthereumAddress? userAddress,
    int? uploadedImagesCount,
    Map<String, BigInt>? marketplaceStats,
    List<CreditTransaction>? transactionHistory,
    bool? isUserRegistered, // Added to copyWith
  }) {
    return MarketplaceLoaded(
      listings: listings ?? this.listings,
      carbonCreditBalance: carbonCreditBalance ?? this.carbonCreditBalance,
      ethBalance: ethBalance ?? this.ethBalance,
      userAddress: userAddress ?? this.userAddress,
      uploadedImagesCount: uploadedImagesCount ?? this.uploadedImagesCount,
      marketplaceStats: marketplaceStats ?? this.marketplaceStats,
      transactionHistory: transactionHistory ?? this.transactionHistory,
      isUserRegistered: isUserRegistered ?? this.isUserRegistered, // Added to copyWith
    );
  }

  // Get listings available for purchase (excluding user's own)
  List<Listing> get availableListings => 
      listings.where((listing) => listing.seller != userAddress).toList();
  
  // Get user's own listings
  List<Listing> get userListings => 
      listings.where((listing) => listing.seller == userAddress).toList();
  
  // Get marketplace statistics with defaults
  BigInt get activeListingsCount => marketplaceStats['activeListings'] ?? BigInt.zero;
  BigInt get totalTransactions => marketplaceStats['totalTransactions'] ?? BigInt.zero;
  BigInt get totalCreditsTraded => marketplaceStats['totalCreditsTraded'] ?? BigInt.zero;

  // Check if user can list credits
  bool get canListCredits => isUserRegistered && carbonCreditBalance > BigInt.zero;
}

class MarketplaceImageUploadSuccess extends MarketplaceState {
  final String message;
  final int uploadedImagesCount;
  
  MarketplaceImageUploadSuccess({
    required this.message,
    required this.uploadedImagesCount,
  });
}