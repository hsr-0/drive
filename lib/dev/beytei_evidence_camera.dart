import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Camera preview and capture inside Beytei. The device's external camera app
/// is never launched, which avoids suspending our order editing route.
/// Returns XFile only after the driver confirms the captured evidence.
class BeyteiEvidenceCameraPage extends StatefulWidget {
  const BeyteiEvidenceCameraPage({super.key});

  @override
  State<BeyteiEvidenceCameraPage> createState() =>
      _BeyteiEvidenceCameraPageState();
}

class _BeyteiEvidenceCameraPageState extends State<BeyteiEvidenceCameraPage>
    with WidgetsBindingObserver {
  static const _blue = Color(0xFF0876C9);

  CameraController? _controller;
  // Serialize camera initialization/disposal across app lifecycle changes.
  Future<void> _cameraQueue = Future<void>.value();
  bool _appActive = true;
  bool _opening = true;
  bool _capturing = false;
  bool _flash = false;
  XFile? _shot;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _queueCamera(_startCamera);
  }

  void _queueCamera(Future<void> Function() job) {
    _cameraQueue = _cameraQueue.then((_) => job()).catchError((Object error) {
      if (mounted) {
        setState(() {
          _opening = false;
          _error = 'تعذر تهيئة الكاميرا. أغلق الشاشة وحاول مجدداً.';
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _appActive = false;
      _queueCamera(_releaseCamera);
    } else if (state == AppLifecycleState.resumed) {
      _appActive = true;
      if (_shot == null) _queueCamera(_startCamera);
    }
  }

  Future<void> _releaseCamera() async {
    final old = _controller;
    _controller = null;
    if (old == null) return;
    try {
      await old.dispose();
    } catch (_) {
      // Disposal can race with OS camera teardown.
    }
  }

  Future<void> _startCamera() async {
    if (!mounted || !_appActive || _shot != null) return;
    await _releaseCamera();
    if (mounted) {
      setState(() {
        _opening = true;
        _error = null;
        _flash = false;
      });
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('camera_unavailable', 'No camera found');
      }
      if (!mounted || !_appActive || _shot != null) return;
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final next = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = next;
      await next.initialize();
      if (!mounted || !_appActive || _shot != null) {
        await _releaseCamera();
        return;
      }
      try {
        await next.setFlashMode(FlashMode.off);
      } catch (_) {
        // Older devices may not support explicit flash control.
      }
      if (mounted) setState(() => _opening = false);
    } on CameraException catch (error) {
      await _releaseCamera();
      if (!mounted) return;
      setState(() {
        _opening = false;
        _error = error.code == 'CameraAccessDenied' ||
                error.code == 'CameraAccessDeniedWithoutPrompt'
            ? 'يجب السماح لبيتي باستخدام الكاميرا من إعدادات الهاتف.'
            : 'الكاميرا غير متاحة الآن. أغلق التطبيقات التي تستخدمها وحاول مرة أخرى.';
      });
    } catch (_) {
      await _releaseCamera();
      if (!mounted) return;
      setState(() {
        _opening = false;
        _error = 'تعذر تشغيل الكاميرا. حاول مجدداً.';
      });
    }
  }

  Future<void> _takePicture() async {
    final camera = _controller;
    if (_capturing || !_appActive || camera == null ||
        !camera.value.isInitialized || camera.value.isTakingPicture) return;
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      final picture = await camera.takePicture();
      if (!mounted) return;
      if (!await File(picture.path).exists()) {
        throw const FileSystemException('Photo not available');
      }
      setState(() => _shot = picture);
      _queueCamera(_releaseCamera);
    } on CameraException catch (_) {
      if (mounted) {
        setState(() => _error = 'فشل التقاط الصورة. أعد التصوير.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر حفظ الصورة. حاول مرة ثانية.');
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _toggleFlash() async {
    final camera = _controller;
    if (camera == null || !camera.value.isInitialized || _capturing) return;
    try {
      final next = !_flash;
      await camera.setFlashMode(next ? FlashMode.always : FlashMode.off);
      if (mounted) setState(() => _flash = next);
    } catch (_) {
      if (mounted) setState(() => _error = 'الفلاش غير مدعوم في هذه الكاميرا.');
    }
  }

  void _retake() {
    setState(() {
      _shot = null;
      _error = null;
    });
    _queueCamera(_startCamera);
  }

  Future<void> _confirm() async {
    final selected = _shot;
    if (selected == null) return;
    await _cameraQueue;
    await _releaseCamera();
    if (mounted) Navigator.of(context).pop<XFile>(selected);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appActive = false;
    // Cleanup follows pending initialization, avoiding controller races.
    unawaited(_cameraQueue.then((_) => _releaseCamera()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _controller;
    final ready = camera != null && camera.value.isInitialized &&
        !_opening && _appActive;
    return Scaffold(
      backgroundColor: const Color(0xFF101720),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101720),
        foregroundColor: Colors.white,
        title: Text(_shot == null ? 'تصوير إثبات المنتج' : 'تأكيد الصورة'),
        centerTitle: true,
        actions: [
          if (_shot == null && ready)
            IconButton(
              tooltip: _flash ? 'إيقاف الفلاش' : 'تشغيل الفلاش',
              onPressed: _capturing ? null : _toggleFlash,
              icon: Icon(_flash ? Icons.flash_on : Icons.flash_off),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _shot != null
                    ? Image.file(File(_shot!.path),
                        cacheWidth: 1200, fit: BoxFit.contain)
                    : ready
                        ? CameraPreview(camera!)
                        : _error != null
                            ? Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.white70, size: 45),
                                    const SizedBox(height: 16),
                                    Text(_error!, textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 16)),
                                    const SizedBox(height: 20),
                                    FilledButton(
                                      onPressed: _appActive && !_capturing
                                          ? () => _queueCamera(_startCamera)
                                          : null,
                                      child: const Text('إعادة المحاولة'),
                                    ),
                                  ],
                                ),
                              )
                            : const CircularProgressIndicator(
                                color: _blue),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 10, 24, 10),
              child: Text('خلي صورة الإثبات واضحة وبإضاءة كافية',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _shot != null
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: _retake,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة التصوير'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _blue,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: _confirm,
                            icon: const Icon(Icons.check),
                            label: const Text('استخدام الصورة'),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _blue),
                        onPressed: ready && !_capturing ? _takePicture : null,
                        icon: _capturing
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.camera_alt, size: 25),
                        label: Text(_capturing ? 'جارٍ التصوير...' : 'التقاط صورة',
                            style: const TextStyle(fontSize: 17)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
