import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final supabase = Supabase.instance.client;

Future<void> initSupabase() async {
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://shrnxdbbaxfhjaxelbjl.supabase.co';
  final supabaseKey = dotenv.env['SUPABASE_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNocm54ZGJiYXhmaGpheGVsYmpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI2NTg4NjIsImV4cCI6MjA1ODIzNDg2Mn0.eyGCfg7ezTME_FM9tC26uYILPhrlgH7-_70Da-r4F98';
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );
} 