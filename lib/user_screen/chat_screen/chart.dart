import 'dart:convert';
import 'package:chat_application/user_screen/openpdf.dart';
import 'package:chat_application/service/chat_service/chat_service.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final int senderId;
  final String senderName;
  final int receiverId;
  const ChatScreen({
    super.key,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
  });
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final ChatService _chatService = ChatService();
  bool _isSending = false;
  bool _showEmojiPicker = false;
  late int senderId;
  late int receiverId;
  late String senderName;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    senderId = widget.senderId;
    senderName = widget.senderName;
    receiverId = widget.receiverId;
    print("Logged-in user ID UI: $senderId");
    print("Receiver ID UI: $receiverId");
    _fetchMessages();
  }

  void _sendMessage({PlatformFile? pdfFile, Uint8List? imageBytes}) async {
    if (_controller.text.isEmpty && (imageBytes == null && pdfFile == null)) {
      return;
    }

    setState(() => _isSending = true);
    String messageContent = _controller.text;
    // If an image is selected, encode it as base64
    String? base64Image;
    if (imageBytes != null) {
      try {
        base64Image = base64Encode(imageBytes);
        messageContent +=
            '[FILE:image]$base64Image'; // Append the image data as base64
      } catch (e) {
        print('Error encoding image: $e');
      }
    }
    // If a PDF is selected, append its name and base64 content
    if (pdfFile != null) {
      try {
        messageContent = pdfFile.name; // Only send filename
      } catch (e) {
        print('Error encoding PDF: $e');
      }
    }
    // Send the message along with the base64-encoded file if present
    final response = await _chatService.sendMessage(
      receiverId,
      messageContent,
      imageBytes != null
          ? null
          : pdfFile != null
              ? null
              : null,
    );

    if (!response['success']) {
      print('Failed to send message: ${response['message']}');
    }
    _fetchMessages();
    setState(() {
      _isSending = false;
      _pickedImageBytes = null;
      _controller.clear();
    });
  }

  void _fetchMessages() async {
    try {
      final messages = await _chatService.fetchMessages(senderId, receiverId);
      setState(() {
        _messages.clear();
        _messages.addAll(messages.map((msg) {
          final rawMessage = msg["message"] ?? "";
          final isFile = rawMessage.startsWith("[FILE:");
          String? fileName;
          String? fileUrl; // Store file URL for PDFs
          Uint8List? imageBytes;

          if (isFile) {
            final fileData =
                rawMessage.replaceAll(RegExp(r'^\[FILE:[^\]]+\]'), '').trim();

            if (rawMessage.startsWith("[FILE:image]")) {
              try {
                if (RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(fileData)) {
                  imageBytes = base64Decode(fileData);
                } else {
                  print("Invalid base64 string for image.");
                }
              } catch (e) {
                print('Error decoding image: $e');
              }
            } else if (rawMessage.startsWith("[pdf]")) {
              fileName = fileData; // Extract file name only for PDF
              fileUrl = msg["fileUrl"]; // Get the URL for the PDF file
            }
          }
          return {
            "text": isFile ? null : rawMessage,
            "imageBytes": imageBytes,
            "fileName": fileName, // Display file name for PDF
            "fileUrl": fileUrl, // Store the file URL for PDF
            "isSender": msg["sender_id"] == senderId,
            "timestamp":
                DateTime.tryParse(msg["created_at"] ?? "") ?? DateTime.now(),
          };
        }));

        _messages.sort((a, b) => a["timestamp"].compareTo(b["timestamp"]));
      });
      // Use a post-frame callback to ensure the scroll happens after the messages are updated.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollToBottom();
        }
      });
    } catch (e) {
      print("Error loading messages: $e");
    }
  }

  Future<Uint8List?> compressImage(Uint8List imageBytes) async {
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return null;

    img.Image compressedImage = img.copyResize(image, width: 800);
    return Uint8List.fromList(img.encodeJpg(compressedImage, quality: 85));
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'pdf'
      ], // Allow PDF files as well
      withData: true,
    );

    if (result != null) {
      final pickedFile = result.files.single;

      // Check if the selected file is an image
      if (pickedFile.extension == 'jpg' ||
          pickedFile.extension == 'jpeg' ||
          pickedFile.extension == 'png') {
        setState(() => _pickedImageBytes = pickedFile.bytes);

        if (_pickedImageBytes != null) {
          _pickedImageBytes = await compressImage(_pickedImageBytes!);
          _showImagePreviewSheet(_pickedImageBytes!);
        }
      }

      else if (pickedFile.extension == 'pdf') {
        print('PDF selected: ${pickedFile.name}');
        _showPdfPreviewSheet(pickedFile);
      }
    }
  }

  void _showPdfPreviewSheet(PlatformFile pdfFile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(10),
          height: 200,
          child: Column(
            children: [
              const Text(
                'Selected PDF',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(pdfFile.name), 
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: const Text("Cancel"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      setState(() => _pickedImageBytes = null);
                      Navigator.pop(context); 
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text("Send"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      Navigator.pop(context); 
                      _sendMessage(pdfFile: pdfFile); 
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPdf(String fileUrl) {
    // Load and open PDF
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewPage(fileUrl: fileUrl),
      ),
    );
  }

  void _showImagePreviewSheet(Uint8List imageBytes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(10),
          height: 250,
          child: Column(
            children: [
              const Text(
                'Selected Image',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Image.memory(imageBytes,
                  width: 150, height: 150), 
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: const Text("Cancel"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      setState(() => _pickedImageBytes = null);
                      Navigator.pop(context);
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text("Send"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      Navigator.pop(context);
                      _sendMessage(
                          imageBytes:
                              imageBytes); 
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        position + 550, 
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  Future<void> _logout() async {
    final BuildContext ctx = context; 

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token'); 
    await prefs.remove('user_id'); 

    if (ctx.mounted) {
      ctx.go('/'); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Row(
          children: [
            const CircleAvatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(senderName, style: const TextStyle(fontSize: 18)),
                  const Text("Active 3m ago",
                      style: TextStyle(fontSize: 14, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          const Icon(Icons.call),
          const SizedBox(width: 10),
          const Icon(Icons.videocam),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (_showEmojiPicker) {
            _toggleEmojiPicker();
          }
        },
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final bool isSender = message["isSender"];
                  final String? messageText = message["text"];
                  final Uint8List? imageBytes = message["imageBytes"];
                  final String? fileUrl = message["fileUrl"];
                  final String? fileName = message["fileName"];

                  return Align(
                    alignment: isSender
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: 10),
                      decoration: BoxDecoration(
                        color: isSender ? Colors.green : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: imageBytes != null
                          ? Image.memory(
                              imageBytes,
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                            )
                          : fileUrl != null
                              ? GestureDetector(
                                  onTap: () {
                                    _openPdf(fileUrl);
                                  },
                                  child: Text('File received: $fileName'),
                                )
                              : Text(
                                  messageText ?? '',
                                  style: TextStyle(
                                    color: isSender
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                    ),
                  );
                },
              ),
            ),
            if (_showEmojiPicker) 
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    setState(() {
                      _controller.text += emoji.emoji;
                    });
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Icon(Icons.mic, color: Colors.grey[850]),
                  const SizedBox(width: 5),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: "Type message",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: IconButton(
                          icon: Icon(
                            _showEmojiPicker
                                ? Icons.keyboard
                                : Icons.emoji_emotions,
                            color: Colors.grey[850],
                          ),
                          onPressed: _toggleEmojiPicker,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.attach_file),
                              onPressed: _pickImage,
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.camera_alt, color: Colors.grey[850]),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: _isSending
                        ? const CircularProgressIndicator(color: Colors.green)
                        : const Icon(Icons.send, color: Colors.green),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey,
    );
  }
}