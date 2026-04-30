import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // ✅ FIX
import '../config.dart';
import '../services/ble_service.dart';
import '../services/supabase_service.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.offering,
  });

  final String studentId;
  final String studentName;
  final SubjectOffering offering;
  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen>
    with WidgetsBindingObserver {
  final _ble = BleService();
  final _db = SupabaseService();
  StreamSubscription<bool>? _proximitySub;

  bool _inRange = false;
  bool _attended = false;
  bool _sessionActive = false;
  bool _loading = false;
  bool _bleGranted = false;

  String? _sessionId;
  String? _subject;
  String? _beaconUuid;

  Map<String, int> _nearbyDevices = {};
  bool _scanningNearby = false;

  Timer? _sessionPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _sessionActive &&
        _beaconUuid != null) {
      _ble.startProximityScanning(_beaconUuid!);
    }
    if (state == AppLifecycleState.paused) {
      _ble.stopProximityScanning();
    }
  }

  Future<void> _init() async {
    final granted = await _ble.requestPermissions();
    setState(() => _bleGranted = granted);

    if (!granted) {
      _toast('Please grant all permissions');
      return;
    }

    _proximitySub = _ble.proximityStream.listen((inRange) {
      if (mounted) setState(() => _inRange = inRange);
    });

    _sessionPollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _checkSession(),
    );

    await _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final sessionForProfessor =
          await _db.getActiveSessionForOffering(widget.offering.id);

      if (sessionForProfessor != null) {
        final newId = sessionForProfessor['id'] as String;
        final dynamic beaconRaw =
            sessionForProfessor['beacon_uuid'] ?? sessionForProfessor['beacon_name'];
        if (beaconRaw == null) {
          throw Exception('Session is missing beacon identifier');
        }
        final dynamic beaconNameRaw = sessionForProfessor['beacon_name'];
        final newBeaconUuid = beaconRaw.toString();
        final newBeaconName = beaconNameRaw?.toString();

        if (_sessionId != newId) {
          setState(() {
            _sessionId = newId;
            _subject = sessionForProfessor['subject'];
            _beaconUuid = newBeaconUuid;
            _sessionActive = true;
            _attended = false;
          });

          await _ble.startProximityScanning(
            newBeaconUuid,
            beaconName: newBeaconName ?? AppConfig.defaultBeaconName,
          );
        }
      } else {
        if (_sessionActive) {
          _ble.stopProximityScanning();
          setState(() {
            _sessionActive = false;
            _inRange = false;
            _sessionId = null;
            _beaconUuid = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Session error: $e');
    }
  }

  Future<void> _scanNearby() async {
    setState(() {
      _scanningNearby = true;
      _nearbyDevices = {};
    });

    final found = await _ble.scanAllDevices(seconds: 8);

    if (mounted) {
      setState(() {
        _nearbyDevices = found;
        _scanningNearby = false;
      });
    }
  }

  Future<void> _markAttendance() async {
    if (!_inRange || !_sessionActive || _attended || _sessionId == null) return;

    setState(() => _loading = true);

    try {
      final ok = await _db.markAttendance(
        sessionId: _sessionId!,
        studentId: widget.studentId,
        studentName: widget.studentName,
      );

      setState(() {
        _attended = ok;
        _loading = false;
      });

      _toast(ok ? 'Attendance marked!' : 'Already marked');
    } catch (e) {
      setState(() => _loading = false);
      _toast('Error: $e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionPollTimer?.cancel();
    _proximitySub?.cancel();
    _ble.stopProximityScanning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_bleGranted)
              ElevatedButton(
                onPressed: () async {
                  await openAppSettings();
                },
                child: const Text('Grant Permissions'),
              ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00897B).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_subject ?? 'No active subject'),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.studentName} (${widget.studentId})',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _attended
                        ? 'Attendance already marked'
                        : _inRange
                            ? 'You are in range of the professor'
                            : 'You are out of range',
                    style: TextStyle(
                      color: _attended
                          ? Colors.green
                          : _inRange
                              ? const Color(0xFF00897B)
                              : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed:
                  (_inRange && _sessionActive && !_attended)
                      ? _markAttendance
                      : null,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.how_to_reg),
              label: Text(_loading ? 'Marking...' : 'Mark Attendance'),
            ),

            const Divider(),

            OutlinedButton(
              onPressed: _scanningNearby ? null : _scanNearby,
              child: Text(_scanningNearby
                  ? 'Scanning...'
                  : 'Scan Nearby Devices'),
            ),

            if (_nearbyDevices.isNotEmpty)
              ...(_nearbyDevices.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(e.key)),
                            Text('${e.value} dBm'),
                          ],
                        ),
                      )),
          ],
        ),
      ),
    );
  }
}