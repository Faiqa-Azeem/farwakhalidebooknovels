import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  try {
    await Supabase.initialize(
      url: "https://sbwyuykklschxdmxlkcq.supabase.co",
      anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNid3l1eWtrbHNjaHhkbXhsa2NxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0MjY5NDcsImV4cCI6MjA2ODAwMjk0N30.XFTEUjkYXzG0GNNnVnAw6nP1L8Fx628nwBUkSa8fPgs",
    );
    final client = Supabase.instance.client;
    
    print("Recent rows in ebook_payments:");
    final payments = await client.from('ebook_payments').select().order('created_at', ascending: false).limit(10);
    for (var p in payments) {
      print(p);
    }

    print("\nRecent rows in ebook_access:");
    final access = await client.from('ebook_access').select().order('created_at', ascending: false).limit(10);
    for (var a in access) {
      print(a);
    }
    
    exit(0);
  } catch (e) {
    print("Error: $e");
    exit(1);
  }
}
