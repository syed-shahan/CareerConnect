import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/opportunities_screen.dart';
import 'screens/opportunity_detail_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/edit_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(CareerConnectApp());
}

// Decides the very first screen shown at app launch, based on whether
// Firebase still has a valid, persisted session. This is what keeps the
// user logged in across app restarts until they explicitly log out.
class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          return OpportunitiesScreen();
        }

        return LoginScreen();
      },
    );
  }
}

class CareerConnectApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),

      // START POINT — checks if the user is already logged in
      home: AuthGate(),

      // ALL ROUTES — NO UI CHANGES
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/home': (context) => OpportunitiesScreen(),
        '/ai': (context) => AIChatScreen(),
        '/profile': (context) => ProfileScreen(),
        '/edit_profile': (context) => EditProfileScreen(),
      },

      // DETAIL SCREEN WITH ARGUMENTS
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          return MaterialPageRoute(
            builder: (context) => OpportunityDetailScreen(),
            settings: settings,
          );
        }

        return null;
      },
    );
  }
}