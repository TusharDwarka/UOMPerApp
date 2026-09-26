import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';

import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// In-app PDF viewer (pages rendered by the `printing` package, which works
/// on Android and Windows). Double-tap a page to zoom.
class PdfViewerScreen extends StatefulWidget {
  final String title;
  final Future<Uint8List> Function() loadBytes;
  final String fileName;
  final String? filePath; // enables "Open in another app"

  const PdfViewerScreen({super.key, required this.title, required this.loadBytes, required this.fileName, this.filePath});

  /// Opens a PDF stored on the device.
  static Future<void> openFile(BuildContext context, String path, {String? title}) {
    final name = path.split(RegExp(r'[\\/]')).last;
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PdfViewerScreen(
        title: title ?? name,
        fileName: name,
        filePath: path,
        loadBytes: () => File(path).readAsBytes(),
      ),
    ));
  }

  static bool isPdf(String name) => name.toLowerCase().endsWith('.pdf');

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final Future<Uint8List> _bytes = widget.loadBytes();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (context, snap) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.textPrimary)),
                      ),
                      if (snap.hasData) ...[
                        CircleIconButton(
                          icon: Icons.print_rounded,
                          tooltip: 'Print',
                          onPressed: () => Printing.layoutPdf(onLayout: (_) async => snap.data!, name: widget.fileName),
                        ),
                        const SizedBox(width: 6),
                        CircleIconButton(
                          icon: Icons.ios_share_rounded,
                          tooltip: 'Share',
                          onPressed: () => Printing.sharePdf(bytes: snap.data!, filename: widget.fileName),
                        ),
                        if (widget.filePath != null) ...[
                          const SizedBox(width: 6),
                          CircleIconButton(
                            icon: Icons.open_in_new_rounded,
                            tooltip: 'Open in another app',
                            onPressed: () => OpenFilex.open(widget.filePath!),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: snap.hasError
                      ? EmptyState(icon: Icons.error_outline_rounded, title: 'Could not open this PDF', subtitle: '${snap.error}')
                      : !snap.hasData
                          ? const Center(child: CircularProgressIndicator())
                          : PdfPreview(
                              build: (_) async => snap.data!,
                              useActions: false,
                              dynamicLayout: false,
                              canChangeOrientation: false,
                              canChangePageFormat: false,
                              canDebug: false,
                              pdfFileName: widget.fileName,
                              maxPageWidth: 760,
                              scrollViewDecoration: BoxDecoration(color: p.canvas),
                              pdfPreviewPageDecoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: p.softShadow,
                              ),
                              loadingWidget: const Center(child: CircularProgressIndicator()),
                              onError: (context, error) => EmptyState(
                                icon: Icons.error_outline_rounded,
                                title: 'Could not render this PDF',
                                subtitle: '$error',
                              ),
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
