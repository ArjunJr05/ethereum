import 'package:ethereum/features/dashboard/bloc/marketplace_bloc.dart';
import 'package:ethereum/listening.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web3dart/web3dart.dart';

class BuyCreditPage extends StatefulWidget {
  const BuyCreditPage({super.key});

  @override
  State<BuyCreditPage> createState() => _BuyCreditPageState();
}

class _BuyCreditPageState extends State<BuyCreditPage> {
  String _sortBy = 'price_low'; // price_low, price_high, amount_high, amount_low, recent
  String _filterBy = 'all'; // all, others_only, registered_only

  @override
  void initState() {
    super.initState();
    // Fetch fresh data when entering the page
    context.read<MarketplaceBloc>().add(MarketplaceFetchDataEvent());
  }

  List<Listing> _filterAndSortListings(List<Listing> listings, EthereumAddress userAddress) {
    var filteredListings = List<Listing>.from(listings);

    // Apply filters
    switch (_filterBy) {
      case 'others_only':
        filteredListings = filteredListings.where((listing) => listing.seller != userAddress).toList();
        break;
      case 'my_listings':
        filteredListings = filteredListings.where((listing) => listing.seller == userAddress).toList();
        break;
      case 'all':
      default:
        // Show all listings
        break;
    }

    // Sort listings
    switch (_sortBy) {
      case 'price_low':
        filteredListings.sort((a, b) => a.pricePerCredit.compareTo(b.pricePerCredit));
        break;
      case 'price_high':
        filteredListings.sort((a, b) => b.pricePerCredit.compareTo(a.pricePerCredit));
        break;
      case 'amount_high':
        filteredListings.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'amount_low':
        filteredListings.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case 'recent':
        filteredListings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return filteredListings;
  }

  void _showPurchaseConfirmation(Listing listing, MarketplaceLoaded state) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Purchase'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Seller Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Seller Information',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Address: ${listing.seller.hex.substring(0, 12)}...${listing.seller.hex.substring(listing.seller.hex.length - 8)}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    Text('Company/Entity: ${_getSellerName(listing.seller)}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Credit Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.eco, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Credit Details',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Credits: ${listing.amount}'),
                    Text('Total Price: ${listing.formattedPrice}'),
                    Text('Price per Credit: ${listing.formattedPricePerCredit}'),
                    Text('Listed: ${listing.timeSinceListed}'),
                  ],
                ),
              ),

              if (listing.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(listing.description),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Transaction Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transaction Summary:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Your ETH Balance: ${state.ethBalance.getValueInUnit(EtherUnit.ether).toStringAsFixed(6)} ETH'),
                    Text('Required ETH: ${listing.formattedPrice}'),
                    Text('Your Credits After: ${state.carbonCreditBalance + listing.amount}'),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  'This transaction will deduct ETH from your wallet and add carbon credits to your balance. This action cannot be undone.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<MarketplaceBloc>().add(
                MarketplaceBuyCreditEvent(
                  listingId: listing.listingId,
                  price: listing.price,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Purchase'),
          ),
        ],
      ),
    );
  }

  String _getSellerName(EthereumAddress seller) {
    // This is a simple mapping - in a real app, you might have a registry of company names
    final sellerHex = seller.hex.toLowerCase();
    
    // Generate a company name based on address for demo purposes
    final addressSuffix = sellerHex.substring(sellerHex.length - 4);
    final companyNames = [
      'EcoTech Solutions',
      'Green Energy Corp',
      'Carbon Zero Ltd',
      'Sustainable Systems',
      'Clean Air Industries',
      'Renewable Resources',
      'Climate Action Co',
      'Earth First LLC',
    ];
    
    final index = int.parse(addressSuffix, radix: 16) % companyNames.length;
    return companyNames[index];
  }

  Widget _buildListingCard(Listing listing, MarketplaceLoaded state) {
    final bool isOwnListing = listing.seller == state.userAddress;
    final bool hasEnoughETH = state.ethBalance.getInWei >= listing.price;
    final String sellerName = _getSellerName(listing.seller);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company/Seller header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOwnListing ? Colors.orange.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isOwnListing ? Colors.orange.shade200 : Colors.blue.shade200,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isOwnListing ? Colors.orange.shade600 : Colors.blue.shade600,
                    radius: 24,
                    child: Icon(
                      isOwnListing ? Icons.person : Icons.business,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOwnListing ? 'Your Listing' : sellerName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isOwnListing ? Colors.orange.shade800 : Colors.blue.shade800,
                          ),
                        ),
                        Text(
                          '${listing.seller.hex.substring(0, 10)}...${listing.seller.hex.substring(listing.seller.hex.length - 8)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (!isOwnListing)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Verified Seller',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      listing.timeSinceListed,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Credits and price info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.eco, color: Colors.green.shade600, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${listing.amount} Credits',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: ${listing.formattedPrice}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                      if (listing.amount > BigInt.from(10))
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Bulk Sale',
                            style: TextStyle(
                              color: Colors.purple.shade800,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      listing.formattedPricePerCredit,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    Text(
                      'per credit',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Description if available
            if (listing.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Description',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listing.description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Buy button or status
            SizedBox(
              width: double.infinity,
              child: isOwnListing
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'This is your listing',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: hasEnoughETH ? () => _showPurchaseConfirmation(listing, state) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasEnoughETH
                            ? Colors.green.shade600
                            : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(hasEnoughETH ? Icons.shopping_cart : Icons.account_balance_wallet),
                      label: Text(
                        hasEnoughETH
                            ? 'Buy from $sellerName'
                            : 'Insufficient ETH Balance',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Carbon Credits'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<MarketplaceBloc>().add(MarketplaceFetchDataEvent());
            },
          ),
        ],
      ),
      body: BlocConsumer<MarketplaceBloc, MarketplaceState>(
        listener: (context, state) {
          if (state is MarketplaceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is MarketplaceLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text('Loading available credits...'),
                ],
              ),
            );
          }

          if (state is! MarketplaceLoaded) {
            return const Center(
              child: Text('Unable to load marketplace data'),
            );
          }

          final sortedListings = _filterAndSortListings(state.listings, state.userAddress);

          return Column(
            children: [
              // Filters and Sort Options
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Filter Options
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _filterBy,
                            decoration: const InputDecoration(
                              labelText: 'Filter',
                              prefixIcon: Icon(Icons.filter_list),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Listings')),
                              DropdownMenuItem(value: 'others_only', child: Text('Other Companies')),
                              DropdownMenuItem(value: 'my_listings', child: Text('My Listings')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _filterBy = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Sort Options
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _sortBy,
                            decoration: const InputDecoration(
                              labelText: 'Sort by',
                              prefixIcon: Icon(Icons.sort),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'price_low', child: Text('Price: Low to High')),
                              DropdownMenuItem(value: 'price_high', child: Text('Price: High to Low')),
                              DropdownMenuItem(value: 'amount_high', child: Text('Amount: Most Credits')),
                              DropdownMenuItem(value: 'amount_low', child: Text('Amount: Least Credits')),
                              DropdownMenuItem(value: 'recent', child: Text('Recently Listed')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _sortBy = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    // Account Summary
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Your Balance: ${state.ethBalance.getValueInUnit(EtherUnit.ether).toStringAsFixed(4)} ETH | ${state.carbonCreditBalance} Credits',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Statistics
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${sortedListings.length}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const Text('Available', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${sortedListings.where((l) => l.seller != state.userAddress).length}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const Text('Companies', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${state.totalTransactions}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const Text('Transactions', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${state.totalCreditsTraded}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const Text('Credits Traded', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Listings
              Expanded(
                child: sortedListings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.eco_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _getEmptyStateMessage(),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getEmptyStateSubtitle(),
                              style: TextStyle(
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _filterBy = 'all';
                                  _sortBy = 'recent';
                                });
                                context.read<MarketplaceBloc>().add(MarketplaceFetchDataEvent());
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh Listings'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          context.read<MarketplaceBloc>().add(MarketplaceFetchDataEvent());
                        },
                        child: ListView.builder(
                          itemCount: sortedListings.length,
                          itemBuilder: (context, index) {
                            final listing = sortedListings[index];
                            return _buildListingCard(listing, state);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getEmptyStateMessage() {
    switch (_filterBy) {
      case 'others_only':
        return 'No credits available from other companies';
      case 'my_listings':
        return 'You have no active listings';
      default:
        return 'No credits available for purchase';
    }
  }

  String _getEmptyStateSubtitle() {
    switch (_filterBy) {
      case 'others_only':
        return 'Try changing the filter or check back later for new listings from other companies';
      case 'my_listings':
        return 'Go to the Sell page to create your first listing';
      default:
        return 'Check back later or earn some credits yourself!';
    }
  }
}