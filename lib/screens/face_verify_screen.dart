import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';

import '../services/access_provider.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';

enum FaceKind { signIn, clockIn, breakEnd }

/// Full-screen face check: the face must sit in the circle, then blink once (a photo can't blink).
/// A snapshot is sent to the admin as an audit record. The very first check is stored as the
/// employee's reference photo.
///
/// Returns true when the check passed.
class FaceVerifyScreen extends StatefulWidget {
  final FaceKind kind;
  const FaceVerifyScreen(this.kind, {super.key});

  static Future<bool> run(BuildContext context, FaceKind kind) async {
    final ok = await Navigator.of(context, rootNavigator: true).push<bool>(PageRouteBuilder(
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) => FaceVerifyScreen(kind),
      transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
    ));
    return ok == true;
  }

  @override
  State<FaceVerifyScreen> createState() => _FaceVerifyScreenState();
}

class _FaceVerifyScreenState extends State<FaceVerifyScreen> with SingleTickerProviderStateMixin {
  CameraController? _cam;
  CameraDescription? _desc;
  final _detector = FaceDetector(
      options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.fast, minFaceSize: .35));
  late final _scan = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  String? _error;
  bool _busy = false; // a frame is being analysed
  bool _done = false;
  bool _saving = false;
  double _progress = 0; // 0..1 for the ring
  String _hint = 'Make sure your head is in the circle while we scan your face';

  // liveness state machine
  int _stableFrames = 0;
  bool _sawOpen = false;
  bool _sawClosed = false;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  String get _title => switch (widget.kind) {
        FaceKind.signIn => 'Verify to sign in',
        FaceKind.clockIn => 'Verify to clock in',
        FaceKind.breakEnd => 'Verify to get back to work',
      };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final front = cams.where((c) => c.lensDirection == CameraLensDirection.front).firstOrNull ?? cams.firstOrNull;
      if (front == null) throw CameraException('none', 'No camera found on this device.');
      _desc = front;
      final c = CameraController(front, ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888);
      await c.initialize();
      await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) return;
      setState(() => _cam = c);
      await c.startImageStream(_onFrame);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error = e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt'
            ? 'Camera permission is needed to verify your face. Allow it in system settings and try again.'
            : (e.description ?? 'Could not open the camera.'));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the camera.');
    }
  }

  InputImage? _toInput(CameraImage image) {
    final cam = _desc!;
    final c = _cam!;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(cam.sensorOrientation);
    } else {
      var comp = _orientations[c.value.deviceOrientation];
      if (comp == null) return null;
      comp = cam.lensDirection == CameraLensDirection.front
          ? (cam.sensorOrientation + comp) % 360
          : (cam.sensorOrientation - comp + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(comp);
    }
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow),
    );
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _done || _saving) return;
    _busy = true;
    try {
      final input = _toInput(image);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      if (!mounted || _done) return;
      if (faces.length != 1) {
        _reset(faces.isEmpty ? 'No face found. Look at the camera.' : 'Only one person should be in the frame.');
        return;
      }
      final f = faces.first;
      final yaw = (f.headEulerAngleY ?? 0).abs();
      final roll = (f.headEulerAngleZ ?? 0).abs();
      if (yaw > 18 || roll > 20) {
        _reset('Look straight at the camera.');
        return;
      }
      final l = f.leftEyeOpenProbability, r = f.rightEyeOpenProbability;
      _stableFrames++;
      if (_stableFrames < 8) {
        setState(() {
          _progress = .1 + .4 * (_stableFrames / 8);
          _hint = 'Hold still…';
        });
        return;
      }
      // liveness: eyes open → closed → open
      if (l != null && r != null) {
        final open = l > .6 && r > .6;
        final closed = l < .25 && r < .25;
        if (open && !_sawClosed) _sawOpen = true;
        if (closed && _sawOpen) _sawClosed = true;
        if (open && _sawOpen && _sawClosed) {
          await _capture();
          return;
        }
      }
      setState(() {
        _progress = _sawClosed ? .85 : .55;
        _hint = 'Now blink once to confirm it is you';
      });
    } catch (_) {
      // a bad frame: ignore and wait for the next
    } finally {
      _busy = false;
    }
  }

  void _reset(String hint) {
    _stableFrames = 0;
    _sawOpen = _sawClosed = false;
    if (_progress != 0 || _hint != hint) {
      setState(() {
        _progress = 0;
        _hint = hint;
      });
    }
  }

  Future<void> _capture() async {
    _done = true;
    final c = _cam!;
    final access = context.read<AccessProvider>();
    try {
      await c.stopImageStream();
      setState(() {
        _progress = .95;
        _saving = true;
        _hint = 'Verified. Saving…';
      });
      final shot = await c.takePicture();
      final b64 = base64Encode(await shot.readAsBytes());
      final enrolled = access.hasFace;
      final kind = !enrolled
          ? 'enroll'
          : switch (widget.kind) {
              FaceKind.signIn => 'sign_in',
              FaceKind.clockIn => 'clock_in',
              FaceKind.breakEnd => 'break_end',
            };
      try {
        await Api.logFace(kind, b64);
        access.hasFace = true;
      } catch (_) {
        // offline: let the person through; the shift itself is queued and retried
      }
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => _progress = 1);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      _done = false;
      _saving = false;
      _reset('Something went wrong. Try again.');
      try {
        await c.startImageStream(_onFrame);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _scan.dispose();
    _detector.close();
    final c = _cam;
    if (c != null) {
      () async {
        try {
          if (c.value.isStreamingImages) await c.stopImageStream();
        } catch (_) {}
        await c.dispose();
      }();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = math.min(MediaQuery.of(context).size.width - 64, 340.0);
    final c = _cam;
    return Scaffold(
      backgroundColor: AppColors.bg(dark),
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(false)),
          ),
          const Spacer(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                const Icon(Icons.no_photography_outlined, size: 56, color: AppColors.red),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _init();
                  },
                  child: const Text('Try again'),
                ),
              ]),
            )
          else ...[
            SizedBox(
              width: size,
              height: size,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(size: Size.square(size), painter: _TickRing(_progress, dark)),
                ClipOval(
                  child: SizedBox(
                    width: size - 44,
                    height: size - 44,
                    child: c == null || !c.value.isInitialized
                        ? const ColoredBox(color: AppColors.blue800, child: Center(child: CircularProgressIndicator()))
                        : FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: c.value.previewSize!.height,
                              height: c.value.previewSize!.width,
                              child: CameraPreview(c),
                            ),
                          ),
                  ),
                ),
                if (c != null && !_done)
                  AnimatedBuilder(
                    animation: _scan,
                    builder: (_, _) => Positioned(
                      top: 22 + (size - 44) * _scan.value,
                      child: Container(
                        width: size - 70,
                        height: 2,
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: .7), boxShadow: [
                          BoxShadow(color: AppColors.accent.withValues(alpha: .5), blurRadius: 10),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 36),
            Text(_title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(_hint,
                    key: ValueKey(_hint), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 16)),
              ),
            ),
          ],
          const Spacer(flex: 2),
        ]),
      ),
    );
  }
}

/// 60 tick marks that turn blue as verification progresses.
class _TickRing extends CustomPainter {
  final double progress;
  final bool dark;
  _TickRing(this.progress, this.dark);

  @override
  void paint(Canvas canvas, Size s) {
    const n = 60;
    final c = s.center(Offset.zero);
    final outer = s.width / 2, inner = outer - 16;
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      final on = i / n < progress;
      final p = Paint()
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = on ? AppColors.accent : (dark ? AppColors.blue800 : AppColors.blue200.withValues(alpha: .6));
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * inner, c + Offset(math.cos(a), math.sin(a)) * outer, p);
    }
  }

  @override
  bool shouldRepaint(_TickRing o) => o.progress != progress || o.dark != dark;
}
