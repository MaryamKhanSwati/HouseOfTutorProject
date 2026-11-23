import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:house_of_tutor/AdminDrawer.dart';
import 'package:house_of_tutor/services/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminTutorCourseVerification extends StatefulWidget {
  const AdminTutorCourseVerification({super.key});

  @override
  State<AdminTutorCourseVerification> createState() =>
      _AdminTutorCourseVerificationState();
}

class _AdminTutorCourseVerificationState
    extends State<AdminTutorCourseVerification> {
  // =========================================================
  // COLORS
  // =========================================================

  final Color primaryColor = const Color(0xFF1E8E7E);
  final Color backgroundColor = const Color(0xFFF4F4F4);
  final Color textColor = const Color(0xFF333333);

  // =========================================================
  // VARIABLES
  // =========================================================

  bool isLoading = true;
  bool isProcessing = false;

  List<dynamic> pendingCourses = [];

  @override
  void initState() {
    super.initState();
    loadPendingCourses();
  }

  // =========================================================
  // LOAD PENDING COURSES
  // GET: /api/Admin/pending-tutor-courses
  // =========================================================

  Future<void> loadPendingCourses() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final response =
          await ApiClient.get('/api/Admin/pending-tutor-courses');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> courses = [];

        if (decoded is List) {
          courses = decoded;
        } else if (decoded is Map) {
          courses = decoded['courses'] ?? [];
        }

        if (!mounted) return;

        setState(() {
          pendingCourses = courses;
          isLoading = false;
        });
      } else {
        throw Exception(
          'Failed to load pending courses: ${response.body}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Error loading pending courses: $e', isError: true);
    }
  }

  // =========================================================
  // APPROVE
  // =========================================================

  Future<void> approveCourse(Map<String, dynamic> course) async {
    final int evidenceId =
        int.tryParse(course['evidence_id']?.toString() ?? '') ?? 0;

    if (evidenceId == 0) {
      showMessage('Invalid transcript ID.', isError: true);
      return;
    }

    final remarksController = TextEditingController(
      text: 'Transcript verified successfully.',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Approve Transcript'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to approve this tutor course?',
              ),
              const SizedBox(height: 15),
              TextField(
                controller: remarksController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  hintText: 'Enter verification remarks',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await reviewCourse(
      evidenceId: evidenceId,
      status: 'Verified',
      remarks: remarksController.text.trim(),
      successMessage: 'Transcript approved successfully.',
    );
  }

  // =========================================================
  // REJECT
  // =========================================================

  Future<void> rejectCourse(Map<String, dynamic> course) async {
    final int evidenceId =
        int.tryParse(course['evidence_id']?.toString() ?? '') ?? 0;

    if (evidenceId == 0) {
      showMessage('Invalid transcript ID.', isError: true);
      return;
    }

    final remarksController = TextEditingController();
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reject Transcript'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please enter the reason for rejecting this transcript.',
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: remarksController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Rejection Reason',
                      hintText: 'Example: Transcript is unclear.',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (remarksController.text.trim().isEmpty) {
                      setDialogState(() {
                        errorText = 'Please enter a rejection reason.';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Reject'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    await reviewCourse(
      evidenceId: evidenceId,
      status: 'Rejected',
      remarks: remarksController.text.trim(),
      successMessage: 'Transcript rejected successfully.',
    );
  }

  // =========================================================
  // COMMON API METHOD
  // PUT: /api/Admin/verify-tutor-course/{evidenceId}
  // Body: { "status": "Verified" | "Rejected", "remarks": "..." }
  // =========================================================

  Future<void> reviewCourse({
    required int evidenceId,
    required String status,
    required String remarks,
    required String successMessage,
  }) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final response = await ApiClient.put(
        '/api/Admin/verify-tutor-course/$evidenceId',
        {
          'status': status,
          'remarks': remarks,
        },
      );

      if (response.statusCode == 200) {
        showMessage(successMessage);
        await loadPendingCourses();
      } else {
        String errorMessage = 'Something went wrong.';

        try {
          final decoded = jsonDecode(response.body);
          errorMessage = decoded['message']?.toString() ?? response.body;
        } catch (_) {
          errorMessage = response.body;
        }

        showMessage(errorMessage, isError: true);
      }
    } catch (e) {
      showMessage('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  // =========================================================
  // OPEN TRANSCRIPT (PDF OPENS EXTERNALLY)
  // =========================================================

  Future<void> openTranscript(Map<String, dynamic> course) async {
    final String url = course['transcript_url']?.toString() ?? '';

    if (url.isEmpty) {
      showMessage('Transcript URL is not available.', isError: true);
      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null || !uri.hasScheme) {
      showMessage('Invalid transcript URL.', isError: true);
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        showMessage('Unable to open transcript.', isError: true);
      }
    } catch (e) {
      showMessage('Could not open transcript: $e', isError: true);
    }
  }

  // =========================================================
  // PREVIEW IMAGE TRANSCRIPT
  // =========================================================

  void previewImage(Map<String, dynamic> course) {
    final String url = course['transcript_url']?.toString() ?? '';

    if (url.isEmpty) {
      showMessage('Transcript URL is not available.', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Transcript Preview',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;

                      return const Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(30),
                        child: Text('Unable to load transcript image.'),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // VIEW TRANSCRIPT
  // =========================================================

  void viewTranscript(Map<String, dynamic> course) {
    final String fileName =
        course['file_name']?.toString().toLowerCase() ?? '';

    final bool isImage = fileName.endsWith('.jpg') ||
        fileName.endsWith('.jpeg') ||
        fileName.endsWith('.png');

    if (isImage) {
      previewImage(course);
    } else {
      openTranscript(course);
    }
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : primaryColor,
      ),
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  String getValue(dynamic value, {String fallback = 'Not provided'}) {
    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  String formatBool(dynamic value) {
    if (value == null) return 'Not provided';
    if (value is bool) return value ? 'Yes' : 'No';

    final text = value.toString().toLowerCase();
    if (text == 'true' || text == '1') return 'Yes';
    if (text == 'false' || text == '0') return 'No';

    return value.toString();
  }

  String formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Not available';
    }

    // 2026-11-15T10:20:30 -> 2026-11-15
    return value.toString().split('T').first;
  }

  // =========================================================
  // COURSE CARD
  // =========================================================

  Widget buildCourseCard(Map<String, dynamic> course) {
    final String fileName =
        getValue(course['file_name'], fallback: 'Transcript');

    final String grade = getValue(course['grade']);
    final String institute = getValue(course['institute']);
    final String labCompleted = formatBool(course['lab_completed']);
    final String gradeStatus =
        getValue(course['grade_verification_status']);
    final String uploadedDate = formatDate(course['uploaded_date']);
    final String evidenceType =
        getValue(course['evidence_type'], fallback: 'Transcript');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.12),
                  child: Icon(
                    Icons.school,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Course ID: ${getValue(course['course_id'])}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Tutor ID: ${getValue(course['tutor_id'])}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 25),

            buildDetailRow('Grade', grade),
            buildDetailRow('Institute', institute),
            buildDetailRow('Lab Completed', labCompleted),
            buildDetailRow('Grade Status', gradeStatus),
            buildDetailRow('Evidence Type', evidenceType),
            buildDetailRow('Uploaded Date', uploadedDate),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    fileName.toLowerCase().endsWith('.pdf')
                        ? Icons.picture_as_pdf
                        : Icons.image,
                    color: primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => viewTranscript(course),
                    child: const Text('View'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        isProcessing ? null : () => approveCourse(course),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        isProcessing ? null : () => rejectCourse(course),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DETAIL ROW
  // =========================================================

  Widget buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: const Text(
          'Tutor Course Verification',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadPendingCourses,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadPendingCourses,
        color: primaryColor,
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                ),
              )
            : pendingCourses.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 130),
                      Icon(
                        Icons.verified_user_outlined,
                        size: 75,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 18),
                      const Center(
                        child: Text(
                          'No Pending Transcripts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'All tutor transcripts have been reviewed.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.pending_actions,
                              color: primaryColor,
                              size: 30,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pending Verification',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${pendingCourses.length} transcript(s) waiting for review',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...pendingCourses.map((item) {
                        final course = Map<String, dynamic>.from(item);
                        return buildCourseCard(course);
                      }),
                    ],
                  ),
      ),
    );
  }
}