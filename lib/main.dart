import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart'




;
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';

import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/courier_dashboard_screen.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  
  try {
    await Firebase.initializeApp();
    await FcmService().init();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _wasAuthenticated = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (context, auth, theme, _) {
        // Deteksi logout secara terpusat untuk membersihkan stack navigasi
        if (_wasAuthenticated && !auth.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigatorKey.currentState?.popUntil((route) => route.isFirst);
          });
        }
        _wasAuthenticated = auth.isAuthenticated;


        // Halaman yang ditampilkan berdasarkan status auth
        Widget homeWidget;
        if (auth.isCheckingAuth) {
          homeWidget = Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: theme.primaryColor),
            ),
          );
        } else if (auth.isAuthenticated) {
          // Navigasi Berdasarkan Role
          if (auth.user?['role'] == 'kurir') {
            homeWidget = const CourierDashboardScreen();
          } else {
            homeWidget = DashboardScreen();
          }
        } else {
          homeWidget = const LoginScreen();
        }

        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Dimsum POS',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: theme.primaryColor),
            primaryColor: theme.primaryColor,
            textTheme: GoogleFonts.outfitTextTheme(),
            useMaterial3: true,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              )
            )
          ),
          home: homeWidget,
        );
      },
    );
  }
}



