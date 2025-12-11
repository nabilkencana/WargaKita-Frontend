import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewer extends StatefulWidget {
  final String url;

  const PdfViewer({super.key, required this.url});

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  @override
  Widget build(BuildContext context) {
    return PDFView(
      filePath: widget.url,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      onRender: (pages) {
        // PDF siap ditampilkan
      },
      onError: (error) {
        print('PDF Error: $error');
      },
      onPageError: (page, error) {
        print('Page $page error: $error');
      },
      onViewCreated: (PDFViewController controller) {
        // Controller untuk navigasi PDF
      },
    );
  }
}