// Beytei / Delivery app: a separate poster-distribution feature.
// No change to normal order acceptance, wallets, driver login, or competition.
// Poster worker access token is independent of the delivery AuthResult.
// Requires flutter_map, latlong2, geolocator + platform implementation imports,
// http and flutter_secure_storage.
// Poster worker -> taxi.beytei.com direct API (no de backend relay).
// User-initiated tracking continues with the app minimized or the screen locked.
// Android uses a visible foreground location notification; iOS uses Background Modes.
// It is NOT designed to restart after a force-stop, logout or process termination.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:geolocator_android/geolocator_android.dart' as geo_android;
import 'package:geolocator_apple/geolocator_apple.dart' as geo_apple;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Public entry: poster workers authenticate separately from food delivery.
class PosterDistributionEntry extends StatelessWidget {
  const PosterDistributionEntry({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal:16, vertical:5),
    child: Material(
      color: const Color(0xFFEFF7FF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const PosterWorkerAccessPage(),
        )),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB7D8F2)),
          ),
          child: const Row(children: [
            CircleAvatar(backgroundColor: Color(0xFF1175C1),
                child: Icon(Icons.route_outlined,color: Colors.white)),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('توزيع البوسترات',style: TextStyle(
                    fontWeight:FontWeight.w800,fontSize:15,color:Color(0xFF164B7A))),
                SizedBox(height:3),
                Text('دخول بالاسم والهاتف وكلمة السر • خريطة الجولة',
                    style: TextStyle(fontSize:11.5,color:Color(0xFF52718E))),
              ],
            )),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFF1175C1),size:16),
          ]),
        ),
      ),
    ),
  );
}

class PosterWorkerAccessPage extends StatefulWidget {
  const PosterWorkerAccessPage({super.key});
  @override
  State<PosterWorkerAccessPage> createState()=>_PosterWorkerAccessPageState();
}

class _PosterWorkerAccessPageState extends State<PosterWorkerAccessPage> {
  static const _storageKey = 'beytei_poster_worker_auth_v4';
  static const _base = 'https://taxi.beytei.com/api/poster-agent/v1';
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _loading=true;
  String? _error;
  String? _sessionToken;
  String? _workerName;
  int? _workerId;

  @override
  void initState(){super.initState();_restore();}

  Future<void> _restore() async {
    try {
      final raw=await _storage.read(key:_storageKey);
      if(raw != null) {
        final json=jsonDecode(raw);
        if(json is Map && json['access_token'] is String && json['worker_id'] is int) {
          final token=json['access_token'] as String;
          final res=await http.get(Uri.parse('$_base/me'), headers:{
            'Authorization':'Bearer $token','Accept':'application/json',
          }).timeout(const Duration(seconds:10));
          if(res.statusCode == 200) {
            final data=jsonDecode(res.body);
            if(data is Map && data['status']=='success' && mounted) {
              setState((){
                _sessionToken=token;
                _workerId=json['worker_id'] as int;
                _workerName=json['worker_name']?.toString();
              });
            }
          } else if(res.statusCode==401) {
            await _storage.delete(key:_storageKey);
          }
        }
      }
    } catch (_) {
      // Connectivity failures are shown on login; never emit secret credentials.
    } finally { if(mounted)setState(()=>_loading=false); }
  }

  Future<void> _login() async {
    if(_name.text.trim().isEmpty || _phone.text.trim().isEmpty || _password.text.isEmpty) {
      setState(()=>_error='اكتب الاسم ورقم الهاتف وكلمة السر الصادرة من الإدارة.'); return;
    }
    setState((){_loading=true;_error=null;});
    try {
      final res=await http.post(Uri.parse('$_base/login'), headers:{
        'Accept':'application/json','Content-Type':'application/json',
      },body:jsonEncode({'name':_name.text.trim(),'phone':_phone.text.trim(),'password':_password.text}))
          .timeout(const Duration(seconds:15));
      final result=jsonDecode(res.body);
      if(res.statusCode!=200 || result is! Map || result['status']!='success') {
        throw StateError(result is Map ? (result['message']?.toString() ?? 'تعذر تسجيل الدخول'):
        'تعذر تسجيل الدخول (${res.statusCode})');
      }
      final worker=result['worker'];
      if(worker is! Map || worker['id'] is! int || result['access_token'] is! String) {
        throw StateError('استجابة الدخول غير صالحة');
      }
      final session=result['access_token'] as String;
      await _storage.write(key:_storageKey,value:jsonEncode({
        'access_token':session,'worker_id':worker['id'],'worker_name':worker['name'],
      }));
      if(mounted) setState((){
        _sessionToken=session;
        _workerId=worker['id'] as int;
        _workerName=worker['name']?.toString();
      });
      _password.clear();
    } catch(e) {
      if(mounted)setState(()=>_error=e.toString().replaceFirst('Bad state: ',''));
    } finally {if(mounted)setState(()=>_loading=false);}
  }

  @override
  void dispose(){_name.dispose();_phone.dispose();_password.dispose();super.dispose();}

