import 'dart:io';
import 'package:ethereum/features/dashboard/bloc/marketplace_bloc.dart';
import 'package:ethereum/features/sell/buying.dart';
import 'package:ethereum/features/sell/sell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web3dart/web3dart.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        context.read<MarketplaceBloc>().add(
              MarketplaceEarnCreditFromImageEvent(imagePath: image.path),
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageUploadDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<MarketplaceBloc>(),
        child: AlertDialog(
          title: const Text('Upload Environmental Action'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.eco, size: 48, color: Colors.green),
              SizedBox(height: 16),
              Text(
                'Upload an image of your environmental action to earn 1 carbon credit!',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Examples: Tree planting, recycling, using renewable energy, etc.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _pickAndUploadImage();
              },
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Choose Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarketplaceStats(MarketplaceLoaded state) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Marketplace Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Active Listings', '${state.activeListingsCount}', Icons.storefront),
            _buildStatRow('Total Transactions', '${state.totalTransactions}', Icons.swap_horiz),
            _buildStatRow('Credits Traded', '${state.totalCreditsTraded}', Icons.eco),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade600),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carbon Credit Marketplace'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              final state = context.read<MarketplaceBloc>().state;
              if (state is MarketplaceLoaded) {
                _showMarketplaceStats(state);
              }
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
          } else if (state is MarketplaceImageUploadSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is MarketplaceInitial || state is MarketplaceLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text('Loading marketplace data...'),
                ],
              ),
            );
          }

          if (state is MarketplaceError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${state.message}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<MarketplaceBloc>().add(MarketplaceFetchDataEvent());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          BigInt carbonBalance = BigInt.zero;
          int uploadedImagesCount = 0;
          String userAddress = '';
          List<dynamic> listings = [];
          EtherAmount ethBalance = EtherAmount.zero();

          if (state is MarketplaceLoaded) {
            carbonBalance = state.carbonCreditBalance;
            uploadedImagesCount = state.uploadedImagesCount;
            userAddress = state.userAddress.hex;
            listings = state.listings;
            ethBalance = state.ethBalance;
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<MarketplaceBloc>().add(MarketplaceFetchDataEvent());
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account Information Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Account',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (userAddress.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.account_circle, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Address: ${userAddress.substring(0, 8)}...${userAddress.substring(userAddress.length - 6)}',
                                    style: const TextStyle(fontFamily: 'monospace'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],

                          Row(
                            children: [
                              const Icon(Icons.eco, color: Colors.green),
                              const SizedBox(width: 8),
                              Text('Carbon Credits: $carbonBalance'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text('ETH Balance: ${ethBalance.getValueInUnit(EtherUnit.ether).toStringAsFixed(4)} ETH'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.image, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text('Images Uploaded: $uploadedImagesCount'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Main Action Buttons
                  Row(
                    children: [
                      // Upload Image Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showImageUploadDialog,
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Earn Credits'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Buy Credits Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<MarketplaceBloc>(),
                                  child: const BuyCreditPage(),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.shopping_cart),
                          label: const Text('Buy Credits'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // Sell Credits Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<MarketplaceBloc>(),
                                  child: const SellCreditPage(),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.sell),
                          label: const Text('Sell Credits'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // View Stats Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (state is MarketplaceLoaded) {
                              _showMarketplaceStats(state);
                            }
                          },
                          icon: const Icon(Icons.analytics),
                          label: const Text('View Stats'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Test Credit Issuance Button
                  if (state is MarketplaceLoaded)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.read<MarketplaceBloc>().add(
                                MarketplaceIssueCreditEvent(
                                  to: state.userAddress,
                                  amount: BigInt.from(5),
                                ),
                              );
                        },
                        icon: const Icon(Icons.bug_report),
                        label: const Text('Test Credit Issuance (+5 Credits)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Marketplace Statistics Summary
                  if (state is MarketplaceLoaded)
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Active Listings',
                            '${state.activeListingsCount}',
                            Icons.storefront,
                            Colors.green.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Total Transactions',
                            '${state.totalTransactions}',
                            Icons.swap_horiz,
                            Colors.blue.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Credits Traded',
                            '${state.totalCreditsTraded}',
                            Icons.eco,
                            Colors.purple.shade600,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Recent Marketplace Activity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Listings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          context.read<MarketplaceBloc>().add(MarketplaceFetchDataEvent());
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Available Listings Preview
                  if (listings.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'No active listings available',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BlocProvider.value(
                                        value: context.read<MarketplaceBloc>(),
                                        child: const SellCreditPage(),
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Be the first to list credits!'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: listings.length > 5 ? 5 : listings.length, // Show max 5
                          itemBuilder: (context, index) {
                            final listing = listings[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.shade600,
                                  child: const Icon(Icons.eco, color: Colors.white),
                                ),
                                title: Text('${listing.amount} Credits'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('From: ${listing.seller.hex.substring(0, 8)}...${listing.seller.hex.substring(listing.seller.hex.length - 6)}'),
                                    Text('Price: ${listing.formattedPrice ?? 'N/A'}'),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BlocProvider.value(
                                        value: context.read<MarketplaceBloc>(),
                                        child: const BuyCreditPage(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),

                        if (listings.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BlocProvider.value(
                                        value: context.read<MarketplaceBloc>(),
                                        child: const BuyCreditPage(),
                                      ),
                                    ),
                                  );
                                },
                                child: Text('View all ${listings.length} listings'),
                              ),
                            ),
                          ),
                      ],
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}