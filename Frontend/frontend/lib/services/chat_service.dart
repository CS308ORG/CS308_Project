import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ChatService {
  // Use localhost for web, 127.0.0.1 for others to avoid CORS issues
  static String get baseUrl => kIsWeb ? 'http://localhost:3000' : 'http://localhost:3000';

  // Customer: Initiate a chat
  Future<Map<String, dynamic>> initiateChat({
    String? customerName,
    String? customerEmail,
  }) async {
    try {
      final token = AuthService().token;
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final body = json.encode({
        if (customerName != null) 'customerName': customerName,
        if (customerEmail != null) 'customerEmail': customerEmail,
      });

      print('ChatService: Initiating chat to $baseUrl/chat/initiate');
      print('ChatService: Headers: $headers');
      print('ChatService: Body: $body');

      final response = await http.post(
        Uri.parse('$baseUrl/chat/initiate'),
        headers: headers,
        body: body,
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout - Is the backend running on $baseUrl?');
        },
      );

      print('ChatService: Response status: ${response.statusCode}');
      print('ChatService: Response body: ${response.body}');

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to initiate chat (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('ChatService: Error initiating chat: $e');
      throw Exception('Error initiating chat: $e');
    }
  }

  // Customer: Send message
  Future<Map<String, dynamic>> sendMessage({
    required String chatId,
    required String message,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      final token = AuthService().token;
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final body = json.encode({
        'message': message,
        if (attachments != null) 'attachments': attachments,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/chat/$chatId/messages'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to send message: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  // Get chat messages (returns both messages and chat status)
  Future<Map<String, dynamic>> getMessages(String chatId) async {
    try {
      final token = AuthService().token;
      final headers = <String, String>{
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/chat/$chatId/messages'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'messages': List<Map<String, dynamic>>.from(data['messages'] ?? []),
          'chatStatus': data['chatStatus'] ?? 'active',
        };
      } else {
        throw Exception('Failed to get messages: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting messages: $e');
    }
  }

  // Upload file
  Future<Map<String, dynamic>> uploadFile({
    required String fileName,
    required String fileData, // base64
    required String mimeType,
  }) async {
    try {
      final token = AuthService().token;
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final body = json.encode({
        'fileName': fileName,
        'fileData': fileData,
        'mimeType': mimeType,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/chat/upload'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to upload file: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error uploading file: $e');
    }
  }

  // Customer: Get my chats
  Future<List<Map<String, dynamic>>> getMyChats({String? guestEmail}) async {
    try {
      final token = AuthService().token;
      final headers = <String, String>{
        if (token != null) 'Authorization': 'Bearer $token',
      };

      var uri = Uri.parse('$baseUrl/chat/my-chats');
      if (guestEmail != null) {
        uri = uri.replace(queryParameters: {'email': guestEmail});
      }

      final response = await http.get(
        uri,
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['chats'] ?? []);
      } else {
        throw Exception('Failed to get chats: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting chats: $e');
    }
  }

  // Support Agent: Get chat queue
  Future<List<Map<String, dynamic>>> getChatQueue() async {
    try {
      final token = AuthService().token;
      if (token == null) throw Exception('Not authenticated');

      final headers = <String, String>{
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/support/chats/queue'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['chats'] ?? []);
      } else {
        throw Exception('Failed to get chat queue: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting chat queue: $e');
    }
  }

  // Support Agent: Claim a chat
  Future<Map<String, dynamic>> claimChat(String chatId) async {
    try {
      final token = AuthService().token;
      if (token == null) throw Exception('Not authenticated');

      final headers = <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/support/chats/$chatId/claim'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to claim chat: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error claiming chat: $e');
    }
  }

  // Support Agent: Send response
  Future<Map<String, dynamic>> sendAgentResponse({
    required String chatId,
    required String message,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      final token = AuthService().token;
      if (token == null) throw Exception('Not authenticated');

      final headers = <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final body = json.encode({
        'message': message,
        if (attachments != null) 'attachments': attachments,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/support/chats/$chatId/respond'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to send response: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending response: $e');
    }
  }

  // Support Agent: Get customer context
  Future<Map<String, dynamic>> getCustomerContext(String chatId) async {
    try {
      final token = AuthService().token;
      if (token == null) throw Exception('Not authenticated');

      final headers = <String, String>{
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/support/chats/$chatId/customer-context'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get customer context: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting customer context: $e');
    }
  }

  // Support Agent: Close chat
  Future<Map<String, dynamic>> closeChat(String chatId) async {
    try {
      final token = AuthService().token;
      if (token == null) throw Exception('Not authenticated');

      final headers = <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.put(
        Uri.parse('$baseUrl/support/chats/$chatId/close'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to close chat: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error closing chat: $e');
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead({
    required String chatId,
    required List<String> messageIds,
  }) async {
    try {
      final token = AuthService().token;
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final body = json.encode({
        'messageIds': messageIds,
      });

      await http.put(
        Uri.parse('$baseUrl/chat/$chatId/messages/read'),
        headers: headers,
        body: body,
      );
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }
}
