import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:house_of_tutor/StudentHome.dart';
import 'package:house_of_tutor/StudentAllClasses.dart';
import 'package:house_of_tutor/StudentCourses.dart';
import 'package:house_of_tutor/StudentDrawer.dart';
import 'package:house_of_tutor/services/api_client.dart';
import 'package:house_of_tutor/services/api_config.dart';
import 'package:house_of_tutor/services/auth_store.dart';
import 'package:url_launcher/url_launcher.dart';

// ====================================================================
// DESIGN COLORS
// ====================================================================

const Color _teal = Color(0xFF0F8579);
const Color _tealSoft = Color(0xFFE6F4F2);
const Color _ink = Color(0xFF1E293B);
const Color _muted = Color(0xFF64748B);
const Color _pageBg = Color(0xFFF5F7FA);
const Color _softBlue = Color(0xFFEAF1FF);
const Color _softGrey = Color(0xFFF1F5F9);
const Color _border = Color(0xFFE2E8F0);
const Color _danger = Color(0xFFDC2626);

const List<BoxShadow> _cardShadow = [
  BoxShadow(
    color: Color(0x140F172A),
    blurRadius: 10,
    offset: Offset(0, 3),
  ),
];

const int _maxTotalBytes = 100 * 1024 * 1024; // 100 MB

// ====================================================================
// SMALL HELPERS
// ====================================================================

// Server address without "/api" and without a trailing slash
String _baseUrl() {
  String base = apiBaseUrl.trim();

  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  if (base.toLowerCase().endsWith('/api')) {
    base = base.substring(0, base.length - 4);
  }

  return base;
}

// API url from an endpoint like /api/Student/xyz
String _apiUrl(String endpoint) {
  if (!endpoint.startsWith('/')) endpoint = '/$endpoint';
  return '${_baseUrl()}$endpoint';
}

// Real URL of an uploaded file (image / pdf / doc)
String _fileUrl(String filePath) {
  String path = filePath.trim().replaceAll('\\', '/');

  if (path.isEmpty) return '';

  if (path.startsWith('http://') || path.startsWith('https://')) {
    return Uri.encodeFull(path);
  }

  final int index = path.toLowerCase().indexOf('/coursecontent/');

  if (index != -1) {
    path = path.substring(index);
  } else if (path.toLowerCase().startsWith('coursecontent/')) {
    path = '/$path';
  }

  path = path.replaceFirst(
    RegExp(r'^/?wwwroot/', caseSensitive: false),
    '',
  );

  if (!path.startsWith('/')) path = '/$path';

  return Uri.encodeFull('${_baseUrl()}$path');
}

// Safe JSON decode
dynamic _decode(String body) {
  if (body.trim().isEmpty) return null;

  try {
    return jsonDecode(body);
  } catch (_) {
    return null;
  }
}

// Readable error text from a failed response
String _errorText(http.Response r, String fallback) {
  final data = _decode(r.body);

  if (data is Map) {
    final msg = data['message'] ?? data['title'] ?? data['error'];

    if (msg != null && msg.toString().trim().isNotEmpty) {
      return msg.toString();
    }

    if (data['errors'] is Map) {
      final parts = <String>[];

      (data['errors'] as Map).forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          parts.add('$key: ${value.first}');
        }
      });

      if (parts.isNotEmpty) return parts.join('\n');
    }
  }

  return '$fallback (Error ${r.statusCode})';
}

// Any 2xx response is a success (200, 201, 204)
bool _isSuccess(int code) => code >= 200 && code < 300;

// Multipart request with JWT token.
//  - UPLOAD API: List<IFormFile> -> field name "files"
//  - UPDATE API: single optional IFormFile -> field name "file"
Future<http.Response> _sendFile({
  required String method,
  required String endpoint,
  required Map<String, String> fields,
  List<File> files = const [],
  File? file,
}) async {
  await AuthStore.instance.hydrate();
  final token = AuthStore.instance.token;

  if (token == null || token.toString().isEmpty) {
    throw Exception('Login token not found. Please login again.');
  }

  final request = http.MultipartRequest(method, Uri.parse(_apiUrl(endpoint)));
  request.headers['Authorization'] = 'Bearer $token';
  request.headers['Accept'] = 'application/json';
  request.fields.addAll(fields);

  for (final f in files) {
    request.files.add(await http.MultipartFile.fromPath('files', f.path));
  }

  if (file != null) {
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
  }

  final streamed = await request.send().timeout(const Duration(minutes: 5));
  return http.Response.fromStream(streamed);
}

// Loading circle while a task runs, then closes itself
Future<T> _withLoader<T>(
  BuildContext context,
  Future<T> Function() task, {
  String message = 'Please wait...',
}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _teal),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    return await task();
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