  @override
  Widget build(BuildContext context){
    if(_sessionToken != null && _workerId != null) {
      return PosterDistributionScreen(token:_sessionToken!,driverId:_workerId.toString());
    }
    return Scaffold(
      backgroundColor:const Color(0xFFF4F8FC),
      appBar:AppBar(title:const Text('دخول توزيع البوسترات'),
          backgroundColor:const Color(0xFF1175C1),foregroundColor:Colors.white),
      body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:
      ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),child:Card(
        child:Padding(padding:const EdgeInsets.all(22),child:Column(
          mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[
            const Icon(Icons.route_outlined,color:Color(0xFF1175C1),size:60),
            const SizedBox(height:12),
            const Text('توزيع البوسترات — منصة بيتي',textAlign:TextAlign.center,
                style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),
            const SizedBox(height:8),
            const Text('لا تحتاج إلى حساب الدلفري. اطلب من الإدارة إنشاء حساب توزيع باسمك ورقم هاتفك وكلمة سر.',
                textAlign:TextAlign.center),
            const SizedBox(height:18),
            TextField(controller:_name,textDirection:TextDirection.rtl,
                decoration:const InputDecoration(labelText:'اسم المندوب',prefixIcon:Icon(Icons.person_outline))),
            const SizedBox(height:12),
            TextField(controller:_phone,keyboardType:TextInputType.phone,
                decoration:const InputDecoration(labelText:'رقم الهاتف',hintText:'078XXXXXXXX',prefixIcon:Icon(Icons.phone_outlined))),
            const SizedBox(height:12),
            TextField(controller:_password,obscureText:true,autocorrect:false,
                enableSuggestions:false,
                decoration:const InputDecoration(labelText:'كلمة السر',prefixIcon:Icon(Icons.lock_outline))),
            const SizedBox(height:15),
            if(_error != null) Padding(padding:const EdgeInsets.only(bottom:10),
                child:Text(_error!,style:const TextStyle(color:Colors.red))),
            FilledButton.icon(onPressed:_loading?null:_login,
                icon:const Icon(Icons.login),label:Text(_loading?'جارٍ الفحص...':'دخول إلى حملاتي')),
          ],
        )),
      )))),
    );
  }
}

class PosterDistributionScreen extends StatefulWidget {
  const PosterDistributionScreen({
    super.key,
    required this.token,
    required this.driverId,
  });

  final String token;
  final String driverId;

  @override
  State<PosterDistributionScreen> createState() =>
      _PosterDistributionScreenState();
}

