import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScanPage extends StatefulWidget {
  final Function(String data) onScanned;

  const QRScanPage({super.key, required this.onScanned});

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  bool scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR")),
      body: MobileScanner(
        onDetect: (capture) {
          if (scanned) return;

          final barcode = capture.barcodes.first;
          final raw = barcode.rawValue;

          if (raw != null) {
            scanned = true;
            widget.onScanned(raw);
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}
