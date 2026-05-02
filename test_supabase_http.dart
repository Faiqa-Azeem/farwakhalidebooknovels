import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

void main() async {
  const supabaseUrl = "https://sbwyuykklschxdmxlkcq.supabase.co";
  const supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNid3l1eWtrbHNjaHhkbXhsa2NxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0MjY5NDcsImV4cCI6MjA2ODAwMjk0N30.XFTEUjkYXzG0GNNnVnAw6nP1L8Fx628nwBUkSa8fPgs";

  try {
    print("Testing insert into ebook_payments...");
    var response = await http.post(
      Uri.parse("$supabaseUrl/rest/v1/ebook_payments"),
      headers: {
        "apikey": supabaseAnonKey,
        "Authorization": "Bearer $supabaseAnonKey",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
      },
      body: jsonEncode({
        "ebook_id": "11111111-1111-1111-1111-111111111111",
        "email": "test@script.com",
        "device_id": "google_play_billing",
        "access_granted": false
      })
    );
    print("Payments Response Status: ${response.statusCode}");
    print("Payments Response Body: ${response.body}");

    print("Testing insert into ebook_access...");
    response = await http.post(
      Uri.parse("$supabaseUrl/rest/v1/ebook_access"),
      headers: {
        "apikey": supabaseAnonKey,
        "Authorization": "Bearer $supabaseAnonKey",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
      },
      body: jsonEncode({
        "user_email": "test@script.com",
        "ebook_id": "11111111-1111-1111-1111-111111111111",
        "device_id": "null",
        "created_at": DateTime.now().toIso8601String()
      })
    );
    print("Access Response Status: ${response.statusCode}");
    print("Access Response Body: ${response.body}");
    exit(0);
  } catch (e) {
    print("Error: $e");
    exit(1);
  }
}
