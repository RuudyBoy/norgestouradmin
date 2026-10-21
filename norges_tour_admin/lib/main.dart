import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:norges_tour_admin/firebase_options.dart';
import 'package:norges_tour_admin/pages/admin_login_page.dart';
import 'package:norges_tour_admin/theme/app_colors.dart';
import 'package:norges_tour_admin/theme/app_theme.dart';
import 'package:norges_tour_admin/widgets/admin_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spike Dunk Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.admin,
      builder: (context, child) {
        return Container(color: AppColors.adminBg, child: child);
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('admins')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (adminSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text("Feil ved sjekk av admin-rettigheter: ${adminSnapshot.error}", textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          child: const Text("Logg ut"),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (adminSnapshot.hasData && adminSnapshot.data!.exists) {
                return const AdminShell();
              }
              
              // Signed in but not an admin — show error and allow sign out
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block, color: Colors.orange, size: 48),
                      const SizedBox(height: 16),
                      const Text("Ingen admin-tilgang for denne brukeren."),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text("Logg ut og prøv en annen bruker"),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }
        return const AdminLoginPage();
      },
    );
  }
}

