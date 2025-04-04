import 'package:flutter/material.dart';
import 'package:chat_application/service/chat_service/chatlist_service.dart';
import 'package:chat_application/user_screen/chat_screen/chart.dart'; 
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _chatUsers = [];
  List<Map<String, dynamic>> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchChatUsers();
  }

  // Fetch chat list
  void _fetchChatUsers() async {
    try {
      final users = await _chatService.fetchChatList();
      setState(() {
        _chatUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading chat list: $e");
      setState(() => _isLoading = false);
    }
  }

  // Search users by name
  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoading = true;
    });

    try {
      final results = await _chatService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print("Error searching users: $e");
      setState(() => _isLoading = false);
    }
  }

  // Get logged-in user ID
  Future<int> getLoggedInUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId != null) {
      return userId;
    } else {
      throw Exception("User ID not found in SharedPreferences.");
    }
  }

  // Navigate to Chat Screen
  void _openChatScreen(int receiverId, String receiverName) async {
    final BuildContext currentContext =
        context; // Store the context before the async call

    try {
      final loggedInUserId = await getLoggedInUserId();

      if (!currentContext.mounted) return; // Ensure context is still valid

      Navigator.push(
        currentContext, // Use stored context
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            senderId: loggedInUserId,
            senderName: receiverName,
            receiverId: receiverId,
          ),
        ),
      );
    } catch (e) {
      print("Error fetching logged-in user ID: $e");
    }
  }

  // Logout function
  Future<void> _logout() async {
    final BuildContext ctx = context; // Store context before async operations

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token'); // Remove authentication token
    await prefs.remove('user_id'); // Remove user ID

    if (ctx.mounted) {
      ctx.go('/'); // Navigate to Login page using go_router
    }
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
            icon: const Icon(Icons.logout),
            onPressed: _logout, // Call logout function
            tooltip: "Logout",
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: "Search users...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // Loading Indicator
          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // Display Search Results (if searching)
          if (_isSearching && _searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          NetworkImage(_searchResults[index]['image'] ?? ''),
                    ),
                    title: Text(_searchResults[index]['name']),
                    onTap: () => _openChatScreen(
                      _searchResults[index]['id'],
                      _searchResults[index]['name'],
                    ),
                  );
                },
              ),
            )

          // Display Chat List (if not searching)
          else if (!_isSearching)
            Expanded(
              child: ListView.builder(
                itemCount: _chatUsers.length,
                itemBuilder: (context, index) {
                  String lastMessage =
                      _chatUsers[index]['last_message'] ?? 'No messages yet';

                  if (lastMessage.startsWith('[FILE:image]')) {
                    lastMessage = 'Image received';
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          NetworkImage(_chatUsers[index]['image'] ?? ''),
                    ),
                    title: Text(_chatUsers[index]['name']),
                    subtitle: Text(lastMessage),
                    onTap: () => _openChatScreen(
                      _chatUsers[index]['id'],
                      _chatUsers[index]['name'],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
