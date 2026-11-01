
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

const Color pitFitYellow = Color(0xFFFFD54F);
const Color pitFitNavy = Color(0xFF101827);
const Color pitFitCard = Color(0xFF1C2738);

class Anatomy3DScreen extends StatefulWidget {
  const Anatomy3DScreen({super.key});

  @override
  State<Anatomy3DScreen> createState() =>
      _Anatomy3DScreenState();
}

class _Anatomy3DScreenState extends State<Anatomy3DScreen> {
  final Flutter3DController controller = Flutter3DController();

  bool loaded = false;
  bool playing = false;
  String? selectedAnimation;
  List<String> animations = [];

  @override
  void initState() {
    super.initState();

    controller.onModelLoaded.addListener(_onModelLoaded);
  }

  Future<void> _onModelLoaded() async {
    if (!controller.onModelLoaded.value) return;

    final available = await controller.getAvailableAnimations();
    debugPrint('Dostępne animacje: $available');

    if (!mounted) return;

    setState(() {
      loaded = true;
      animations = available;
      selectedAnimation =
          available.isEmpty ? null : available.first;
    });
  }

void _play() {
  if (!loaded || selectedAnimation == null) return;

  if (playing) {
    controller.pauseAnimation();
  } else {
    controller.playAnimation(
      animationName: selectedAnimation,
    );
  }

  setState(() => playing = !playing);
}

  @override
  void dispose() {
    controller.onModelLoaded.removeListener(_onModelLoaded);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pitFitNavy,
      appBar: AppBar(
        backgroundColor: pitFitNavy,
        foregroundColor: Colors.white,
        title: const Text('Anatomia 3D'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 420,
            decoration: BoxDecoration(
              color: pitFitCard,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Flutter3DViewer(
              controller: controller,
              src: 'assets/models/pitfit_anatomy.glb',
              activeGestureInterceptor: true,
              enableTouch: true,
              onError: (error) {
                debugPrint('Błąd modelu 3D: $error');
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Przeciągnij palcem, aby obracać model.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          const Text(
            'Animacja ćwiczenia',
            style: TextStyle(
              color: pitFitYellow,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (animations.isEmpty)
            const Text(
              'Model powinien zawierać animacje, aby można '
              'było je odtwarzać.',
              style: TextStyle(color: Colors.white70),
            )
          else ...[
         DropdownButtonFormField<String>(
          initialValue: selectedAnimation,
              dropdownColor: pitFitCard,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Wybierz animację',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
              items: animations.map((animation) {
                return DropdownMenuItem(
                  value: animation,
                  child: Text(animation),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedAnimation = value;
                  playing = false;
                });
                controller.stopAnimation();
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: pitFitYellow,
                foregroundColor: pitFitNavy,
              ),
              onPressed: _play,
              icon: Icon(
                playing ? Icons.pause : Icons.play_arrow,
              ),
              label: Text(playing ? 'Pauza' : 'Odtwórz'),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Grupy mięśni',
            style: TextStyle(
              color: pitFitYellow,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Wybór mięśni i ich podświetlanie dodamy po '
            'przygotowaniu modelu z osobnymi elementami '
            'anatomicznymi.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

