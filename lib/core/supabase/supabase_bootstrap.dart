import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initSupabase() async {
  const definedUrl = String.fromEnvironment('SUPABASE_URL');
  const definedAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (definedUrl.isEmpty || definedAnonKey.isEmpty) {
    await dotenv.load(fileName: '.env');
  }
  final url = definedUrl.isNotEmpty ? definedUrl : dotenv.env['SUPABASE_URL'];
  final anonKey =
      definedAnonKey.isNotEmpty
          ? definedAnonKey
          : dotenv.env['SUPABASE_ANON_KEY'];
  if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
    throw StateError('Missing Supabase configuration.');
  }
  await Supabase.initialize(
    url: url,
    anonKey: anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

SupabaseClient get supabase => Supabase.instance.client;
