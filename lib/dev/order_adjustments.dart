import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Proof uploads are sent ONLY to de.beytei.com (Laravel).
/// A submitted proposal NEVER alters the amount collected from the customer.
class DriverOrderAdjustmentPage extends StatefulWidget {
  final Map<String, dynamic> order;
  final String bearerToken;
  const DriverOrderAdjustmentPage({super.key, required this.order, required this.bearerToken});
  @override State<DriverOrderAdjustmentPage> createState() => _DriverOrderAdjustmentPageState();
}

class _DriverOrderAdjustmentPageState extends State<DriverOrderAdjustmentPage> {
  final _reason = TextEditingController();
  final _amount = TextEditingController();
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unitPrice = TextEditingController();
  String _action = 'remove_item';
  List<Map<String, dynamic>> _lines = [];
  int? _selected;
  XFile? _photo;
  String? _requestUuid;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  int get _id => int.tryParse((widget.order['id'] ?? '').toString()) ?? 0;
  String get _root => 'https://de.beytei.com/api/taxi/v3/driver/orders/' + _id.toString();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() {
    _reason.dispose(); _amount.dispose(); _name.dispose();
    _quantity.dispose(); _unitPrice.dispose(); super.dispose();
  }
  void _changed(VoidCallback update) {
    setState(() { update(); _requestUuid = null; });
  }
  Future<void> _load() async {
    if (_id < 1) { setState(() { _loading = false; _error = 'رقم الطلب غير صالح'; }); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final r = await http.get(Uri.parse(_root + '/edit-context'), headers: {
        'Authorization': 'Bearer ' + widget.bearerToken,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 20));
      final body = jsonDecode(r.body);
      if (r.statusCode != 200 || body is! Map || body['success'] != true ||
          body['lines'] is! List) {
        throw StateError('فشل جلب المنتجات من Laravel (HTTP ' + r.statusCode.toString() + ')');
      }
      if (mounted) setState(() {
        _lines = (body['lines'] as List).whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)).toList();
        _selected = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر جلب تفاصيل التعديل. تحقق من الاتصال والصلاحيات.');
    } finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _pick(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source,
          maxWidth: 1600, maxHeight: 1600, imageQuality: 75);
      if (image != null && mounted) _changed(() => _photo = image);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الكاميرا أو المعرض')));
    }
  }
  Future<void> _submit() async {
    if (_busy) return;
    final qty = int.tryParse(_quantity.text.trim());
    final unit = int.tryParse(_unitPrice.text.trim());
    final price = int.tryParse(_amount.text.trim());
    if (_photo == null || _reason.text.trim().length < 8 ||
        (_action != 'add_item' && _selected == null) ||
        (_action == 'change_price' && (price == null || price < 0 || price % 250 != 0)) ||
        (_action == 'add_item' && (_name.text.trim().length < 2 ||
            qty == null || qty < 1 || qty > 50 ||
            unit == null || unit < 250 || unit % 250 != 0))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('اختر المنتج وصورة الإثبات وسبباً واضحاً، والتزم بمضاعفات 250 دينار.')));
      return;
    }
    _requestUuid ??= const Uuid().v4();
    setState(() => _busy = true);
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_root + '/edits'))
        ..headers['Authorization'] = 'Bearer ' + widget.bearerToken
        ..headers['Accept'] = 'application/json'
        ..fields['action'] = _action
        ..fields['reason'] = _reason.text.trim()
        ..fields['request_uuid'] = _requestUuid!;
      if (_action == 'add_item') {
        request.fields['item_name'] = _name.text.trim();
        request.fields['quantity'] = qty.toString();
        request.fields['unit_price_iqd'] = unit.toString();
      } else {
        final line = _lines[_selected!];
        request.fields['line_index'] = line['line_index'].toString();
        request.fields['line_hash'] = line['line_hash'].toString();
        if (_action == 'change_price') {
          request.fields['proposed_total_iqd'] = price.toString();
        }
      }
      final file = File(_photo!.path);
      if (await file.length() > 3 * 1024 * 1024) {
        throw const FormatException('الصورة أكبر من 3 ميغابايت.');
      }
      request.files.add(await http.MultipartFile.fromPath('proof', _photo!.path));
      final streamed = await request.send().timeout(const Duration(seconds: 40));
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body);
      if (![200,201].contains(response.statusCode) || body is! Map || body['success'] != true) {
        throw StateError('رفض السيرفر حفظ الإثبات (HTTP ' + response.statusCode.toString() + ')');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم حفظ طلب التعديل والصورة على Laravel. المبلغ لم يتغيّر بعد.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تعذر حفظ الإثبات: ' + e.toString())));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تعديل منتج مع صورة إثبات'),
      actions: [IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))]),
    body: _loading ? const Center(child: CircularProgressIndicator())
    : _error != null ? Center(child: Text(_error!))
    : ListView(padding: const EdgeInsets.all(16), children: [
      const Text('التعديل مقترح للمراجعة، ولا يغيّر مبلغ الزبون تلقائياً.'),
      DropdownButtonFormField<String>(
        value: _action, decoration: const InputDecoration(labelText: 'نوع العملية'),
        items: const [
          DropdownMenuItem(value:'remove_item',child:Text('إزالة منتج غير متوفر')),
          DropdownMenuItem(value:'change_price',child:Text('تغيير سعر منتج')),
          DropdownMenuItem(value:'add_item',child:Text('إضافة منتج جديد')),
        ],
        onChanged: _busy ? null : (v) => _changed(() { _action = v ?? 'remove_item'; _selected = null; }),
      ),
      if (_action != 'add_item') DropdownButtonFormField<int>(
        value: _selected, isExpanded: true,
        decoration: const InputDecoration(labelText: 'المنتج'),
        items: [for(var i=0;i<_lines.length;i++) DropdownMenuItem(
          value:i,child:Text((_lines[i]['name'] ?? 'منتج').toString(),
            overflow:TextOverflow.ellipsis))],
        onChanged: _busy ? null : (v) => _changed(() => _selected = v),
      ),
      if (_action == 'change_price') TextField(controller:_amount,
        keyboardType:TextInputType.number, decoration:const InputDecoration(
          labelText:'السعر الجديد للسطر (مضاعفات 250)')),
      if (_action == 'add_item') ...[
        TextField(controller:_name,decoration:const InputDecoration(labelText:'اسم المنتج')),
        TextField(controller:_quantity,keyboardType:TextInputType.number,
          decoration:const InputDecoration(labelText:'الكمية')),
        TextField(controller:_unitPrice,keyboardType:TextInputType.number,
          decoration:const InputDecoration(labelText:'سعر الوحدة (مضاعفات 250)')),
      ],
      TextField(controller:_reason,minLines:2,maxLines:4,
        decoration:const InputDecoration(labelText:'سبب التعديل')),
      Wrap(spacing:8,children:[
        TextButton.icon(onPressed:_busy?null:()=>_pick(ImageSource.camera),
          icon:const Icon(Icons.camera_alt),label:const Text('تصوير')),
        TextButton.icon(onPressed:_busy?null:()=>_pick(ImageSource.gallery),
          icon:const Icon(Icons.photo_library),label:const Text('المعرض')),
      ]),
      if (_photo != null) Image.file(File(_photo!.path),height:170),
      const SizedBox(height:12),
      FilledButton(onPressed:_busy?null:_submit,
        child:Text(_busy?'جارٍ الرفع...':'إرسال التعديل والإثبات إلى Laravel')),
    ]),
  );
}
