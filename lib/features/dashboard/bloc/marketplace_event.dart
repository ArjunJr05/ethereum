part of 'marketplace_bloc.dart';

@immutable
sealed class MarketplaceEvent {}

// Core events
class MarketplaceFetchDataEvent extends MarketplaceEvent {}

class MarketplaceIssueCreditEvent extends MarketplaceEvent {
  final EthereumAddress to;
  final BigInt amount;
  
  MarketplaceIssueCreditEvent({
    required this.to, 
    required this.amount,
  });
}

class MarketplaceEarnCreditFromImageEvent extends MarketplaceEvent {
  final String imagePath;
  
  MarketplaceEarnCreditFromImageEvent({
    required this.imagePath,
  });
}

class MarketplaceListCreditEvent extends MarketplaceEvent {
  final BigInt amount;
  final BigInt price;
  final String description;
  
  MarketplaceListCreditEvent({
    required this.amount,
    required this.price,
    this.description = '',
  });
}

class MarketplaceBuyCreditEvent extends MarketplaceEvent {
  final BigInt listingId;
  final BigInt price;
  
  MarketplaceBuyCreditEvent({
    required this.listingId, 
    required this.price,
  });
}

class MarketplaceCancelListingEvent extends MarketplaceEvent {
  final BigInt listingId;
  
  MarketplaceCancelListingEvent({
    required this.listingId,
  });
}

class MarketplaceFetchTransactionHistoryEvent extends MarketplaceEvent {}

// Added registration event
class MarketplaceRegisterUserEvent extends MarketplaceEvent {}