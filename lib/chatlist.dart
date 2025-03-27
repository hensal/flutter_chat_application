import 'package:chat_application/chart.dart';
import 'package:chat_application/main.dart';
import 'package:flutter/material.dart';
import 'package:chat_application/service/chatlist_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import your LoginPage

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _chatUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChatUsers();
  }

  // Fetch the list of chat users
  void _fetchChatUsers() async {
    try {
      final users = await _chatService.fetchChatList();
      setState(() {
        _chatUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading chat list: $e");
    }
  }

  // Fetch logged-in user ID from SharedPreferences
  Future<int> getLoggedInUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId != null) {
      return userId;
    } else {
      throw Exception("User ID not found in SharedPreferences.");
    }
  }

  // Logout function
  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green,
          title: const Text("Chats"),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.exit_to_app),
              onPressed: _logout,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _chatUsers.length,
                itemBuilder: (context, index) {
                  String lastMessage =
                      _chatUsers[index]['last_message'] ?? 'No messages yet';

                  // If the last message is "Image received", display that text instead
                  if (lastMessage.startsWith('[FILE:image]')) {
                    lastMessage =
                        'Image received'; // Replace with 'Image received'
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          NetworkImage(_chatUsers[index]['image'] ?? ''),
                    ),
                    title: Text(_chatUsers[index]['name']),
                    subtitle: Text(
                        lastMessage), // Show 'Image received' if the message is an image
                    onTap: () async {
                      try {
                        final loggedInUserId = await getLoggedInUserId();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              senderId: loggedInUserId,
                              senderName:
                                  _chatUsers[index]['name'] ?? "Unknown",
                              receiverId: _chatUsers[index]['id'] ?? 0,
                            ),
                          ),
                        );
                      } catch (e) {
                        print("Error fetching logged-in user ID: $e");
                      }
                    },
                  );
                },
              ));
  }
}
