import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/data/repo/dashboard/dashboard_repo.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';

/// All data is read from Laravel. No seat totals, other drivers, or wallet
/// funding amounts are ever requested from driver-facing endpoints.
class ContestDetailsScreen extends StatefulWidget {
  const ContestDetailsScreen({super.key});

  @override
  State<ContestDetailsScreen> createState() => _ContestDetailsScreenState();
}

class _BeyteiContest {
  final int id, target, progress;
  final String title, reward, status, startTime, endTime, rejectionReason;
  final bool joined, open;

  const _BeyteiContest({
    required this.id,
    required this.target,
    required this.progress,
    required this.title,
    required this.reward,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.rejectionReason,
    required this.joined,
    required this.open,
  });

  static int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static String asText(dynamic v) => v == null ? '' : '$v';

  factory _BeyteiContest.fromJson(Map<String, dynamic> j) => _BeyteiContest(
        id: asInt(j['contest_id']),
        target: asInt(j['target_rides']),
        progress: asInt(j['completed_rides']),
        title: asText(j['title']),
        reward: asText(j['reward_amount']),
        status: asText(j['enrollment_status']),
        startTime: asText(j['start_time']),
        endTime: asText(j['end_time']),
        rejectionReason: asText(j['review_reason']),
        joined: j['joined'] == true,
        open: j['registration_open'] == true,
      );
}

