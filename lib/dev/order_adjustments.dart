import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'beytei_evidence_camera.dart';

/// Restaurant order adjustments are validated and applied by the delivery API.
/// This screen never edits order amounts locally and does not change dispatch.
class DriverOrderAdjustmentPage extends StatefulWidget {
  final Map<String, dynamic> order;
  final String bearerToken;

  const DriverOrderAdjustmentPage({
    super.key,
    required this.order,
    required this.bearerToken,
  });

  @override
  State<DriverOrderAdjustmentPage> createState() =>
      _DriverOrderAdjustmentPageState();
}

class _DriverOrderAdjustmentPageState extends State<DriverOrderAdjustmentPage>
    with WidgetsBindingObserver {
  static const _brand = Color(0xFF0876C9);
  static const _cardRadius = 16.0;

  final _picker = ImagePicker();
  final _scroll = ScrollController();
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unitPrice = TextEditingController();
  final _newTotal = TextEditingController();

  String _action = 'remove_item';
  List<Map<String, dynamic>> _lines = [];
  int? _selected;
  String? _savedLineHash;
  XFile? _photo;
  String? _requestUuid;
  String? _error;
  String? _success;
  bool _loading = true;
  bool _busy = false;
  bool _picking = false;
  bool _recovering = false;
  bool _preparingPhoto = false;
  int? _proofBytes;
  bool _savedAny = false;
  int? _currentCollection;

  int get _id => int.tryParse((widget.order['id'] ?? '').toString()) ?? 0;
  String get _endpoint =>
      'https://de.beytei.com/api/taxi/v3/driver/orders/$_id';
  String get _draftKey => 'beytei_v44_order_edit_draft_$_id';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _name.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _newTotal.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_picking) {
      _recoverLostPhoto();
    }
  }

  Future<void> _initialize() async {
    await _restoreDraft();
    await _recoverLostPhoto();
    await _load();
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, jsonEncode({
        'action': _action,
        'line_hash': _savedLineHash,
        'name': _name.text,
        'quantity': _quantity.text,
        'unit_price': _unitPrice.text,
        'new_total': _newTotal.text,
        'proof_path': _photo?.path,
        'request_uuid': _requestUuid,
      }));
    } catch (_) {
      // A draft-save failure must never prevent the driver's normal workflow.
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;
      final action = data['action']?.toString();
      if (action == 'remove_item' || action == 'change_price' ||
          action == 'add_item') {
        _action = action!;
      }
      _savedLineHash = data['line_hash']?.toString();
      _name.text = data['name']?.toString() ?? '';
      _quantity.text = data['quantity']?.toString() ?? '1';
      _unitPrice.text = data['unit_price']?.toString() ?? '';
      _newTotal.text = data['new_total']?.toString() ?? '';
      _requestUuid = data['request_uuid']?.toString();
      final path = data['proof_path']?.toString();
      if (path != null && path.isNotEmpty && await File(path).exists()) {
        _photo = XFile(path);
        _proofBytes = await File(path).length();
      }
    } catch (_) {
      // Invalid old drafts must not crash the editor.
    }
  }

  Future<void> _discardDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  Future<void> _recoverLostPhoto() async {
    if (_recovering || _picking) return;
    _recovering = true;
    try {
      final lost = await _picker.retrieveLostData();
      if (lost.isEmpty) return;
      if (lost.exception != null) {
        _setError('تعذر استعادة الصورة بعد الرجوع من الكاميرا. حاول مرة أخرى.');
        return;
      }
      if (lost.files != null && lost.files!.isNotEmpty) {
        await _retainPhoto(lost.files!.first);
      } else if (lost.file != null) {
        await _retainPhoto(lost.file!);
      }
    } catch (_) {
      // Some iOS picker implementations don't have Android lost-data state.
    } finally {
      _recovering = false;
    }
  }

  /// Convert the camera/gallery proof to a compact JPEG *before* upload.
  /// Keep enough resolution to read labels and receipts; Laravel accepts JPEG
  /// and enforces a 3 MiB maximum. Never upload a file with a false extension.
  Future<void> _retainPhoto(XFile selected) async {
    if (_preparingPhoto) return;
    final sourceFile = File(selected.path);
    if (!await sourceFile.exists()) {
      _setError('تعذر قراءة الصورة. اخترها مرة أخرى.');
      return;
    }
    if (mounted) setState(() => _preparingPhoto = true);
    try {
      final dir = await getApplicationSupportDirectory();
      final photoDir = Directory('${dir.path}/beytei_order_edit_proofs');
      await photoDir.create(recursive: true);
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final jpeg = File('${photoDir.path}/proof_${_id}_$stamp.jpg');
      File ready;

      try {
        // Quality-first adaptive compression: keep the first acceptable
        // quality result instead of blindly forcing every proof to 100 KiB.
        // Most photos should be <500 KiB; receipts remain readable.
        // If the scene is complex, use a slightly bigger proof rather
        // than destroying the evidence just to hit an arbitrary target.
        const targetBytes = 500 * 1024;
        const hardMaxBytes = 3 * 1024 * 1024;
        const variants = <(int, int)>[
          (1600, 78),
          (1440, 72),
          (1280, 66),
          (1152, 60),
          (1024, 55),
        ];
        List<int>? bestBytes;
        for (final (edge, quality) in variants) {
          final candidate = await FlutterImageCompress.compressWithFile(
            sourceFile.absolute.path,
            minWidth: edge,
            minHeight: edge,
            quality: quality,
            keepExif: false,
            format: CompressFormat.jpeg,
          );
          if (candidate == null || candidate.isEmpty) continue;
          if (bestBytes == null || candidate.length < bestBytes.length) {
            bestBytes = candidate;
          }
          if (candidate.length <= targetBytes) {
            bestBytes = candidate;
            break;
          }
        }
        if (bestBytes == null || bestBytes.length > hardMaxBytes) {
          throw const FormatException('No safe compressed image.');
        }
        final bytes = bestBytes;
        await jpeg.writeAsBytes(bytes, flush: true);
        ready = jpeg;
      } catch (_) {
        // Plugin codecs may fail on rare formats. Keep a supported original
        // only if its actual size already meets the Laravel upload limit.
        final extension = sourceFile.path.split('.').last.toLowerCase();
        if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension) ||
            await sourceFile.length() > 3 * 1024 * 1024) {
          throw const _EditorFailure(
              'تعذر ضغط هذه الصورة بشكل مناسب. جرّب التصوير مجدداً أو اختر صورة أخرى.');
        }
        ready = await sourceFile.copy(
            '${photoDir.path}/proof_${_id}_$stamp.$extension');
      }
      final size = await ready.length();
      if (size > 3 * 1024 * 1024) {
        await ready.delete();
        throw const _EditorFailure('الصورة أكبر من الحد المسموح. اختر صورة أصغر.');
      }
      if (!mounted) return;
      setState(() {
        _photo = XFile(ready.path);
        _proofBytes = size;
        _error = null;
        _requestUuid = null;
      });
      await _saveDraft();
    } on _EditorFailure catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError('تعذر تجهيز الصورة للإرسال. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _preparingPhoto = false);
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      if (!_savedAny) _success = null;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 240), curve: Curves.easeOut);
    }
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _error = null;
      _success = null;
      _requestUuid = null;
    });
    _saveDraft();
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (_id <= 0) {
      setState(() {
        _loading = false;
        _error = 'رقم الطلب غير صالح.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('$_endpoint/edit-context'),
        headers: {
          'Authorization': 'Bearer ${widget.bearerToken}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));
      final body = _decode(response.body);
      if (response.statusCode != 200 || body['success'] != true ||
          body['lines'] is! List) {
        throw _EditorFailure(_apiMessage(response.statusCode, body));
      }
      final lines = (body['lines'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final selectedHash = _savedLineHash ??
          (_selected != null && _selected! < _lines.length
              ? _lines[_selected!]['line_hash']?.toString()
              : null);
      int? index;
      if (selectedHash != null) {
        for (var i = 0; i < lines.length; i++) {
          if (lines[i]['line_hash']?.toString() == selectedHash) {
            index = i;
            break;
          }
        }
      }
      if (index == null && lines.length == 1) index = 0;
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _selected = index;
        _savedLineHash = index == null ? null : lines[index]['line_hash']?.toString();
        _currentCollection = _asInt(body['total_to_collect_iqd']);
      });
      if (!_savedAny) _saveDraft();
    } on _EditorFailure catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError('تعذر تحميل منتجات الطلب. تحقق من الاتصال ثم اضغط تحديث.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy || _picking || _preparingPhoto) return;
    FocusScope.of(context).unfocus();
    await _saveDraft();
    _picking = true;
    var needsLostDataRecovery = false;
    try {
      // Camera stays INSIDE Beytei: no external Android camera Activity.
      // The gallery still uses the system photo picker with lost-data recovery.
      final XFile? selected;
      if (source == ImageSource.camera) {
        selected = await Navigator.of(context).push<XFile>(
          MaterialPageRoute<XFile>(
            builder: (_) => const BeyteiEvidenceCameraPage(),
          ),
        );
      } else {
        selected = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
      }
      if (selected != null) {
        await _retainPhoto(selected);
      } else if (source == ImageSource.gallery) {
        needsLostDataRecovery = true;
      }
    } on PlatformException catch (_) {
      _setError('تعذر فتح الكاميرا أو معرض الصور. تحقق من صلاحية الوصول للصور.');
    } catch (_) {
      _setError('تعذر حفظ الصورة. حاول مجدداً أو اخترها من المعرض.');
    } finally {
      _picking = false;
      // Recovery must happen only AFTER clearing the picker flag; otherwise
      // _recoverLostPhoto() would deliberately return without doing anything.
      if (needsLostDataRecovery && mounted) await _recoverLostPhoto();
    }
  }

  static Map<String, dynamic> _decode(String source) {
    try {
      final parsed = jsonDecode(source);
      return parsed is Map ? Map<String, dynamic>.from(parsed) : {};
    } catch (_) {
      return {};
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  static int? _moneyInput(String input) {
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final cleaned = StringBuffer();
    for (final character in input.trim().split('')) {
      if (character == ',' || character == '٬' || character == ' ') continue;
      final arabic = eastern.indexOf(character);
      final farsi = persian.indexOf(character);
      cleaned.write(arabic != -1 ? arabic : farsi != -1 ? farsi : character);
    }
    return int.tryParse(cleaned.toString());
  }

  String _apiMessage(int status, Map<String, dynamic> body) {
    final code = body['code']?.toString();
    const errors = <String, String>{
      'unauthorized': 'انتهت جلسة الدخول. أغلق الشاشة وسجّل الدخول من جديد.',
      'feature_disabled': 'تعديل الطلبات غير متاح حالياً. حاول لاحقاً.',
      'pilot_restricted': 'هذا الطلب غير مشمول بالتعديل حالياً.',
      'not_assigned': 'الطلب لم يعد مسنداً إلى حسابك.',
      'order_locked': 'انتهت إمكانية التعديل؛ يمكن التعديل قبل استلام الطلب فقط.',
      'order_lines_missing': 'تفاصيل المنتجات غير موجودة في بيانات الطلب. يجب تصحيحها من السيرفر.',
      'invalid_line_totals': 'توجد مشكلة في أسعار المنتجات الأصلية. لا يمكن تعديل الطلب بأمان.',
      'order_total_mismatch': 'مجموع أسعار المنتجات لا يطابق مبلغ الطلب. يجب تصحيح بيانات الطلب أولاً.',
      'restaurant_ownership_missing': 'بيانات المطعم غير مكتملة لهذا الطلب.',
      'stale_line': 'تغير المنتج أثناء التعديل. اضغط تحديث واختر المنتج من جديد.',
      'invalid_amount': 'المبلغ المطلوب غير صالح.',
      'invalid_quantity': 'كمية المنتج غير صالحة.',
      'invalid_proposal': 'اختر سعراً مختلفاً عن السعر الحالي.',
      'discount_exceeds_remaining_food': 'قيمة الخصم أكبر من مجموع المنتجات بعد التعديل. يلزم مراجعة الطلب.',
      'food_total_out_of_range': 'مجموع الطلب الناتج خارج الحد المسموح.',
      'too_many_edits': 'بلغ الطلب الحد الأعلى من التعديلات.',
      'internal_error': 'حدث خطأ أثناء حفظ التعديل في السيرفر. حاول مرة أخرى.',
    };
    if (code != null && errors.containsKey(code)) return errors[code]!;
    if (status == 401) return 'انتهت جلسة الدخول. سجّل الدخول من جديد.';
    if (status == 403) return 'ليس لديك صلاحية تعديل هذا الطلب.';
    if (status == 404) return 'لم يتم العثور على الطلب أو لم يعد مسنداً إليك.';
    if (status == 409) return 'تغيرت بيانات الطلب. اضغط تحديث ثم أعد المحاولة.';
    if (status == 413) return 'حجم الصورة كبير. التقط صورة أصغر.';
    if (status == 422) {
      final details = body['errors'];
      if (details is Map) {
        if (details.containsKey('proof')) return 'صيغة الصورة غير مدعومة أو حجمها أكبر من 3 ميغابايت.';
        if (details.containsKey('line_index') || details.containsKey('line_hash')) {
          return 'يرجى اختيار المنتج المراد تعديله.';
        }
        if (details.containsKey('proposed_total_iqd') ||
            details.containsKey('unit_price_iqd')) {
          return 'تحقق من السعر الجديد، يجب ألا يتجاوز خمسة ملايين دينار.';
        }
      }
      return 'بعض بيانات التعديل غير صحيحة. تحقق من المنتج والسعر والصورة.';
    }
    if (status >= 500) return 'خطأ مؤقت في السيرفر (HTTP $status). حاول مجدداً.';
    return 'تعذر حفظ التعديل (HTTP $status). حاول مجدداً.';
  }

  String? _validate() {
    if (_action != 'add_item') {
      if (_lines.isEmpty) return 'لا توجد منتجات في الطلب لتعديلها.';
      if (_selected == null || _selected! >= _lines.length) {
        return 'اختر المنتج الذي تريد تعديله.';
      }
    }
    if (_action == 'add_item') {
      if (_name.text.trim().length < 2) return 'اكتب اسم المنتج الجديد.';
      final quantity = _moneyInput(_quantity.text);
      if (quantity == null || quantity < 1 || quantity > 50) {
        return 'أدخل كمية صحيحة من 1 إلى 50.';
      }
      final price = _moneyInput(_unitPrice.text);
      if (price == null || price < 1 || price > 5000000 ||
          price * quantity > 5000000) {
        return 'تحقق من سعر الوحدة وإجمالي المنتج (الحد الأعلى خمسة ملايين دينار).';
      }
    }
    if (_action == 'change_price') {
      final price = _moneyInput(_newTotal.text);
      if (price == null || price < 0 || price > 5000000) {
        return 'أدخل السعر الإجمالي الجديد للمنتج بشكل صحيح.';
      }
      final current = _asInt(_lines[_selected!]['total_iqd']);
      if (current != null && current == price) {
        return 'السعر الجديد يساوي السعر الحالي. أدخل سعراً مختلفاً.';
      }
    }
    if (_photo == null) return 'أرفق صورة إثبات قبل حفظ التعديل.';
    if (!File(_photo!.path).existsSync()) return 'الصورة لم تعد متاحة. اختر صورة أخرى.';
    return null;
  }

  String get _automaticReason {
    switch (_action) {
      case 'remove_item':
        return 'إزالة المنتج لأنه غير متوفر لدى المطعم';
      case 'change_price':
        return 'تعديل سعر المنتج المسجل في الطلب';
      default:
        return 'إضافة منتج جديد إلى الطلب أثناء التجهيز';
    }
  }

  Future<void> _submit() async {
    if (_busy || _loading || _picking || _preparingPhoto) return;
    FocusScope.of(context).unfocus();
    final validation = _validate();
    if (validation != null) {
      _setError(validation);
      return;
    }
    _requestUuid ??= const Uuid().v4();
    await _saveDraft();
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_endpoint/edits'))
        ..headers['Authorization'] = 'Bearer ${widget.bearerToken}'
        ..headers['Accept'] = 'application/json'
        ..fields['action'] = _action
        ..fields['reason'] = _automaticReason
        ..fields['request_uuid'] = _requestUuid!;

      if (_action == 'add_item') {
        request.fields['item_name'] = _name.text.trim();
        request.fields['quantity'] = _moneyInput(_quantity.text).toString();
        request.fields['unit_price_iqd'] = _moneyInput(_unitPrice.text).toString();
      } else {
        final selectedLine = _lines[_selected!];
        request.fields['line_index'] = selectedLine['line_index'].toString();
        request.fields['line_hash'] = selectedLine['line_hash'].toString();
        if (_action == 'change_price') {
          request.fields['proposed_total_iqd'] = _moneyInput(_newTotal.text).toString();
        }
      }
      final proofFile = File(_photo!.path);
      if (await proofFile.length() > 3 * 1024 * 1024) {
        throw const _EditorFailure('الصورة أكبر من 3 ميغابايت. اختر صورة أصغر.');
      }
      request.files.add(await http.MultipartFile.fromPath('proof', proofFile.path));
      final responseStream = await request.send().timeout(const Duration(seconds: 40));
      final response = await http.Response.fromStream(responseStream);
      final body = _decode(response.body);
      if ((response.statusCode != 200 && response.statusCode != 201) ||
          body['success'] != true) {
        throw _EditorFailure(_apiMessage(response.statusCode, body));
      }
      final updated = body['amounts'];
      final collection = updated is Map ? _asInt(updated['total_to_collect_iqd']) : null;
      await _discardDraft();
      if (!mounted) return;
      _name.clear();
      _quantity.text = '1';
      _unitPrice.clear();
      _newTotal.clear();
      setState(() {
        _savedAny = true;
        _success = collection == null
            ? 'تم حفظ التعديل بنجاح.'
            : 'تم حفظ التعديل. المبلغ المطلوب تحصيله الآن: $collection د.ع';
        _currentCollection = collection ?? _currentCollection;
        _photo = null;
        _proofBytes = null;
        _requestUuid = null;
        _selected = null;
        _savedLineHash = null;
      });
      await _load();
      if (!mounted) return;
      setState(() => _success ??= 'تم حفظ التعديل بنجاح.');
    } on _EditorFailure catch (e) {
      _setError(e.message);
    } on SocketException catch (_) {
      _setError('تعذر الاتصال بالإنترنت. تأكد من الشبكة ثم أعد المحاولة.');
    } catch (_) {
      _setError('تعذر إكمال إرسال التعديل. تحقق من الشبكة ثم حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _close() => Navigator.of(context).pop(_savedAny);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_savedAny,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _savedAny) _close();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF15243A),
          title: const Text('تعديل محتويات الطلب',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'الرجوع إلى الطلب',
            onPressed: _close,
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث المنتجات',
              onPressed: _busy || _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading && _lines.isEmpty
            ? const Center(child: CircularProgressIndicator(color: _brand))
            : Column(children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _orderBanner(),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _messageBanner(_error!, false),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 12),
                        _messageBanner(_success!, true),
                      ],
                      const SizedBox(height: 20),
                      _sectionTitle('1', 'شنو تريد تعدّل؟'),
                      const SizedBox(height: 12),
                      _choice(
                        'remove_item', 'منتج غير متوفر',
                        'إزالة المنتج من الطلب وخصم قيمته',
                        Icons.remove_circle_outline,
                      ),
                      const SizedBox(height: 8),
                      _choice(
                        'change_price', 'تغيير سعر منتج',
                        'تحديث سعر أحد منتجات الطلب',
                        Icons.price_change_outlined,
                      ),
                      const SizedBox(height: 8),
                      _choice(
                        'add_item', 'إضافة منتج',
                        'إضافة منتج جديد إلى الطلب',
                        Icons.add_circle_outline,
                      ),
                      const SizedBox(height: 22),
                      _sectionTitle('2', _action == 'add_item'
                          ? 'بيانات المنتج الجديد' : 'اختار المنتج من الطلب'),
                      const SizedBox(height: 12),
                      if (_action == 'add_item') _addFields()
                      else _productOptions(),
                      if (_action == 'change_price') ...[
                        const SizedBox(height: 12),
                        _input(_newTotal, 'السعر الجديد للمنتج (د.ع)',
                            Icons.payments_outlined,
                            keyboard: TextInputType.number,
                            onChanged: (_) => _update(() {})),
                        const Padding(
                          padding: EdgeInsets.only(top: 6, right: 6),
                          child: Text('اكتب سعر المنتج بالكامل، وليس فرق السعر.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF67768C))),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _sectionTitle('3', 'صورة الإثبات'),
                      const SizedBox(height: 8),
                      const Text('صوّر المنتج أو اختر صورة واضحة من المعرض.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF67768C))),
                      const SizedBox(height: 12),
                      if (_preparingPhoto) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Row(children: [
                            SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 10),
                            Expanded(child: Text('جارٍ ضغط صورة الإثبات لتسريع الرفع...',
                              style: TextStyle(fontSize: 13, color: Color(0xFF44617B)))),
                          ]),
                        ),
                      ],
                      Row(children: [
                        Expanded(child: _imageButton(
                            'الكاميرا', Icons.photo_camera_outlined, ImageSource.camera)),
                        const SizedBox(width: 10),
                        Expanded(child: _imageButton(
                            'المعرض', Icons.photo_library_outlined, ImageSource.gallery)),
                      ]),
                      if (_photo != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(_photo!.path),
                            height: 190,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                _messageBanner('لا يمكن عرض الصورة، اختر غيرها.', false),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.check_circle, color: Color(0xFF13815D), size: 17),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                              _proofBytes == null
                                  ? 'صورة الإثبات جاهزة للرفع السريع'
                                  : 'صورة الإثبات جاهزة · ${(_proofBytes! / 1024).ceil()} كيلوبايت',
                              style: const TextStyle(
                                  color: Color(0xFF13815D), fontSize: 13))),
                        ]),
                      ],
                      const SizedBox(height: 10),
                      const Text('ما تحتاج تكتب سبب؛ نوع التعديل يحدد السبب تلقائياً.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF67768C))),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE5EAF1))),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _brand,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _busy || _loading || _picking || _preparingPhoto ? null : _submit,
                          icon: _busy
                              ? const SizedBox(height: 18, width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle_outline),
                          label: Text(_busy ? 'جارٍ حفظ التعديل...' : _preparingPhoto ? 'جارٍ تجهيز الصورة...' : 'حفظ التعديل',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (_savedAny) TextButton.icon(
                        onPressed: _close,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('العودة إلى الطلب'),
                      ),
                    ]),
                  ),
                ),
              ]),
      ),
    );
  }

  Widget _orderBanner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F4FD),
      borderRadius: BorderRadius.circular(_cardRadius),
    ),
    child: Row(children: [
      const Icon(Icons.receipt_long_outlined, color: _brand, size: 30),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الطلب رقم #$_id',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                  color: Color(0xFF153452))),
          if (_currentCollection != null)
            Text('المبلغ المطلوب تحصيله: $_currentCollection د.ع',
                style: const TextStyle(fontSize: 13, color: Color(0xFF3B6080))),
        ],
      )),
    ]),
  );

  Widget _messageBanner(String message, bool success) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: success ? const Color(0xFFE8F8F1) : const Color(0xFFFFF0EC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: success
          ? const Color(0xFFB2E5CF) : const Color(0xFFFFCEBF)),
    ),
    child: Row(children: [
      Icon(success ? Icons.check_circle_outline : Icons.info_outline,
          color: success ? const Color(0xFF13815D) : const Color(0xFFBC533E)),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
          style: TextStyle(fontSize: 13, color: success
              ? const Color(0xFF14583F) : const Color(0xFF9A3624)))),
    ]),
  );

  Widget _sectionTitle(String number, String title) => Row(children: [
    CircleAvatar(
      radius: 13,
      backgroundColor: _brand,
      child: Text(number, style: const TextStyle(
          color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
    ),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(
        fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF172D44))),
  ]);

  Widget _choice(String type, String title, String subtitle, IconData icon) {
    final active = _action == type;
    return Material(
      color: active ? const Color(0xFFE8F4FD) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _busy ? null : () => _update(() => _action = type),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? _brand : const Color(0xFFE4E9F0),
                width: active ? 1.5 : 1),
          ),
          child: Row(children: [
            Icon(icon, color: active ? _brand : const Color(0xFF667990), size: 26),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Color(0xFF203550), fontSize: 14)),
                Text(subtitle, style: const TextStyle(
                    color: Color(0xFF6B7A90), fontSize: 12)),
              ],
            )),
            Icon(active ? Icons.radio_button_checked : Icons.radio_button_off,
                color: active ? _brand : const Color(0xFFAAB7C7)),
          ]),
        ),
      ),
    );
  }

  Widget _productOptions() {
    if (_lines.isEmpty) {
      return _messageBanner('لم تصل قائمة المنتجات لهذا الطلب. اضغط تحديث. '
          'إذا استمرت المشكلة، يلزم تصحيح بيانات الأصناف على السيرفر.', false);
    }
    return Column(children: [
      for (var i = 0; i < _lines.length; i++) ...[
        _productOption(i),
        if (i != _lines.length - 1) const SizedBox(height: 8),
      ],
    ]);
  }

  Widget _productOption(int index) {
    final line = _lines[index];
    final active = index == _selected;
    final name = (line['name'] ?? 'منتج').toString();
    final quantity = _asInt(line['quantity']) ?? 1;
    final price = _asInt(line['total_iqd']);
    return Material(
      color: active ? const Color(0xFFE8F4FD) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _busy ? null : () => _update(() {
          _selected = index;
          _savedLineHash = line['line_hash']?.toString();
        }),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? _brand : const Color(0xFFE4E9F0)),
          ),
          child: Row(children: [
            Icon(active ? Icons.check_circle : Icons.circle_outlined,
                color: active ? _brand : const Color(0xFFA7B1C0)),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600))),
            const SizedBox(width: 6),
            Text('×$quantity${price == null ? '' : '  ·  $price د.ع'}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF61758B))),
          ]),
        ),
      ),
    );
  }

  Widget _input(TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboard, ValueChanged<String>? onChanged}) => TextField(
    controller: controller,
    keyboardType: keyboard,
    textInputAction: TextInputAction.next,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _brand, size: 22),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _brand, width: 1.5),
      ),
    ),
  );

  Widget _addFields() => Column(children: [
    _input(_name, 'اسم المنتج', Icons.fastfood_outlined,
        onChanged: (_) => _update(() {})),
    const SizedBox(height: 10),
    _input(_quantity, 'الكمية', Icons.numbers,
        keyboard: TextInputType.number, onChanged: (_) => _update(() {})),
    const SizedBox(height: 10),
    _input(_unitPrice, 'سعر الوحدة (د.ع)', Icons.payments_outlined,
        keyboard: TextInputType.number, onChanged: (_) => _update(() {})),
    Builder(builder: (context) {
      final quantity = _moneyInput(_quantity.text);
      final unit = _moneyInput(_unitPrice.text);
      if (quantity == null || unit == null || quantity < 1 || unit < 1) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text('إجمالي المنتج: ${quantity * unit} د.ع',
              style: const TextStyle(color: _brand, fontWeight: FontWeight.bold)),
        ),
      );
    }),
  ]);

  Widget _imageButton(String title, IconData icon, ImageSource source) =>
      OutlinedButton.icon(
        onPressed: _busy || _picking || _preparingPhoto ? null : () => _pick(source),
        style: OutlinedButton.styleFrom(
          foregroundColor: _brand,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: Color(0xFFCBDDED)),
        ),
        icon: Icon(icon, size: 21),
        label: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}

class _EditorFailure implements Exception {
  final String message;
  const _EditorFailure(this.message);
}
