import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Added
import 'package:supabase_flutter/supabase_flutter.dart'; // Added

import 'write_novel.dart';
import 'edit_novel.dart';
import '../home_screens/login_screen.dart';

// ✅ Correct imports for writer-specific screens
import 'package:farwa_khalid_ebook_novels/screens/writer/add.dart';
import 'package:farwa_khalid_ebook_novels/screens/writer/post_notification_screen.dart';
import 'package:farwa_khalid_ebook_novels/screens/writer/admin_payment_screen.dart';
import 'package:farwa_khalid_ebook_novels/screens/writer/admin_access_screen.dart';
import 'package:farwa_khalid_ebook_novels/screens/writer/manage_access_screen.dart'; // Added
import 'package:farwa_khalid_ebook_novels/screens/writer/writer_voiceover_screen.dart'; // Added


class WriterMain extends StatefulWidget {
  const WriterMain({super.key});

  @override
  State<WriterMain> createState() => _WriterMainState();
}

class _WriterMainState extends State<WriterMain> {
  String _username = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    setState(() {
      _username = doc.data()?['username'] ?? 'Writer';
    });
  }

  void _showEditUsernameDialog() {
    final TextEditingController controller = TextEditingController(text: _username);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Edit Username"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter new username"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newUsername = controller.text.trim();
                if (newUsername.isEmpty) return;
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .update({'username': newUsername});
                  setState(() {
                    _username = newUsername;
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color mainBlue = Color(0xFF0D2144);

    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          title: const Text(
            "Welcome Farwa!",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          centerTitle: true,
          backgroundColor: mainBlue,
        ),

        // ✅ Drawer with Username + Edit + Logout
        drawer: Drawer(
          width: MediaQuery.of(context).size.width * 0.6,
          child: Container(
            color: Colors.white,
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: mainBlue,
                    child: Text(
                      _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 30),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _username,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),

                  ListTile(
                    leading: const Icon(Icons.edit, color: mainBlue),
                    title: const Text("Edit Username"),
                    onTap: _showEditUsernameDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: mainBlue),
                    title: const Text("Logout"),
                    onTap: () async {
                      // Sign out from all Auth providers
                      await FirebaseAuth.instance.signOut();
                      await Supabase.instance.client.auth.signOut();
                      await GoogleSignIn.instance.signOut();

                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        body: _buildBody(context, mainBlue),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Color mainBlue) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ✅ Logo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: mainBlue,
              borderRadius: BorderRadius.circular(20),
              image: const DecorationImage(
                image: AssetImage('assets/images/logo.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ✅ Farwa Khalid (dancing script) and e-book novels (poppins)
          Text(
            "Farwa Khalid",
            style: GoogleFonts.dancingScript(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: mainBlue,
            ),
          ),
          Text(
            "e-book novels",
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: mainBlue,
            ),
          ),
          const SizedBox(height: 24),

          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildCard(context, mainBlue,
                  title: "Upload New Novel/eBook",
                  icon: Icons.cloud_upload,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WriteNovelScreen()),
                    );
                  }),
              _buildCard(context, mainBlue,
                  title: "Delete",
                  icon: Icons.edit,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditNovelScreen()),
                    );
                  }),
              _buildCard(context, mainBlue,
                  title: "Add/Edit",
                  icon: Icons.message,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddScreen()),
                    );
                  }),
              _buildCard(context, mainBlue,
                  title: "Post Notifications",
                  icon: Icons.campaign,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PostNotificationsScreen()),
                    );
                  }),
              _buildCard(context, mainBlue,
                  title: "Manage Payments",
                  icon: Icons.payment,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminPaymentScreen()),
                    );
                  }),
              _buildCard(context, mainBlue,
                  title: "Grant Access",
                  icon: Icons.lock_open,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminAccessScreen()),
                    );
                  }),
              _buildCard(context, mainBlue,
                  title: "Manage Access",
                  icon: Icons.admin_panel_settings,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ManageAccessScreen()),
                    );
                  }),
              _buildCard(context, mainBlue,
                  title: "Voiceovers",
                  icon: Icons.mic,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WriterVoiceoverScreen()),
                    );
                  }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
      BuildContext context,
      Color mainBlue, {
        required String title,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: mainBlue.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: mainBlue),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: mainBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
