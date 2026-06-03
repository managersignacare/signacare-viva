import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'core/theme.dart';
import 'core/offline/offline_write_queue.dart';
import 'core/services/auth_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/sync_client.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const ProviderScope(child: VivaApp()));
}

class VivaApp extends ConsumerStatefulWidget {
  const VivaApp({super.key});

  @override
  ConsumerState<VivaApp> createState() => _VivaAppState();
}

class _VivaAppState extends ConsumerState<VivaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Audit Tier 4.1 — drain any queued offline writes at boot. Network
    // may be available even though the previous session was killed
    // mid-queue. Fire-and-forget intentionally: the flush has its own
    // error handling and should not block app launch.
    // ignore: discarded_futures
    OfflineWriteQueue.instance.flush();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Attempt to flush queued writes whenever the user brings Viva
      // back to the foreground. Good heuristic for "network is
      // probably back" without a dedicated connectivity plugin.
      // ignore: discarded_futures
      OfflineWriteQueue.instance.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(patientAuthProvider);

    // Phase 11B — on patient login, initialise Firebase, register
    // the FCM device token with the backend, hydrate the local
    // downstream-sync cache, and start the 60-second delta poll
    // loop. Logout clears the cache + stops the poll so a second
    // patient on the same device never sees the previous user's
    // data. Idempotent — Riverpod's ref.listen dedupes by identity.
    ref.listen<PatientAuthState>(patientAuthProvider, (prev, next) {
      final sync = ref.read(vivaSyncClientProvider);
      if (!next.isAuthenticated) {
        if (prev?.isAuthenticated == true) {
          // ignore: discarded_futures
          sync.clear();
        }
        return;
      }
      if (prev?.isAuthenticated == true) return;
      final fcm = ref.read(vivaFcmServiceProvider);
      // ignore: discarded_futures
      fcm.initialise(onSyncTrigger: () => sync.refresh()).then((_) async {
        await fcm.registerToken();
        await sync.hydrate();
        await sync.refresh();
        sync.startPeriodic();
      });
    });

    return MaterialApp(
      title: 'Viva by Signacare',
      theme: vivaTheme,
      debugShowCheckedModeBanner: false,
      home: authState.isLoading
          ? const _SplashScreen()
          : authState.isAuthenticated
              ? const PatientHomeScreen()
              : const PatientLoginScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SvgPicture.asset('assets/signacare-logo.svg', width: 64, height: 64,
            colorFilter: const ColorFilter.mode(kPrimary, BlendMode.srcIn)),
          const SizedBox(height: 20),
          const Text('Viva', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: kPrimary, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          const Text('by Signacare', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextLight)),
          const SizedBox(height: 6),
          const Text('Your Wellbeing Companion', style: TextStyle(fontSize: 12, color: kTextLight)),
          const SizedBox(height: 48),
          const CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5),
        ]),
      ),
    );
  }
}
