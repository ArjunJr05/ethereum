import 'package:web3dart/web3dart.dart';

class Listing {
  final BigInt listingId;
  final EthereumAddress seller;
  final BigInt amount;
  final BigInt price;
  final BigInt pricePerCredit;
  final bool active;
  final DateTime createdAt;
  final String description;

  Listing({
    required this.listingId,
    required this.seller,
    required this.amount,
    required this.price,
    required this.pricePerCredit,
    required this.active,
    required this.createdAt,
    required this.description,
  });

  // Factory constructor for the simplified smart contract
  // The tuple order from Solidity is: listingId, seller, amount, price, pricePerCredit, createdAt, active, description
  factory Listing.fromSimplifiedTuple(List<dynamic> tuple) {
    return Listing(
      listingId: tuple[0] as BigInt,
      seller: tuple[1] as EthereumAddress,
      amount: tuple[2] as BigInt,
      price: tuple[3] as BigInt,
      pricePerCredit: tuple[4] as BigInt,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (tuple[5] as BigInt).toInt() * 1000,
      ),
      active: tuple[6] as bool,
      description: tuple[7] as String,
    );
  }

  // Keep the old method for backward compatibility if needed
  factory Listing.fromTuple(List<dynamic> tuple) {
    return Listing.fromSimplifiedTuple(tuple);
  }

  // Helper method to format price in ETH
  String get formattedPrice {
    final etherAmount = EtherAmount.inWei(price);
    return '${etherAmount.getValueInUnit(EtherUnit.ether).toStringAsFixed(6)} ETH';
  }

  // Helper method to format price per credit in ETH
  String get formattedPricePerCredit {
    final etherAmount = EtherAmount.inWei(pricePerCredit);
    return '${etherAmount.getValueInUnit(EtherUnit.ether).toStringAsFixed(8)} ETH';
  }

  // Helper method to get time since listing
  String get timeSinceListed {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  // Helper method to get seller address formatted
  String get formattedSellerAddress {
    final address = seller.hex;
    return '${address.substring(0, 8)}...${address.substring(address.length - 6)}';
  }
}