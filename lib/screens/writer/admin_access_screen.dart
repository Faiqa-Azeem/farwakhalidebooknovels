import 'package:flutter/material.dart';
import '../../models/ebook.dart';
import '../../utils/supabase_service.dart';

class AdminAccessScreen extends StatefulWidget {
  const AdminAccessScreen({super.key});

  @override
  State<AdminAccessScreen> createState() => _AdminAccessScreenState();
}

class _AdminAccessScreenState extends State<AdminAccessScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  List<Ebook> _ebooks = [];
  Ebook? _selectedEbook;
  bool _isLoading = false;
  bool _isGranting = false;

  @override
  void initState() {
    super.initState();
    _loadEbooks();
  }

  Future<void> _loadEbooks() async {
    setState(() => _isLoading = true);
    try {
      final ebooks = await SupabaseService.getAllEbooks();
      setState(() {
        _ebooks = ebooks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ebooks: $e')),
        );
      }
    }
  }

  Future<void> _grantAccess() async {
    if (!_formKey.currentState!.validate() || _selectedEbook == null) return;

    setState(() => _isGranting = true);
    final email = _emailController.text.trim();

    try {
      await SupabaseService.grantAccess(
        email: email, 
        ebookId: _selectedEbook!.id
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Access granted to $email for "${_selectedEbook!.title}"'),
            backgroundColor: Colors.green,
          ),
        );
        _emailController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString().replaceAll("Exception:", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isGranting = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Grant eBook Access"),
        backgroundColor: const Color(0xFF0D2144),
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select eBook",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Ebook>(
                    isExpanded: true,
                    value: _selectedEbook,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    hint: const Text("Choose an eBook..."),
                    items: _ebooks.map((ebook) {
                      return DropdownMenuItem(
                        value: ebook,
                        child: Text(
                          ebook.title.length > 30 
                            ? '${ebook.title.substring(0, 30)}...' 
                            : ebook.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedEbook = val),
                    validator: (val) => val == null ? "Please select an eBook" : null,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  const Text(
                    "User Email",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: "user@gmail.com",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return "Email is required";
                      if (!val.contains('@')) return "Enter a valid email";
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isGranting ? null : _grantAccess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D2144),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isGranting 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : const Text("GRANT ACCESS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
