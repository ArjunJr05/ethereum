import 'package:ethereum/features/dashboard/bloc/marketplace_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web3dart/web3dart.dart';

class SellCreditPage extends StatefulWidget {
  const SellCreditPage({super.key});

  @override
  State<SellCreditPage> createState() => _SellCreditPageState();
}

class _SellCreditPageState extends State<SellCreditPage> {
  final _amountController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-refresh data when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketplaceBloc>().add(MarketplaceFetchDataEvent());
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an amount';
    }
    final amount = BigInt.tryParse(value);
    if (amount == null || amount <= BigInt.zero) {
      return 'Please enter a valid positive number';
    }
    
    final state = context.read<MarketplaceBloc>().state;
    if (state is MarketplaceLoaded) {
      if (amount > state.carbonCreditBalance) {
        return 'Insufficient credits. You have ${state.carbonCreditBalance}';
      }
    }
    
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a price';
    }
    
    final ethAmount = double.tryParse(value);
    if (ethAmount == null || ethAmount <= 0) {
      return 'Please enter a valid price in ETH';
    }
    
    return null;
  }

  BigInt _convertEthToWei(double ethAmount) {
    final weiAmount = (ethAmount * 1e18).round();
    return BigInt.from(weiAmount);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Future<void> _handleRegistration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Register for Marketplace'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You need to register your account to list credits for sale.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Registration is required to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• List credits for sale'),
            Text('• Cancel your listings'),
            Text('• Participate in the marketplace'),
            SizedBox(height: 16),
            Text(
              'This is a one-time process and requires a small gas fee.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Register Now'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      context.read<MarketplaceBloc>().add(MarketplaceRegisterUserEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Carbon Credits'),
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
            setState(() => _isLoading = false);
            _showSnackBar(state.message, isError: true);
          } else if (state is MarketplaceLoaded && _isLoading) {
            setState(() => _isLoading = false);
            _showSnackBar('Credits listed successfully!');
            // Clear the form after successful listing
            _amountController.clear();
            _priceController.clear();
            _descriptionController.clear();
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
                  Text('Loading marketplace data...'),
                ],
              ),
            );
          }

          if (state is! MarketplaceLoaded) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load marketplace data',
                    style: TextStyle(fontSize: 16),
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

          return RefreshIndicator(
            onRefresh: () async {
              context.read<MarketplaceBloc>().add(MarketplaceFetchDataEvent());
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User's current balance
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: state.isUserRegistered 
                                      ? Colors.green.shade700 
                                      : Colors.orange.shade700,
                                  child: Icon(
                                    state.isUserRegistered 
                                        ? Icons.verified_user 
                                        : Icons.warning,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Your Account',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: state.isUserRegistered 
                                                  ? Colors.green.shade200 
                                                  : Colors.orange.shade200,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              state.isUserRegistered ? 'Registered' : 'Not Registered',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: state.isUserRegistered 
                                                    ? Colors.green.shade800 
                                                    : Colors.orange.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${state.userAddress.hex.substring(0, 10)}...${state.userAddress.hex.substring(state.userAddress.hex.length - 8)}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            Row(
                              children: [
                                const Icon(Icons.eco, color: Colors.green, size: 32),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Available Credits',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      state.carbonCreditBalance.toString(),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'ETH Balance',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                      Text(
                                        '${state.ethBalance.getValueInUnit(EtherUnit.ether).toStringAsFixed(4)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Registration warning if not registered
                    if (!state.isUserRegistered)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.warning, color: Colors.red.shade600, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Registration Required',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You need to register your account in the marketplace before you can list credits for sale.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _handleRegistration,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Register Account'),
                            ),
                          ],
                        ),
                      ),

                    // Warning if no credits
                    if (state.carbonCreditBalance == BigInt.zero)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.info, color: Colors.orange.shade600, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'No Credits to Sell',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You need to earn credits first before you can sell them. Upload environmental action images or use the test credit button to get started.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                          ],
                        ),
                      ),
                    
                    // Amount input
                    TextFormField(
                      controller: _amountController,
                      enabled: state.canListCredits,
                      decoration: InputDecoration(
                        labelText: 'Amount of Credits to Sell',
                        hintText: 'Enter number of credits',
                        prefixIcon: const Icon(Icons.eco),
                        border: const OutlineInputBorder(),
                        suffixIcon: state.carbonCreditBalance > BigInt.zero
                            ? TextButton(
                                onPressed: () => _amountController.text = state.carbonCreditBalance.toString(),
                                child: const Text('Max'),
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validateAmount,
                    ),
                    const SizedBox(height: 16),
                    
                    // Price input (in ETH)
                    TextFormField(
                      controller: _priceController,
                      enabled: state.canListCredits,
                      decoration: const InputDecoration(
                        labelText: 'Total Price (ETH)',
                        hintText: 'Enter price in ETH (e.g., 0.001)',
                        prefixIcon: Icon(Icons.monetization_on),
                        border: OutlineInputBorder(),
                        helperText: 'Price in Ethereum (ETH)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      validator: _validatePrice,
                    ),
                    const SizedBox(height: 16),

                    // Description input
                    TextFormField(
                      controller: _descriptionController,
                      enabled: state.canListCredits,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Describe your carbon credits (e.g., source, certification)',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      maxLength: 200,
                    ),
                    const SizedBox(height: 24),
                    
                    // Price calculation
                    if (_amountController.text.isNotEmpty && _priceController.text.isNotEmpty)
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Price Breakdown:',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Builder(
                                builder: (context) {
                                  final amount = BigInt.tryParse(_amountController.text);
                                  final price = double.tryParse(_priceController.text);
                                  if (amount != null && price != null && amount > BigInt.zero) {
                                    final pricePerCredit = price / amount.toDouble();
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Price per credit: ${pricePerCredit.toStringAsFixed(6)} ETH',
                                          style: TextStyle(color: Colors.blue.shade700),
                                        ),
                                        Text(
                                          'Total earnings: ${price.toStringAsFixed(6)} ETH',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // List button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (state.canListCredits && !_isLoading)
                            ? Colors.green.shade700 
                            : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: (state.canListCredits && !_isLoading) ? _onListCredits : null,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(_getButtonIcon(state)),
                      label: Text(_getButtonText(state)),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Current user's listings
                    if (state.userListings.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Your Active Listings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.userListings.length,
                        itemBuilder: (context, index) {
                          final listing = state.userListings[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade600,
                                child: const Icon(Icons.sell, color: Colors.white),
                              ),
                              title: Text('${listing.amount} Credits'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Price: ${listing.formattedPrice}'),
                                  Text('Listed: ${listing.timeSinceListed}'),
                                  if (listing.description.isNotEmpty)
                                    Text(
                                      listing.description,
                                      style: const TextStyle(fontStyle: FontStyle.italic),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              trailing: TextButton(
                                onPressed: () => _showCancelConfirmation(listing),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // Info card
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                const Text(
                                  'How it works',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Register your account (one-time setup)\n'
                              '• Set your price and list credits for sale\n'
                              '• Other users can purchase your credits with ETH\n'
                              '• Your credits are locked until sold or cancelled\n'
                              '• You receive ETH directly to your wallet when sold\n'
                              '• Small gas fees apply for blockchain transactions',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getButtonIcon(MarketplaceLoaded state) {
    if (!state.isUserRegistered) {
      return Icons.person_add;
    } else if (state.carbonCreditBalance <= BigInt.zero) {
      return Icons.eco_outlined;
    } else {
      return Icons.add_shopping_cart;
    }
  }

  String _getButtonText(MarketplaceLoaded state) {
    if (_isLoading) {
      return 'Processing...';
    } else if (!state.isUserRegistered) {
      return 'Register to Sell Credits';
    } else if (state.carbonCreditBalance <= BigInt.zero) {
      return 'No Credits Available';
    } else {
      return 'List for Sale';
    }
  }

  void _onListCredits() async {
    final state = context.read<MarketplaceBloc>().state;
    if (state is! MarketplaceLoaded) return;

    // Check if user is registered
    if (!state.isUserRegistered) {
      _handleRegistration();
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    
    final amount = BigInt.tryParse(_amountController.text);
    final priceEth = double.tryParse(_priceController.text);
    
    if (amount != null && priceEth != null) {
      setState(() => _isLoading = true);
      
      final priceWei = _convertEthToWei(priceEth);
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm Listing'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Credits to sell: $amount'),
              Text('Total price: $priceEth ETH'),
              Text('Price per credit: ${(priceEth / amount.toDouble()).toStringAsFixed(6)} ETH'),
              if (_descriptionController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Description: ${_descriptionController.text}'),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  'Your credits will be locked until the listing is sold or cancelled. You can cancel anytime from your listings.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Listing'),
            ),
          ],
        ),
      );
      
      if (confirmed == true) {
        context.read<MarketplaceBloc>().add(
          MarketplaceListCreditEvent(
            amount: amount, 
            price: priceWei,
            description: _descriptionController.text,
          ),
        );
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCancelConfirmation(listing) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Listing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this listing?'),
            const SizedBox(height: 8),
            Text('Credits: ${listing.amount}'),
            Text('Price: ${listing.formattedPrice}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Your credits will be returned to your available balance.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep Listing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<MarketplaceBloc>().add(
                MarketplaceCancelListingEvent(listingId: listing.listingId),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Listing'),
          ),
        ],
      ),
    );
  }
}