import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'admin_web_panel_screen.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _adminUserCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();

  @override
  void dispose() {
    _adminUserCtrl.dispose();
    _adminPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sensors, size: 64, color: Color(0xFF5C6BC0)),
              const SizedBox(height: 16),
              const Text(
                'BLE Attendance',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Proximity-based attendance system',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              _roleButton(
                context,
                icon: Icons.school,
                label: 'I am a Professor',
                sub: 'Login and start attendance sessions',
                color: const Color(0xFF5C6BC0),
                onTap: () => _openAuth(role: 'professor'),
              ),
              const SizedBox(height: 16),
              _roleButton(
                context,
                icon: Icons.person,
                label: 'I am a Student',
                sub: 'Register/Login and mark attendance',
                color: const Color(0xFF00897B),
                onTap: () => _openAuth(role: 'student'),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 16),
                _roleButton(
                  context,
                  icon: Icons.admin_panel_settings,
                  label: 'Admin Panel (Web)',
                  sub: 'Create professor accounts',
                  color: const Color(0xFF6A1B9A),
                  onTap: _openAdminLogin,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  void _openAuth({required String role}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AuthScreen(initialRole: role)),
    );
  }

  Future<void> _openAdminLogin() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Admin Login',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _adminUserCtrl,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _adminPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  final ok = _adminUserCtrl.text.trim() == 'ADMIN-NATH' &&
                      _adminPassCtrl.text.trim() == '1234567890';
                  Navigator.pop(ctx, ok);
                },
                child: const Text('Login'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (ok != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid admin credentials.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminWebPanelScreen()),
    );
  }
}