class _ContestDetailsScreenState extends State<ContestDetailsScreen> {
  final DashBoardRepo _repo = Get.find<DashBoardRepo>();
  List<_BeyteiContest> _contests = const [];
  List<Map<String, dynamic>> _notices = const [];
  List<Map<String, dynamic>> _rides = const [];
  int? _expandedRideContestId;
  int? _joiningId;
  bool _loading = true;
  bool _loadingRides = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  static Map<String, dynamic>? _jsonObject(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  Future<void> _refresh() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final ResponseModel res = await _repo.getFundedContests();
      final data = _jsonObject(res.responseJson);
      final payload = _jsonObject(data?['data']);
      final entries = payload?['contests'];
      if (res.statusCode != 200 || data?['status'] != 'success' || entries is! List) {
        throw StateError('تعذر تحميل التحديات من السيرفر. تحقق من الاتصال وحاول مجدداً.');
      }

      final contests = entries
          .whereType<Map>()
          .map((item) => _BeyteiContest.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);

      List<Map<String, dynamic>> notices = const [];
      try {
        final noticeRes = await _repo.getFundedContestNotices();
        final noticeData = _jsonObject(_jsonObject(noticeRes.responseJson)?['data']);
        final raw = noticeData?['notices'];
        if (noticeRes.statusCode == 200 && raw is List) {
          notices = raw.whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .take(10).toList(growable: false);
        }
      } catch (_) {
        // Notifications must not hide a successful contest list.
      }
      if (!mounted) { return; }
      setState(() { _contests = contests; _notices = notices; });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'تعذر تحميل التحديات. تأكد من الاتصال وأعد المحاولة.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join(_BeyteiContest contest) async {
    if (_joiningId != null) return;
    setState(() => _joiningId = contest.id);
    try {
      final response = await _repo.joinFundedContest(contest.id);
      final data = _jsonObject(response.responseJson);
      if (response.statusCode != 200 || data?['status'] != 'success') {
        final messages = data?['message'];
        final message = messages is List && messages.isNotEmpty
            ? messages.first.toString() : 'تعذر التسجيل حالياً';
        throw StateError(message);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول اشتراكك وتخصيص تمويل جائزتك')),
        );
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _joiningId = null);
    }
  }

  Future<void> _showRides(_BeyteiContest contest) async {
    if (_loadingRides) return;
    if (_expandedRideContestId == contest.id) {
      setState(() => _expandedRideContestId = null);
      return;
    }
    setState(() { _expandedRideContestId = contest.id; _loadingRides = true; _rides = const []; });
    try {
      final res = await _repo.getMyContestRides(contest.id);
      final data = _jsonObject(_jsonObject(res.responseJson)?['data']);
      final raw = data?['rides'];
      if (res.statusCode != 200 || raw is! List) {
        throw StateError('تعذر تحميل الرحلات المحتسبة');
      }
      if (mounted && _expandedRideContestId == contest.id) {
        setState(() => _rides = raw.whereType<Map>()
            .map((x) => Map<String, dynamic>.from(x)).toList());
      }
    } catch (_) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل الرحلات المحتسبة'))); }
    } finally {
      if (mounted) { setState(() => _loadingRides = false); }
    }
  }

  String _status(_BeyteiContest c) {
    switch (c.status) {
      case 'joined': return 'مشترك';
      case 'review': return 'أكملت الهدف — قيد المراجعة';
      case 'approved': return 'تم صرف المكافأة';
      case 'rejected': return 'مرفوضة بعد المراجعة';
      case 'incomplete': return 'انتهى دون إكمال الهدف';
      default: return c.open ? 'التسجيل متاح' : 'التسجيل غير متاح حالياً';
    }
  }

  Widget _contestCard(_BeyteiContest c) {
    final ratio = c.target > 0 ? (c.progress / c.target).clamp(0.0, 1.0) : 0.0;
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.emoji_events, color: Color(0xFF087DB7)),
            const SizedBox(width: 8),
            Expanded(child: Text(c.title, style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 8),
          Text('المكافأة: ${c.reward} دينار عراقي',
              style: const TextStyle(color: Color(0xFF087DB7), fontWeight: FontWeight.bold)),
          Text('المطلوب: ${c.target} رحلة مؤهلة'),
          Text('من: ${c.startTime}'),
          Text('إلى: ${c.endTime}'),
          const SizedBox(height: 8),
          Text(_status(c), style: const TextStyle(fontWeight: FontWeight.w600)),
          if (c.joined) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: ratio.toDouble(),
              minHeight: 10, backgroundColor: const Color(0xFFE4EEF4),
              color: const Color(0xFF0077B6),
              borderRadius: BorderRadius.circular(10)),
            const SizedBox(height: 7),
            Text('تقدمك: ${c.progress} من ${c.target} رحلة'),
            if (c.rejectionReason.isNotEmpty)
              Text('سبب المراجعة: ${c.rejectionReason}', style:
                const TextStyle(color: Colors.deepOrange)),
            TextButton.icon(
              onPressed: () => _showRides(c),
              icon: const Icon(Icons.receipt_long),
              label: const Text('رحلاتي المحتسبة'),
            ),
            if (_expandedRideContestId == c.id) ...[
              if (_loadingRides) const LinearProgressIndicator(),
              if (!_loadingRides && _rides.isEmpty)
                const Text('لا توجد رحلات محتسبة بعد'),
              if (!_loadingRides)
                ..._rides.map((r) => ListTile(
                  dense: true,
                  title: Text('رحلة #${r['uid'] ?? r['id']}'),
                  subtitle: Text('${r['start_time'] ?? ''} — ${r['status'] ?? ''}'),
                )),
            ],
          ] else if (c.open) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: _joiningId != null ? null : () => _join(c),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0077B6)),
              child: Text(_joiningId == c.id ? 'جاري الاشتراك...' : 'اشترك في التحدي'),
            )),
          ],
          const SizedBox(height: 6),
          const Text('تُصرف المكافأة بعد التحقق من الرحلات وموافقة فريق المنصة.',
            style: TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F9FC),
        appBar: AppBar(
          title: const Text('التحديات والمكافآت'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF114A69),
          centerTitle: true,
        ),
        body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (_error != null) ...[
                  Center(child: Text(_error!, textAlign: TextAlign.center)),
                  const SizedBox(height: 8),
                  Center(child: OutlinedButton(
                    onPressed: _refresh, child: const Text('إعادة المحاولة'))),
                ] else ...[
                  if (_contests.isEmpty)
                    const Padding(padding: EdgeInsets.all(30),
                      child: Center(child: Text('لا توجد تحديات متاحة حالياً'))),
                  ..._contests.map(_contestCard),
                  if (_notices.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('إشعارات المكافآت', style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                    ..._notices.map((n) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.notifications_outlined,
                          color: Color(0xFF0077B6)),
                        title: Text('${n['title'] ?? ''}'),
                        subtitle: Text('${n['body'] ?? ''}'),
                      ),
                    )),
                  ],
                ],
              ]),
            ),
      ),
    );
  }
}
