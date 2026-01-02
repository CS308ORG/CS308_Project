import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'dart:async';

class ChatConversationPage extends StatefulWidget {
  final String chatId;

  const ChatConversationPage({Key? key, required this.chatId})
      : super(key: key);

  @override
  _ChatConversationPageState createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _customerContext;
  bool _isLoading = true;
  bool _isSending = false;
  bool _showCustomerInfo = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadCustomerContext();
    // Auto-refresh messages every 3 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    try {
      if (!silent && mounted) {
        setState(() => _isLoading = true);
      }

      final response = await _chatService.getMessages(widget.chatId);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response['messages'] ?? []);
          _isLoading = false;
        });

        // Scroll to bottom
        Future.delayed(Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e')),
        );
      }
    }
  }

  Future<void> _loadCustomerContext() async {
    try {
      final context = await _chatService.getCustomerContext(widget.chatId);
      if (mounted) {
        setState(() {
          _customerContext = context;
        });
      }
    } catch (e) {
      print('Failed to load customer context: $e');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await _chatService.sendAgentResponse(
        chatId: widget.chatId,
        message: message,
      );

      _messageController.clear();
      await _loadMessages(silent: true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _closeChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Close Chat'),
        content: Text('Are you sure you want to close this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Close Chat'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _chatService.closeChat(widget.chatId);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to close chat: $e')),
        );
      }
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

      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Widget _buildCustomerInfoPanel() {
    if (_customerContext == null) {
      return Center(child: CircularProgressIndicator());
    }

    final isGuest = _customerContext!['isGuest'] == true;

    return Container(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            if (isGuest) ...[
              _buildInfoRow('Name', _customerContext!['customerName'] ?? 'N/A'),
              _buildInfoRow('Email', _customerContext!['customerEmail'] ?? 'N/A'),
              SizedBox(height: 8),
              Text('Guest User', style: TextStyle(color: Colors.grey)),
            ] else ...[
              _buildInfoRow('Name', _customerContext!['profile']?['name'] ?? 'N/A'),
              _buildInfoRow('Email', _customerContext!['profile']?['email'] ?? 'N/A'),
              _buildInfoRow('Role', _customerContext!['profile']?['role'] ?? 'N/A'),
              SizedBox(height: 16),
              Text(
                'Recent Orders',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              if (_customerContext!['recentOrders']?.isEmpty ?? true)
                Text('No orders', style: TextStyle(color: Colors.grey))
              else
                ..._customerContext!['recentOrders'].take(3).map<Widget>((order) {
                  return Card(
                    child: ListTile(
                      title: Text('Order #${order['id']}'),
                      subtitle: Text('Status: ${order['status']}'),
                      trailing: Text('\$${order['total_amount']}'),
                    ),
                  );
                }).toList(),
              SizedBox(height: 16),
              Text(
                'Cart Items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              if (_customerContext!['cart']?.isEmpty ?? true)
                Text('Cart is empty', style: TextStyle(color: Colors.grey))
              else
                Text('${_customerContext!['cart'].length} items in cart'),
              SizedBox(height: 16),
              Text(
                'Wishlist',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              if (_customerContext!['wishlist']?.isEmpty ?? true)
                Text('Wishlist is empty', style: TextStyle(color: Colors.grey))
              else
                Text('${_customerContext!['wishlist'].length} items in wishlist'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Conversation'),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              setState(() {
                _showCustomerInfo = !_showCustomerInfo;
              });
            },
            tooltip: 'Customer Info',
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: _closeChat,
            tooltip: 'Close Chat',
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: _showCustomerInfo ? 2 : 1,
            child: Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _messages.isEmpty
                          ? Center(
                              child: Text('No messages yet'),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                final isAgent = message['senderType'] == 'agent';
                                final messageText = message['message'] ?? '';
                                final timestamp = _formatTimestamp(message['createdAt']);

                                return Align(
                                  alignment: isAgent
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 12),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width * 0.7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAgent
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          messageText,
                                          style: TextStyle(
                                            color: isAgent
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          timestamp,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isAgent
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        offset: Offset(0, -2),
                        blurRadius: 4,
                        color: Colors.black12,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                          enabled: !_isSending,
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: _isSending
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.send),
                        onPressed: _isSending ? null : _sendMessage,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_showCustomerInfo)
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(
                  left: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: _buildCustomerInfoPanel(),
            ),
        ],
      ),
    );
  }
}
