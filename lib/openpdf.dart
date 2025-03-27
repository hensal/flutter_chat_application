import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';


class PDFViewPage extends StatelessWidget {
  final String fileUrl;

  PDFViewPage({required this.fileUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF Viewer'),
      ),
      body: Center(
        child: PDFView(
          filePath: fileUrl,
        ),
      ),
    );
  }
}
