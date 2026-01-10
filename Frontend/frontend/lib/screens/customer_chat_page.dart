import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class CustomerChatPage extends StatefulWidget {
  @override
  _CustomerChatPageState createState() => _CustomerChatPageState();
}

class _CustomerChatPageState extends State<CustomerChatPage> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = false;
  String? _guestEmail;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);

    try {
      final isLoggedIn = _authService.isLoggedIn;

      if (isLoggedIn) {
        // Logged-in user: get their chats
        final chats = await _chatService.getMyChats();
        if (mounted) {
          setState(() {
            _chats = chats;
            _isLoading = false;
          });
        }
      } else {
        // Guest user: ask for email to retrieve chats
        final email = await _showGuestEmailDialog();
        if (email != null) {
          _guestEmail = email;
          final chats = await _chatService.getMyChats(guestEmail: email);
          if (mounted) {
            setState(() {
              _chats = chats;
              _isLoading = false;
            });
          }
        } else {
          // User cancelled
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      }
    } catch (e) {
      print('Error loading chats: $e');
      if (mounted) {
        setState(() => _isLoading = false);

        // Check if it's an authentication error
        if (e.toString().contains('401') ||
            e.toString().contains('Unauthorized') ||
            e.toString().contains('not logged in')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please log in to view chat history'),
              action: SnackBarAction(
                label: 'Login',
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load chats. Please try again.')),
          );
        }
      }
    }
  }

  Future<String?> _showGuestEmailDialog() async {
    final TextEditingController emailController = TextEditingController();

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Enter Your Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please enter your email to view your chat history or start a new chat.'),
            SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'your@email.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid email')),
                );
                return;
              }
              Navigator.pop(context, email);
            },
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _startNewChat() async {
    final isLoggedIn = _authService.isLoggedIn;

    if (isLoggedIn) {
      // Logged-in user: directly create chat
      await _createAndOpenChat();
    } else {
      // Guest user: collect name and email
      final info = await _showGuestInfoDialog();
      if (info != null) {
        await _createAndOpenChat(
          guestName: info['name'],
          guestEmail: info['email'],
        );
      }
    }
  }

  Future<Map<String, String>?> _showGuestInfoDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();

    // Pre-fill email if we already have it
    if (_guestEmail != null) {
      emailController.text = _guestEmail!;
    }

    return await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Start New Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please provide your information to start chatting with support.'),
            SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'Your name',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'your@email.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              if (name.isEmpty || email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please fill in all fields correctly')),
                );
                return;
              }
              Navigator.pop(context, {'name': name, 'email': email});
            },
            child: Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAndOpenChat({String? guestName, String? guestEmail}) async {
    try {
      final response = await _chatService.initiateChat(
        customerName: guestName,
        customerEmail: guestEmail,
      );

      final chatId = response['chatId'];
      if (chatId != null && mounted) {
        // Navigate to conversation page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CustomerChatConversationPage(
              chatId: chatId,
              guestEmail: guestEmail,
            ),
          ),
        ).then((_) {
          // Refresh chat list when returning
          _loadChats();
        });
      }
    } catch (e) {
      print('Error creating chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e')),
        );
      }
    }
  }

  void _openChat(Map<String, dynamic> chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerChatConversationPage(
          chatId: chat['id'],
          guestEmail: _guestEmail,
        ),
      ),
    ).then((_) {
      // Refresh chat list when returning
      _loadChats();
    });
  }

  String _getChatStatusText(String status) {
    switch (status) {
      case 'active':
        return 'Waiting for support';
      case 'claimed':
        return 'Agent responding';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  Color _getChatStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.orange;
      case 'claimed':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Support Chat'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadChats,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No chat history',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Start a new conversation with support',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _startNewChat,
                        icon: Icon(Icons.add),
                        label: Text('Start New Chat'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    final status = chat['status'] ?? 'active';
                    final lastMessage = chat['lastMessage'];
                    final unreadCount = chat['unreadCount'] ?? 0;
                    final createdAt = chat['createdAt'];

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getChatStatusColor(status),
                          child: Icon(
                            status == 'closed' ? Icons.check : Icons.chat,
                            color: Colors.white,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getChatStatusText(status),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              SizedBox(height: 4),
                              Text(
                                lastMessage['text'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            SizedBox(height: 4),
                            Text(
                              _formatDate(createdAt),
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () => _openChat(chat),
                      ),
                    );
                  },
                ),
      floatingActionButton: _chats.isNotEmpty
          ? FloatingActionButton(
              onPressed: _startNewChat,
              child: Icon(Icons.add),
              tooltip: 'Start New Chat',
            )
          : null,
    );
  }

  String _formatDate(dynamic dateTime) {
    if (dateTime == null) return '';

    try {
      DateTime dt;
      if (dateTime is String) {
        dt = DateTime.parse(dateTime);
      } else if (dateTime is DateTime) {
        dt = dateTime;
      } else {
        return '';
      }

      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inDays == 0) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (e) {
      return '';
    }
  }
}

