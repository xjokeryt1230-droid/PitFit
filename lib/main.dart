import 'package:firebase_auth/firebase_auth.dart';
import 'services/notification_service.dart';
import 'services/step_tracking_service.dart';
import 'dart:io';
import 'workout_history_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'exercise_history_screen.dart';
import 'chat/chats_screen.dart';
import 'exercise_progress_service.dart';
import 'notification_status_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'chat/chat_service.dart';
import 'firebase_options.dart';
import 'account_service.dart';
import 'workout_history_service.dart';
import 'workout_plans_screen.dart';
import 'workout_plan_service.dart';
import 'anatomy_3d_screen.dart';
import 'nutrition_screen.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

const Color pitFitYellow = Color(0xFFFFD54F);
const Color pitFitNavy = Color(0xFF101827);
const Color pitFitCard = Color(0xFF1C2738);

class PitFitMark extends StatelessWidget {
  final double size;

  const PitFitMark({super.key, this.size = 1});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100 * size,
      height: 100 * size,
      child: CustomPaint(painter: _PitFitMarkPainter()),
    );
  }
}

class _PitFitMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 100;
    final scaleY = size.height / 100;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    final path = Path()
      ..fillType = PathFillType.evenOdd
      // Zewnętrzny kształt litery
      ..moveTo(7, 28)
      ..lineTo(70, 10)
      ..cubicTo(88, 5, 99, 12, 94, 31)
      ..lineTo(89, 49)
      ..cubicTo(86, 61, 77, 67, 64, 71)
      ..lineTo(39, 78)
      ..lineTo(44, 56)
      ..lineTo(65, 49)
      ..lineTo(70, 34)
      ..lineTo(35, 44)
      ..lineTo(23, 96)
      ..lineTo(0, 100)
      ..lineTo(13, 39)
      ..cubicTo(14, 33, 11, 30, 7, 28)
      ..close()
      // Wycięcie wewnątrz górnej części P
      ..moveTo(39, 35)
      ..lineTo(70, 27)
      ..lineTo(66, 41)
      ..lineTo(36, 50)
      ..close();

    final paint = Paint()
      ..color = pitFitYellow
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PitFitLogo extends StatelessWidget {
  final double size;
  final bool watermark;

  const PitFitLogo({super.key, this.size = 1, this.watermark = false});

  @override
  Widget build(BuildContext context) {
    final opacity = watermark ? 0.12 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PitFitMark(size: 0.85 * size),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Pit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 31 * size,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                TextSpan(
                  text: 'Fit',
                  style: TextStyle(
                    color: pitFitYellow,
                    fontSize: 31 * size,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget pitFitWatermark() {
  return const Positioned(
    right: 12,
    top: 12,
    child: PitFitLogo(size: 0.55, watermark: true),
  );
}

class ExerciseInfo {
  final String name;
  final String technique;
  final List<String> muscles;
  final String? imageAsset;

  const ExerciseInfo({
    required this.name,
    required this.technique,
    required this.muscles,
    this.imageAsset,
  });
}

const Map<String, ExerciseInfo> exerciseCatalog = {
  'pompki': ExerciseInfo(
    name: 'Pompki',
    technique:
        '1. Ustaw dłonie nieco szerzej niż barki.\n'
        '2. Utrzymuj ciało w jednej linii.\n'
        '3. Opuszczaj klatkę piersiową, zginając łokcie.\n'
        '4. Odepchnij się i wróć do pozycji wyjściowej.',
    muscles: ['Klatka piersiowa', 'Triceps', 'Przednie barki'],
    imageAsset: 'assets/exercises/pompki.jpg',
  ),
  'przysiady': ExerciseInfo(
    name: 'Przysiady',
    technique:
        '1. Stań na szerokość barków.\n'
        '2. Cofnij biodra i uginaj kolana.\n'
        '3. Utrzymuj stopy na podłożu i plecy w naturalnej pozycji.\n'
        '4. Wróć do stania, kontrolując ruch.',
    muscles: [
      'Mięśnie czworogłowe uda',
      'Pośladki',
      'Mięśnie tylnej części uda',
    ],
    imageAsset: 'assets/exercises/przysiady.jpg',
  ),
  'plank': ExerciseInfo(
    name: 'Plank',
    technique:
        '1. Oprzyj przedramiona na podłożu.\n'
        '2. Wyprostuj nogi i utrzymuj ciało w jednej linii.\n'
        '3. Napnij brzuch i pośladki.\n'
        '4. Oddychaj spokojnie i nie opuszczaj bioder.',
    muscles: ['Mięśnie brzucha', 'Mięśnie głębokie tułowia', 'Pośladki'],
    imageAsset: 'assets/exercises/plank.jpg',
  ),
  'wyciskanie sztangi': ExerciseInfo(
    name: 'Wyciskanie sztangi',
    technique:
        '1. Połóż się stabilnie na ławce i ustaw stopy na podłożu.\n'
        '2. Chwyć sztangę pewnie, nie przesadzając z szerokością chwytu.\n'
        '3. Opuszczaj ją kontrolowanie w kierunku klatki piersiowej.\n'
        '4. Wypchnij sztangę do góry bez gwałtownego blokowania łokci.',
    muscles: ['Klatka piersiowa', 'Triceps', 'Przednie barki'],
    imageAsset: 'assets/exercises/wyciskanie_sztangi.jpg',
  ),
};

ExerciseInfo? findExerciseInfo(String name) {
  final normalized = name.trim().toLowerCase();

  for (final entry in exerciseCatalog.entries) {
    if (normalized == entry.key ||
        normalized == entry.value.name.toLowerCase()) {
      return entry.value;
    }
  }

  return null;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.instance.initialize();
  NotificationService.instance.startAuthListener();

  // Czekamy, aż Firebase odtworzy zapisaną sesję.
  final initialUser = await FirebaseAuth.instance.authStateChanges().first;

  runApp(PitFitApp(initialUser: initialUser));
}
class PitFitApp extends StatelessWidget {
  final User? initialUser;

  const PitFitApp({super.key, this.initialUser});

  Widget _homeFor(User? user) {
    if (user == null) return const WelcomeScreen();

    // Taka sama nazwa jak przy logowaniu, bo to klucz lokalnych danych.
    final username =
        user.displayName ?? user.email?.split('@').first ?? 'Użytkownik';

    return DashboardScreen(username: username, role: 'Użytkownik');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PitFit',
      debugShowCheckedModeBanner: false,

      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('pl', 'PL'), Locale('en', 'US')],

      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: pitFitNavy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: pitFitYellow,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: pitFitNavy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: pitFitCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: pitFitYellow),
          ),
        ),
      ),
            home: _homeFor(initialUser),
    );
  }
}

