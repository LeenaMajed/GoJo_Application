import 'package:flutter/material.dart';
import 'package:gojo/screens/sign_in_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme.dart';
import 'services/app_state.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(), // streams drive all data — no caching needed
      child: const GojoApp(),
    ),
  );
}

class GojoApp extends StatelessWidget {
  const GojoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoJo — Explore Jordan',
      debugShowCheckedModeBanner: false,
      theme: gojoLightTheme(),
      darkTheme: gojoDarkTheme(),
      themeMode: context.watch<AppState>().themeMode,
      home: const SignInScreen(),
    );
  }
}