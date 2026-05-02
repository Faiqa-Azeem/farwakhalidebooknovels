import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print("Testing Supabase connection...");
  try {
    await Supabase.initialize(
      url: "https://sbwyuykklschxdmxlkcq.supabase.co",
      anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNid3l1eWtrbHNjaHhkbXhsa2NxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0MjY5NDcsImV4cCI6MjA2ODAwMjk0N30.XFTEUjkYXzG0GNNnVnAw6nP1L8Fx628nwBUkSa8fPgs",
    );
    final client = Supabase.instance.client;
    
    // Testing ebook_payments insert
    print("Attempting insert into ebook_payments...");
    await client.from('ebook_payments').insert({
      'ebook_id': 'test_id',
      'email': 'test@example.com',
      'device_id': 'test_device',
      'access_granted': false,
    });
    print("Insert into ebook_payments successful.");
    
    print("Attempting insert into ebook_access...");
    await client.from('ebook_access').insert({
      'user_email': 'test@example.com',
      'ebook_id': 'test_id',
      'device_id': 'test_device',
      'created_at': DateTime.now().toIso8601String(),
    });
    print("Insert into ebook_access successful.");
    
    // Clean up
    await client.from('ebook_access').delete().eq('user_email', 'test@example.com').eq('ebook_id', 'test_id');
    await client.from('ebook_payments').delete().eq('email', 'test@example.com').eq('ebook_id', 'test_id');
    print("Cleanup successful.");

    exit(0);
  } catch (e) {
    print("Error during DB test: $e");
    exit(1);
  }
}