// --------------------------------------------------
// EKRAN POWITALNY
// --------------------------------------------------

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF07182B), pitFitNavy, Color(0xFF050B14)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const PitFitLogo(size: 1.25),
                  const SizedBox(height: 38),

                  const Text(
                    'Twój trening. Twój progres.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Nasz cel.',
                    style: TextStyle(color: Colors.white60, fontSize: 16),
                  ),

                  const SizedBox(height: 55),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: pitFitYellow,
                        foregroundColor: pitFitNavy,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Zaloguj się',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: pitFitYellow, width: 1.3),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Utwórz konto',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    'PITFIT  •  TWÓJ TRENING, TWOJE ZASADY',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
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

// --------------------------------------------------
// LOGOWANIE
// --------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: pitFitCard),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final firebaseUser = credential.user;

      if (!mounted) return;

      if (firebaseUser == null) {
        _showMessage('Nie udało się pobrać danych konta.');
        return;
      }

      final username =
          firebaseUser.displayName ??
          firebaseUser.email?.split('@').first ??
          'Użytkownik';

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DashboardScreen(username: username, role: 'Użytkownik'),
        ),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Adres e-mail jest nieprawidłowy.';
          break;
        case 'user-not-found':
        case 'invalid-credential':
        case 'wrong-password':
          message = 'Nieprawidłowy e-mail lub hasło.';
          break;
        case 'user-disabled':
          message = 'To konto zostało wyłączone.';
          break;
        case 'too-many-requests':
          message = 'Zbyt wiele prób. Spróbuj później.';
          break;
        case 'network-request-failed':
          message = 'Sprawdź połączenie z internetem.';
          break;
        default:
          message = 'Błąd logowania: ${e.code}';
      }

      _showMessage(message);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Wystąpił błąd logowania.');
      debugPrint('Błąd logowania: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _watermark() {
    return Positioned(
      right: -35,
      bottom: 65,
      child: Opacity(opacity: 0.045, child: const PitFitLogo(size: 2.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pitFitNavy,
      body: Stack(
        children: [
          _watermark(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 80,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white70,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Center(child: PitFitLogo(size: 0.95)),

                      const SizedBox(height: 34),

                      const Text(
                        'Witaj ponownie!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 9),

                      const Text(
                        'Zaloguj się i wróć do swoich aktywności.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                      ),

                      const SizedBox(height: 34),

                      _fieldLabel('ADRES E-MAIL'),

                      const SizedBox(height: 9),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Wpisz swój adres e-mail',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: pitFitYellow,
                          ),
                          filled: true,
                          fillColor: pitFitCard,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 19,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: pitFitYellow,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (email.isEmpty ||
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(email)) {
                            return 'Wpisz prawidłowy adres e-mail.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 22),

                      _fieldLabel('HASŁO'),

                      const SizedBox(height: 9),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Wpisz swoje hasło',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: pitFitYellow,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white54,
                            ),
                          ),
                          filled: true,
                          fillColor: pitFitCard,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 19,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: pitFitYellow,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Wpisz hasło.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: _loading ? null : _login,
                          style: FilledButton.styleFrom(
                            backgroundColor: pitFitYellow,
                            foregroundColor: pitFitNavy,
                            disabledBackgroundColor: pitFitYellow.withValues(
                              alpha: 0.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: pitFitNavy,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'ZALOGUJ SIĘ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Nie masz jeszcze konta? ',
                            style: TextStyle(color: Colors.white60),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Zarejestruj się',
                              style: TextStyle(
                                color: pitFitYellow,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      const Center(
                        child: Text(
                          'PITFIT • TWÓJ TRENING, TWOJE ZASADY',
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 10,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: pitFitYellow,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }
}

// --------------------------------------------------
// REJESTRACJA
// --------------------------------------------------

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      await credential.user?.updateDisplayName(_usernameController.text.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konto utworzone! Możesz się zalogować.')),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'Ten adres e-mail jest już zarejestrowany.';
          break;
        case 'invalid-email':
          message = 'Adres e-mail jest nieprawidłowy.';
          break;
        case 'weak-password':
          message = 'Hasło jest zbyt słabe.';
          break;
        case 'operation-not-allowed':
          message = 'Włącz Email/Password w Firebase Console.';
          break;
        case 'network-request-failed':
          message = 'Sprawdź połączenie z internetem.';
          break;
        default:
          message = 'Błąd Firebase: ${e.code}';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e, stackTrace) {
      debugPrint('BŁĄD REJESTRACJI: $e');
      debugPrint('STACK TRACE: $stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Błąd rejestracji: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: pitFitYellow),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: pitFitCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: pitFitYellow, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pitFitNavy,
      appBar: AppBar(
        backgroundColor: pitFitNavy,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Rejestracja',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: -35,
              bottom: 45,
              child: Opacity(
                opacity: 0.045,
                child: const PitFitLogo(size: 2.5),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: PitFitLogo(size: 0.85)),
                    const SizedBox(height: 26),

                    const Text(
                      'Dołącz do PitFit!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Utwórz konto i rozpocznij swoją przygodę.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 30),

                    TextFormField(
                      controller: _usernameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Nazwa użytkownika',
                        icon: Icons.person_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 3) {
                          return 'Nazwa musi mieć co najmniej 3 znaki.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 17),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Adres e-mail',
                        icon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty ||
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(email)) {
                          return 'Wpisz prawidłowy adres e-mail.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 17),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Hasło',
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 5) {
                          return 'Hasło musi mieć co najmniej 5 znaków.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 17),

                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Powtórz hasło',
                        icon: Icons.lock_reset,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Hasła nie są takie same.';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!_loading) _register();
                      },
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: pitFitYellow,
                          foregroundColor: pitFitNavy,
                          disabledBackgroundColor: pitFitYellow.withValues(
                            alpha: 0.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                        ),
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: pitFitNavy,
                                ),
                              )
                            : const Text(
                                'UTWÓRZ KONTO',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Masz już konto?',
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Zaloguj się',
                            style: TextStyle(
                              color: pitFitYellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'PITFIT • TWÓJ PLAN. TWÓJ PROGRES.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// PANEL GŁÓWNY
// --------------------------------------------------

class DashboardScreen extends StatefulWidget {
  final String username;
  final String role;

  const DashboardScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final StepTrackingService _stepTrackingService = StepTrackingService();
  List<int> _last7DaysSteps = List.filled(7, 0);
  bool _isLoadingWeeklySteps = false;
  int _todaySteps = 0;
  bool _isLoadingSteps = false;
  bool _stepsPermissionGranted = false;
  String? _stepsError;
  String? _friendCode;
  bool _loadingFriendCode = false;
  String _displayName = '';
  String? _photoUrl;
  bool _savingProfile = false;
  bool _uploadingPhoto = false;
  List<Map<String, Object?>> _progressExercises = [];
  bool _loadingProgressExercises = false;
  int? _selectedProgressExerciseId;
  int _progressHistoryRefreshKey = 0;

  // Indeks 1 oznacza Home.
  int selectedTab = 1;

  int completedWorkouts = 0;
  int _weeklyGoal = 3;
  bool _isLoadingHistory = true;

  List<Map<String, Object?>> _workoutHistory = [];
  
  @override
  void initState() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermissionOnce();
    });
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHistory();
    _loadWeeklyGoal();
    _loadProgressExercises();
    _loadProfile();
    _loadLocalProfilePhoto();
    _loadFriendCode();
    _loadTodaySteps();
    _loadLast7DaysSteps();
  }
  @override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _loadTodaySteps();
    _loadLast7DaysSteps();
  }
}
Future<void> _loadLast7DaysSteps() async {
  if (_isLoadingWeeklySteps) return;

  setState(() => _isLoadingWeeklySteps = true);

  try {
    final steps = await _stepTrackingService.getLast7DaysSteps();

    if (!mounted) return;

    setState(() {
      _last7DaysSteps = steps;
      _isLoadingWeeklySteps = false;
    });
  } catch (e) {
    debugPrint('Błąd pobierania tygodniowych kroków: $e');

    if (!mounted) return;

    setState(() => _isLoadingWeeklySteps = false);
  }
}
  Future<void> _loadTodaySteps() async {
    if (_isLoadingSteps) return;

    setState(() {
      _isLoadingSteps = true;
      _stepsError = null;
    });

    try {
      final steps = await _stepTrackingService.getTodaySteps();

      if (!mounted) return;

      setState(() {
        _todaySteps = steps;
        _isLoadingSteps = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingSteps = false;
        _stepsError = 'Nie udało się pobrać kroków.';
      });
    }
  }

  Future<void> _requestStepsPermission() async {
    setState(() {
      _isLoadingSteps = true;
      _stepsError = null;
    });

    final granted = await _stepTrackingService.requestPermission();

    if (!mounted) return;

    setState(() {
      _stepsPermissionGranted = granted;
      _isLoadingSteps = false;
    });

    if (granted) {
      await _loadTodaySteps();
    } else {
      setState(() {
        _stepsError = 'Nie przyznano dostępu do danych o krokach.';
      });
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await WorkoutHistoryService.instance.getHistory(
        widget.username,
      );

      if (!mounted) return;

      setState(() {
        _workoutHistory = history;
        completedWorkouts = history.length;
        _isLoadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoadingHistory = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się wczytać historii: $e')),
      );
    }
  }

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _startOfWeek(DateTime date) {
    final day = _startOfDay(date);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  DateTime? _workoutDate(Map<String, Object?> workout) {
    final value = workout['completed_at'];
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  int get _thisWeekCount {
    final start = _startOfWeek(DateTime.now());
    final end = start.add(const Duration(days: 7));

    return _workoutHistory.where((workout) {
      final date = _workoutDate(workout);
      return date != null && !date.isBefore(start) && date.isBefore(end);
    }).length;
  }

  int get _thisMonthCount {
    final now = DateTime.now();

    return _workoutHistory.where((workout) {
      final date = _workoutDate(workout);
      return date != null && date.year == now.year && date.month == now.month;
    }).length;
  }

  List<int> get _lastSevenDays {
    final today = _startOfDay(DateTime.now());

    return List.generate(7, (index) {
      final day = today.subtract(Duration(days: 6 - index));

      return _workoutHistory.where((workout) {
        final date = _workoutDate(workout);
        return date != null && _startOfDay(date) == day;
      }).length;
    });
  }

  Future<void> _startWorkout(String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: pitFitCard,
        title: Text(title),
        content: const Text(
          'Po wykonaniu treningu możesz oznaczyć go jako ukończony. '
          'Zapisać ukończenie w historii?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: pitFitYellow,
              foregroundColor: pitFitNavy,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ukończ trening'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    try {
      await WorkoutHistoryService.instance.saveWorkout(
        username: widget.username,
        title: title,
      );

      if (!mounted) return;

      await _loadHistory();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trening zapisany w historii!')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zapisać treningu: $e')),
      );
    }
  }
     void _openWorkoutHistory() {
       Navigator.push(
         context,
         MaterialPageRoute(
           builder: (_) => WorkoutHistoryScreen(workouts: _workoutHistory),
         ),
       );
     }
    Future<void> _logout() async {
    // Najpierw usuń urządzenie z powiadomień, dopóki jesteś zalogowany.
    await NotificationService.instance.removeFcmToken();

    await AccountService.instance.logout();
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  Future<void> _loadWeeklyGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGoal = prefs.getInt('pitfit_goal_${widget.username}');

    if (!mounted) return;

    setState(() => _weeklyGoal = savedGoal ?? 3);
  }

  Future<void> _changeWeeklyGoal() async {
    final goal = await showDialog<int>(
      context: context,
      builder: (_) => _WeeklyGoalDialog(initialGoal: _weeklyGoal),
    );

    if (goal == null || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pitfit_goal_${widget.username}', goal);

      if (!mounted) return;

      setState(() => _weeklyGoal = goal);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Nie udało się zapisać celu: $e')));
    }
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      if (!mounted) return;

      setState(() {
        _displayName =
            (data?['displayName'] as String?)?.trim().isNotEmpty == true
            ? (data!['displayName'] as String).trim()
            : user.displayName ?? widget.username;

        _photoUrl = data?['photoUrl'] as String? ?? user.photoURL;
      });
    } catch (e) {
      debugPrint('Nie udało się wczytać profilu: $e');
    }
  }

  Future<void> _changeProfileName() async {
    final controller = TextEditingController(
      text: _displayName.isNotEmpty ? _displayName : widget.username,
    );

    String? validationError;

    try {
      final newName = await showDialog<String>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                backgroundColor: pitFitCard,
                title: const Text('Zmień nazwę użytkownika'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: 'Nowa nazwa',
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: validationError,
                  ),
                  onChanged: (_) {
                    if (validationError != null) {
                      setDialogState(() => validationError = null);
                    }
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                    },
                    child: const Text('Anuluj'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final name = controller.text.trim();

                      if (name.length < 3) {
                        setDialogState(() {
                          validationError =
                              'Nazwa musi mieć co najmniej 3 znaki.';
                        });
                        return;
                      }

                      Navigator.of(
                        dialogContext,
                        rootNavigator: true,
                      ).pop(name);
                    },
                    child: const Text('Zapisz'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (newName == null || !mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() => _savingProfile = true);

      try {
        await user.updateDisplayName(newName);

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': newName,
          'photoUrl': _photoUrl ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;

        setState(() {
          _displayName = newName;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nazwa użytkownika została zmieniona.')),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się zmienić nazwy: $e')),
        );
      } finally {
        if (mounted) {
          setState(() => _savingProfile = false);
        }
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _changeProfilePhoto() async {
    try {
      final picker = ImagePicker();

      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 900,
      );

      if (image == null || !mounted) return;

      setState(() => _uploadingPhoto = true);

      final directory = await getApplicationDocumentsDirectory();
      final localPhoto = File('${directory.path}/profile_photo.jpg');

      await File(image.path).copy(localPhoto.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pitfit_profile_photo_path', localPhoto.path);

      if (!mounted) return;

      setState(() {
        _photoUrl = localPhoto.path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zdjęcie profilowe zostało zmienione.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zmienić zdjęcia: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _loadLocalProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('pitfit_profile_photo_path');

    if (!mounted) return;

    if (savedPath != null && File(savedPath).existsSync()) {
      setState(() {
        _photoUrl = savedPath;
      });
    }
  }

  Future<void> _loadFriendCode() async {
    if (_loadingFriendCode || _friendCode != null) return;

    setState(() {
      _loadingFriendCode = true;
    });

    try {
      final code = await _chatService.getOrCreateFriendCode();

      if (!mounted) return;

      setState(() {
        _friendCode = code;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać kodu znajomego: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingFriendCode = false;
        });
      }
    }
  }
  @override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}
  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildWorkoutPage(),
      _buildHomePage(),
      _buildProgressPage(),
      ChatsScreen(),
      const NutritionScreen(),
      _buildProfilePage(),
    ];

    return Scaffold(
      backgroundColor: pitFitNavy,
      appBar: AppBar(
        backgroundColor: pitFitNavy,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            PitFitMark(size: 0.34),
            const SizedBox(width: 9),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Pit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  TextSpan(
                    text: 'Fit',
                    style: TextStyle(
                      color: pitFitYellow,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: pitFitCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: pitFitYellow.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      color: pitFitYellow,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _displayName.isNotEmpty ? _displayName : widget.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: selectedTab, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: pitFitCard,
          border: Border(
            top: BorderSide(color: pitFitYellow.withValues(alpha: 0.16)),
          ),
        ),
        child: NavigationBar(
          height: 70,
          backgroundColor: pitFitCard,
          elevation: 0,
          indicatorColor: pitFitYellow.withValues(alpha: 0.16),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: selectedTab,
          onDestinationSelected: (index) {
            setState(() => selectedTab = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center, color: pitFitYellow),
              label: 'Plan',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: pitFitYellow),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights, color: pitFitYellow),
              label: 'Postęp',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble, color: pitFitYellow),
              label: 'Kontakt',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu, color: pitFitYellow),
              label: 'Dieta',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: pitFitYellow),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // PLAN TRENINGOWY
  // --------------------------------------------------

  Widget _buildWorkoutPage() {
    return WorkoutPlansScreen(
      username: widget.username,
      onStartWorkout: _startWorkout,
    );
  }

  // --------------------------------------------------
  // HOME
  // --------------------------------------------------

  Widget _buildHomePage() {
    final latestWorkout = _workoutHistory.isNotEmpty
        ? _workoutHistory.first
        : null;

    final latestTitle = latestWorkout?['workout_title'] as String?;
    final latestDate = latestWorkout == null
        ? null
        : _workoutDate(latestWorkout);

    final formattedDate = latestDate == null
        ? 'Data nieznana'
        : '${latestDate.day.toString().padLeft(2, '0')}.'
              '${latestDate.month.toString().padLeft(2, '0')}.'
              '${latestDate.year} · '
              '${latestDate.hour.toString().padLeft(2, '0')}:'
              '${latestDate.minute.toString().padLeft(2, '0')}';

    final name = _displayName.isNotEmpty ? _displayName : widget.username;

    return RefreshIndicator(
      color: pitFitYellow,
      backgroundColor: pitFitCard,
      onRefresh: () async {
        await _loadHistory();
        await _loadWeeklyGoal();
        await _loadProgressExercises();
      },
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: 110,
            child: Opacity(opacity: 0.035, child: const PitFitLogo(size: 2.5)),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            children: [
              Text(
                'WITAJ PONOWNIE',
                style: TextStyle(
                  color: pitFitYellow.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Każdy trening to kolejny krok do przodu.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // GŁÓWNY PANEL
              Container(
                padding: const EdgeInsets.all(21),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF26364D),
                      Color(0xFF172438),
                      Color(0xFF101827),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: pitFitYellow.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'TWÓJ CZAS. TWÓJ PROGRES.',
                            style: TextStyle(
                              color: pitFitYellow,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        const PitFitMark(size: 0.55),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Gotowy na kolejny trening?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Otwórz swój plan i pracuj nad kolejnym krokiem.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: pitFitYellow,
                          foregroundColor: pitFitNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          setState(() => selectedTab = 0);
                        },
                        icon: const Icon(Icons.fitness_center),
                        label: const Text(
                          'OTWÓRZ PLAN TRENINGOWY',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // SZYBKIE SKRÓTY
              const Text(
                'Odkrywaj PitFit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _dashboardShortcut(
                      icon: Icons.view_in_ar,
                      title: 'Anatomia 3D',
                      subtitle: 'Poznaj mięśnie',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const Anatomy3DScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dashboardShortcut(
                      icon: Icons.insights,
                      title: 'Postępy',
                      subtitle: 'Sprawdź historię',
                      onTap: () {
                        setState(() => selectedTab = 2);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // STATYSTYKI
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Twoja aktywność',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.bolt, color: pitFitYellow, size: 22),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      icon: Icons.calendar_view_week,
                      title: 'Ten tydzień',
                      value: _isLoadingHistory ? '...' : '$_thisWeekCount',
                      description: 'Ukończone treningi',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      icon: Icons.emoji_events_outlined,
                      title: 'Łącznie',
                      value: _isLoadingHistory ? '...' : '$completedWorkouts',
                      description: 'Ukończone treningi',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              if (!_isLoadingHistory) _buildWeeklyGoalCard(),

              _buildExercisePreviewSection(),

              const SizedBox(height: 25),

              // OSTATNI TRENING
              const Text(
                'Ostatni trening',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoadingHistory)
                const Center(
                  child: CircularProgressIndicator(color: pitFitYellow),
                )
              else if (latestTitle == null)
                _emptyCard(
                  Icons.event_note_outlined,
                  'Nie masz jeszcze ukończonych treningów. '
                  'Gdy ukończysz pierwszy, pojawi się tutaj.',
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: pitFitCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: pitFitYellow.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: pitFitYellow,
                      ),
                    ),
                    title: Text(
                      latestTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      formattedDate,
                      style: const TextStyle(color: Colors.white60),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: pitFitYellow,
                    ),
                    onTap: () {
                      setState(() => selectedTab = 2);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dashboardShortcut({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: pitFitCard,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: pitFitYellow.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: pitFitYellow.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: pitFitYellow, size: 24),
              ),
              const SizedBox(height: 13),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // KONTAKT Z TRENEREM
  // -------------------------------------------------

  // --------------------------------------------------
  // CEL TYGODNIOWY
  // --------------------------------------------------

  Widget _buildWeeklyGoalCard() {
    final progress = (_thisWeekCount / _weeklyGoal).clamp(0.0, 1.0).toDouble();
    final reached = _thisWeekCount >= _weeklyGoal;
    final remaining = _weeklyGoal - _thisWeekCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pitFitCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: reached ? pitFitYellow : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: pitFitYellow, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Cel tygodniowy',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Zmień cel',
                onPressed: _changeWeeklyGoal,
                icon: const Icon(Icons.edit_outlined, color: pitFitYellow),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reached
                ? 'Cel osiągnięty! Świetna robota!'
                : 'Realizuj swój plan krok po kroku.',
            style: TextStyle(color: reached ? pitFitYellow : Colors.white70),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_thisWeekCount',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: pitFitYellow,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  ' / $_weeklyGoal treningów',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white12,
              color: pitFitYellow,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            reached
                ? '100% celu wykonane'
                : 'Pozostało $remaining '
                      '${remaining == 1 ? 'trening' : 'treningów'}',
            style: const TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // POSTĘPY I HISTORIA
  // --------------------------------------------------
  Future<void> _loadProgressExercises() async {
    if (_loadingProgressExercises) return;

    setState(() => _loadingProgressExercises = true);

    try {
      final plans = await WorkoutPlanService.instance.getPlans(widget.username);

      final exercises = <Map<String, Object?>>[];

      for (final plan in plans) {
        final planId = plan['id'] as int;
        final planName = plan['name'] as String? ?? 'Plan treningowy';

        final fullPlan = await WorkoutPlanService.instance.getPlan(
          planId,
          widget.username,
        );

        if (fullPlan == null) continue;

        final planExercises = (fullPlan['exercises'] as List? ?? []).map(
          (item) => Map<String, Object?>.from(item as Map),
        );

        for (final exercise in planExercises) {
          exercises.add({...exercise, 'plan_name': planName});
        }
      }

      if (!mounted) return;

      setState(() {
        _progressExercises = exercises;

        if (_selectedProgressExerciseId != null &&
            !exercises.any((e) => e['id'] == _selectedProgressExerciseId)) {
          _selectedProgressExerciseId = null;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się wczytać ćwiczeń: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingProgressExercises = false);
      }
    }
  }

  Future<void> _saveExerciseProgress({
    required int exerciseId,
    required String exerciseName,
    required String planName,
    double? weight,
    int? reps,
    int? durationSeconds,
  }) async {
    try {
      await ExerciseProgressService.instance.saveProgress(
        username: widget.username,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        planName: planName,
        weight: weight,
        reps: reps,
        durationSeconds: durationSeconds,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wynik ćwiczenia został zapisany.')),
      );

      setState(() {
        _progressHistoryRefreshKey++;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zapisać wyniku: $e')),
      );
    }
  }

  Future<List<Map<String, Object?>>> _getSelectedExerciseProgress() async {
    final exerciseId = _selectedProgressExerciseId;

    if (exerciseId == null) {
      return [];
    }
   
    return ExerciseProgressService.instance.getProgress(
      username: widget.username,
      exerciseId: exerciseId,
    );
  }
Future<void> _openExerciseHistory(String exerciseName) async {
    try {
      final records = await _getSelectedExerciseProgress();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseHistoryScreen(
            exerciseName: exerciseName,
            records: records,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się wczytać historii: $e')),
      );
    }
  }
  Widget _buildProgressPage() {
    final totalWeeklySteps = _last7DaysSteps.fold<int>(
  0,
  (total, steps) => total + steps,
);

final averageDailySteps = totalWeeklySteps / 7;

final maxSteps = _last7DaysSteps.fold<int>(
  0,
  (maxValue, steps) => steps > maxValue ? steps : maxValue,
);

const stepDayLabels = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd'];
    final counts = _lastSevenDays;
    final maxCount = counts.fold<int>(
      0,
      (maxValue, value) => value > maxValue ? value : maxValue,
    );

    final totalLastSevenDays = counts.fold<int>(
      0,
      (total, value) => total + value,
    );

    final averagePerDay = totalLastSevenDays / 7;
    final goalProgress = _weeklyGoal > 0
        ? (_thisWeekCount / _weeklyGoal).clamp(0.0, 1.0)
        : 0.0;

    const dayLabels = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd'];

    final today = _startOfDay(DateTime.now());
    final firstDay = today.subtract(const Duration(days: 6));

    final bestDayIndex = counts.isEmpty ? -1 : counts.indexOf(maxCount);
    final bestDayDate = bestDayIndex < 0
        ? null
        : firstDay.add(Duration(days: bestDayIndex));

    final bestDayLabel = maxCount == 0 || bestDayDate == null
        ? 'Brak treningów'
        : '${dayLabels[bestDayDate.weekday - 1]} · $maxCount '
              '${maxCount == 1
                  ? 'trening'
                  : maxCount < 5
                  ? 'treningi'
                  : 'treningów'}';

    return RefreshIndicator(
      color: pitFitYellow,
      onRefresh: () async {
  await _loadHistory();
  await _loadTodaySteps();
  await _loadLast7DaysSteps();
},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          // Nagłówek
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: pitFitCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: pitFitYellow.withValues(alpha: 0.22)),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -8,
                  top: -12,
                  child: Icon(
                    Icons.insights_rounded,
                    size: 105,
                    color: Colors.white.withValues(alpha: 0.035),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: pitFitYellow.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PITFIT · STATYSTYKI',
                            style: TextStyle(
                              color: pitFitYellow,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Twoje postępy',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Każdy trening to kolejny krok do przodu.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          _buildExerciseProgressSection(),

          const SizedBox(height: 22),

          if (_isLoadingHistory)
            const LinearProgressIndicator(
              color: pitFitYellow,
              backgroundColor: Colors.white12,
            ),

          if (!_isLoadingHistory) ...[
            _buildWeeklyGoalCard(),
            const SizedBox(height: 12),

            // Realizacja celu tygodniowego
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: pitFitCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: pitFitYellow.withValues(alpha: 0.14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        color: pitFitYellow,
                        size: 23,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Cel tygodniowy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${(goalProgress * 100).round()}%',
                        style: const TextStyle(
                          color: pitFitYellow,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: goalProgress,
                      minHeight: 11,
                      backgroundColor: Colors.white12,
                      color: pitFitYellow,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_thisWeekCount z $_weeklyGoal treningów w tym tygodniu',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  if (_thisWeekCount >= _weeklyGoal) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: pitFitYellow,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'Cel tygodniowy osiągnięty!',
                          style: TextStyle(
                            color: pitFitYellow,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Statystyki główne
          const Text(
            'Twoje wyniki',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.fitness_center,
                  title: 'Łącznie',
                  value: _isLoadingHistory ? '...' : '$completedWorkouts',
                  description: 'Ukończone treningi',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: Icons.date_range,
                  title: 'Ten tydzień',
                  value: _isLoadingHistory ? '...' : '$_thisWeekCount',
                  description: 'Od poniedziałku',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _statCard(
            icon: Icons.calendar_month,
            title: 'Ten miesiąc',
            value: _isLoadingHistory ? '...' : '$_thisMonthCount',
            description: 'Ukończone treningi w tym miesiącu',
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.trending_up,
                  title: 'Średnio dziennie',
                  value: _isLoadingHistory
                      ? '...'
                      : averagePerDay.toStringAsFixed(1),
                  description: 'Treningi przez 7 dni',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: Icons.emoji_events_rounded,
                  title: 'Najlepszy dzień',
                  value: _isLoadingHistory ? '...' : bestDayLabel,
                  description: 'Ostatnie 7 dni',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Kroki z Health Connect
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: pitFitCard,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: pitFitYellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.directions_walk_rounded,
                        color: pitFitYellow,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kroki dzisiaj',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Twoja dzienna aktywność',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoadingSteps ? null : _loadTodaySteps,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: pitFitYellow,
                      ),
                      tooltip: 'Odśwież kroki',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_isLoadingSteps)
                  const Center(
                    child: CircularProgressIndicator(color: pitFitYellow),
                  )
                else if (_stepsPermissionGranted)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _todaySteps.toString(),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: pitFitYellow,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 6),
                        child: Text(
                          'kroków',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'Połącz PitFit z Health Connect, aby odczytywać '
                    'liczbę kroków z telefonu.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                if (_stepsError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _stepsError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (!_stepsPermissionGranted) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingSteps
                          ? null
                          : _requestStepsPermission,
                      icon: const Icon(Icons.favorite_border_rounded),
                      label: const Text('Połącz z Health Connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pitFitYellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 28),
// WYKRES KROKÓW — OSTATNIE 7 DNI
Container(
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: pitFitCard,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: pitFitYellow.withValues(alpha: 0.16),
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Kroki — ostatnie 7 dni',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Twoja tygodniowa aktywność',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
      const SizedBox(height: 20),

      if (_isLoadingWeeklySteps)
        const Center(
          child: CircularProgressIndicator(color: pitFitYellow),
        )
      else ...[
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.directions_walk,
                title: 'Łącznie',
                value: totalWeeklySteps.toString(),
                description: 'Kroków w 7 dni',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.trending_up,
                title: 'Średnio',
                value: averageDailySteps.toStringAsFixed(0),
                description: 'Kroków dziennie',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final steps = _last7DaysSteps[index];
              final barHeight = maxSteps == 0
                  ? 6.0
                  : 90.0 * steps / maxSteps;

              final date = _startOfDay(DateTime.now())
                  .subtract(Duration(days: 6 - index));

              final isToday = index == 6;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        steps >= 1000
                            ? '${(steps / 1000).toStringAsFixed(1)}k'
                            : '$steps',
                        style: TextStyle(
                          color: isToday ? pitFitYellow : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: isToday
                              ? pitFitYellow
                              : pitFitYellow.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        stepDayLabels[date.weekday - 1],
                        style: TextStyle(
                          color: isToday ? pitFitYellow : Colors.white54,
                          fontSize: 11,
                          fontWeight: isToday
                              ? FontWeight.w900
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    ],
  ),
),

const SizedBox(height: 24),
          // Wykres aktywności
          const Text(
            'Aktywność',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'Ostatnie 7 dni',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              color: pitFitCard,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Liczba ukończonych treningów dziennie',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (index) {
                      final count = counts[index];
                      final barHeight = maxCount == 0
                          ? 6.0
                          : 90.0 * count / maxCount;
                      final date = firstDay.add(Duration(days: index));
                      final isToday = date == today;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '$count',
                                style: TextStyle(
                                  color: isToday
                                      ? pitFitYellow
                                      : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? pitFitYellow
                                      : pitFitYellow.withValues(alpha: 0.38),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                dayLabels[date.weekday - 1],
                                style: TextStyle(
                                  color: isToday
                                      ? pitFitYellow
                                      : Colors.white54,
                                  fontSize: 11,
                                  fontWeight: isToday
                                      ? FontWeight.w900
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Historia treningów
                       InkWell(
               onTap: _openWorkoutHistory,
               borderRadius: BorderRadius.circular(14),
               child: Padding(
                 padding: const EdgeInsets.symmetric(vertical: 6),
                 child: Row(
                   children: [
                     const Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             'Historia treningów',
                             style: TextStyle(
                               fontSize: 21,
                               fontWeight: FontWeight.w900,
                             ),
                           ),
                           SizedBox(height: 3),
                           Text(
                             'Dotknij, aby zobaczyć wszystkie i wyszukać po dacie',
                             style: TextStyle(
                               color: Colors.white54,
                               fontSize: 12,
                             ),
                           ),
                         ],
                       ),
                     ),
                     if (!_isLoadingHistory)
                       Text(
                         '${_workoutHistory.length} zapisów',
                         style: const TextStyle(
                           color: Colors.white54,
                           fontSize: 12,
                         ),
                       ),
                     const Icon(
                       Icons.chevron_right_rounded,
                       color: pitFitYellow,
                     ),
                   ],
                 ),
               ),
             ),
          const SizedBox(height: 12),

          if (_isLoadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: pitFitYellow),
              ),
            )
          else if (_workoutHistory.isEmpty)
            _emptyCard(
              Icons.event_note_outlined,
              'Nie masz jeszcze ukończonych treningów. '
              'Wybierz trening i oznacz go jako ukończony!',
            )
          else
            ..._workoutHistory.take(3).map((workout) {
              final title = workout['workout_title'] as String? ?? 'Trening';
              final date = _workoutDate(workout);

              final formattedDate = date == null
                  ? 'Data nieznana'
                  : '${date.day.toString().padLeft(2, '0')}.'
                        '${date.month.toString().padLeft(2, '0')}.'
                        '${date.year} · '
                        '${date.hour.toString().padLeft(2, '0')}:'
                        '${date.minute.toString().padLeft(2, '0')}';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pitFitCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.045),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: pitFitYellow.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: pitFitYellow,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.done_rounded,
                      color: pitFitYellow,
                      size: 19,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // KARTA STATYSTYK
  // --------------------------------------------------

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pitFitCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: pitFitYellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: pitFitYellow, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: pitFitYellow,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pitFitCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: pitFitYellow, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // PROFIL
  // --------------------------------------------------

  Widget _buildProfilePage() {
    final name = _displayName.isEmpty ? widget.username : _displayName;
    final hasPhoto =
        _photoUrl != null &&
        _photoUrl!.isNotEmpty &&
        File(_photoUrl!).existsSync();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: pitFitCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: pitFitYellow.withValues(alpha: 0.2)),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                top: -12,
                child: Icon(
                  Icons.person_rounded,
                  size: 110,
                  color: Colors.white.withValues(alpha: 0.035),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: pitFitYellow.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PITFIT · TWOJE KONTO',
                      style: TextStyle(
                        color: pitFitYellow,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Twój profil',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Zarządzaj swoim kontem i ustawieniami.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Karta użytkownika
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: pitFitCard,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: pitFitYellow, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: pitFitYellow,
                      backgroundImage: hasPhoto
                          ? FileImage(File(_photoUrl!))
                          : null,
                      child: !hasPhoto
                          ? const Icon(
                              Icons.person_rounded,
                              size: 52,
                              color: pitFitNavy,
                            )
                          : null,
                    ),
                  ),
                  Material(
                    color: pitFitYellow,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Zmień zdjęcie',
                      onPressed: _uploadingPhoto ? null : _changeProfilePhoto,
                      icon: _uploadingPhoto
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: pitFitNavy,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              color: pitFitNavy,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: pitFitYellow.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  widget.role,
                  style: const TextStyle(
                    color: pitFitYellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: pitFitYellow,
                    foregroundColor: pitFitNavy,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: _savingProfile ? null : _changeProfileName,
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(
                    _savingProfile ? 'Zapisywanie...' : 'Zmień nazwę',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),

                // Powiadomienia
        const NotificationStatusCard(),
const SizedBox(height: 20),

        // Kod znajomego
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: pitFitCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: pitFitYellow.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_alt_rounded, color: pitFitYellow, size: 23),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Dodaj znajomych',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Udostępnij swój kod znajomym, aby mogli Cię znaleźć.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: pitFitNavy,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: _loadingFriendCode
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: pitFitYellow,
                                ),
                              )
                            : Text(
                                _friendCode ?? 'Brak kodu',
                                style: const TextStyle(
                                  color: pitFitYellow,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Kopiuj kod',
                    onPressed: _friendCode == null
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: _friendCode!),
                            );

                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kod znajomego skopiowany!'),
                              ),
                            );
                          },
                    style: IconButton.styleFrom(
                      backgroundColor: pitFitYellow,
                      foregroundColor: pitFitNavy,
                    ),
                    icon: const Icon(Icons.copy_rounded),
                  ),
                  const SizedBox(width: 3),
                  IconButton(
                    tooltip: 'Odśwież kod',
                    onPressed: _loadingFriendCode
                        ? null
                        : () {
                            setState(() {
                              _friendCode = null;
                            });
                            _loadFriendCode();
                          },
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Informacje o koncie
        const Text(
          'Informacje o koncie',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: pitFitCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _profileRow(
                Icons.check_circle_outline_rounded,
                'Ukończone treningi',
                '$completedWorkouts',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Divider(color: Colors.white12, height: 1),
              ),
              _profileRow(
                Icons.storage_rounded,
                'Historia',
                'Zapisywana lokalnie na tym urządzeniu',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Divider(color: Colors.white12, height: 1),
              ),
              _profileRow(
                Icons.flag_rounded,
                'Cel tygodniowy',
                '$_weeklyGoal treningów',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Wylogowanie
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              'Wyloguj się',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseProgressSection() {
    if (_loadingProgressExercises) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_progressExercises.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Postęp ćwiczeń',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Najpierw dodaj ćwiczenia do swojego planu treningowego.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loadProgressExercises,
                icon: const Icon(Icons.refresh),
                label: const Text('Wczytaj ćwiczenia'),
              ),
            ],
          ),
        ),
      );
    }

    final matchingExercises = _progressExercises
        .where((e) => e['id'] == _selectedProgressExerciseId)
        .toList();

    final selectedExercise = matchingExercises.isEmpty
        ? null
        : matchingExercises.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Postęp ćwiczeń',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selectedProgressExerciseId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Wybierz ćwiczenie',
                border: OutlineInputBorder(),
              ),
              items: _progressExercises.map((exercise) {
                final id = exercise['id'] as int;
                final name = exercise['name'] as String? ?? 'Ćwiczenie';
                final plan = exercise['plan_name'] as String? ?? 'Plan';

                return DropdownMenuItem<int>(
                  value: id,
                  child: Text('$name — $plan', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProgressExerciseId = value;
                });
              },
            ),
            if (selectedExercise != null) ...[
              const SizedBox(height: 16),
              _ExerciseProgressEntryForm(
                key: ValueKey(selectedExercise['id']),
                onSave: ({double? weight, int? reps, int? durationSeconds}) {
                  return _saveExerciseProgress(
                    exerciseId: selectedExercise['id'] as int,
                    exerciseName:
                        selectedExercise['name'] as String? ?? 'Ćwiczenie',
                    planName:
                        selectedExercise['plan_name'] as String? ?? 'Plan',
                    weight: weight,
                    reps: reps,
                    durationSeconds: durationSeconds,
                  );
                },
              ),
              const SizedBox(height: 20),
                            InkWell(
                onTap: () => _openExerciseHistory(
                  selectedExercise['name'] as String? ?? 'Ćwiczenie',
                ),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Historia wyników',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Dotknij, aby zobaczyć wszystkie i wyszukać po dacie',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: pitFitYellow,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, Object?>>>(
                key: ValueKey(
                  'progress-$_selectedProgressExerciseId-$_progressHistoryRefreshKey',
                ),
                future: _getSelectedExerciseProgress(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final records = snapshot.data ?? [];

                  if (records.isEmpty) {
                    return const Text('Nie zapisano jeszcze żadnych wyników.');
                  }

                  final sortedRecords = List<Map<String, Object?>>.from(
                    records,
                  );

                  sortedRecords.sort((a, b) {
                    final dateA = DateTime.tryParse(
                      a['recorded_at'] as String? ?? '',
                    );
                    final dateB = DateTime.tryParse(
                      b['recorded_at'] as String? ?? '',
                    );

                    if (dateA == null && dateB == null) return 0;
                    if (dateA == null) return 1;
                    if (dateB == null) return -1;

                    return dateB.compareTo(dateA);
                  });

                    final visibleRecords = sortedRecords.take(3).toList();

                  return Column(
                    children: [
                      ...visibleRecords.map((record) {
                        final date = DateTime.tryParse(
                          record['recorded_at'] as String? ?? '',
                        );

                        final weight = record['weight'] as num?;
                        final reps = record['reps'] as num?;
                        final duration = record['duration_seconds'] as num?;

                        final details = <String>[];

                        if (weight != null) {
                          details.add('${weight.toString()} kg');
                        }

                        if (reps != null) {
                          details.add('${reps.toInt()} powt.');
                        }

                        if (duration != null) {
                          final seconds = duration.toInt();
                          details.add('${seconds ~/ 60} min ${seconds % 60} s');
                        }

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.trending_up),
                          title: Text(
                            details.isEmpty
                                ? 'Brak szczegółów'
                                : details.join(' · '),
                          ),
                          subtitle: Text(
                            date == null
                                ? 'Data nieznana'
                                : '${date.day.toString().padLeft(2, '0')}.'
                                      '${date.month.toString().padLeft(2, '0')}.'
                                      '${date.year}  '
                                      '${date.hour.toString().padLeft(2, '0')}:'
                                      '${date.minute.toString().padLeft(2, '0')}',
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExercisePreviewSection() {
    if (_progressExercises.isEmpty) {
      return const SizedBox.shrink();
    }

    final seen = <String>{};
    final exercises = _progressExercises
        .where((exercise) {
          final name = (exercise['name'] ?? '').toString().trim();
          return name.isNotEmpty && seen.add(name.toLowerCase());
        })
        .take(10)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Poznaj swoje ćwiczenia',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Zdjęcia, technika i zaangażowane mięśnie',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: exercises.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              final name = (exercise['name'] ?? '').toString();
              final info = findExerciseInfo(name);

              return SizedBox(
                width: 155,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showExerciseDetails(exercise),
                  child: Container(
                    decoration: BoxDecoration(
                      color: pitFitCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: pitFitYellow.withValues(alpha: 0.25),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            child: info?.imageAsset != null
                                ? Image.asset(
                                    info!.imageAsset!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (
                                      context,
                                      error,
                                      stackTrace,
                                    ) => _exerciseImagePlaceholder(),
                                  )
                                : _exerciseImagePlaceholder(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                info == null
                                    ? 'Zobacz szczegóły'
                                    : info.muscles.take(2).join(' • '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _exerciseImagePlaceholder() {
    return Container(
      color: const Color(0xFF263449),
      alignment: Alignment.center,
      child: const Icon(Icons.fitness_center, color: pitFitYellow, size: 42),
    );
  }

  void _showExerciseDetails(Map<String, Object?> exercise) {
    final name = (exercise['name'] ?? 'Ćwiczenie').toString();
    final info = findExerciseInfo(name);

    final sets = exercise['sets'] ?? 3;
    final reps = exercise['reps'] ?? 10;
    final duration = exercise['duration_seconds'] ?? 0;
    final notes = (exercise['notes'] ?? '').toString().trim();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pitFitCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 190,
                    child: info?.imageAsset != null
                        ? Image.asset(
                            info!.imageAsset!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _exerciseImagePlaceholder(),
                          )
                        : _exerciseImagePlaceholder(),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Twój plan',
                  style: TextStyle(
                    color: pitFitYellow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  duration is int && duration > 0
                      ? '$sets serii • $duration s'
                      : '$sets serii • $reps powtórzeń',
                  style: const TextStyle(color: Colors.white),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Notatki: $notes',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Technika wykonania',
                  style: TextStyle(
                    color: pitFitYellow,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  info?.technique ??
                      'Brak instrukcji dla tego ćwiczenia. '
                          'Dodaj opis techniki do katalogu ćwiczeń, '
                          'aby wyświetlać sprawdzone wskazówki.',
                  style: const TextStyle(color: Colors.white, height: 1.5),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Zaangażowane mięśnie',
                  style: TextStyle(
                    color: pitFitYellow,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (info == null)
                  const Text(
                    'Brak danych o mięśniach dla tego ćwiczenia.',
                    style: TextStyle(color: Colors.white70),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: info.muscles.map((muscle) {
                      return Chip(
                        label: Text(muscle),
                        backgroundColor: const Color(0xFF303D50),
                        labelStyle: const TextStyle(color: Colors.white),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: pitFitYellow),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------
// OKNO ZMIANY CELU TYGODNIOWEGO
// --------------------------------------------------

class _WeeklyGoalDialog extends StatefulWidget {
  final int initialGoal;

  const _WeeklyGoalDialog({required this.initialGoal});

  @override
  State<_WeeklyGoalDialog> createState() => _WeeklyGoalDialogState();
}

class _WeeklyGoalDialogState extends State<_WeeklyGoalDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialGoal.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final goal = int.tryParse(_controller.text.trim());

    if (goal == null || goal < 1 || goal > 14) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wpisz liczbę od 1 do 14.')));
      return;
    }

    Navigator.of(context).pop(goal);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: pitFitCard,
      title: const Text('Cel tygodniowy'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        maxLength: 2,
        decoration: const InputDecoration(
          labelText: 'Liczba treningów',
          hintText: 'Np. 3',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: pitFitYellow,
            foregroundColor: pitFitNavy,
          ),
          onPressed: _submit,
          child: const Text('Zapisz'),
        ),
      ],
    );
  }
}

class _ExerciseProgressEntryForm extends StatefulWidget {
  final Future<void> Function({double? weight, int? reps, int? durationSeconds})
  onSave;

  const _ExerciseProgressEntryForm({super.key, required this.onSave});

  @override
  State<_ExerciseProgressEntryForm> createState() =>
      _ExerciseProgressEntryFormState();
}

class _ExerciseProgressEntryFormState
    extends State<_ExerciseProgressEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _minutesController = TextEditingController();
  final _secondsController = TextEditingController();

  String _mode = 'weight_reps';
  bool _saving = false;

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    double? weight;
    int? reps;
    int? durationSeconds;

    if (_mode == 'weight_reps') {
      weight = double.tryParse(
        _weightController.text.trim().replaceAll(',', '.'),
      );
      reps = int.tryParse(_repsController.text.trim());
    } else if (_mode == 'reps') {
      reps = int.tryParse(_repsController.text.trim());
    } else {
      final minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
      final seconds = int.tryParse(_secondsController.text.trim()) ?? 0;
      durationSeconds = minutes * 60 + seconds;
    }

    setState(() => _saving = true);

    try {
      await widget.onSave(
        weight: weight,
        reps: reps,
        durationSeconds: durationSeconds,
      );

      if (!mounted) return;

      _weightController.clear();
      _repsController.clear();
      _minutesController.clear();
      _secondsController.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validatePositiveNumber(String? value) {
    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));

    if (parsed == null || parsed <= 0) {
      return 'Wpisz liczbę większą od zera.';
    }

    return null;
  }

  String? _validatePositiveInteger(String? value) {
    final parsed = int.tryParse((value ?? '').trim());

    if (parsed == null || parsed <= 0) {
      return 'Wpisz liczbę całkowitą większą od zera.';
    }

    return null;
  }

  String? _validateTimePart(String? value) {
    final parsed = int.tryParse((value ?? '').trim());

    if (parsed == null || parsed < 0) {
      return 'Wpisz zero lub większą liczbę.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Rodzaj wyniku'),
            items: const [
              DropdownMenuItem(
                value: 'weight_reps',
                child: Text('Ciężar i powtórzenia'),
              ),
              DropdownMenuItem(value: 'reps', child: Text('Liczba powtórzeń')),
              DropdownMenuItem(value: 'time', child: Text('Czas ćwiczenia')),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _mode = value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          if (_mode == 'weight_reps') ...[
            TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Ciężar (kg)'),
              validator: _validatePositiveNumber,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Liczba powtórzeń'),
              validator: _validatePositiveInteger,
            ),
          ] else if (_mode == 'reps') ...[
            TextFormField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Liczba powtórzeń'),
              validator: _validatePositiveInteger,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minuty'),
                    validator: _validateTimePart,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _secondsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sekundy'),
                    validator: (value) {
                      final error = _validateTimePart(value);
                      if (error != null) return error;

                      final seconds = int.parse(value!.trim());
                      if (seconds > 59) {
                        return 'Maksymalnie 59.';
                      }

                      final minutes =
                          int.tryParse(_minutesController.text.trim()) ?? 0;

                      if (minutes == 0 && seconds == 0) {
                        return 'Czas musi być większy od zera.';
                      }

                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Zapisywanie...' : 'Zapisz wynik'),
          ),
        ],
      ),
    );
  }
}