Future<bool> _openExternal(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

int _courseIdOf(dynamic c) {
  if (c is! Map) return 0;

  return int.tryParse(
        (c['course_id'] ?? c['courseId'] ?? c['CourseId'] ?? '0').toString(),
      ) ??
      0;
}

String _courseNameOf(dynamic c) {
  if (c is! Map) return 'Course';

  return (c['course_name'] ??
          c['courseName'] ??
          c['CourseName'] ??
          c['course_title'] ??
          c['CourseTitle'] ??
          'Course')
      .toString();
}

// Course codes list: [{course_code, institute, program}, ...]
List<dynamic> _courseCodesOf(dynamic c) {
  if (c is! Map) return [];

  final codes = c['course_codes'] ?? c['courseCodes'] ?? c['CourseCodes'];

  return codes is List ? codes : [];
}

String _codeOf(dynamic code) {
  if (code is! Map) return '';

  return (code['course_code'] ??
          code['courseCode'] ??
          code['CourseCode1'] ??
          '')
      .toString();
}

String _instituteOf(dynamic code) =>
    code is Map ? (code['institute'] ?? '').toString() : '';

String _programOf(dynamic code) =>
    code is Map ? (code['program'] ?? '').toString() : '';

int _contentIdOf(Map content) {
  return int.tryParse(
        (content['content_id'] ?? content['contentId'] ?? '0').toString(),
      ) ??
      0;
}

bool _isImageName(String name) {
  final n = name.toLowerCase().trim();

  return n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png');
}

IconData _fileIcon(String name, {required bool isImage}) {
  final n = name.toLowerCase().trim();

  if (isImage) return Icons.image_rounded;
  if (n.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
  if (n.endsWith('.doc') || n.endsWith('.docx')) {
    return Icons.description_rounded;
  }

  return Icons.insert_drive_file_rounded;
}

Color _fileColor(String name, {required bool isImage}) {
  final n = name.toLowerCase().trim();

  if (isImage) return const Color(0xFF7C3AED);
  if (n.endsWith('.pdf')) return const Color(0xFFDC2626);
  if (n.endsWith('.doc') || n.endsWith('.docx')) {
    return const Color(0xFF2563EB);
  }

  return _teal;
}

String _fileTypeLabel(String name, {required bool isImage}) {
  final n = name.toLowerCase().trim();

  if (isImage) return 'IMAGE';
  if (n.endsWith('.pdf')) return 'PDF';
  if (n.endsWith('.doc') || n.endsWith('.docx')) return 'DOC';

  return 'FILE';
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';

  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// "2026-09-17T10:20:00" -> "17 Sep 2026"
String _formatDate(dynamic value) {
  if (value == null) return '';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  try {
    final d = DateTime.parse(value.toString()).toLocal();
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  } catch (_) {
    return value.toString();
  }
}

InputDecoration _fieldStyle(String hint, {Widget? prefix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
    prefixIcon: prefix,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _teal, width: 1.5),
    ),
  );
}

Widget _fieldLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 14),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _ink,
      ),
    ),
  );
}

Widget _sheetHandle() {
  return Center(
    child: Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

Widget _circleClose(VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: _softGrey,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.close, size: 20, color: _ink),
    ),
  );
}

// ====================================================================
// DASHED BORDER (file picker box)
// ====================================================================

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, this.radius = 16});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ====================================================================
// IMAGE VIEWER (zoomable)
// ====================================================================

class _ImageViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String> headers;

  const _ImageViewerScreen({
    required this.url,
    required this.title,
    required this.headers,
  });

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  int attempt = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Open in browser',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => _openExternal(widget.url),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(
            widget.url,
            key: ValueKey(attempt),
            headers: widget.headers,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;

              return SizedBox(
                height: 300,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint('IMAGE LOAD ERROR: ${widget.url} -> $error');

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image_outlined,
                      size: 60,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load image',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => attempt++),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// UPLOAD FORM (multiple files)
// ====================================================================

class _ContentFormResult {
  final String title;
  final String description;
  final List<File> files;

  _ContentFormResult(this.title, this.description, this.files);
}

Future<_ContentFormResult?> _showContentForm(
  BuildContext context, {
  required String courseName,
  String submitLabel = 'Upload Selected Files',
}) {
  return showModalBottomSheet<_ContentFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContentFormSheet(
      courseName: courseName,
      submitLabel: submitLabel,
    ),
  );
}

class _ContentFormSheet extends StatefulWidget {
  final String courseName;
  final String submitLabel;

  const _ContentFormSheet({
    required this.courseName,
    required this.submitLabel,
  });

  @override
  State<_ContentFormSheet> createState() => _ContentFormSheetState();
}

class _ContentFormSheetState extends State<_ContentFormSheet> {
  late final TextEditingController titleCtrl =
      TextEditingController(text: widget.courseName);
  final TextEditingController descCtrl = TextEditingController();

  final List<File> files = [];
  final List<String> fileNames = [];
  String error = '';

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  int get totalBytes {
    int total = 0;

    for (final f in files) {
      try {
        total += f.lengthSync();
      } catch (_) {}
    }

    return total;
  }

