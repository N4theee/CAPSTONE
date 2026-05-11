import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ble_service.dart';
import '../services/supabase_service.dart';
import 'professor_dashboard_screen.dart';
import 'student_dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.initialRole});

  final String initialRole;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _db = SupabaseService();
  final _ble = BleService();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  bool _loading = false;
  bool _isRegister = false;
  bool _rememberMe = false;

  late String _role;
  static const _rememberRoleKey = 'remember_role';
  static const _rememberUserKey = 'remember_username';
  static const _rememberPassKey = 'remember_password';

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    _isRegister = _role == 'student';
    _loadRemembered();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _studentIdCtrl.dispose();
    _fullNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString(_rememberRoleKey);
    if (savedRole != _role) return;
    if (!mounted) return;
    setState(() {
      _rememberMe = true;
      _userCtrl.text = prefs.getString(_rememberUserKey) ?? '';
      _passCtrl.text = prefs.getString(_rememberPassKey) ?? '';
    });
  }

  Future<void> _saveRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString(_rememberRoleKey, _role);
      await prefs.setString(_rememberUserKey, _userCtrl.text.trim());
      await prefs.setString(_rememberPassKey, _passCtrl.text.trim());
      return;
    }
    await prefs.remove(_rememberRoleKey);
    await prefs.remove(_rememberUserKey);
    await prefs.remove(_rememberPassKey);
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_role == 'student' && _isRegister) {
        final deviceInfo = await _ble.getAttendanceDeviceInfo();
        await _db.registerStudent(
          studentId: _studentIdCtrl.text,
          fullName: _fullNameCtrl.text,
          username: _userCtrl.text,
          password: _passCtrl.text,
          deviceUuid: deviceInfo.deviceUuid,
          deviceName: deviceInfo.deviceName,
        );
      }

      final user = await _db.login(
        username: _userCtrl.text,
        password: _passCtrl.text,
        role: _role,
      );
      if (user == null) {
        throw Exception('Invalid credentials');
      }
      await _saveRemembered();

      if (!mounted) return;
      if (_role == 'student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => StudentDashboardScreen(user: user)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ProfessorDashboardScreen(user: user)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auth failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleTitle = _role == 'student' ? 'Student' : 'Professor';
    return Scaffold(
      appBar: AppBar(title: Text('$roleTitle ${_isRegister ? "Register" : "Login"}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'student', label: Text('Student')),
                    ButtonSegment(value: 'professor', label: Text('Professor')),
                  ],
                  selected: {_role},
                  onSelectionChanged: (v) {
                    setState(() {
                      _role = v.first;
                      if (_role == 'professor') _isRegister = false;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_role == 'student')
                  SwitchListTile(
                    value: _isRegister,
                    onChanged: (value) => setState(() => _isRegister = value),
                    title: const Text('Register new student account'),
                    contentPadding: EdgeInsets.zero,
                  ),
                if (_role == 'student' && _isRegister) ...[
                  TextField(
                    controller: _studentIdCtrl,
                    decoration: const InputDecoration(labelText: 'Student ID'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _fullNameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  title: const Text('Remember me'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(_isRegister ? 'Register & Login' : 'Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
