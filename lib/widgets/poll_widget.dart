import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:async';

import '../models/poll.dart';

class PollWidget extends StatefulWidget {
  final String pollId;
  final bool isWriter;

  const PollWidget({super.key, required this.pollId, this.isWriter = false});

  @override
  State<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends State<PollWidget> {
  String? _userId;
  StreamSubscription<AuthState>? _authSubscription;

  // Defines the main blue app color
  final Color mainBlue = const Color(0xFF0D2144);

  @override
  void initState() {
    super.initState();
    _loadUserId();
    
    // Listen for auth changes to support switching accounts dynamically
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _loadUserId();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    // 1. Try Supabase Auth (Priority - "Gmail ID")
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (mounted) setState(() => _userId = user.id);
      return;
    }

    // 2. Fallback: Device ID (For anonymous readers)
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('poll_user_id');
    if (id == null) {
      final random = Random();
      id = '${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(100000)}';
      await prefs.setString('poll_user_id', id);
    }
    if (mounted) setState(() => _userId = id);
  }

  // Optimistic State
  bool _isVoting = false;
  String? _optimisticOptionId;

  Future<void> _vote(String optionId) async {
    if (_userId == null) return;
    
    // 1. Optimistic Update
    setState(() {
      _isVoting = true;
      _optimisticOptionId = optionId;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final pollRef = firestore.collection('polls').doc(widget.pollId);
      final voteRef = pollRef.collection('votes').doc(_userId);

      await firestore.runTransaction((transaction) async {
        final pollSnapshot = await transaction.get(pollRef);
        final voteSnapshot = await transaction.get(voteRef);

        if (!pollSnapshot.exists) throw Exception("Poll does not exist");

        final poll = Poll.fromFirestore(pollSnapshot);
        String? previousOptionId;

        if (voteSnapshot.exists) {
          previousOptionId = voteSnapshot.data()?['optionId'];
          if (previousOptionId == optionId) return; // Same vote
        }

        // Calculate new options
        List<Map<String, dynamic>> newOptions = poll.options.map((opt) {
          int votes = opt.votes;
          if (opt.id == previousOptionId) votes--;
          if (opt.id == optionId) votes++;
          return {
            'id': opt.id,
            'text': opt.text,
            'votes': max(0, votes), // Ensure no negative
          };
        }).toList();

        // Update Poll
        transaction.update(pollRef, {'options': newOptions});

        // Update User Vote
        transaction.set(voteRef, {
          'optionId': optionId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint("Vote error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      // 2. Clear Optimistic State
      if (mounted) {
        setState(() {
          _isVoting = false;
          _optimisticOptionId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('polls').doc(widget.pollId).snapshots(),
      builder: (context, pollSnapshot) {
        if (pollSnapshot.hasError) return Text('Error: ${pollSnapshot.error}');
        if (!pollSnapshot.hasData || !pollSnapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final poll = Poll.fromFirestore(pollSnapshot.data!);
        
        // Listen to user's vote
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('polls')
              .doc(widget.pollId)
              .collection('votes')
              .doc(_userId)
              .snapshots(),
          builder: (context, voteSnapshot) {
            String? selectedOptionId;
            if (voteSnapshot.hasData && voteSnapshot.data!.exists) {
              selectedOptionId = voteSnapshot.data!['optionId'];
            }
            
            // ✅ OPTIMISTIC UI: Override with local state if voting
            if (_isVoting && _optimisticOptionId != null) {
              selectedOptionId = _optimisticOptionId;
            }

            int totalVotes = poll.options.fold(0, (sum, item) => sum + item.votes);

            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Question Header
                  Text(
                    poll.question,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  ...poll.options.map((option) {
                    final percent = totalVotes == 0 ? 0.0 : (option.votes / totalVotes);
                    final isSelected = option.id == selectedOptionId;
                    
                    return GestureDetector(
                      onTap: () => (widget.isWriter || _isVoting) ? null : _vote(option.id),
                      child: Container(
                        height: 54, 
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? mainBlue : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          color: _isVoting && isSelected ? Colors.blue.shade50 : Colors.transparent,
                        ),
                        child: Stack(
                          children: [
                            // Progress Bar Background
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10), 
                              child: FractionallySizedBox(
                                widthFactor: percent == 0 ? 0.0 : percent,
                                child: Container(
                                  color: isSelected 
                                      ? mainBlue.withOpacity(0.15) 
                                      : Colors.grey.shade100,
                                ),
                              ),
                            ),
                            
                            // Content Overlay
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  // Text
                                  Expanded(
                                    child: Text(
                                      option.text,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: isSelected ? mainBlue : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  
                                  // User Feedback: Loading or Check
                                  if (_isVoting && isSelected)
                                     const Padding(
                                       padding: EdgeInsets.only(right: 8),
                                       child: SizedBox(
                                         width: 16, height: 16, 
                                         child: CircularProgressIndicator(strokeWidth: 2)
                                       ),
                                     )
                                  else if (isSelected)
                                     Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Icon(Icons.check_circle, color: mainBlue, size: 20),
                                    ),

                                  Text(
                                    '${(percent * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? mainBlue : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  
                  if (totalVotes > 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$totalVotes votes',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
