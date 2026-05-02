import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'text_editor_screen.dart';
import 'admin_payment_screen.dart';
import '../../widgets/poll_widget.dart';

class PostNotificationsScreen extends StatefulWidget {
  const PostNotificationsScreen({super.key});

  @override
  State<PostNotificationsScreen> createState() => _PostNotificationsScreenState();
}

class _PostNotificationsScreenState extends State<PostNotificationsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> notifications = [];
  static const writerId = 'DFm3K8mo4QPM4pqjVU3VDm1po9q2'; // fixed author ID
  final Color mainBlue = const Color(0xFF0D2144);

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      final data = await supabase
          .from('post_notifications')
          .select()
          .order('pinned', ascending: false)
          .order('created_at', ascending: false);

      setState(() {
        notifications = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
  }

  Future<void> addOrEditNotification({Map<String, dynamic>? existing}) async {
    final text = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditorScreen(
          type: existing != null ? "Edit Notification" : "Add Notification",
          count: 1,
          initialContent: existing?['text'] ?? '',
        ),
      ),
    );

    if (text == null || text.isEmpty) return;

    try {
      if (existing != null) {
        // Update
        await supabase
            .from('post_notifications')
            .update({'text': text})
            .eq('id', existing['id']);
      } else {
        // Insert
        final inserted = await supabase
            .from('post_notifications')
            .insert({'text': text, 'author_id': writerId, 'pinned': false})
            .select()
            .single();

        notifications.insert(0, inserted);
      }
      fetchNotifications();
    } catch (e) {
      debugPrint('Add/Edit notification error: $e');
    }
  }

  Future<void> deleteNotification(Map<String, dynamic> notif) async {
    try {
      await supabase
          .from('post_notifications')
          .delete()
          .eq('id', notif['id']);

      setState(() {
        notifications.removeWhere((n) => n['id'] == notif['id']);
      });
    } catch (e) {
      debugPrint('Delete notification error: $e');
    }
  }

  Future<void> togglePinned(Map<String, dynamic> notif) async {
    final newPinned = !(notif['pinned'] ?? false);
    try {
      await supabase
          .from('post_notifications')
          .update({'pinned': newPinned})
          .eq('id', notif['id']);

      setState(() {
        notif['pinned'] = newPinned;
        notifications.sort((a, b) {
          final pinA = a['pinned'] ?? false;
          final pinB = b['pinned'] ?? false;
          if (pinA && !pinB) return -1;
          if (!pinA && pinB) return 1;
          return (b['created_at'] ?? "").compareTo(a['created_at'] ?? "");
        });
      });
    } catch (e) {
      debugPrint('Pinned toggle error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Notifications', style: TextStyle(color: Colors.white)),
        backgroundColor: mainBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts, color: Colors.white),
            tooltip: "Manage Payments",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminPaymentScreen()),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          final text = notif['text'] ?? '';
          final regex = RegExp(r'\|\|POLL_ID:(.+?)\|\|');
          final match = regex.firstMatch(text);
          final pollId = match?.group(1);
          final cleanText = text.replaceAll(regex, '').trim();

          return Card(
            color: mainBlue.withOpacity(0.8),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      cleanText,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: notif['pinned'] ?? false,
                          onChanged: (_) => togglePinned(notif),
                          activeColor: Colors.green,
                        ),
                        // Only edit non-polls for now ideally, but allowing edit might break poll link if text changed. 
                        // User can edit text, keeping ID? TextEditor doesn't know about ID.
                        // I'll disable edit for polls or handle it carefully. Disabling for MVP safety.
                        if (pollId == null)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () => addOrEditNotification(existing: notif),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteNotification(notif),
                        ),
                      ],
                    ),
                  ),
                  if (pollId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: PollWidget(
                        pollId: pollId,
                        isWriter: true,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: mainBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => addOrEditNotification(),
      ),
      persistentFooterButtons: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: mainBlue),
            onPressed: _showCreatePollDialog,
            icon: const Icon(Icons.poll, color: Colors.white),
            label: const Text("Create Poll", style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Future<void> _showCreatePollDialog() async {
    final questionController = TextEditingController();
    List<TextEditingController> optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Create Poll"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: questionController,
                      decoration: const InputDecoration(labelText: "Question"),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(optionControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: optionControllers[index],
                                decoration: InputDecoration(labelText: "Option ${index + 1}"),
                              ),
                            ),
                            if (optionControllers.length > 2)
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    optionControllers.removeAt(index);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          optionControllers.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("Add Option"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (questionController.text.isEmpty) return;
                    final validOptions = optionControllers
                        .where((c) => c.text.isNotEmpty)
                        .map((c) => c.text)
                        .toList();
                    if (validOptions.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("At least 2 options required")),
                      );
                      return;
                    }

                    // Create Poll in Firestore
                    try {
                      final pollRef = FirebaseFirestore.instance.collection('polls').doc();
                      await pollRef.set({
                        'question': questionController.text,
                        'options': validOptions.asMap().entries.map((e) {
                          return {
                            'id': e.key.toString(), // Simplify ID
                            'text': e.value,
                            'votes': 0,
                          };
                        }).toList(),
                        'created_at': FieldValue.serverTimestamp(),
                        'voters': [],
                      });

                      final pollId = pollRef.id;
                      final notificationText = "${questionController.text} ||POLL_ID:$pollId||";

                      // Save to Supabase (Author ID handled by existing logic or passed here)
                      // Reusing addOrEdit function or Supabase directly? 
                      // addOrEditNotification uses TextEditor, we want direct insert.
                      // I will adapt direct insert here.
                      
                      await supabase.from('post_notifications').insert({
                        'text': notificationText,
                        'author_id': writerId,
                        'pinned': false,
                      });

                      Navigator.pop(context);
                      fetchNotifications(); // Refresh list

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Poll Created!")),
                      );

                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e")),
                      );
                    }
                  },
                  child: const Text("Post Poll"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
