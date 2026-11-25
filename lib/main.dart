import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/supabase_auth_repository.dart';
import 'data/repositories/supabase_bid_repository.dart';
import 'data/repositories/supabase_hostel_repository.dart';
import 'data/repositories/supabase_notification_repository.dart';
import 'data/repositories/supabase_room_repository.dart';
import 'data/repositories/supabase_seeker_repository.dart';
import 'domain/repositories/i_auth_repository.dart';
import 'domain/repositories/i_hostel_repository.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  if (SupabaseConfig.anonKey.isEmpty) {
    runApp(
      const StartupIssueApp(
        message: 'SUPABASE_ANON_KEY is missing.',
        details:
            'Run Chrome with --dart-define=SUPABASE_ANON_KEY=<your-Supabase-anon-key>.',
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await SupabaseAuthRepository.initializeGoogleSignIn();
    }
    final authRepository = SupabaseAuthRepository();
    Get.put<SupabaseAuthRepository>(authRepository, permanent: true);
    Get.put<IAuthRepository>(authRepository, permanent: true);
    Get.put<IHostelRepository>(SupabaseHostelRepository(), permanent: true);
    Get.put<SupabaseRoomRepository>(SupabaseRoomRepository(), permanent: true);
    Get.put<SupabaseBidRepository>(SupabaseBidRepository(), permanent: true);
    Get.put<SupabaseSeekerRepository>(
      SupabaseSeekerRepository(),
      permanent: true,
    );
    Get.put<SupabaseNotificationRepository>(
      SupabaseNotificationRepository(),
      permanent: true,
    );
  } on Exception catch (error, stackTrace) {
    debugPrint('Application initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(
      StartupIssueApp(message: 'Application setup failed.', details: '$error'),
    );
    return;
  }

  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  runApp(const HostelBuddyApp());
}

class StartupIssueApp extends StatelessWidget {
  const StartupIssueApp({
    required this.message,
    required this.details,
    super.key,
  });

  final String message;
  final String details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hostel Buddy setup',
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.settings_suggest_outlined, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(details),
                  const SizedBox(height: 16),
                  const SelectableText(
                    'Example: flutter run -d chrome '
                    '--dart-define=SUPABASE_ANON_KEY=<your-anon-key>',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HostelBuddyApp extends StatelessWidget {
  const HostelBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Hostel Buddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
      defaultTransition: Transition.fadeIn,
    );
  }
}
