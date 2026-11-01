import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'main.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  final TextEditingController _manualController = TextEditingController();
  final RegExp _codePattern = RegExp(r'^\d{8,14}$');
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _finish(String code) {
    if (_handled) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && _codePattern.hasMatch(value)) {
        _finish(value);
        return;
      }
    }
  }

  void _submitManual() {
    final code = _manualController.text.trim();

    if (!_codePattern.hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kod powinien mieć od 8 do 14 cyfr.')),
      );
      return;
    }

    _finish(code);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (e) {
      debugPrint('Latarka niedostępna: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pitFitNavy,
      appBar: AppBar(
        title: const Text('Skanuj kod kreskowy'),
        actions: [
          IconButton(
            tooltip: 'Latarka',
            onPressed: _toggleTorch,
            icon: const Icon(Icons.flashlight_on_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 280,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: pitFitYellow, width: 3),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18,
                  child: Text(
                    'Ustaw kod kreskowy w ramce',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: pitFitCard,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 14,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Albo wpisz kod ręcznie',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _submitManual(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _submitManual,
                    style: FilledButton.styleFrom(
                      backgroundColor: pitFitYellow,
                      foregroundColor: pitFitNavy,
                    ),
                    child: const Text('Użyj'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}