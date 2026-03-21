import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart' hide AuthProvider;
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart' hide AuthProvider;
import 'package:amplify_api/amplify_api.dart';
import 'amplifyconfiguration.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/ble_provider.dart';
import 'providers/sos_provider.dart';
import 'providers/esp32_debug_provider.dart';
import 'providers/modes_provider.dart';
import 'screens/splash_screen.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure Amplify
  await _configureAmplify();

  // Initialize background service
  await initializeBackgroundService();

  runApp(const SurakshaPlusApp());
}

Future<void> _configureAmplify() async {
  try {
    final authPlugin = AmplifyAuthCognito();
    final apiPlugin = AmplifyAPI();

    await Amplify.addPlugins([authPlugin, apiPlugin]);
    await Amplify.configure(amplifyconfig);

    safePrint('[Amplify] Configured successfully');
  } on AmplifyAlreadyConfiguredException {
    safePrint('[Amplify] Already configured — skipping');
  } on Exception catch (e) {
    safePrint('[Amplify] Configuration failed: $e');
  }
}

class SurakshaPlusApp extends StatelessWidget {
  const SurakshaPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BleProvider()),
        ChangeNotifierProvider(create: (_) => SosProvider()),
        ChangeNotifierProvider(create: (_) => Esp32DebugProvider()),
        ChangeNotifierProvider(create: (_) => ModesProvider()),
      ],
      child: MaterialApp(
        title: 'Suraksha+',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
