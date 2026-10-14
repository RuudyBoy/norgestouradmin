import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_text_styles.dart';
import 'theme/admin_ui.dart';
import 'theme/app_colors.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // AuthGate in main.dart will verify admin status and navigate
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "En feil oppstod ved innlogging.";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Noe gikk galt: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.adminSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.adminOutline),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14111827),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: AdminIconTile(
                    icon: Icons.sports_volleyball,
                    size: 56,
                    iconSize: 28,
                    radius: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Spike Dunk Admin",
                  textAlign: TextAlign.center,
                  style: AdminText.ui(size: 26, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  "Logg inn for å administrere turneringer",
                  textAlign: TextAlign.center,
                  style: AppText.uiBody.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "E-post",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: "Passord",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppColors.adminDanger.withValues(alpha: 0.08),
                      border: Border.all(color: AppColors.adminDanger.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.adminDangerText),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.adminText,
                          ),
                        )
                      : const Text("Logg inn"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
