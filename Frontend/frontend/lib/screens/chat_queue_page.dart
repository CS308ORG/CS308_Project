import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'chat_conversation_page.dart';
import 'dart:async';

class ChatQueuePage extends StatefulWidget {
  final bool showClosed;

  const ChatQueuePage({Key? key, this.showClosed = false}) : super(key: key);

  @override
  _ChatQueuePageState createState() => _ChatQueuePageState();
}

class _ChatQueuePageState extends State<ChatQueuePage> {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadChats();
    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _loadChats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final chats = await _chatService.getChatQueue();
      if (mounted) {
        setState(() {
          _chats = chats;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _claimAndOpenChat(String chatId) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Claim the chat
      await _chatService.claimChat(chatId);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Navigate to conversation
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatConversationPage(chatId: chatId),
          ),
        );

        // Refresh list when returning
        if (result == true) {
          _loadChats();
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to claim chat: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else if (timestamp is Map && timestamp.containsKey('_seconds')) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(
          timestamp['_seconds'] * 1000,
        );
      } else {
        return '';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return '${difference.inDays}d ago';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showClosed ? 'Chat History' : 'Live Chat Queue'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadChats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('Error: $_error'),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadChats,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _chats.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            widget.showClosed ? 'No chat history' : 'No active chats',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadChats,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _chats.length,
                        itemBuilder: (context, index) {
                          final chat = _chats[index];
                          final customerInfo = chat['customerInfo'] ?? {};
                          final lastMessage = chat['lastMessage'];
                          final unreadCount = chat['unreadCount'] ?? 0;
                          final status = chat['status'] ?? 'active';
                          final isClaimed = status == 'claimed';

                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isClaimed
                                    ? Colors.orange
                                    : Theme.of(context).primaryColor,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      customerInfo['name'] ?? 'Guest',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$unreadCount',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (lastMessage != null) ...[
                                    Text(
                                      lastMessage['message'] ?? 'Attachment',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                  ],
                                  Row(
                                    children: [
                                      Icon(
                                        isClaimed ? Icons.lock : Icons.lock_open,
                                        size: 12,
                                        color: isClaimed
                                            ? Colors.orange
                                            : Colors.green,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        isClaimed ? 'Claimed' : 'Available',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isClaimed
                                              ? Colors.orange
                                              : Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Spacer(),
                                      Text(
                                        _formatTimestamp(chat['lastMessageAt']),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () => _claimAndOpenChat(chat['id']),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
