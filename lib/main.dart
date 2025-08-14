import 'package:ethereum/features/dashboard/ui/marketplace_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ethereum/features/dashboard/bloc/marketplace_bloc.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carbon Credit Marketplace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: BlocProvider(
        create: (context) => MarketplaceBloc()..add(MarketplaceFetchDataEvent()),
        child: const MarketplacePage(),
      ),
    );
  }
}

// Alternative if you have multiple pages that need the bloc:
class MyAppWithPersistentBloc extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MarketplaceBloc()..add(MarketplaceFetchDataEvent()),
      child: MaterialApp(
        title: 'Carbon Credit Marketplace',
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MarketplacePage(),
      ),
    );
  }
}