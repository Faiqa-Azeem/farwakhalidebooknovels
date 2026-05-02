import 'package:flutter/material.dart';
import '../../models/ebook.dart';
import '../../utils/supabase_service.dart';

class ManageAccessScreen extends StatefulWidget {
  const ManageAccessScreen({super.key});

  @override
  State<ManageAccessScreen> createState() => _ManageAccessScreenState();
}

class _ManageAccessScreenState extends State<ManageAccessScreen> {
  List<Ebook> _ebooks = [];
  Ebook? _selectedEbook;
  bool _isLoadingEbooks = true;

  List<Map<String, dynamic>> _accessList = [];
  bool _isLoadingAccess = false;

  @override
  void initState() {
    super.initState();
    _loadEbooks();
  }

  Future<void> _loadEbooks() async {
    try {
      final ebooks = await SupabaseService.getAllEbooks();
      setState(() {
        _ebooks = ebooks;
        _isLoadingEbooks = false;
        // Optional: Auto-select first if available
        // if (_ebooks.isNotEmpty) _selectedEbook = _ebooks.first;
      });
    } catch (e) {
      setState(() => _isLoadingEbooks = false);
      print("Error loading ebooks: $e");
    }
  }

  Future<void> _loadAccessList() async {
    if (_selectedEbook == null) return;
    setState(() => _isLoadingAccess = true);
    
    try {
      final list = await SupabaseService.getAccessList(_selectedEbook!.id);
      setState(() {
        _accessList = list;
        _isLoadingAccess = false;
      });
    } catch (e) {
      setState(() => _isLoadingAccess = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading access list: $e')),
        );
      }
    }
  }

  Future<void> _revokeAccess(String accessId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Revoke Access?"),
        content: Text("Are you sure you want to remove access for $email?\n\nThey will be blocked immediately."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Revoke"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.revokeAccess(accessId);
      // Refresh list
      _loadAccessList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access revoked successfully'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error revoking access: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const mainBlue = Color(0xFF0D2144);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Access"),
        backgroundColor: mainBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. Selector Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: _isLoadingEbooks
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<Ebook>(
                    value: _selectedEbook,
                    decoration: InputDecoration(
                      labelText: "Select eBook to Manage",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: _ebooks.map((ebook) {
                      return DropdownMenuItem(
                        value: ebook,
                        child: Text(
                          ebook.title.length > 30 ? '${ebook.title.substring(0, 30)}...' : ebook.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedEbook = val);
                      _loadAccessList();
                    },
                  ),
          ),
          
          const Divider(height: 1),

          // 2. List Section
          Expanded(
            child: _selectedEbook == null
                ? Center(child: Text("Select an eBook above", style: TextStyle(color: Colors.grey[600])))
                : _isLoadingAccess
                    ? const Center(child: CircularProgressIndicator())
                    : _accessList.isEmpty
                        ? Center(child: Text("No users have access to this eBook.", style: TextStyle(color: Colors.grey[600])))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _accessList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _accessList[index];
                              final email = item['user_email'] ?? 'Unknown';
                              final deviceId = item['device_id'];
                              final isLocked = deviceId != null;

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isLocked ? Colors.green.shade100 : Colors.orange.shade100,
                                    child: Icon(
                                      isLocked ? Icons.phonelink_lock : Icons.hourglass_empty,
                                      color: isLocked ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                  title: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  subtitle: Text(
                                    isLocked ? "Locked to Device: $deviceId" : "Pending first read...",
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _revokeAccess(item['id'], email),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
