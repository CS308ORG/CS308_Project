import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

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
  List<PlatformFile> _selectedFiles = [];

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
      print('Loading customer context for chat: ${widget.chatId}');
      final context = await _chatService.getCustomerContext(widget.chatId);
      print('Customer context loaded successfully: ${context.toString()}');
      if (mounted) {
        setState(() {
          _customerContext = context;
        });
        print('Customer context set in state');
      }
    } catch (e) {
      print('Failed to load customer context: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load customer info: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if ((message.isEmpty && _selectedFiles.isEmpty) || _isSending) return;

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

      await _chatService.sendAgentResponse(
        chatId: widget.chatId,
        message: message,
        attachments: attachments,
      );

      _messageController.clear();
      setState(() => _selectedFiles.clear());
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
              Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Name', _customerContext!['customerName'] ?? 'N/A'),
                      _buildInfoRow('Email', _customerContext!['customerEmail'] ?? 'N/A'),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Guest User',
                          style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, size: 20, color: Theme.of(context).primaryColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _customerContext!['profile']?['name'] ?? 'N/A',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.email, size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _customerContext!['profile']?['email'] ?? 'N/A',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.badge, size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _customerContext!['profile']?['role']?.toString().toUpperCase() ?? 'CUSTOMER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Recent Orders',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              if (_customerContext!['recentOrders']?.isEmpty ?? true)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text('No orders yet', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                )
              else
                ..._customerContext!['recentOrders'].take(5).map<Widget>((order) {
                  final orderId = order['id']?.toString().substring(0, 8) ?? 'N/A';
                  final status = order['status'] ?? 'pending';
                  final totalAmount = order['total_amount'] ?? order['totalAmount'] ?? 0;
                  final deliveryStatus = order['delivery_status'] ?? order['deliveryStatus'] ?? 'processing';
                  final orderDate = order['created_at'] ?? order['createdAt'];

                  Color statusColor;
                  IconData statusIcon;

                  switch (status.toLowerCase()) {
                    case 'completed':
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle;
                      break;
                    case 'cancelled':
                      statusColor = Colors.red;
                      statusIcon = Icons.cancel;
                      break;
                    case 'pending':
                      statusColor = Colors.orange;
                      statusIcon = Icons.hourglass_empty;
                      break;
                    default:
                      statusColor = Colors.blue;
                      statusIcon = Icons.info;
                  }

                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.shopping_bag, size: 16, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text(
                                    'Order #$orderId',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              Text(
                                '\$${totalAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              SizedBox(width: 4),
                              Text(
                                'Status: ${status.toUpperCase()}',
                                style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.local_shipping, size: 14, color: Colors.grey),
                              SizedBox(width: 4),
                              Text(
                                'Delivery: ${deliveryStatus.toUpperCase()}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                          if (orderDate != null) ...[
                            SizedBox(height: 4),
                            Text(
                              _formatOrderDate(orderDate),
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              SizedBox(height: 16),
              Text(
                'Shopping Cart',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_cart, color: Theme.of(context).primaryColor),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (_customerContext!['cart']?.isEmpty ?? true)
                              ? 'Cart is empty'
                              : '${_customerContext!['cart'].length} item(s) in cart',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Wishlist',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.favorite, color: Colors.red),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (_customerContext!['wishlist']?.isEmpty ?? true)
                              ? 'Wishlist is empty'
                              : '${_customerContext!['wishlist'].length} item(s) in wishlist',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatOrderDate(dynamic date) {
    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is Map && date.containsKey('_seconds')) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(date['_seconds'] * 1000);
      } else {
        return '';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
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
                                final attachments = message['attachments'] as List?;

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
                                        if (messageText.isNotEmpty) ...[
                                          Text(
                                            messageText,
                                            style: TextStyle(
                                              color: isAgent
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          if (attachments != null && attachments.isNotEmpty)
                                            SizedBox(height: 8),
                                        ],
                                        if (attachments != null && attachments.isNotEmpty)
                                          ...attachments.map((attachment) {
                                            final type = attachment['type'] ?? 'file';
                                            final name = attachment['name'] ?? 'File';
                                            final url = attachment['url'] ?? '';

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
                                                      color: isAgent ? Colors.white.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
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
                                            IconData icon;
                                            Color iconColor;

                                            if (type == 'video') {
                                              icon = Icons.videocam;
                                              iconColor = Colors.red;
                                            } else if (type == 'document') {
                                              icon = Icons.picture_as_pdf;
                                              iconColor = Colors.red[700]!;
                                            } else {
                                              icon = Icons.attach_file;
                                              iconColor = Colors.blue;
                                            }

                                            return Container(
                                              margin: EdgeInsets.only(top: 4),
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isAgent
                                                    ? Colors.white.withValues(alpha: 0.2)
                                                    : Colors.white.withValues(alpha: 0.5),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: InkWell(
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
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      icon,
                                                      size: 24,
                                                      color: isAgent ? Colors.white : iconColor,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Flexible(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            name,
                                                            style: TextStyle(
                                                              color: isAgent ? Colors.white : Colors.black87,
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          Text(
                                                            'Tap to open',
                                                            style: TextStyle(
                                                              color: isAgent ? Colors.white70 : Colors.black54,
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
                                          }),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedFiles.isNotEmpty)
                        Container(
                          height: 80,
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedFiles.length,
                            itemBuilder: (context, index) {
                              final file = _selectedFiles[index];
                              return Container(
                                width: 100,
                                margin: EdgeInsets.only(right: 8),
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
                                            file.extension == 'pdf'
                                                ? Icons.picture_as_pdf
                                                : (file.extension == 'mp4' ||
                                                        file.extension == 'mov' ||
                                                        file.extension == 'avi')
                                                    ? Icons.videocam
                                                    : Icons.image,
                                            size: 32,
                                            color: Colors.grey[700],
                                          ),
                                          SizedBox(height: 4),
                                          Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 4),
                                            child: Text(
                                              file.name,
                                              style: TextStyle(fontSize: 10),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: InkWell(
                                        onTap: () => _removeFile(index),
                                        child: Container(
                                          padding: EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.attach_file),
                            onPressed: _isSending ? null : _pickFiles,
                            color: Theme.of(context).primaryColor,
                          ),
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
