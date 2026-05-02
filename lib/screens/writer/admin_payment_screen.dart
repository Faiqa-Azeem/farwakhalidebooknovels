import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/supabase_service.dart';

class AdminPaymentScreen extends StatefulWidget {
  const AdminPaymentScreen({super.key});

  @override
  State<AdminPaymentScreen> createState() => _AdminPaymentScreenState();
}

class _AdminPaymentScreenState extends State<AdminPaymentScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Payments (No relationship join)
      final response = await _supabase
          .from('ebook_payments')
          .select('*')
          .eq('access_granted', false)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

      // 2. Fetch Associated Ebooks manually
      if (data.isNotEmpty) {
        final ebookIds = data.map((e) => e['ebook_id']).whereType<String>().toSet().toList();
        
        if (ebookIds.isNotEmpty) {
          final ebooksResponse = await _supabase
              .from('ebooks')
              .select('id, title, price, cover_url')
              .filter('id', 'in', ebookIds);
          
          final ebooksList = List<Map<String, dynamic>>.from(ebooksResponse);
          final ebooksMap = {for (var e in ebooksList) e['id']: e};

          // 3. Merge Data
          for (var payment in data) {
            final ebook = ebooksMap[payment['ebook_id']];
            if (ebook != null) {
              payment['ebooks'] = ebook; // Mimic the structure expected by UI
            } else {
               payment['ebooks'] = {'title': 'Unknown Book', 'price': '?'};
            }
          }
        }
      }

      setState(() {
        _requests = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching requests: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error loading requests: $e")));
      }
    }
  }

  Future<void> _grantAccess(String paymentId, String userEmail, String bookTitle, String ebookId) async {
    try {
      await _supabase
          .from('ebook_payments')
          .update({'access_granted': true})
          .eq('id', paymentId);

      await SupabaseService.grantAccess(
        email: userEmail,
        ebookId: ebookId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Access granted for $userEmail to '$bookTitle'"),
          backgroundColor: Colors.green,
        ),
      );
      _fetchRequests(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error granting access: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const mainBlue = Color(0xFF0D2144);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Ebook Access"),
        backgroundColor: mainBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        "No pending requests",
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    itemBuilder: (context, index) {
                      final req = _requests[index];
                      final ebook = req['ebooks'];
                      final created = DateTime.parse(req['created_at']);
                      final dateStr = "${created.day}/${created.month} ${created.hour}:${created.minute}";

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: const Icon(Icons.person, color: mainBlue),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          req['user_email'] ?? "Unknown User",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Requested: ${ebook['title']}",
                                          style: const TextStyle(color: Colors.blueGrey, fontSize: 14),
                                        ),
                                        Text(
                                          "Price: PKR ${ebook['price'] ?? '?'}",
                                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    dateStr,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      // Maybe reject / delete?
                                    },
                                    child: const Text("Ignore", style: TextStyle(color: Colors.grey)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _grantAccess(
                                        req['id'], req['user_email'] ?? 'User', ebook['title'] ?? 'Book', req['ebook_id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.check),
                                    label: const Text("Grant Access"),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
