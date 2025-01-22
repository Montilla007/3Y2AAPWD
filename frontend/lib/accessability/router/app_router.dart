import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/authScreens/login_screen.dart';
import 'package:frontend/accessability/presentation/screens/authScreens/signup_screen.dart';
import 'package:frontend/accessability/presentation/screens/authScreens/onboarding_screen.dart';
import 'package:frontend/accessability/presentation/screens/chat_system/inbox_screen.dart';
import 'package:frontend/accessability/presentation/screens/gpsScreen/gps.dart';
import 'package:frontend/accessability/presentation/screens/settings/settings_screen.dart';
import 'package:frontend/accessability/presentation/screens/splash_screen.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/account_screen.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/biometric_screen.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/chat_with_support_screen.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/preferences_screen.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/privacy_security_screen.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/about_screen.dart';
import 'package:frontend/accessability/presentation/widgets/chatWidgets/chat_convo_screen.dart';

class AppRouter {
  Route<dynamic>? onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case '/':
        return _buildRoute(const Splashscreen(), clearStack: true);
      case SignupScreen.routeName:
        return _buildRoute(const SignupScreen());
      case '/login':
        return _buildRoute(const LoginScreen(), clearStack: true);
      case '/onboarding':
        return _buildRoute(const OnboardingScreen(), clearStack: true);
      case '/homescreen':
        return _buildRoute(const GpsScreen(), clearStack: true);
      case '/account':
        return _buildRoute(const AccountScreen());
      case '/preferences':
        return _buildRoute(const PreferencesScreen());
      case '/privacy':
        return _buildRoute(const PrivacySecurity());
      case '/chatsupport':
        return _buildRoute(const ChatAndSupport());
      case '/biometric':
        return _buildRoute(const BiometricLogin());
      case '/settings':
        return _buildRoute(const SettingsScreen(), clearStack: true);
      case '/inbox':
        return _buildRoute(const Inbox());
      case '/about':
        return _buildRoute(const AboutScreen());
      case '/chatconvo':
        final args = routeSettings.arguments as Map<String, dynamic>;
        final receiverEmail = args['receiverEmail'];
        final receiverID = args['receiverID'];
        return _buildRoute(ChatConvoScreen(receiverEmail: receiverEmail, receiverID: receiverID,));
    }
    return null; // Handle unknown routes
  }

  MaterialPageRoute _buildRoute(Widget child, {bool clearStack = false}) {
    return MaterialPageRoute(
      builder: (context) {
        if (clearStack) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => child),
              (route) => false,
            );
          });
          return const SizedBox.shrink();
        }
        return child;
      },
    );
  }
}
