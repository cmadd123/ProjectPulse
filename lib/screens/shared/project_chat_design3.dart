import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';

// Design 3 (Personality Injection) version of ProjectChatScreen
// - Human-friendly timestamps ("2 hours ago" vs "2:30 PM")
// - Warmer empty state message
// - More encouraging send feedback

class ProjectChatDesign3 extends StatefulWidget {
  final String projectId;
  final String projectName;
  final bool isContractor;
  final bool embedded;
  final String? emptyStateHint; // Override empty state text
  final String? inputHint; // Override input placeholder

  const ProjectChatDesign3({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.isContractor,
    this.embedded = false,
    this.emptyStateHint,
    this.inputHint,
  });

  @override
  State<ProjectChatDesign3> createState() => _ProjectChatDesign3State();
}

class _ProjectChatDesign3State extends State<ProjectChatDesign3> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('messages')
          .add({
        'text': text,
        'sender_ref': FirebaseFirestore.instance.collection('users').doc(user.uid),
        'sender_role': widget.isContractor ? 'contractor' : 'client',
        'created_at': FieldValue.serverTimestamp(),
        'read': false,
      });

      _messageController.clear();

      // Notify the other party about the new message
      if (!widget.isContractor) {
        NotificationService.sendChatMessageNotification(
          projectId: widget.projectId,
          projectName: widget.projectName,
          messagePreview: text,
        );
      }

      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  // Human-friendly timestamp
  String _formatTimestamp(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    // Older messages - show date
    return DateFormat('MMM d').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    final body = Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('projects')
                  .doc(widget.projectId)
                  .collection('messages')
                  .orderBy('created_at', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.emptyStateHint ??
                                (widget.isContractor
                                    ? 'Send a message to your client'
                                    : 'Send a message to your contractor'),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                // Auto-scroll to bottom on new messages
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final text = data['text'] as String;
                    final senderRole = data['sender_role'] as String;
                    final createdAt = (data['created_at'] as Timestamp?)?.toDate();
                    final isMe = senderRole == (widget.isContractor ? 'contractor' : 'client');

                    return _buildMessageBubble(
                      text: text,
                      isMe: isMe,
                      senderRole: senderRole,
                      timestamp: createdAt,
                    );
                  },
                );
              },
            ),
          ),

          // Message input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 12,
                bottom: (MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom
                    : 48) + 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: widget.inputHint ??
                            (widget.isContractor
                                ? 'Send an update...'
                                : 'Ask a question...'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
    );

    if (widget.embedded) return body;


    return Scaffold(
      extendBody: false,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.projectName),
            const Text(
              'Messages',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: body,
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isMe,
    required String senderRole,
    DateTime? timestamp,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: senderRole == 'contractor'
                      ? Colors.blue[700]
                      : Colors.orange[700],
                  child: Text(
                    senderRole == 'contractor' ? '🔨' : '👤',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: senderRole == 'contractor'
                      ? Colors.blue[700]
                      : Colors.orange[700],
                  child: Text(
                    senderRole == 'contractor' ? '🔨' : '👤',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 0 : 40,
                right: isMe ? 40 : 0,
              ),
              child: Text(
                _formatTimestamp(timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