// Conversation page for customer
class CustomerChatConversationPage extends StatefulWidget {
  final String chatId;
  final String? guestEmail;

  CustomerChatConversationPage({required this.chatId, this.guestEmail});

  @override
  _CustomerChatConversationPageState createState() => _CustomerChatConversationPageState();
}

class _CustomerChatConversationPageState extends State<CustomerChatConversationPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  Timer? _refreshTimer;
  String _chatStatus = 'active'; // active, claimed, closed
  List<PlatformFile> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();

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
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await _chatService.getMessages(widget.chatId);
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response['messages'] ?? []);
          _chatStatus = response['chatStatus'] ?? 'active';
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
      print('Error loading messages: $e');
      if (mounted && !silent) {
        setState(() => _isLoading = false);
        // Check if it's an authentication error
        if (e.toString().contains('401') || e.toString().contains('Unauthorized') || e.toString().contains('not logged in')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please log in to view this chat'),
              action: SnackBarAction(
                label: 'Login',
                onPressed: () {
                  // Navigate to login
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load chat. Please try again.')),
          );
        }
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi'],
        allowMultiple: true,
      );

      if (result != null && mounted) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      print('Error picking files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick files: $e')),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if ((text.isEmpty && _selectedFiles.isEmpty) || _isSending) return;

    setState(() => _isSending = true);

    try {
      List<Map<String, dynamic>>? attachments;

      // Upload files if any
      if (_selectedFiles.isNotEmpty) {
        attachments = [];
        for (var file in _selectedFiles) {
          try {
            // Convert file to base64
            String base64Data;
            if (kIsWeb) {
              base64Data = base64Encode(file.bytes!);
            } else {
              final bytes = await file.xFile.readAsBytes();
              base64Data = base64Encode(bytes);
            }

            // Upload file
            final uploadResult = await _chatService.uploadFile(
              fileName: file.name,
              fileData: base64Data,
              mimeType: _getMimeType(file.extension ?? ''),
            );

            attachments.add({
              'url': uploadResult['url'],
              'type': _getFileType(file.extension ?? ''),
              'name': file.name,
            });
          } catch (e) {
            print('Error uploading file ${file.name}: $e');
          }
        }
      }

      // Send message with attachments
      await _chatService.sendMessage(
        chatId: widget.chatId,
        message: text,
        attachments: attachments,
      );

      _messageController.clear();
      setState(() => _selectedFiles.clear());
      await _loadMessages(silent: true);
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'application/octet-stream';
    }
  }

  String _getFileType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'document';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return 'image';
      case 'mp4':
      case 'mov':
      case 'avi':
        return 'video';
      default:
        return 'file';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with Support'),
      ),
      body: Column(
        children: [
          // Closed chat warning banner
          if (_chatStatus == 'closed')
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              color: Colors.red[100],
              child: Row(
                children: [
                  Icon(Icons.lock, color: Colors.red[900], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This chat has been closed. You cannot send new messages.',
                      style: TextStyle(
                        color: Colors.red[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Send a message to start the conversation',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isCustomer = message['sender'] == 'customer';
                          final isSupport = message['sender'] == 'support';
                          final text = message['message'] ?? '';
                          final createdAt = message['createdAt'];
                          final attachments = message['attachments'] as List?;

                          // Customer = sağda mavi, Support = solda turuncu
                          final alignment = isCustomer ? Alignment.centerRight : Alignment.centerLeft;
                          final color = isCustomer ? Colors.blue : (isSupport ? Colors.orange[700] : Colors.grey[300]);
                          final textColor = (isCustomer || isSupport) ? Colors.white : Colors.black;

                          return Align(
                            alignment: alignment,
                            child: Container(
                              margin: EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.all(12),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isCustomer) ...[
                                    Text(
                                      'Support Agent',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                  ],
                                  if (text.isNotEmpty) ...[
                                    Text(
                                      text,
                                      style: TextStyle(
                                        color: textColor,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                  ],
                                  // Show attachments
                                  if (attachments != null && attachments.isNotEmpty) ...[
                                    ...attachments.map((attachment) {
                                      final attachmentMap = attachment as Map<String, dynamic>;
                                      final type = attachmentMap['type'] ?? 'file';
                                      final url = attachmentMap['url'] ?? '';
                                      final name = attachmentMap['name'] ?? 'Attachment';

                                      // Show image directly
                                      if (type == 'image' && url.isNotEmpty) {
                                        return GestureDetector(
                                          onTap: () {
                                            // Show image in dialog
                                            showDialog(
                                              context: context,
                                              builder: (context) => Dialog(
                                                backgroundColor: Colors.transparent,
                                                child: Stack(
                                                  children: [
                                                    Center(
                                                      child: InteractiveViewer(
                                                        child: Image.network(
                                                          url,
                                                          fit: BoxFit.contain,
                                                          loadingBuilder: (context, child, loadingProgress) {
                                                            if (loadingProgress == null) return child;
                                                            return Center(
                                                              child: CircularProgressIndicator(
                                                                value: loadingProgress.expectedTotalBytes != null
                                                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                                    : null,
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: 10,
                                                      right: 10,
                                                      child: IconButton(
                                                        icon: Icon(Icons.close, color: Colors.white, size: 30),
                                                        onPressed: () => Navigator.pop(context),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      bottom: 10,
                                                      right: 10,
                                                      child: IconButton(
                                                        icon: Icon(Icons.open_in_new, color: Colors.white, size: 24),
                                                        onPressed: () async {
                                                          try {
                                                            final uri = Uri.parse(url);
                                                            if (await canLaunchUrl(uri)) {
                                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                            } else {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(content: Text('Cannot open this image')),
                                                              );
                                                            }
                                                          } catch (e) {
                                                            print('Could not open: $e');
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text('Failed to open image: $e')),
                                                            );
                                                          }
                                                        },
                                                        tooltip: 'Open in new tab',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            margin: EdgeInsets.only(top: 8),
                                            constraints: BoxConstraints(
                                              maxWidth: 200,
                                              maxHeight: 200,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.3),
                                                width: 2,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.network(
                                                url,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Container(
                                                    height: 150,
                                                    width: 150,
                                                    child: Center(
                                                      child: CircularProgressIndicator(
                                                        value: loadingProgress.expectedTotalBytes != null
                                                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                            : null,
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    height: 150,
                                                    width: 150,
                                                    color: Colors.grey[300],
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.broken_image, size: 40, color: Colors.grey[600]),
                                                        SizedBox(height: 8),
                                                        Text('Image not available', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      // Show video/PDF with icon and name
                                      return InkWell(
                                        onTap: () async {
                                          if (url.isNotEmpty) {
                                            try {
                                              final uri = Uri.parse(url);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                              }
                                            } catch (e) {
                                              print('Could not launch $url: $e');
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Could not open file')),
                                                );
                                              }
                                            }
                                          }
                                        },
                                        child: Container(
                                          margin: EdgeInsets.only(top: 4),
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                type == 'video'
                                                    ? Icons.videocam
                                                    : type == 'document'
                                                        ? Icons.picture_as_pdf
                                                        : Icons.attach_file,
                                                color: textColor,
                                                size: 24,
                                              ),
                                              SizedBox(width: 8),
                                              Flexible(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: TextStyle(
                                                        color: textColor,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      'Tap to open',
                                                      style: TextStyle(
                                                        color: textColor.withValues(alpha: 0.7),
                                                        fontSize: 10,
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
                                  ],
                                  SizedBox(height: 4),
                                  Text(
                                    _formatTime(createdAt),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: (isCustomer || isSupport) ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Message input - disabled if chat is closed
          if (_chatStatus != 'closed')
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Selected files preview
                  if (_selectedFiles.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(bottom: 8),
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedFiles.length,
                        itemBuilder: (context, index) {
                          final file = _selectedFiles[index];
                          return Container(
                            margin: EdgeInsets.only(right: 8),
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _getFileIcon(file.extension ?? ''),
                                        size: 30,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        file.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                    icon: Icon(Icons.close, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(),
                                    onPressed: () => _removeFile(index),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  // Input row
                  Row(
                    children: [
                      // Attach button
                      IconButton(
                        icon: Icon(Icons.attach_file),
                        onPressed: _isSending ? null : _pickFiles,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: _isSending
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                icon: Icon(Icons.send, color: Colors.white),
                                onPressed: _isSending ? null : _sendMessage,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatTime(dynamic dateTime) {
    if (dateTime == null) return '';

    try {
      DateTime dt;
      if (dateTime is String) {
        dt = DateTime.parse(dateTime);
      } else if (dateTime is DateTime) {
        dt = dateTime;
      } else {
        return '';
      }

      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
