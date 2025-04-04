import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  static const String _baseUrl = 'http://localhost:5003';

Future<Map<String, dynamic>> sendMessage(int receiverId, String message, File? file) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');

  if (token == null) {
    return {'success': false, 'message': 'No token found, please login again'};
  }

  if (message.isEmpty && file == null) {
    return {'success': false, 'message': 'Either message or file must be provided'};
  }

  final url = Uri.parse('http://localhost:5003/send-message');

  Map<String, dynamic> body = {
    'receiver_id': receiverId,
    'message': message.isNotEmpty ? message : null,
  };

  if (file != null) {
    final fileType = file.path.split('.').last.toLowerCase();
    final fileName = file.path.split('/').last;

    if (fileType == 'jpg' || fileType == 'jpeg' || fileType == 'png') {
      // Convert image to base64 and send it
      final fileBytes = await file.readAsBytes();
      final base64File = base64Encode(fileBytes);
      body['file'] = base64File;
    } else if (fileType == 'pdf') {
      // Only send the filename, not the file content
      body['file'] = null;
      body['fileName'] = fileName;
    }

    body['fileType'] = fileType;
  }

  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  );

  final responseBody = jsonDecode(response.body);

  if (response.statusCode == 200) {
    return {'success': true, 'message': 'Message sent successfully', 'data': responseBody};
  } else {
    return {'success': false, 'message': 'Failed to send message: ${responseBody["message"]}'};
  }
}



Future<List<Map<String, dynamic>>> fetchMessages(int userId, int otherUserId) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');

  if (token == null) {
    throw Exception('No authentication token found');
  }

  final response = await http.get(
    Uri.parse('$_baseUrl/messages?sender_id=$userId&receiver_id=$otherUserId'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    final List<dynamic> responseBody = json.decode(response.body);

    return responseBody.map((msg) {
      String message = msg["message"] ?? "";
      String? fileUrl;
      String? imageBase64;

      if (msg["file_type"] == "pdf") {
        fileUrl = '$_baseUrl${msg["file_url"]}'; // Get the URL for the PDF
      } else if (msg["file_type"] == "image" && msg["image_data"] != null) {
        imageBase64 = 'data:image/jpeg;base64,${msg["image_data"]}';
      }

      return {
        "message": message,
        "fileUrl": fileUrl, // URL for PDF download
        "imageBase64": imageBase64, // Base64 encoded image
        "created_at": msg["created_at"] ?? "",
        "sender_id": msg["sender_id"],
        "receiver_id": msg["receiver_id"],
      };
    }).toList();
  } else {
    throw Exception('Failed to load messages: ${response.body}');
  }
}


}