  // Select many files at once. Tapping again ADDS more files.
  Future<void> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );

    if (result == null) return;

    final existing = files.map((f) => f.path).toSet();

    setState(() {
      for (final item in result.files) {
        if (item.path == null || existing.contains(item.path)) continue;

        files.add(File(item.path!));
        fileNames.add(item.name);
        existing.add(item.path!);
      }

      error = '';
    });
  }

  void submit() {
    if (titleCtrl.text.trim().isEmpty) {
      setState(() => error = 'Please enter content title.');
      return;
    }

    if (files.isEmpty) {
      setState(() => error = 'Please select at least one file.');
      return;
    }

    if (totalBytes > _maxTotalBytes) {
      setState(() => error = 'Total selected files cannot exceed 100 MB.');
      return;
    }

    Navigator.pop(
      context,
      _ContentFormResult(
        titleCtrl.text.trim(),
        descCtrl.text.trim(),
        List<File>.from(files),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasFiles = files.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Course Content',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.courseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    _circleClose(() => Navigator.pop(context)),
                  ],
                ),

                _fieldLabel('Content Title *'),
                TextField(
                  controller: titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldStyle('Example: Week 1 Notes'),
                ),

                _fieldLabel('Description (Optional)'),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldStyle('Enter details about these files'),
                ),

                _fieldLabel('Course Content Files *'),
                InkWell(
                  onTap: pickFiles,
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(
                    painter: _DashedBorderPainter(
                      color: hasFiles ? _teal : const Color(0xFFB6C2D2),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: hasFiles ? _teal.withOpacity(0.06) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _teal.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.cloud_upload,
                              color: _teal,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasFiles
                                      ? '${files.length} file(s) selected'
                                      : 'Select Files',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: hasFiles ? _teal : _ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  hasFiles
                                      ? '${_formatSize(totalBytes)} total - tap to add more'
                                      : 'Tap to choose one or more files',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.attach_file, color: _muted),
                        ],
                      ),
                    ),
                  ),
                ),

                if (fileNames.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...List.generate(fileNames.length, (index) {
                    final name = fileNames[index];
                    final isImg = _isImageName(name);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _fileIcon(name, isImage: isImg),
                            size: 20,
                            color: _fileColor(name, isImage: isImg),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _ink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove file',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setState(() {
                                files.removeAt(index);
                                fileNames.removeAt(index);
                              });
                            },
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: _danger,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Allowed: PDF, DOC, DOCX, JPG, JPEG, PNG. Maximum total: 100 MB.',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ),

                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error,
                      style: const TextStyle(
                        color: _danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: submit,
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(
                      widget.submitLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// EDIT FORM (title, description, optional replacement file)
// ====================================================================

class _EditContentResult {
  final String title;
  final String description;
  final File? replacementFile;

  _EditContentResult(this.title, this.description, this.replacementFile);
}

Future<_EditContentResult?> _showEditContentForm(
  BuildContext context, {
  required String courseName,
  required String title,
  required String description,
  required String currentFileName,
}) {
  return showModalBottomSheet<_EditContentResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditContentSheet(
      courseName: courseName,
      oldTitle: title,
      oldDescription: description,
      currentFileName: currentFileName,
    ),
  );
}

class _EditContentSheet extends StatefulWidget {
  final String courseName;
  final String oldTitle;
  final String oldDescription;
  final String currentFileName;

  const _EditContentSheet({
    required this.courseName,
    required this.oldTitle,
    required this.oldDescription,
    required this.currentFileName,
  });

  @override
  State<_EditContentSheet> createState() => _EditContentSheetState();
}

class _EditContentSheetState extends State<_EditContentSheet> {
  late final TextEditingController titleCtrl;
  late final TextEditingController descCtrl;

  File? replacementFile;
  String replacementName = '';
  String error = '';

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.oldTitle);
    descCtrl = TextEditingController(text: widget.oldDescription);
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  Future<void> pickReplacement() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      replacementFile = File(result.files.single.path!);
      replacementName = result.files.single.name;
      error = '';
    });
  }

  void submit() {
    if (titleCtrl.text.trim().isEmpty) {
      setState(() => error = 'Title is required.');
      return;
    }

    if (replacementFile != null &&
        replacementFile!.lengthSync() > _maxTotalBytes) {
      setState(() => error = 'Replacement file cannot exceed 100 MB.');
      return;
    }

    Navigator.pop(
      context,
      _EditContentResult(
        titleCtrl.text.trim(),
        descCtrl.text.trim(),
        replacementFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasNew = replacementFile != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Content',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.courseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    _circleClose(() => Navigator.pop(context)),
                  ],
                ),

                _fieldLabel('Content Title *'),
                TextField(
                  controller: titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldStyle('Title'),
                ),

                _fieldLabel('Description'),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldStyle('Description'),
                ),

                _fieldLabel('Replace File (Optional)'),
                InkWell(
                  onTap: pickReplacement,
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(
                    painter: _DashedBorderPainter(
                      color: hasNew ? _teal : const Color(0xFFB6C2D2),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: hasNew ? _teal.withOpacity(0.06) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _teal.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.swap_horiz_rounded,
                              color: _teal,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasNew ? replacementName : 'Choose new file',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: hasNew ? _teal : _ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.currentFileName.isEmpty
                                      ? 'Current file will stay if you skip this'
                                      : 'Current: ${widget.currentFileName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.attach_file, color: _muted),
                        ],
                      ),
                    ),
                  ),
                ),

                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error,
                      style: const TextStyle(
                        color: _danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: submit,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text(
                      'Save Changes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// SCREEN 1: COURSE CATALOG + MY COURSES
// ====================================================================

class StudentAddCourses extends StatefulWidget {
  const StudentAddCourses({super.key});

  @override
  State<StudentAddCourses> createState() => _StudentAddCoursesState();
}

class _StudentAddCoursesState extends State<StudentAddCourses> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Tabs: false = Course Catalog, true = My Courses
  bool isMyCoursesView = false;

  // Catalog
  bool catalogLoading = true;
  String catalogError = '';
  List<Map<String, dynamic>> catalogCourses = [];
  final TextEditingController searchCtrl = TextEditingController();
  Timer? searchTimer;
  final Set<int> addingIds = {};

  // My courses
  bool myLoading = true;
  String myError = '';
  List<dynamic> myCourses = [];

  // This screen is "Add Courses" (index 1)
  final int selectedIndex = 1;

  static const String logoPath = 'assets/images/logo.png';

  @override
  void initState() {
    super.initState();
    fetchCatalog();
    fetchMyCourses();
  }

  @override
  void dispose() {
    searchTimer?.cancel();
    searchCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      if (data['data'] is List) return data['data'];
      if (data['courses'] is List) return data['courses'];
    }

    return [];
  }

  String _messageOf(dynamic data, String fallback) {
    if (data is Map && data['message'] != null) {
      final m = data['message'].toString().trim();
      if (m.isNotEmpty) return m;
    }

    return fallback;
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red.shade700 : _teal,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ------------------------------------------------------------
  // Bottom navigation
  // ------------------------------------------------------------

  void onTapBottom(int index) {
    if (index == selectedIndex) return;

    Widget? screen;

    if (index == 0) screen = const StudentHome();
    if (index == 2) screen = const StudentCourses();
    if (index == 3) screen = const StudentAllClasses();

    if (screen == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen!),
    );
  }

  // ------------------------------------------------------------
  // API: catalog (search by course name or course code)
  // GET /api/Student/all-courses?search=
  // Returns only courses NOT enrolled yet.
  // ------------------------------------------------------------

  Future<void> fetchCatalog({String search = ''}) async {
    if (!mounted) return;

    setState(() {
      catalogLoading = true;
      catalogError = '';
    });

    try {
      String url = '/api/Student/all-courses';

      if (search.trim().isNotEmpty) {
        url += '?search=${Uri.encodeQueryComponent(search.trim())}';
      }

      final response = await ApiClient.get(url);
      final data = await ApiClient.decodeJson(response);

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          catalogLoading = false;
          catalogError = _messageOf(data, 'Unable to load course catalog.');
        });
        return;
      }

      // Remove duplicates, keep course codes, sort A-Z
      final Map<int, Map<String, dynamic>> unique = {};

      for (final c in _extractList(data)) {
        final id = _courseIdOf(c);
        if (id == 0) continue;

        unique[id] = {
          'course_id': id,
          'course_name': _courseNameOf(c),
          'course_codes': _courseCodesOf(c),
        };
      }

      final list = unique.values.toList()
        ..sort((a, b) => a['course_name']
            .toString()
            .toLowerCase()
            .compareTo(b['course_name'].toString().toLowerCase()));

      setState(() {
        catalogCourses = list;
        catalogLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        catalogLoading = false;
        catalogError = 'Error loading courses: $e';
      });
    }
  }

  void onSearchChanged(String value) {
    searchTimer?.cancel();
    setState(() {}); // refresh the clear (x) button

    searchTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      fetchCatalog(search: value);
    });
  }

  void clearSearch() {
    searchTimer?.cancel();
    searchCtrl.clear();
    setState(() {});
    fetchCatalog();
  }

  // ------------------------------------------------------------
  // API: my enrolled courses
  // ------------------------------------------------------------

  Future<void> fetchMyCourses({bool silent = false}) async {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        myLoading = true;
        myError = '';
      });
    }

    try {
      var response = await ApiClient.get(
        '/api/Student/my-courses-for-student-add-courses',
      );

      // Fallback to the older endpoint if the new one is not available
      if (response.statusCode == 404) {
        response = await ApiClient.get('/api/Student/my-courses');
      }

      final data = await ApiClient.decodeJson(response);

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          myCourses = _extractList(data);
          myLoading = false;
          myError = '';
        });
      } else {
        setState(() {
          myLoading = false;
          myError = _messageOf(data, 'Unable to load your courses.');
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        myLoading = false;
        myError = 'Error loading your courses: $e';
      });
    }
  }

  // ------------------------------------------------------------
  // "+ Add": ask for content, add the course, upload every file
  // ------------------------------------------------------------

  Future<void> addCourseWithContent(Map<String, dynamic> course) async {
    final int id = _courseIdOf(course);

    if (id == 0 || addingIds.contains(id)) return;

    final form = await _showContentForm(
      context,
      courseName: _courseNameOf(course),
      submitLabel: 'Add Course & Upload',
    );

    if (form == null || !mounted) return;

    setState(() => addingIds.add(id));

    String? error;
    bool added = false;
    int uploaded = 0;

    try {
      // STEP 1: add the course
      final addResponse = await ApiClient.post(
        '/api/Student/add-courses',
        {
          'courseIds': [id],
        },
      );

      if (_isSuccess(addResponse.statusCode)) {
        added = true;

        // STEP 2: one request per file = one content record per file
        for (final f in form.files) {
          final res = await _sendFile(
            method: 'POST',
            endpoint: '/api/Student/upload-course-content',
            fields: {
              'course_id': id.toString(),
              'title': form.title,
              'description': form.description,
            },
            files: [f],
          );

          if (_isSuccess(res.statusCode)) {
            uploaded++;
          } else {
            debugPrint('UPLOAD FAILED: ${res.statusCode} ${res.body}');

            error = 'Course added, but "${f.path.split(Platform.pathSeparator).last}" '
                'failed to upload: ${_errorText(res, 'Upload failed')}. '
                'Open the course and upload the remaining files again.';
            break;
          }
        }
      } else {
        final data = await ApiClient.decodeJson(addResponse);
        error = _messageOf(data, 'Failed to add course.');
      }
    } catch (e) {
      error = added
          ? 'Course added, but upload failed: $e. Open the course and upload again.'
          : 'Error: $e';
    }

    if (!mounted) return;

    if (added) await fetchMyCourses(silent: true);

    if (!mounted) return;

    setState(() {
      addingIds.remove(id);

      if (added) {
        catalogCourses.removeWhere((c) => _courseIdOf(c) == id);
      }
    });

    if (error == null) {
      _snack(
        uploaded == 1
            ? 'Course added and 1 file uploaded.'
            : 'Course added and $uploaded files uploaded.',
      );
    } else {
      _snack(error, error: true);
    }
  }

  // ------------------------------------------------------------
  // Open course content (bottom sheet)
  // ------------------------------------------------------------

  void openCourse(dynamic course) {
    final id = _courseIdOf(course);

    if (id <= 0) {
      _snack('Invalid course ID.', error: true);
      return;
    }

    StudentCourseContentScreen.show(
      context,
      courseId: id,
      courseName: _courseNameOf(course),
    );
  }

  // ------------------------------------------------------------
  // UI: app bar
  // ------------------------------------------------------------

  Widget buildLogo() {
    return Image.asset(
      logoPath,
      height: 32,
      width: 32,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.school, color: _teal, size: 26);
      },
    );
  }

  PreferredSizeWidget buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Container(
            decoration: BoxDecoration(
              color: _softGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu, color: _ink),
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildLogo(),
          const SizedBox(width: 8),
          const Text(
            'House of Tutor',
            style: TextStyle(
              color: _teal,
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _border),
      ),
    );
  }

  // ------------------------------------------------------------
  // UI: header (title, tabs, search)
  // ------------------------------------------------------------

  Widget _tab(String title, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? _teal : _muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isMyCoursesView ? 'My Courses' : 'Course Catalog',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Material(
                color: _tealSoft,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (isMyCoursesView) {
                      fetchMyCourses();
                    } else {
                      fetchCatalog(search: searchCtrl.text);
                    }
                  },
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(Icons.refresh_rounded, color: _teal),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isMyCoursesView
                ? '${myCourses.length} ${myCourses.length == 1 ? 'course' : 'courses'} currently enrolled'
                : 'Search by course name or course code',
            style: const TextStyle(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 16),

          // Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFECEFF3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _tab('Course Catalog', !isMyCoursesView, () {
                    setState(() => isMyCoursesView = false);
                  }),
                ),
                Expanded(
                  child: _tab(
                    'My Courses (${myCourses.length})',
                    isMyCoursesView,
                    () {
                      setState(() => isMyCoursesView = true);
                      fetchMyCourses(silent: true);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Search (catalog only)
          if (!isMyCoursesView) ...[
            const SizedBox(height: 14),
            TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                searchTimer?.cancel();
                fetchCatalog(search: value);
              },
              decoration: InputDecoration(
                hintText: 'Search course name or code (e.g. OOP, CS)',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search, color: _muted),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        onPressed: clearSearch,
                        icon: const Icon(Icons.close, color: _muted),
                      )
                    : null,
                filled: true,
                fillColor: _pageBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _teal, width: 1.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildListTitle() {
    final String title = isMyCoursesView ? 'Your Enrollments' : 'Available Courses';
    final String count = isMyCoursesView
        ? '${myCourses.length} courses'
        : '${catalogCourses.length} found';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _tealSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _teal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // UI: empty / error state
  // ------------------------------------------------------------

  Widget buildState({
    required IconData icon,
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: _tealSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _teal, size: 42),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: _muted, height: 1.5),
        ),
        if (buttonText != null && onPressed != null) ...[
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------
  // UI: course code box (code, institute, program)
  // ------------------------------------------------------------

  Widget _metaRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: _muted),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget buildCodeBox(dynamic code, {bool last = false}) {
    final String courseCode = _codeOf(code);
    final String institute = _instituteOf(code);
    final String program = _programOf(code);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: last ? 0 : 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE5EAEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.confirmation_number_rounded,
                  size: 17, color: _teal),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  courseCode.isEmpty ? 'Course code not available' : courseCode,
                  style: const TextStyle(
                    color: _teal,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (institute.isNotEmpty) ...[
            const SizedBox(height: 8),
            _metaRow('Institute', institute),
          ],
          if (program.isNotEmpty) ...[
            const SizedBox(height: 5),
            _metaRow('Program', program),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // UI: catalog card
  // ------------------------------------------------------------

  Widget buildCatalogCard(Map<String, dynamic> course) {
    final int id = _courseIdOf(course);
    final bool adding = addingIds.contains(id);
    final List<dynamic> codes = _courseCodesOf(course);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Color(0xFF1E9BF0),
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _courseNameOf(course),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Course content required after adding',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed:
                      id == 0 || adding ? null : () => addCourseWithContent(course),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    disabledBackgroundColor: _teal.withOpacity(0.5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: adding
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 19),
                            SizedBox(width: 3),
                            Text(
                              'Add',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEDF0F2)),
          const SizedBox(height: 12),
          if (codes.isEmpty)
            const Text(
              'No course code available',
              style: TextStyle(fontSize: 13, color: _muted),
            )
          else
            ...List.generate(
              codes.length,
              (i) => buildCodeBox(codes[i], last: i == codes.length - 1),
            ),
        ],
      ),
    );
  }

  Widget buildCatalogBody() {
    if (catalogLoading) {
      return const Center(child: CircularProgressIndicator(color: _teal));
    }

    Widget content;

    if (catalogError.isNotEmpty && catalogCourses.isEmpty) {
      content = buildState(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load catalog',
        message: catalogError,
        buttonText: 'Try Again',
        onPressed: () => fetchCatalog(search: searchCtrl.text),
      );
    } else if (catalogCourses.isEmpty) {
      final bool searching = searchCtrl.text.trim().isNotEmpty;

      content = buildState(
        icon: Icons.search_off_rounded,
        title: searching ? 'No matching courses found' : 'No available courses',
        message: searching
            ? 'Try another course name or course code.'
            : 'All available courses are already added, or no courses are available.',
        buttonText: searching ? 'Clear Search' : null,
        onPressed: searching ? clearSearch : null,
      );
    } else {
      content = ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        itemCount: catalogCourses.length,
        itemBuilder: (context, index) => buildCatalogCard(catalogCourses[index]),
      );
    }

    return RefreshIndicator(
      color: _teal,
      onRefresh: () => fetchCatalog(search: searchCtrl.text),
      child: content,
    );
  }

  // ------------------------------------------------------------
  // UI: my course card
  // ------------------------------------------------------------

  Widget buildMyCourseCard(dynamic course) {
    final List<dynamic> codes = _courseCodesOf(course);

    final List<String> codeTexts = codes
        .map((c) => _codeOf(c))
        .where((t) => t.trim().isNotEmpty)
        .toList();

    return GestureDetector(
      onTap: () => openCourse(course),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: _cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _softBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.menu_book_rounded, color: _teal, size: 27),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _courseNameOf(course),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Enrolled',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF10A37F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (codeTexts.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            codeTexts.take(2).join(', ') +
                                (codeTexts.length > 2 ? '...' : ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to view and manage content',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget buildMyCoursesBody() {
    if (myLoading) {
      return const Center(child: CircularProgressIndicator(color: _teal));
    }

    Widget content;

    if (myError.isNotEmpty && myCourses.isEmpty) {
      content = buildState(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load courses',
        message: myError,
        buttonText: 'Try Again',
        onPressed: () => fetchMyCourses(),
      );
    } else if (myCourses.isEmpty) {
      content = buildState(
        icon: Icons.menu_book_outlined,
        title: 'No enrolled courses',
        message: 'Add a course from the Course Catalog to get started.',
        buttonText: 'Browse Catalog',
        onPressed: () => setState(() => isMyCoursesView = false),
      );
    } else {
      content = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        itemCount: myCourses.length,
        itemBuilder: (context, index) => buildMyCourseCard(myCourses[index]),
      );
    }

    return RefreshIndicator(
      color: _teal,
      onRefresh: () => fetchMyCourses(),
      child: content,
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _pageBg,
      drawer: const StudentDrawer(),
      appBar: buildAppBar(),
      body: Column(
        children: [
          buildHeader(),
          const Divider(height: 1, color: _border),
          buildListTitle(),
          Expanded(
            child: isMyCoursesView ? buildMyCoursesBody() : buildCatalogBody(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 10,
        selectedItemColor: _teal,
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        onTap: onTapBottom,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            activeIcon: Icon(Icons.add_box),
            label: 'Add Courses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Courses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            activeIcon: Icon(Icons.school),
            label: 'Classes',
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// SCREEN 2: COURSE CONTENT (bottom sheet)
// ====================================================================
//
// Open it with:
//   StudentCourseContentScreen.show(context,
//       courseId: 1, courseName: 'Computer Science');
//
// - Image  -> inline preview + zoomable viewer
// - PDF/DOC -> opens in the phone's viewer
// - Upload (multiple files), Edit (replace file), Delete
// ====================================================================

class StudentCourseContentScreen extends StatefulWidget {
  final int courseId;
  final String courseName;
  final Color primaryColor;

  const StudentCourseContentScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    this.primaryColor = _teal,
  });

  static Future<void> show(
    BuildContext context, {
    required int courseId,
    required String courseName,
    Color primaryColor = _teal,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudentCourseContentScreen(
        courseId: courseId,
        courseName: courseName,
        primaryColor: primaryColor,
      ),
    );
  }

  @override
  State<StudentCourseContentScreen> createState() =>
      _StudentCourseContentScreenState();
}

class _StudentCourseContentScreenState
    extends State<StudentCourseContentScreen> {
  bool isLoading = true;
  List<dynamic> courseContents = [];
  String errorMessage = '';

  // Message shown inside the sheet (snackbars would be hidden behind it)
  String notice = '';
  bool noticeIsError = false;
  Timer? noticeTimer;

  Map<String, String> imageHeaders = {};

  @override
  void initState() {
    super.initState();
    loadToken();
    fetchCourseContent();
  }

  @override
  void dispose() {
    noticeTimer?.cancel();
    super.dispose();
  }

  Future<void> loadToken() async {
    try {
      await AuthStore.instance.hydrate();
      final token = AuthStore.instance.token;

      if (token != null && token.toString().isNotEmpty && mounted) {
        setState(() {
          imageHeaders = {'Authorization': 'Bearer $token'};
        });
      }
    } catch (_) {}
  }

  void setNotice(String text, {bool error = false}) {
    if (!mounted) return;

    noticeTimer?.cancel();

    setState(() {
      notice = text;
      noticeIsError = error;
    });

    noticeTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => notice = '');
    });
  }

  // ------------------------------------------------------------
  // Get content list
  // ------------------------------------------------------------

  Future<void> fetchCourseContent({bool silent = false}) async {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      final response = await ApiClient.get(
        '/api/Student/my-course-content/${widget.courseId}',
      );
      final data = await ApiClient.decodeJson(response);

      if (!mounted) return;

      if (response.statusCode == 200) {
        List<dynamic> content = [];

        if (data is Map && data['data'] is List) {
          content = List<dynamic>.from(data['data']);
        } else if (data is List) {
          content = List<dynamic>.from(data);
        }

        setState(() {
          courseContents = content;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = data is Map
              ? (data['message']?.toString() ?? 'Failed to load course content.')
              : 'Failed to load course content.';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Error loading content: $e';
        isLoading = false;
      });
    }
  }

  // ------------------------------------------------------------
  // Upload (multiple files, one request per file)
  // ------------------------------------------------------------

  Future<void> uploadContent() async {
    final form = await _showContentForm(
      context,
      courseName: widget.courseName,
    );

    if (form == null || !mounted) return;

    int uploaded = 0;
    String? uploadError;

    try {
      await _withLoader(
        context,
        () async {
          for (final f in form.files) {
            final response = await _sendFile(
              method: 'POST',
              endpoint: '/api/Student/upload-course-content',
              fields: {
                'course_id': widget.courseId.toString(),
                'title': form.title,
                'description': form.description,
              },
              files: [f],
            );

            if (_isSuccess(response.statusCode)) {
              uploaded++;
            } else {
              debugPrint('UPLOAD FAILED: ${response.statusCode} ${response.body}');
              uploadError = _errorText(response, 'Upload failed');
              break;
            }
          }
        },
        message: 'Uploading ${form.files.length} file(s)...',
      );
    } catch (e) {
      uploadError = 'Upload error: $e';
    }

    if (!mounted) return;

    // Refresh even on partial success so uploaded files appear
    await fetchCourseContent(silent: true);

    if (uploadError == null) {
      setNotice(
        uploaded == 1
            ? '1 file uploaded successfully.'
            : '$uploaded files uploaded successfully.',
      );
    } else {
      setNotice(
        '$uploaded of ${form.files.length} files uploaded. $uploadError',
        error: true,
      );
    }
  }

  // ------------------------------------------------------------
  // Edit (title / description / optional replacement file)
  // PUT /api/Student/update-course-content/{contentId}
  // ------------------------------------------------------------

  Future<void> editContent(Map<String, dynamic> content, String fileName) async {
    final int contentId = _contentIdOf(content);

    if (contentId <= 0) {
      setNotice('Content ID is missing. Cannot edit this item.', error: true);
      return;
    }

    final form = await _showEditContentForm(
      context,
      courseName: widget.courseName,
      title: content['title']?.toString() ?? '',
      description: content['description']?.toString() ?? '',
      currentFileName: fileName,
    );

    if (form == null || !mounted) return;

    try {
      final response = await _withLoader(
        context,
        () => _sendFile(
          method: 'PUT',
          endpoint: '/api/Student/update-course-content/$contentId',
          fields: {
            'title': form.title,
            'description': form.description,
          },
          file: form.replacementFile,
        ),
        message: 'Saving changes...',
      );

      if (!mounted) return;

      if (_isSuccess(response.statusCode)) {
        setNotice('Course content updated successfully.');
        await fetchCourseContent(silent: true);
      } else {
        debugPrint('UPDATE FAILED: ${response.statusCode} ${response.body}');
        setNotice(_errorText(response, 'Update failed'), error: true);
      }
    } catch (e) {
      setNotice('Update error: $e', error: true);
    }
  }

  // ------------------------------------------------------------
  // Delete
  // DELETE /api/Student/delete-course-content/{contentId}
  // ------------------------------------------------------------

  Future<void> deleteContent(Map<String, dynamic> content) async {
    final int contentId = _contentIdOf(content);

    if (contentId <= 0) {
      setNotice('Content ID is missing. Cannot delete this item.', error: true);
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Course Content?',
          style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
        content: Text(
          'Are you sure you want to delete "${content['title'] ?? 'Course Content'}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await AuthStore.instance.hydrate();
      final token = AuthStore.instance.token;

      if (token == null || token.toString().isEmpty) {
        throw Exception('Login token not found. Please login again.');
      }

      final response = await _withLoader(
        context,
        () => http.delete(
          Uri.parse(_apiUrl('/api/Student/delete-course-content/$contentId')),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(minutes: 2)),
        message: 'Deleting...',
      );

      if (!mounted) return;

      if (_isSuccess(response.statusCode)) {
        setNotice('Course content deleted successfully.');
        await fetchCourseContent(silent: true);
      } else {
        debugPrint('DELETE FAILED: ${response.statusCode} ${response.body}');
        setNotice(_errorText(response, 'Delete failed'), error: true);
      }
    } catch (e) {
      setNotice('Delete error: $e', error: true);
    }
  }

  // ------------------------------------------------------------
  // Open: image -> in-app viewer, others -> external app
  // ------------------------------------------------------------

  Future<void> openContent({
    required String fileUrl,
    required String title,
    required bool isImage,
  }) async {
    if (fileUrl.isEmpty) {
      setNotice('File is not available.', error: true);
      return;
    }

    if (isImage) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ImageViewerScreen(
            url: fileUrl,
            title: title,
            headers: imageHeaders,
          ),
        ),
      );
      return;
    }

    final opened = await _openExternal(fileUrl);

    if (!opened) setNotice('Unable to open file.', error: true);
  }

  // ------------------------------------------------------------
  // UI pieces
  // ------------------------------------------------------------

  Widget buildBanner() {
    final int n = courseContents.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.library_books_rounded, color: widget.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$n ${n == 1 ? 'content' : 'contents'} uploaded',
              style: TextStyle(
                color: widget.primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildNotice() {
    if (notice.isEmpty) return const SizedBox.shrink();

    final Color color = noticeIsError ? _danger : widget.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            noticeIsError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notice,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildImagePreview(String url, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: 170,
          color: _softGrey,
          child: Image.network(
            url,
            headers: imageHeaders,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;

              return const Center(
                child: CircularProgressIndicator(color: _teal, strokeWidth: 2.4),
              );
            },
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 40,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildCard(Map<String, dynamic> content) {
    final String title =
        (content['title']?.toString().trim().isNotEmpty ?? false)
            ? content['title'].toString()
            : 'Course Content';

    final String description = content['description']?.toString().trim() ?? '';
    final String filePath = content['file_path']?.toString() ?? '';

    String fileName = content['file_name']?.toString().trim() ?? '';

    if (fileName.isEmpty && filePath.isNotEmpty) {
      fileName = filePath.replaceAll('\\', '/').split('/').last;
    }

    final String fileUrl = _fileUrl(filePath);
    final bool isImage = _isImageName(fileName) || _isImageName(filePath);
    final Color typeColor = _fileColor(fileName, isImage: isImage);
    final String date = _formatDate(content['uploaded_date']);

    void open() => openContent(fileUrl: fileUrl, title: title, isImage: isImage);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + title + type badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _fileIcon(fileName, isImage: isImage),
                  color: typeColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _fileTypeLabel(fileName, isImage: isImage),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: typeColor,
                            ),
                          ),
                        ),
                        if (date.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            date,
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: _muted, height: 1.4),
            ),
          ],

          if (isImage && fileUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            buildImagePreview(fileUrl, open),
          ],

          if (fileName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.attach_file, size: 17, color: _muted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // Open
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: fileUrl.isEmpty ? null : open,
              icon: const Icon(Icons.open_in_new, size: 19),
              label: const Text(
                'Open',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Edit + Delete
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => editContent(content, fileName),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.primaryColor,
                    side: BorderSide(color: widget.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => deleteContent(content),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _danger,
                    side: const BorderSide(color: _danger),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Upload button is ALWAYS visible
  Widget buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: uploadContent,
        icon: const Icon(Icons.cloud_upload),
        label: const Text(
          'Upload New Course Content',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget buildList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: _teal));
    }

    if (errorMessage.isNotEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.cloud_off_outlined, size: 52, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 15),
          ),
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => fetchCourseContent(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      children: [
        buildNotice(),
        buildBanner(),
        const SizedBox(height: 16),
        buildUploadButton(),
        const SizedBox(height: 22),

        if (courseContents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text(
                  'No Course Content Yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Upload your first course content using the button above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted),
                ),
              ],
            ),
          )
        else ...[
          const Text(
            'Uploaded Content',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 14),
          ...courseContents.map((item) {
            if (item is! Map) return const SizedBox.shrink();
            return buildCard(Map<String, dynamic>.from(item));
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Course Content',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.courseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    _circleClose(() => Navigator.pop(context)),
                  ],
                ),
              ),

              const Divider(height: 1, color: _border),

              Expanded(
                child: Container(
                  color: const Color(0xFFFAFBFD),
                  child: RefreshIndicator(
                    color: _teal,
                    onRefresh: () => fetchCourseContent(silent: true),
                    child: buildList(),
                  ),
                ),
              ),

              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _softGrey,
                        foregroundColor: _ink,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}