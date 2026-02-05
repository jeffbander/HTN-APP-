import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sourceManager.dart';
import 'navigationManager.dart';

class ContentView extends StatelessWidget {
  const ContentView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NavigationManager>(
      create: (context) {
        final sourceManager = Provider.of<SourceManager>(context, listen: false);
        return NavigationManager(sourceManager); // Pass the SourceManager instance
      },
      child: Consumer<NavigationManager>(
        builder: (context, navigationManager, _) {
              return MaterialApp(
            // navigatorKey: navigationManager.navigatorKey,
            home: const Scaffold(), // Initial container; NavigationManager handles navigation.
          );
        }
      ),
    );
  }
}
