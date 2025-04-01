import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_config.dart';

class AuthService {
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String role,
    required String name,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'role': role,
        'name': name,
      },
    );

    if (response.user != null) {
      // Create profile in profiles table
      await supabase.from('profiles').insert({
        'id': response.user!.id,
        'email': email,
        'name': name,
        'role': role,
      });
    }

    return response;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  static Future<String?> getUserRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final response = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();

    return response['role'] as String?;
  }
} 