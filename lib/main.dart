import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/auth_service.dart';
import 'services/temple_service.dart';
import 'services/cart_service.dart';
import 'services/wallet_service.dart';
import 'services/address_service.dart';
import 'utils/app_logger.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  // Catch all synchronous Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logE('FlutterError', details.exception);
  };

  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => CartService()),
          ProxyProvider<AuthService, TempleService>(
            update: (_, auth, previous) => TempleService(auth.apiClient),
          ),
          ProxyProvider<AuthService, WalletService>(
            update: (_, auth, previous) => WalletService(auth.apiClient),
          ),
          ChangeNotifierProxyProvider<AuthService, AddressService>(
            create: (context) => AddressService(context.read<AuthService>().apiClient),
            update: (_, auth, previous) => previous ?? AddressService(auth.apiClient),
          ),
        ],
        child: MaterialApp(
          title: 'Temple',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0D0B14),
            fontFamily: 'Segoe UI',
          ),
          navigatorKey: navigatorKey,
          home: const TempleApp(),
        ),
      ),
    );
  }, (error, stackTrace) {
    logE('Uncaught error', error);
    logD('$stackTrace');
  });
}
