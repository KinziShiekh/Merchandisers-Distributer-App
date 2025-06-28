import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/get_navigation.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:merchandiser_app/auth/loginscreen.dart';
import 'package:merchandiser_app/auth/signUp.dart';
import 'package:merchandiser_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:merchandiser_app/pages/homepage.dart';

import 'package:merchandiser_app/pages/profile/profiel_screen.dart';
import 'package:merchandiser_app/pages/splashscreen.dart';
import 'package:merchandiser_app/provider/auth_provider.dart';
import 'package:merchandiser_app/provider/splash_provider.dart';
import 'package:merchandiser_app/provider/user_provider.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Unlimited cache size
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => SplashProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        // ChangeNotifierProvider(create: (context) => MapProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MerchandiserApp',
      theme: ThemeData(
        useMaterial3: true,
      ),
      initialRoute: '/', // Define initial route
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => const SignInScreen(),
        '/home': (context) => HomeScreen(),
        '/profile': (context) => ProfileScreen(),
        '/signup': (context) => SignUpScreen(),
        '/signin': (context) => SignInScreen(),
      },
    );
  }
}