class _PosterDistributionScreenState extends State<PosterDistributionScreen>
    with WidgetsBindingObserver {
  // Dedicated poster worker API; does not use the taxi/delivery developer token.
  static const String _apiBase =
      'https://taxi.beytei.com/api/poster-agent/v1';

  final MapController _mapController = MapController();
  final List<LatLng> _route = <LatLng>[];
  final List<_PosterVisit> _visits = <_PosterVisit>[];
  final List<Map<String, dynamic>> _pendingPositions = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _pendingVisits = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _pendingPlaces = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _approvedPlaces = <Map<String, dynamic>>[];
  // V5.2: server-synchronized map overlays, visible to all authorized workers
  // assigned to the same campaign. This does not track anybody when idle.
  List<Map<String, dynamic>> _sharedVisits = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _namedFeatures = <Map<String, dynamic>>[];
  Set<String> _mappedProposalIds = <String>{};
  bool _liveLoading = false;
  Timer? _mapRefreshDebounce;


  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Future<void> _saveChain = Future<void>.value();
  bool _mapReady = false;
  StreamSubscription<geo.Position>? _gps;
  Timer? _syncTimer;
  List<Map<String, dynamic>> _campaigns = <Map<String, dynamic>>[];
  int? _selectedCampaign;
  int? _roundId;
  String? _sessionUuid;
  String _status = 'idle'; // idle, active, paused, ended
  String? _queuedState; // pause/end pending server ACK; local GPS is already stopped
  bool _reconciling = false;
  bool _loading = true;
  bool _working = false;
  bool _syncing = false;
  bool _followLocation = true;
  bool _consent = false;
  String? _notice;
  LatLng? _me;
  double? _accuracy;
  DateTime? _lastSample;
  LatLng? _lastSamplePoint;
  DateTime? _lastVisitTime;
  DateTime? _lastBackgroundSyncAttempt;

  String get _key => 'beytei_posters_v4_${widget.driverId}';
  bool get _isActive => _status == 'active' && _roundId != null;
  bool get _hasRound => _roundId != null && _status != 'ended';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      _fetchLiveMap(); // Names and visits remain visible outside an active GPS round.
      if (_hasRound) {
        if (_queuedState != null) { _retryQueuedState(); }
        else { _flush(); }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A started field round keeps its OS-backed location stream when the
    // screen is locked or the app is minimized. Do NOT cancel it on inactive,
    // hidden or paused. Android displays a persistent location notification;
    // iOS shows its system location indicator.
    // Do not automatically restart a persisted session after a process kill:
    // the distributor must explicitly resume/confirm their consent.
    if (state == AppLifecycleState.resumed) {
      _fetchLiveMap();
      if (_isActive && _consent && _gps == null) _startGps();
      if (_hasRound) {
        if (_queuedState != null) { _retryQueuedState(); }
        else { _flush(); }
      }
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _mapRefreshDebounce?.cancel();
    _stopGps();
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final raw = await _secureStorage.read(key: _key);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw);
        if (data is Map) {
          final saved = Map<String, dynamic>.from(data);
          _roundId = (saved['round_id'] as num?)?.toInt();
          _selectedCampaign = (saved['campaign_id'] as num?)?.toInt();
          _sessionUuid = saved['session_uuid']?.toString();
          _status = saved['status']?.toString() ?? 'idle';
          _queuedState = saved['pending_state']?.toString();
          if (_queuedState == 'ended') _status = 'paused';
          if (_status == 'ended') {
            _roundId = null;
            _status = 'idle';
          }
          final pendingPositions = saved['pending_positions'];
          if (pendingPositions is List) {
            _pendingPositions.addAll(pendingPositions
                .whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
          }
          final pendingPlaces = saved['pending_places'];
          if (pendingPlaces is List) {
            _pendingPlaces.addAll(pendingPlaces.whereType<Map>()
                .map((e) => Map<String,dynamic>.from(e)));
          }
          final pendingVisits = saved['pending_visits'];
          if (pendingVisits is List) {
            _pendingVisits.addAll(pendingVisits
                .whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
          }
          final track = saved['route'];
          if (track is List) {
            for (final p in track.whereType<Map>()) {
              final lat = (p['lat'] as num?)?.toDouble();
              final lng = (p['lng'] as num?)?.toDouble();
              if (lat != null && lng != null) _route.add(LatLng(lat, lng));
            }
          }
          final visitItems = saved['visits'];
          if (visitItems is List) {
            for (final v in visitItems.whereType<Map>()) {
              final lat = (v['lat'] as num?)?.toDouble();
              final lng = (v['lng'] as num?)?.toDouble();
              if (lat == null || lng == null) continue;
              _visits.add(_PosterVisit(LatLng(lat, lng),
                  v['outcome']?.toString() ?? 'delivered'));
            }
          }
        }
      }
      await _fetchCampaigns();
      await _fetchPlaces();
      await _fetchLiveMap();
      try {
        final last = await geo.Geolocator.getLastKnownPosition();
        if (last != null && mounted) _updateMapLocation(last);
      } catch (_) { /* Optional last known location */ }
      if (_queuedState != null) {
        // Continue pending stop request, but never silently resume GPS.
        _notice = 'التتبع متوقف على هاتفك. جارٍ مزامنة حالة الجولة مع الإدارة.';
        _retryQueuedState();
      } else if (_isActive) {
        // Restored sessions are never silently tracked without consent.
        _notice = 'لديك جولة سابقة. وافق على التتبع لاستئناف إرسال الموقع.';
      }
    } catch (e) {
      _notice = 'تعذر استعادة معلومات الجولة: ${_friendlyError(e)}';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchCampaigns() async {
    try {
      final data = await _request('GET', 'campaigns');
      final list = data['data'];
      if (list is! List) throw StateError('تنسيق الحملات غير صحيح');
      _campaigns = list.whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m)).toList();
      if (_selectedCampaign == null && _campaigns.isNotEmpty) {
        _selectedCampaign = (_campaigns.first['id'] as num).toInt();
      }
      if (_campaigns.isEmpty) {
        _notice = 'لا توجد حملة مخصصة لحسابك حالياً. اطلب من الإدارة تكليفك.';
      }
    } catch (e) {
      _notice = _friendlyError(e);
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchPlaces() async {
    if (_selectedCampaign == null) return;
    try {
      final data = await _request('GET', 'geo-places?campaign_id=$_selectedCampaign');
      final arr = data['data'];
      if (arr is List) {
        _approvedPlaces = arr.whereType<Map>()
            .map((e) => Map<String,dynamic>.from(e)).toList();
        if (mounted) setState(() {});
      }
    } catch (_) { // Geo labels are optional; delivery functionality must remain available.
    }
  }

  Future<void> _fetchLiveMap() async {
    final campaignId = _selectedCampaign;
    if (campaignId == null || _liveLoading) return;
    _liveLoading = true;
    try {
      var url = 'live-map?campaign_id=$campaignId';
      if (_mapReady) {
        final bounds = _mapController.camera.visibleBounds;
        if (bounds.north > bounds.south && bounds.east > bounds.west) {
          url += '&south=${bounds.south}&north=${bounds.north}'
              '&west=${bounds.west}&east=${bounds.east}';
        }
      }
      final data = await _request('GET', url);
      if (_selectedCampaign != campaignId || !mounted) return;
      final features = data['features'];
      final visits = data['visits'];
      if (features is List && visits is List) {
        setState(() {
          _namedFeatures = features.whereType<Map>()
              .map((x) => Map<String, dynamic>.from(x)).toList();
          _mappedProposalIds = _namedFeatures
              .where((f) => f['proposal_id'] != null)
              .map((f) => f['proposal_id'].toString()).toSet();
          _sharedVisits = visits.whereType<Map>()
              .map((x) => Map<String, dynamic>.from(x)).toList();
        });
      }
    } catch (_) {
      // Cached map remains visible on poor Internet, and offline GPS queue is unchanged.
    } finally {
      _liveLoading = false;
    }
  }

  void _refreshMapAfterMove() {
    _mapRefreshDebounce?.cancel();
    _mapRefreshDebounce = Timer(const Duration(milliseconds: 900), () { _fetchLiveMap(); });
  }

  List<LatLng> _geometryOf(Map<String,dynamic> f) {
    final raw = f['geometry'];
    if (raw is! List) return const <LatLng>[];
    final out = <LatLng>[];
    for (final p in raw) {
      if (p is! Map) continue;
      final lat = num.tryParse('${p['lat']}')?.toDouble();
      final lng = num.tryParse('${p['lng']}')?.toDouble();
      if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) {
        out.add(LatLng(lat,lng));
      }
    }
    return out;
  }

  List<Polyline> _namedStreetLines() {
    final lines=<Polyline>[];
    for(final f in _namedFeatures) {
      if (f['kind'] != 'street') continue;
      final points=_geometryOf(f);
      if(points.length < 2) continue;
      lines.add(Polyline(points:points,strokeWidth:5,color:const Color(0xFF408DCA)));
    }
    return lines;
  }

  List<Polygon> _namedAreaPolygons() {
    final polygons=<Polygon>[];
    for(final f in _namedFeatures) {
      if (f['kind'] == 'street') continue;
      final points=_geometryOf(f);
      if(points.length < 3) continue;
      polygons.add(Polygon(points: points, color: const Color(0x153B9E69),
          borderColor: const Color(0xFF4B9970), borderStrokeWidth: 2));
    }
    return polygons;
  }

  List<Marker> _namedLabels() {
    final labels=<Marker>[];
    for(final f in _namedFeatures) {
      final points = _geometryOf(f);
      if(points.isEmpty) continue;
      final name=f['name']?.toString() ?? '';
      if(name.isEmpty) continue;
      if(f['kind']=='street' && points.length>=2) {
        double total=0;
        for(int i=1;i<points.length;i++) {
          total+=geo.Geolocator.distanceBetween(points[i-1].latitude,
              points[i-1].longitude,points[i].latitude,points[i].longitude);
        }
        final maxLabels = (total/200).ceil().clamp(1,6);
        for(int k=0;k<maxLabels;k++) {
          final target=(k+0.5)*total/maxLabels;
          double walked=0;
          LatLng markerPoint=points.first;
          for(int i=1;i<points.length;i++) {
            final a=points[i-1],b=points[i];
            final length=geo.Geolocator.distanceBetween(a.latitude,a.longitude,
                b.latitude,b.longitude);
            if(walked+length>=target || i==points.length-1) {
              final t=length<1?0.5:((target-walked)/length).clamp(0.0,1.0).toDouble();
              markerPoint=LatLng(a.latitude+(b.latitude-a.latitude)*t,
                  a.longitude+(b.longitude-a.longitude)*t);
              break;
            }
            walked+=length;
          }
          labels.add(Marker(point:markerPoint,width:105,height:34,child:IgnorePointer(
              child:Center(child:Container(padding:const EdgeInsets.symmetric(horizontal:4,vertical:2),
                  color:const Color(0xDEFFFFFF),
                  child:Text(name,maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,
                      style:const TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:Color(0xFF1765A0))))))));
        }
      } else {
        final lat=(num.tryParse('${f['lat']}') ?? points.first.latitude).toDouble();
        final lng=(num.tryParse('${f['lng']}') ?? points.first.longitude).toDouble();
        labels.add(Marker(point:LatLng(lat,lng),width:115,height:34,child:IgnorePointer(
            child:Center(child:Container(color:const Color(0xE8FFFFFF),
                padding:const EdgeInsets.all(3),child:Text(name,maxLines:1,
                    overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,
                        fontWeight:FontWeight.bold,color:Color(0xFF34684A))))))));
      }
    }
    return labels;
  }

  bool _isAlreadyShared(_PosterVisit visit) => _sharedVisits.any((p) {
    if(p['outcome'] != visit.outcome) return false;
    final lat=num.tryParse('${p['lat']}')?.toDouble();
    final lng=num.tryParse('${p['lng']}')?.toDouble();
    return lat!=null && lng!=null &&
        (lat-visit.position.latitude).abs()<0.000001 &&
        (lng-visit.position.longitude).abs()<0.000001;
  });

  Color _sharedColor(Map<String,dynamic> v) {
    if(v['review_status'] == 'rejected') return const Color(0xFF777777);
    switch(v['outcome']) {
      case 'delivered': return const Color(0xFF18865C);
      case 'no_answer': return const Color(0xFFDD4439);
      case 'refused': return const Color(0xFF9F1C2D);
      default: return const Color(0xFF7E7E7E);
    }
  }

  List<Marker> _allWorkerVisitMarkers() => _sharedVisits.map((v) {
    final lat=num.tryParse('${v['lat']}')?.toDouble();
    final lng=num.tryParse('${v['lng']}')?.toDouble();
    if(lat==null||lng==null||lat.abs()>90||lng.abs()>180) return null;
    final outcome=v['outcome']?.toString()??'';
    final status=v['review_status']?.toString()??'';
    final label=outcome=='delivered'?'تم التسليم':
    outcome=='no_answer'?'لا يوجد رد':'رفض الاستلام';
    return Marker(point:LatLng(lat,lng),width:32,height:35,child:
    Tooltip(message:'$label — ${status=='approved'?'معتمد':status=='pending'?'بانتظار المراجعة':'مرفوض إدارياً'}',
        child:Icon(status=='pending' ? Icons.location_on_outlined : Icons.location_on_rounded,
            color:_sharedColor(v),size:30)));
  }).whereType<Marker>().toList();

  Future<void> _proposePlace() async {
    if (!_isActive || _me == null || _accuracy == null || _accuracy! > 100) {
      _alert('ابدأ جولة وانتظر دقة GPS أفضل من 100 متر قبل اقتراح شارع أو منطقة.');
      return;
    }
    final form = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final parentCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String type = 'street';
    final submitted = await showDialog<Map<String,String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: const Text('اقتراح شارع أو منطقة غير مسجلة'),
        content: Form(key: form, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, children: [
          const Text('يرتبط المقترح بموقع GPS الحالي، ولا يصبح اسماً معتمداً حتى تراجعه الإدارة.',
              style: TextStyle(fontSize:12)),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(value:type,
              items: const [
                DropdownMenuItem(value:'street',child:Text('شارع')),
                DropdownMenuItem(value:'area',child:Text('منطقة')),
                DropdownMenuItem(value:'neighborhood',child:Text('حي')),
                DropdownMenuItem(value:'district',child:Text('قضاء')),
              ], onChanged:(v) => refresh(()=>type=v??'street'),
              decoration:const InputDecoration(labelText:'نوع المكان')),
          TextFormField(controller:nameCtrl, maxLength:120,
              decoration:const InputDecoration(labelText:'اسم الشارع / المنطقة'),
              validator:(s) => (s??'').trim().length < 2 ? 'أدخل اسماً صحيحاً' : null),
          TextFormField(controller:parentCtrl,maxLength:120,
              decoration:const InputDecoration(labelText:'المنطقة أو الحي التابع (اختياري)')),
          TextFormField(controller:notesCtrl,maxLength:250,
              decoration:const InputDecoration(labelText:'ملاحظات مفيدة (اختياري)'),maxLines:2),
        ]))),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
          FilledButton(onPressed:(){if (form.currentState!.validate()) {
            Navigator.pop(ctx, {'feature_type':type,'name':nameCtrl.text.trim(),
              'parent_name':parentCtrl.text.trim(),'notes':notesCtrl.text.trim()});
          }},child:const Text('إرسال للإدارة')),
        ],
      )),
    );
    // Controllers may be disposed after the dialog returns, not during build.
    nameCtrl.dispose(); parentCtrl.dispose(); notesCtrl.dispose();
    if (submitted == null || !mounted) return;
    final item = <String,dynamic>{
      'event_uuid':_uuidV4(),...submitted,
      'lat':_me!.latitude,'lng':_me!.longitude,
      'accuracy_m':_accuracy!.round().clamp(0,150),
      'recorded_at':DateTime.now().toUtc().toIso8601String(),
    };
    _pendingPlaces.add(item); await _save();
    final done = await _flush();
    if (mounted) _alert(done
        ? 'تم إرسال المقترح، وهو بانتظار اعتماد الإدارة.'
        : 'تم حفظ المقترح على الهاتف، وسيُرسل عند عودة الإنترنت.');
  }

  Future<Map<String, dynamic>> _request(String method, String path,
      [Map<String, dynamic>? payload]) async {
    final url = Uri.parse('$_apiBase/$path');
    final headers = <String, String>{
      'Authorization': 'Bearer ${widget.token}',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final http.Response response;
    if (method == 'GET') {
      response = await http.get(url, headers: headers)
          .timeout(const Duration(seconds: 14));
    } else {
      response = await http.post(url, headers: headers,
          body: jsonEncode(payload ?? const <String, dynamic>{}))
          .timeout(const Duration(seconds: 14));
    }
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      data = decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      data = {};
    }
    if (response.statusCode < 200 || response.statusCode >= 300 ||
        data['status'] != 'success') {
      if (response.statusCode == 401) {
        throw StateError('انتهت صلاحية تسجيل دخول البوسترات.');
      }
      if (response.statusCode == 403) {
        throw StateError('تم إيقاف صلاحية الحملة أو إلغاؤها من الإدارة.');
      }
      if (response.statusCode == 404 || response.statusCode == 503) {
        throw StateError('خدمة توزيع البوسترات غير مفعلة في السيرفر بعد.');
      }
      throw StateError(data['message']?.toString() ??
          'تعذر تنفيذ العملية (رمز ${response.statusCode})');
    }
    return data;
  }

  String _friendlyError(Object error) =>
      error.toString().replaceFirst(RegExp(r'^Bad state: '), '');

  void _alert(String message) {
    if (!mounted) return;
    setState(() => _notice = message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _uuidV4() {
    final random = Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final s = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-'
        '${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  Future<bool> _checkGpsPermission() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      _alert('فعّل GPS من إعدادات الهاتف أولاً.');
      return false;
    }
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      _alert('يلزم السماح بالموقع أثناء استخدام التطبيق لبدء الجولة.');
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    final encoded = jsonEncode({
      'round_id': _roundId,
      'campaign_id': _selectedCampaign,
      'session_uuid': _sessionUuid,
      'status': _status,
      'pending_state': _queuedState,
      'pending_positions': _pendingPositions,
      'pending_visits': _pendingVisits,
      'pending_places': _pendingPlaces,
      'route': _route.length > 1000
          ? _route.sublist(_route.length - 1000)
          .map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList()
          : _route.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'visits': _visits.map((v) => {
        'lat': v.position.latitude,
        'lng': v.position.longitude,
        'outcome': v.outcome,
      }).toList(),
    });
    _saveChain = _saveChain.catchError((_) {}).then<void>((_) =>
        _secureStorage.write(key: _key, value: encoded));
    return _saveChain;
  }

  Future<void> _start() async {
    if (_working || _selectedCampaign == null || !_consent) return;
    if (!await _checkGpsPermission()) return;
    setState(() => _working = true);
    try {
      final initialPosition = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 15));
      _updateMapLocation(initialPosition);
      _sessionUuid ??= _uuidV4();
      await _save(); // Keep the idempotency UUID even if a request times out.
      final data = await _request('POST', 'rounds/start', {
        'session_uuid': _sessionUuid,
        'campaign_id': _selectedCampaign,
        'started_at': DateTime.now().toUtc().toIso8601String(),
      });
      _roundId = (data['round_id'] as num).toInt();
      _status = data['round_status']?.toString() ?? 'active';
      _notice = null;
      await _save();
      if (_isActive) {
        await _startGps();
        _acceptPosition(initialPosition);
      }
    } catch (e) {
      _alert(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _startGps() async {
    if (!_isActive || !_consent || _gps != null || !mounted) return;
    if (!await _checkGpsPermission()) return;

    // Start while the app is visible (Android 12+/14+ requirement). This is
    // independent of the existing food-order tracking stream in tx.dart.
    final geo.LocationSettings settings;
    if (Platform.isAndroid) {
      settings = geo_android.AndroidSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: Duration(seconds: 15),
        foregroundNotificationConfig: geo_android.ForegroundNotificationConfig(
          notificationTitle: 'منصة بيتي — توزيع البوسترات',
          notificationText: 'جولة التوزيع نشطة. يجري مشاركة الموقع مع الإدارة. افتح التطبيق لإيقافها.',
          notificationChannelName: 'متابعة جولات توزيع البوسترات',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (Platform.isIOS) {
      // Info.plist MUST include UIBackgroundModes/location; otherwise setting
      // allowBackgroundLocationUpdates may terminate the iOS process.
      settings = geo_apple.AppleSettings(
        accuracy: geo.LocationAccuracy.high,
        activityType: geo_apple.ActivityType.fitness,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    _gps = geo.Geolocator.getPositionStream(locationSettings: settings)
        .listen(_acceptPosition, onError: (Object error) {
      _stopGps();
      _alert('توقف بث الموقع. افتح شاشة التوزيع وتحقق من إذن الموقع وخدمات GPS.');
    });
  }

  void _stopGps() {
    _gps?.cancel();
    _gps = null;
  }

  Future<void> _logoutPoster() async {
    if (_hasRound || _queuedState != null) {
      _alert('أنهِ الجولة وانتظر مزامنة جميع البيانات قبل تسجيل الخروج من البوسترات.');
      return;
    }
    try {await _request('POST','logout');} catch (_) {}
    await _secureStorage.delete(key:'beytei_poster_worker_auth_v4');
    if (mounted) Navigator.of(context).pop();
  }


  void _updateMapLocation(geo.Position p) {
    final where = LatLng(p.latitude, p.longitude);
    _me = where;
    _accuracy = p.accuracy;
    if (mounted) {
      setState(() {});
      if (_followLocation && _mapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mapController.move(where, 16);
        });
      }
    }
  }

  void _acceptPosition(geo.Position p) {
    if (!_isActive || !mounted || !_consent) return;
    _updateMapLocation(p);
    if (p.accuracy > 150) return; // Don't claim a precise route from poor fixes.
    final point = LatLng(p.latitude, p.longitude);
    final current = DateTime.now().toUtc();
    if (_lastSample != null && _lastSamplePoint != null) {
      final seconds = current.difference(_lastSample!).inSeconds;
      final distance = geo.Geolocator.distanceBetween(
        _lastSamplePoint!.latitude, _lastSamplePoint!.longitude,
        p.latitude, p.longitude,
      );
      if (seconds < 12 && distance < 15) return;
      if (seconds >= 2 && distance / seconds > 40) return; // GPS teleport
    }
    _lastSample = current;
    _lastSamplePoint = point;
    _route.add(point);
    if (_route.length > 1000) _route.removeAt(0);
    _pendingPositions.add({
      'event_uuid': _uuidV4(),
      'lat': p.latitude,
      'lng': p.longitude,
      'accuracy_m': p.accuracy.round().clamp(0, 3000),
      'speed_mps': p.speed.isFinite ? p.speed.clamp(0, 120) : null,
      'recorded_at': current.toIso8601String(),
    });
    // Persist unsent points, including when offline. For Android the location
    // foreground service allows callbacks while the app is minimized.
    _save();
    if (mounted) setState(() {});
    // A Dart periodic timer may be delayed by OS background scheduling.
    // Flush opportunistically when the OS delivers a new GPS point.
    final shouldFlush = _pendingPositions.length >= 5 ||
        _lastBackgroundSyncAttempt == null ||
        current.difference(_lastBackgroundSyncAttempt!) >=
            const Duration(seconds: 20);
    if (shouldFlush) {
      _lastBackgroundSyncAttempt = current;
      _flush();
    }
  }

  Future<bool> _flush() async {
    if (_roundId == null || _syncing) return false;
    _syncing = true;
    try {
      while (_pendingPositions.isNotEmpty) {
        final snapshot = _pendingPositions.take(60)
            .map((p) => Map<String, dynamic>.from(p)).toList();
        await _request('POST', 'rounds/$_roundId/locations', {'points': snapshot});
        final sentIds = snapshot.map((p) => p['event_uuid']).toSet();
        _pendingPositions.removeWhere((p) => sentIds.contains(p['event_uuid']));
        await _save();
      }
      while (_pendingVisits.isNotEmpty) {
        final copy = Map<String, dynamic>.from(_pendingVisits.first);
        await _request('POST', 'rounds/$_roundId/visits', copy);
        _pendingVisits.removeWhere((p) => p['event_uuid'] == copy['event_uuid']);
        await _save();
      }
      while (_pendingPlaces.isNotEmpty) {
        final copy = Map<String,dynamic>.from(_pendingPlaces.first);
        await _request('POST','rounds/$_roundId/geo-proposals',copy);
        _pendingPlaces.removeWhere((p)=>p['event_uuid']==copy['event_uuid']);
        await _save();
      }
      if (mounted) setState(() {});
      return true;
    } catch (error) {
      // Keep unsent events locally for network outages, but stop GPS promptly
      // when the worker/campaign permission is revoked by the backend.
      final message = error.toString();
      if (message.contains('انتهت صلاحية تسجيل دخول البوسترات') ||
          message.contains('تم إيقاف صلاحية الحملة')) {
        _stopGps();
        _status = 'paused';
        await _save();
        if (mounted) _alert('توقف تسجيل GPS: $message');
      }
      if (mounted) setState(() {});
      return false;
    } finally {
      _syncing = false;
    }
  }

  Future<bool> _retryQueuedState() async {
    if (_queuedState == null || _roundId == null || _reconciling) return false;
    _reconciling = true;
    try {
      // Send already collected points BEFORE server marks round paused/ended.
      if (!await _flush() || _pendingPositions.isNotEmpty || _pendingVisits.isNotEmpty || _pendingPlaces.isNotEmpty) {
        return false;
      }
      final state = _queuedState!;
      await _request('POST', 'rounds/$_roundId/state', {'state': state});
      _queuedState = null;
      _status = state;
      if (state == 'ended') {
        _roundId = null;
        _sessionUuid = null;
        _route.clear();
        _visits.clear();
        _pendingPositions.clear();
        _pendingVisits.clear();
        _pendingPlaces.clear();
      }
      await _save();
      return true;
    } catch (_) {
      // Keep local GPS off and retry in this screen when network returns.
      return false;
    } finally {
      _reconciling = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _setRoundState(String state) async {
    if (_roundId == null || _working) return;
    if (state == 'active' && _queuedState != null) {
      _alert('توجد حالة إيقاف لم تُزامن بعد. أعد الاتصال بالإنترنت أولاً.');
      return;
    }
    if (state == 'active' && (!_consent || !await _checkGpsPermission())) {
      _alert('يرجى تأكيد موافقتك على تسجيل الموقع أولاً.');
      return;
    }
    setState(() => _working = true);
    try {
      if (state != 'active') {
        // Privacy: local tracking stops immediately even without Internet.
        _stopGps();
        _status = 'paused';
        _queuedState = state;
        await _save();
        if (!await _retryQueuedState()) {
          _alert('توقف GPS على الهاتف فوراً. مزامنة الإيقاف مع السيرفر معلقة حتى عودة الإنترنت.');
        }
        return;
      }
      await _request('POST', 'rounds/$_roundId/state', {'state': 'active'});
      _status = 'active';
      await _save();
      await _startGps();
    } catch (e) {
      _alert(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _recordVisit(String outcome) async {
    if (!_isActive || _working || _me == null) return;
    if (_lastVisitTime != null &&
        DateTime.now().difference(_lastVisitTime!) < const Duration(seconds: 10)) {
      _alert('تم تسجيل زيارة قبل لحظات. تأكد من الانتقال إلى موقع آخر.');
      return;
    }
    if (_accuracy == null || _accuracy! > 100) {
      _alert('دقة الموقع ضعيفة. اقترب من موقع التسليم وانتظر تحسن GPS.');
      return;
    }
    final item = <String, dynamic>{
      'event_uuid': _uuidV4(),
      'outcome': outcome,
      'lat': _me!.latitude,
      'lng': _me!.longitude,
      'accuracy_m': _accuracy!.round(),
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    };
    _lastVisitTime = DateTime.now();
    _pendingVisits.add(item);
    _visits.add(_PosterVisit(_me!, outcome));
    await _save();
    if (mounted) setState(() {});
    final synced = await _flush();
    if (mounted && !synced) {
      _alert('تم حفظ نقطة الزيارة على الهاتف؛ ستُرسل عند رجوع الإنترنت.');
    }
  }

  Future<void> _tryExit() async {
    if (!_isActive) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final pause = await showDialog<bool>(context: context, builder: (context) =>
        AlertDialog(
          title: const Text('إيقاف تسجيل الموقع؟'),
          content: const Text('عند تصغير التطبيق أو قفل الشاشة سيستمر إرسال موقعك أثناء الجولة. أما الخروج من شاشة التوزيع فيتطلب إيقاف الجولة مؤقتاً أولاً.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('البقاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إيقاف والخروج')),
          ],
        ),
    );
    if (pause != true || !mounted) return;
    await _setRoundState('paused');
    if (_status == 'paused' && mounted) Navigator.of(context).pop();
  }

  Color _visitColor(String outcome) {
    switch (outcome) {
      case 'delivered': return const Color(0xFF209B63);
      case 'no_answer': return const Color(0xFFE6A134);
      default: return const Color(0xFFD75454);
    }
  }

  String _campaignLabel(Map<String, dynamic> campaign) =>
      '${campaign['title'] ?? 'حملة'} — ${campaign['city'] ?? ''}';

  @override
  Widget build(BuildContext context) {
    final posterCount = _visits.where((v) => v.outcome == 'delivered').length;
    final pendingCount = _pendingVisits.length + _pendingPositions.length + _pendingPlaces.length;
    final mapCenter = _me ?? const LatLng(32.91, 45.06);

    return PopScope(
      canPop: !_isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isActive) _tryExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1175C1),
          foregroundColor: Colors.white,
          title: const Text('توزيع البوسترات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'خروج من توزيع البوسترات',
              onPressed: _logoutPoster,
            ),
            IconButton(
              icon: const Icon(Icons.my_location_rounded),
              tooltip: 'موقعي',
              onPressed: _me == null ? null : () => _mapController.move(_me!, 16),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              if (_notice != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF5E2),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(_notice!, style: const TextStyle(fontSize: 12)),
                ),
              DropdownButtonFormField<int>(
                value: _campaigns.any((c) => c['id'] == _selectedCampaign)
                    ? _selectedCampaign : null,
                decoration: const InputDecoration(
                  labelText: 'الحملة المخصصة لي',
                  border: OutlineInputBorder(),
                  filled: true, fillColor: Colors.white,
                ),
                items: _campaigns.map((c) => DropdownMenuItem<int>(
                  value: (c['id'] as num).toInt(),
                  child: Text(_campaignLabel(c),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: _hasRound ? null : (value) {
                  setState(() { _selectedCampaign = value; _sessionUuid = null; });
                  _fetchPlaces();
                  _fetchLiveMap();
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _MiniStat('تسليمات مسجلة', '$posterCount')),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat('مسافة المسار',
                    '${_routeDistanceKm().toStringAsFixed(2)} كم')),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat('بانتظار الإرسال', '$pendingCount')),
              ]),
            ]),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: mapCenter,
                    initialZoom: 15, maxZoom: 19,
                    onMapReady: () {
                      _mapReady = true;
                      if (_me != null) _mapController.move(_me!, 16);
                      _refreshMapAfterMove();
                    },
                    onPositionChanged: (_, hasGesture) {
                      if (hasGesture) {
                        if (_followLocation) setState(() => _followLocation = false);
                        _refreshMapAfterMove();
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'beytei.delivery',
                    ),
                    // Shared street names persist and are drawn as full lines.
                    if (_namedAreaPolygons().isNotEmpty)
                      PolygonLayer(polygons:_namedAreaPolygons()),
                    if (_namedStreetLines().isNotEmpty)
                      PolylineLayer(polylines:_namedStreetLines()),
                    if (_route.length >= 2)
                      PolylineLayer(polylines: [Polyline(
                        points: _route,
                        strokeWidth: 4,
                        color: const Color(0xFF1175C1),
                      )]),
                    CircleLayer(circles: [
                      if (_me != null && _accuracy != null && _accuracy! < 100)
                        CircleMarker(point: _me!, radius: _accuracy!,
                            color: const Color(0x221175C1),
                            borderColor: const Color(0x551175C1),
                            borderStrokeWidth: 1,
                            useRadiusInMeter: true),
                    ]),
                    MarkerLayer(markers: [
                      ..._namedLabels(),
                      ..._allWorkerVisitMarkers(),
                      if (_me != null)
                        Marker(point: _me!, width: 46, height: 46,
                            child: const Icon(Icons.navigation_rounded,
                                color: Color(0xFF0F6DB9), size: 38)),
                      ..._approvedPlaces.where((p) => p['lat'] != null && p['lng'] != null
                          && !_mappedProposalIds.contains(p['id'].toString()))
                          .map((p) => Marker(
                        point: LatLng(double.parse(p['lat'].toString()),
                            double.parse(p['lng'].toString())),
                        width: 100,height: 47,
                        child: Column(mainAxisSize:MainAxisSize.min,children:[
                          const Icon(Icons.signpost_outlined,size:20,color:Color(0xFF1765A0)),
                          Container(padding:const EdgeInsets.symmetric(horizontal:4),
                              color:Colors.white.withOpacity(.9),
                              child:Text(p['name']?.toString()??'',maxLines:1,
                                  overflow:TextOverflow.ellipsis,
                                  style:const TextStyle(fontSize:9,fontWeight:FontWeight.bold))),
                        ]),
                      )),
                      ..._visits.where((v) => !_isAlreadyShared(v)).map((v) => Marker(
                        point: v.position, width: 35, height: 35,
                        child: Icon(Icons.location_on_rounded,
                            color: _visitColor(v.outcome), size: 29),
                      )),
                    ]),
                    const RichAttributionWidget(attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ]),
                  ],
                ),
                Positioned(top: 10, right: 10,
                    child: FloatingActionButton.small(
                      heroTag: 'posterFollow',
                      backgroundColor: Colors.white,
                      onPressed: () {
                        setState(() => _followLocation = true);
                        if (_me != null) _mapController.move(_me!, 16);
                      },
                      child: Icon(_followLocation
                          ? Icons.gps_fixed : Icons.gps_not_fixed,
                          color: const Color(0xFF1175C1)),
                    )),
                if (_me == null)
                  const Positioned(left: 12, right: 12, bottom: 15,
                      child: Card(child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Text('خريطة تقريبية حتى يصل موقع GPS الحقيقي.',
                            textAlign: TextAlign.center),
                      ))),
              ]),
            ),
          )),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              if (!_hasRound || !_consent) ...[
                CheckboxListTile(
                  value: _consent,
                  onChanged: (v) {
                    setState(() => _consent = v ?? false);
                    if (_consent && _isActive) _startGps();
                  },
                  dense: true, controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('أوافق على مشاركة موقعي مع الإدارة طوال الجولة، حتى عند قفل الشاشة أو تصغير التطبيق، ويمكنني إيقافها مؤقتاً أو إنهاؤها',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
              if (!_hasRound) ...[
                SizedBox(width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _working || !_consent || _selectedCampaign == null
                          ? null : _start,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('بدء توزيع البوسترات'),
                    )),
              ],
              if (_hasRound) ...[
                if (_isActive && _gps == null && _consent)
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: _working ? null : _startGps,
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('استئناف مشاركة موقعي'),
                  )),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: _working || _queuedState != null || (!_isActive && !_consent)
                        ? null : () => _setRoundState(
                        _isActive ? 'paused' : 'active'),
                    icon: Icon(_isActive ? Icons.pause : Icons.play_arrow),
                    label: Text(_isActive ? 'إيقاف مؤقت' : 'استئناف الجولة'),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton.icon(
                    onPressed: _working || _queuedState != null ? null : () => _confirmFinish(),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFAB4747)),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('إنهاء الجولة'),
                  )),
                ]),
                // Visible at all times; actual proposal requires an active, consented round.
                const SizedBox(height: 8),
                SizedBox(width:double.infinity,child:OutlinedButton.icon(
                  onPressed: (_working || !_isActive) ? null : _proposePlace,
                  icon:const Icon(Icons.add_location_alt_outlined),
                  label:const Text('اقتراح شارع أو حي أو منطقة أو قضاء'),
                )),
                if (_isActive) ...[
                  const SizedBox(height: 7),
                  Row(children: [
                    Expanded(child: _visitButton('تم التسليم', 'delivered',
                        Icons.check_circle_outline, const Color(0xFF209B63))),
                    const SizedBox(width: 6),
                    Expanded(child: _visitButton('لا يوجد رد', 'no_answer',
                        Icons.do_not_disturb_alt_outlined, const Color(0xFFE6A134))),
                    const SizedBox(width: 6),
                    Expanded(child: _visitButton('رفض', 'refused',
                        Icons.cancel_outlined, const Color(0xFFD75454))),
                  ]),
                ],
              ],
              const SizedBox(height: 5),
              Text(_queuedState != null ? 'التتبع متوقف، وحالة الجولة تنتظر مزامنة الإنترنت.'
                  : _status == 'active' ? 'الجولة نشطة: يستمر إرسال الموقع عند تصغير التطبيق أو قفل الشاشة، ويظهر مؤشر تتبع النظام'
                  : _status == 'paused' ? 'الجولة متوقفة مؤقتاً: لا يتم إرسال GPS'
                  : 'المواقع المسجلة لا تثبت التسليم وحدها؛ الاعتماد من الإدارة.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF667788))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _visitButton(String label, String outcome, IconData icon, Color color) =>
      OutlinedButton.icon(
        onPressed: _working ? null : () => _recordVisit(outcome),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          side: BorderSide(color: color.withOpacity(.45)),
        ),
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 10)),
      );

  Future<void> _confirmFinish() async {
    final yes = await showDialog<bool>(context: context,
        builder: (context) => AlertDialog(
          title: const Text('إنهاء جولة التوزيع'),
          content: const Text('سيتم وقف تتبع الموقع ولن تستطيع استكمال هذه الجولة بعد إنهائها.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('تراجع')),
            FilledButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('إنهاء')),
          ],
        ));
    if (yes == true) await _setRoundState('ended');
  }

  double _routeDistanceKm() {
    var meters = 0.0;
    for (var i = 1; i < _route.length; i++) {
      meters += geo.Geolocator.distanceBetween(
        _route[i - 1].latitude, _route[i - 1].longitude,
        _route[i].latitude, _route[i].longitude,
      );
    }
    return meters / 1000;
  }
}

class _PosterVisit {
  final LatLng position;
  final String outcome;
  const _PosterVisit(this.position, this.outcome);
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.title, this.value);
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE9F5))),
    child: Column(children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800,
          fontSize: 15, color: Color(0xFF164B7A))),
      Text(title, style: const TextStyle(fontSize: 9, color: Color(0xFF667788)),
          textAlign: TextAlign.center),
    ]),
  );
}
