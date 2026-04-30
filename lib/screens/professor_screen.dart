import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ble_service.dart';
import '../services/supabase_service.dart';

class ProfessorScreen extends StatefulWidget {
  const ProfessorScreen({
    super.key,
    required this.professorName,
    required this.offering,
  });

  final String professorName;
  final SubjectOffering offering;
  @override
  State<ProfessorScreen> createState() => _ProfessorScreenState();
}

class _ProfessorScreenState extends State<ProfessorScreen> {
  final _db = SupabaseService();
  final _ble = BleService();

  bool _active  = false;
  bool _loading = false;
  String? _sessionId;
  List<Map<String, dynamic>> _attendees = [];
  Timer? _pollTimer;

  Future<void> _startSession() async {
    setState(() => _loading = true);
    try {
      final granted = await _ble.requestPermissions();
      if (!granted) {
        throw Exception('Bluetooth permissions are required');
      }

      final btOn = await _ble.isBluetoothOn();
      if (!btOn) {
        throw Exception('Please turn on Bluetooth first');
      }

      await _ble.startProfessorBeacon(
        beaconUuid: widget.offering.beaconUuid,
        localName: widget.offering.beaconName,
      );

      final session = await _db.startSession(
        professorId: widget.offering.professorId,
        offeringId: widget.offering.id,
        subject: widget.offering.label,
        beaconUuid: widget.offering.beaconUuid,
        beaconName: widget.offering.beaconName,
      );
      setState(() {
        _sessionId = session['id'];
        _active    = true;
        _loading   = false;
      });
      _pollTimer = Timer.periodic(
        const Duration(seconds: 4), (_) => _refresh());
    } catch (e) {
      setState(() => _loading = false);
      _toast('Error starting session: $e');
    }
  }

  Future<void> _endSession() async {
    if (_sessionId == null) return;
    setState(() => _loading = true);
    _pollTimer?.cancel();
    try {
      await _db.endSession(_sessionId!);
      await _ble.stopProfessorBeacon();
      setState(() {
        _active   = false;
        _loading  = false;
        _sessionId = null;
      });
    } catch (e) {
      setState(() => _loading = false);
      _toast('Error ending session: $e');
    }
  }

  Future<void> _refresh() async {
    if (_sessionId == null) return;
    final list = await _db.getAttendees(_sessionId!);
    if (mounted) setState(() => _attendees = list);
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ble.stopProfessorBeacon();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Professor'),
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF5C6BC0).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF5C6BC0).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.offering.subjectCode} - ${widget.offering.subjectTitle}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.professorName} • Section ${widget.offering.section}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.sensors,
                        size: 14,
                        color: _active ? Colors.green : Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _active
                            ? 'Session active — beacon UUID: ${widget.offering.beaconUuid}'
                            : 'No active session',
                        style: TextStyle(
                            fontSize: 13,
                            color: _active ? Colors.green : Colors.grey),
                      ),
                    ),
                  ]),
                  if (_active) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Keep this screen open. Students within range can mark attendance.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Start / End button
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _active ? _endSession : _startSession,
                    icon: Icon(
                        _active ? Icons.stop_circle : Icons.play_circle),
                    label:
                        Text(_active ? 'End Session' : 'Start Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _active ? Colors.red : const Color(0xFF5C6BC0),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

            const SizedBox(height: 20),

            // Attendees header
            Row(children: [
              const Text('Attendees',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF5C6BC0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${_attendees.length}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Text(
                'live attendance',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ]),

            const SizedBox(height: 8),

            Expanded(
              child: _attendees.isEmpty
                  ? Center(
                      child: Text(
                        _active
                            ? 'Waiting for students...'
                            : 'Start a session to begin',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: _attendees.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final a = _attendees[i];
                        final t = DateTime.tryParse(
                                a['marked_at'] ?? '')
                            ?.toLocal();
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF5C6BC0)
                                .withValues(alpha: 0.15),
                            child: Text(
                              (a['student_name'] as String)[0]
                                  .toUpperCase(),
                              style: const TextStyle(
                                  color: Color(0xFF5C6BC0),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(a['student_name']),
                          subtitle: Text(a['student_id']),
                          trailing: t != null
                              ? Text(
                                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey),
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}