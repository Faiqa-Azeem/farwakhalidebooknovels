import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import your upload screens
import 'upload_novel.dart';
import 'upload_ebook.dart';

class WriteNovelScreen extends StatelessWidget {
  const WriteNovelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color mainBlue = Color(0xFF0D2144);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: mainBlue,
        title: const Text(
          "Choose What to Write",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "What do you want to write?",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: mainBlue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Novel Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UploadNovelScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: mainBlue,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Novel",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),

            // E-Book Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UploadEbookScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: mainBlue, width: 2),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "E-Book",
                style: TextStyle(fontSize: 16, color: mainBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
