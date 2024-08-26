import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_qr_scanner_example/qr_scanner_overlay.dart';
import 'package:flutter_web_qr_scanner_example/scanned_barcode_label.dart';
import 'package:flutter_web_qr_scanner_example/scanner_button_widgets.dart';
import 'package:flutter_web_qr_scanner_example/scanner_error_widget.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController(
    autoStart: false,
    torchEnabled: false,
    useNewCameraSelector: true,
  );

  Barcode? _barcode;
  StreamSubscription<Object?>? _subscription;
  Timer? _debounce;

  Widget _buildBarcode(Barcode? value) {
    if (value == null) {
      return const Text(
        '아무거나 스캔좀해주세요..',
        overflow: TextOverflow.fade,
        style: TextStyle(color: Colors.white),
      );
    }

    return Text(
      value.displayValue ?? 'No display value.',
      overflow: TextOverflow.fade,
      style: const TextStyle(color: Colors.white),
    );
  }

  void _handleBarcode(BarcodeCapture barcodes) {
    if (mounted) {
      setState(() {
        _barcode = barcodes.barcodes.firstOrNull;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _subscription = controller.barcodes.listen(_handleBarcode);

    unawaited(controller.start());
  }

  @override
  Future<void> dispose() async {
    _debounce?.cancel();

    super.dispose();
    await controller.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        _subscription = controller.barcodes.listen(_handleBarcode);

        unawaited(controller.start());
      case AppLifecycleState.inactive:
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(controller.stop());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(Offset.zero),
      width: 200,
      height: 200,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('스캔스캔스캔'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: MobileScanner(
              onDetect: (barcodes) {
                // if (_debounce?.isActive ?? false) _debounce?.cancel();
                // _debounce = Timer(const Duration(milliseconds: 1000), () {
                //   if (mounted) {
                //     ScaffoldMessenger.of(context).showSnackBar(
                //       SnackBar(
                //         content: Text(
                //           "값 : ${barcodes.barcodes[0].displayValue}\n포맷 : ${barcodes.barcodes[0].format.toString()}",
                //         ),
                //         duration: const Duration(seconds: 2),
                //         behavior: SnackBarBehavior.floating,
                //       ),
                //     );
                //   }
                // });
              },
              fit: BoxFit.contain,
              controller: controller,
              scanWindow: scanWindow,
              errorBuilder: (context, error, child) {
                return ScannerErrorWidget(error: error);
              },
              overlayBuilder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ScannedBarcodeLabel(barcodes: controller.barcodes),
                  ),
                );
              },
            ),
          ),
          // CustomPaint(
          //   painter: WebScannerOverlay(scanWindow: scanWindow),
          // ),
          QRScannerOverlay(overlayColour: Colors.black.withOpacity(0.5)),

          // ValueListenableBuilder(
          //   valueListenable: controller,
          //   builder: (context, value, child) {
          //     if (!value.isInitialized ||
          //         !value.isRunning ||
          //         value.error != null) {
          //       return const SizedBox();
          //     }

          //     return CustomPaint(
          //       painter: ScannerOverlay(scanWindow: scanWindow),
          //     );
          //   },
          // ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StartStopMobileScannerButton(controller: controller),
                  SwitchCameraButton(controller: controller),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  const ScannerOverlay({
    required this.scanWindow,
    this.borderRadius = 12.0,
  });

  final Rect scanWindow;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: use `Offset.zero & size` instead of Rect.largest
    // we need to pass the size to the custom paint widget
    final backgroundPath = Path()..addRect(Rect.largest);

    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          scanWindow,
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
      );

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final borderRect = RRect.fromRectAndCorners(
      scanWindow,
      topLeft: Radius.circular(borderRadius),
      topRight: Radius.circular(borderRadius),
      bottomLeft: Radius.circular(borderRadius),
      bottomRight: Radius.circular(borderRadius),
    );

    // First, draw the background,
    // with a cutout area that is a bit larger than the scan window.
    // Finally, draw the scan window itself.
    canvas.drawPath(backgroundWithCutout, backgroundPaint);
    canvas.drawRRect(borderRect, borderPaint);
  }

  @override
  bool shouldRepaint(ScannerOverlay oldDelegate) {
    return scanWindow != oldDelegate.scanWindow ||
        borderRadius != oldDelegate.borderRadius;
  }
}

class WebScannerOverlay extends CustomPainter {
  final Rect scanWindow;

  WebScannerOverlay({required this.scanWindow});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // 전체 화면에 반투명한 배경을 그립니다
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // scanWindow 영역을 투명하게 만듭니다
    canvas.drawRect(scanWindow, Paint()..blendMode = BlendMode.clear);

    // scanWindow 주변에 테두리를 그립니다
    canvas.drawRect(scanWindow, borderPaint);

    // 선택적: 스캔 영역 안내 텍스트 추가
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'QR 코드를 이 영역 안에 위치시켜주세요',
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(
          scanWindow.left + (scanWindow.width - textPainter.width) / 2,
          scanWindow.bottom + 20,
        ));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
