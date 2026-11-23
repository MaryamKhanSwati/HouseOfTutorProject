
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:house_of_tutor/services/api_client.dart';

class TutorNotification extends StatefulWidget {
  const TutorNotification({super.key});

  @override
  State<TutorNotification> createState() => _TutorNotificationState();
}

class _TutorNotificationState extends State<TutorNotification> {
  // =========================================================
  // COLORS
  // =========================================================

  static const Color primaryColor = Color(0xFF1E8E7E);
  static const Color backgroundColor = Color(0xFFF4F7F8);
  static const Color textColor = Color(0xFF263238);
  static const Color secondaryText = Color(0xFF78909C);

  // =========================================================
  // VARIABLES
  // =========================================================

  bool _loading = true;

  List<Map<String, dynamic>> _items = [];

  final Set<int> _busyIds = {};

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // =========================================================
  // GET VALUE FROM JSON
  // Supports camelCase and PascalCase
  // =========================================================

  String _getValue(Map<String, dynamic> item, String key) {
    final value = item[key] ?? item[
      key[0].toUpperCase() + key.substring(1)
    ];

    if (value == null) return '';

    return value.toString();
  }

  // =========================================================
  // GET REQUEST ID
  // =========================================================

  int _getRequestId(Map<String, dynamic> item) {
    final value = item['requestId'] ?? item['RequestId'];

    if (value is int) return value;

    return int.tryParse(value.toString()) ?? -1;
  }

  // =========================================================
  // FORMAT DATE
  // =========================================================

  String _formatDate(String value) {
    if (value.isEmpty) return '';

    final date = DateTime.tryParse(value);

    if (date == null) return value;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr',
      'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
  }

  // =========================================================
  // FORMAT TIME
  // =========================================================

  String _formatTime(String value) {
    if (value.isEmpty) return '';

    // Handles values like 14:30:00
    final parts = value.split(':');

    if (parts.length < 2) return value;

    final hour = int.tryParse(parts[0]);

    if (hour == null) return value;

    final minute = parts[1];

    final period = hour >= 12 ? 'PM' : 'AM';

    final formattedHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$formattedHour:$minute $period';
  }

  // =========================================================
  // LOAD NOTIFICATIONS API
  // GET: /api/Tutor/notifications
  // =========================================================

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.get(
        '/api/Tutor/notifications',
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        // Backend currently returns a plain List.
        // Also supports { data: [...] }.

        final list = decoded is List
            ? decoded
            : decoded is Map && decoded['data'] is List
                ? decoded['data']
                : [];

        final notifications = list
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();

        if (!mounted) return;

        setState(() {
          _items = notifications;
        });
      } else {
        final message =
            ApiClient.messageFromBody(response.body) ??
                'Unable to load notifications';

        if (!mounted) return;

        setState(() {
          _errorMessage = message;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // =========================================================
  // ACCEPT / REJECT CONFIRMATION
  // =========================================================

  Future<void> _showConfirmation(
    int requestId,
    bool accept,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            accept ? 'Accept Request?' : 'Reject Request?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          content: Text(
            accept
                ? 'Are you sure you want to accept this scheduling request?'
                : 'Are you sure you want to reject this scheduling request?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: secondaryText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    accept ? primaryColor : Colors.red.shade500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Text(accept ? 'Yes, Accept' : 'Yes, Reject'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _respondToRequest(requestId, accept);
    }
  }

  // =========================================================
  // ACCEPT / REJECT API
  // =========================================================

  Future<void> _respondToRequest(
    int requestId,
    bool accept,
  ) async {
    if (_busyIds.contains(requestId)) return;

    setState(() {
      _busyIds.add(requestId);
    });

    try {
      final endpoint = accept
          ? '/api/Tutor/accept-re-and-pre-schedule-request/$requestId'
          : '/api/Tutor/reject-re-and-pre-schedule-request/$requestId';

      final response = await ApiClient.put(endpoint, {});

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Remove the completed notification immediately.

        setState(() {
          _items.removeWhere(
            (item) => _getRequestId(item) == requestId,
          );
        });

        _showSnackBar(
          accept
              ? 'Request accepted successfully!'
              : 'Request rejected successfully!',
          Colors.green,
        );

        // Reload latest notifications from backend.
        await _loadNotifications();
      } else {
        final message =
            ApiClient.messageFromBody(response.body) ??
                'Action failed. Please try again.';

        _showSnackBar(message, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Network error. Please check your connection.',
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyIds.remove(requestId);
        });
      }
    }
  }

  // =========================================================
  // SNACKBAR
  // =========================================================

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // =========================================================
  // INFORMATION ROW
  // =========================================================

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 19,
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
                    color: secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // REQUEST TYPE BADGE
  // =========================================================

  Widget _requestBadge(String type) {
    final isReschedule =
        type.toLowerCase() == 'reschedule';

    final color = isReschedule
        ? const Color(0xFF2878C8)
        : const Color(0xFF8E5BC2);

    final background = isReschedule
        ? const Color(0xFFEAF3FF)
        : const Color(0xFFF3ECFF);

    final label = isReschedule
        ? 'Reschedule Request'
        : 'Preschedule Request';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 15,
            color: color,
          ),

          const SizedBox(width: 6),

          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // NOTIFICATION CARD
  // =========================================================

  Widget _notificationCard(Map<String, dynamic> item) {
    final id = _getRequestId(item);

    final type = _getValue(item, 'requestType');

    final student = _getValue(item, 'studentName');

    final course = _getValue(item, 'courseTitle');

    final day = _getValue(item, 'day');

    final time = _formatTime(
      _getValue(item, 'time'),
    );

    final classDate = _formatDate(
      _getValue(item, 'classDate'),
    );

    final requestDate = _formatDate(
      _getValue(item, 'requestDate'),
    );

    final busy = _busyIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFECEFF1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ==========================================
          // CARD HEADER
          // ==========================================

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _requestBadge(type),
                ),

                const Icon(
                  Icons.access_time_rounded,
                  color: secondaryText,
                  size: 15,
                ),

                const SizedBox(width: 5),

                const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE89A25),
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            color: Color(0xFFF0F2F3),
          ),

          // ==========================================
          // STUDENT INFORMATION
          // ==========================================

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Student
                Row(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: primaryColor.withOpacity(0.1),
                      child: const Icon(
                        Icons.person_outline,
                        color: primaryColor,
                        size: 25,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Student',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            student.isEmpty ? 'Unknown Student' : student,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Course
                _infoRow(
                  Icons.menu_book_outlined,
                  'Course',
                  course,
                ),

                // Day
                _infoRow(
                  Icons.calendar_view_day_outlined,
                  'Day',
                  day,
                ),

                // Class Date
                _infoRow(
                  Icons.calendar_month_outlined,
                  'Class Date',
                  classDate,
                ),

                // Time
                _infoRow(
                  Icons.schedule_outlined,
                  'Class Time',
                  time,
                ),

                // Request Date
                if (requestDate.isNotEmpty)
                  _infoRow(
                    Icons.event_note_outlined,
                    'Request Submitted',
                    requestDate,
                  ),

                const SizedBox(height: 5),

                // ==================================
                // ACCEPT / REJECT BUTTONS
                // ==================================

                Row(
                  children: [

                    // ACCEPT BUTTON
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: busy || id < 0
                            ? null
                            : () => _showConfirmation(id, true),

                        icon: busy
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                              ),

                        label: const Text('Accept'),

                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              primaryColor.withOpacity(0.5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // REJECT BUTTON
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy || id < 0
                            ? null
                            : () => _showConfirmation(id, false),

                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                        ),

                        label: const Text('Reject'),

                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side: BorderSide(
                            color: Colors.red.shade200,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
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
          ),
        ],
      ),
    );
  }

  // =========================================================
  // EMPTY NOTIFICATIONS
  // =========================================================

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 110),

        Center(
          child: Container(
            height: 115,
            width: 115,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 65,
              color: primaryColor,
            ),
          ),
        ),

        const SizedBox(height: 25),

        const Center(
          child: Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),

        const SizedBox(height: 10),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 35),
          child: Text(
            'You have no pending reschedule or preschedule requests. New requests will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryText,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // ERROR STATE
  // =========================================================

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 130),

        const Icon(
          Icons.cloud_off_outlined,
          color: Colors.redAccent,
          size: 65,
        ),

        const SizedBox(height: 20),

        const Center(
          child: Text(
            'Unable to Load Notifications',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            _errorMessage ?? 'Please try again.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: secondaryText,
              fontSize: 13,
            ),
          ),
        ),

        const SizedBox(height: 20),

        Center(
          child: ElevatedButton.icon(
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // MAIN UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      // ================================================
      // APP BAR
      // ================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,

        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),

        actions: [
          IconButton(
            onPressed: _loadNotifications,
            tooltip: 'Refresh',
            icon: const Icon(
              Icons.refresh_rounded,
              color: primaryColor,
            ),
          ),

          const SizedBox(width: 5),
        ],

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),

      // ================================================
      // BODY
      // ================================================

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )

          : Column(
              children: [

                // ======================================
                // HEADER / SUMMARY
                // ======================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,

                  child: Row(
                    children: [

                      Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: primaryColor,
                          size: 27,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Requests',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              '${_items.length} pending request${_items.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: secondaryText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_items.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ======================================
                // REQUEST LIST
                // ======================================

                Expanded(
                  child: RefreshIndicator(
                    color: primaryColor,
                    onRefresh: _loadNotifications,

                    child: _errorMessage != null
                        ? _errorState()

                        : _items.isEmpty
                            ? _emptyState()

                            : ListView.builder(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),

                                padding: const EdgeInsets.fromLTRB(
                                  16, 20, 16, 25,
                                ),

                                itemCount: _items.length,

                                itemBuilder: (context, index) {
                                  return _notificationCard(
                                    _items[index],
                                  );
                                },
                              ),
                  ),
                ),
              ],
            ),
    );
  }
}


























// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:house_of_tutor/services/api_client.dart';

// class TutorNotification extends StatefulWidget {
//   const TutorNotification({super.key});

//   @override
//   State<TutorNotification> createState() => _TutorNotificationState();
// }

// class _TutorNotificationState extends State<TutorNotification> {
//   bool _loading = true;
//   List<Map<String, dynamic>> _items = [];
//   final Set<int> _busyIds = {};

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   // ---------------------------------------------------------------------
//   // DATA
//   // ---------------------------------------------------------------------

//   Future<void> _load() async {
//     setState(() => _loading = true);
//     try {
//       final res = await ApiClient.get('/api/Tutor/notifications');
//       if (res.statusCode == 200) {
//         final decoded = jsonDecode(utf8.decode(res.bodyBytes));

//         // Handle both a plain list AND a wrapped { data: [...] } response,
//         // same as my-requests does.
//         final list = (decoded is Map && decoded['data'] is List)
//             ? decoded['data']
//             : (decoded is List ? decoded : []);

//         if (mounted) {
//           setState(() {
//             _items = (list as List)
//                 .whereType<Map>()
//                 .map((e) => Map<String, dynamic>.from(e))
//                 .toList();
//           });
//         }
//       } else {
//         if (mounted) {
//           final msg = ApiClient.messageFromBody(res.body) ?? 'Failed to load notifications';
//           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error: $e')),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   // ---------------------------------------------------------------------
//   // ACCEPT / REJECT
//   // ---------------------------------------------------------------------

//   Future<void> _respond(int requestId, bool accept) async {
//     setState(() => _busyIds.add(requestId));
//     try {
//       final path = accept
//           ? '/api/Tutor/accept-re-and-pre-schedule-request/$requestId'
//           : '/api/Tutor/reject-re-and-pre-schedule-request/$requestId';

//       final res = await ApiClient.put(path, {});

//       if (!mounted) return;

//       if (res.statusCode == 200) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(accept ? 'Request accepted' : 'Request rejected')),
//         );
//         await _load();
//       } else {
//         final msg = ApiClient.messageFromBody(res.body) ?? 'Action failed (${res.statusCode})';
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Network error: $e')),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _busyIds.remove(requestId));
//     }
//   }

//   // ---------------------------------------------------------------------
//   // UI HELPERS
//   // ---------------------------------------------------------------------

//   Widget _labelValue(String label, String value) {
//     if (value.isEmpty) return const SizedBox.shrink();
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 10),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: const TextStyle(color: Colors.grey, fontSize: 14),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             value,
//             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//         ],
//       ),
//     );
//   }

//   // ---------------------------------------------------------------------
//   // UI
//   // ---------------------------------------------------------------------

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F7FA),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         foregroundColor: Colors.teal,
//         title: const Text(
//           'Notifications',
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         centerTitle: true,
//       ),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : _items.isEmpty
//               ? RefreshIndicator(
//                   onRefresh: _load,
//                   child: ListView(
//                     physics: const AlwaysScrollableScrollPhysics(),
//                     children: const [
//                       SizedBox(height: 200),
//                       Center(child: Text('No pending requests')),
//                     ],
//                   ),
//                 )
//               : RefreshIndicator(
//                   onRefresh: _load,
//                   child: ListView.separated(
//                     padding: const EdgeInsets.all(12),
//                     itemCount: _items.length,
//                     separatorBuilder: (_, __) => const SizedBox(height: 14),
//                     itemBuilder: (context, index) {
//                       final item = _items[index];

//                       final requestId = item['requestId'] ?? item['RequestId'];
//                       final id = requestId is int
//                           ? requestId
//                           : int.tryParse(requestId.toString()) ?? -1;
//                       final busy = _busyIds.contains(id);

//                       final type =
//                           (item['requestType'] ?? item['RequestType'] ?? '').toString();
//                       final studentName =
//                           (item['studentName'] ?? item['StudentName'] ?? '').toString();
//                       final courseTitle =
//                           (item['courseTitle'] ?? item['CourseTitle'] ?? '').toString();
//                       final day = (item['day'] ?? item['Day'] ?? '').toString();
//                       final time = (item['time'] ?? item['Time'] ?? '').toString();
//                       final classDate =
//                           (item['classDate'] ?? item['ClassDate'] ?? '').toString();

//                       final isReschedule = type.toLowerCase() == 'reschedule';

//                       return Container(
//                         padding: const EdgeInsets.all(18),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(18),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.05),
//                               blurRadius: 10,
//                             ),
//                           ],
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             // ---- Type badge ----
//                             Container(
//                               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//                               decoration: BoxDecoration(
//                                 color: Colors.blue.shade50,
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                               child: Text(
//                                 type,
//                                 style: const TextStyle(
//                                   color: Colors.teal,
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 16),

//                             _labelValue('Student', studentName),
//                             _labelValue('Course', courseTitle),
//                             _labelValue('Day', day),
//                             _labelValue('Time', time),
//                             _labelValue('Class Date', classDate),

//                             const SizedBox(height: 6),

//                             // ---- Accept / Reject ----
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ElevatedButton(
//                                     style: ElevatedButton.styleFrom(
//                                       backgroundColor: Colors.green,
//                                       foregroundColor: Colors.white,
//                                       padding: const EdgeInsets.symmetric(vertical: 14),
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(30),
//                                       ),
//                                     ),
//                                     onPressed: busy || id < 0 ? null : () => _respond(id, true),
//                                     child: busy
//                                         ? const SizedBox(
//                                             width: 18,
//                                             height: 18,
//                                             child: CircularProgressIndicator(
//                                               strokeWidth: 2,
//                                               color: Colors.white,
//                                             ),
//                                           )
//                                         : const Text(
//                                             'Accept',
//                                             style: TextStyle(
//                                               fontWeight: FontWeight.bold,
//                                               fontSize: 16,
//                                             ),
//                                           ),
//                                   ),
//                                 ),
//                                 const SizedBox(width: 12),
//                                 Expanded(
//                                   child: ElevatedButton(
//                                     style: ElevatedButton.styleFrom(
//                                       backgroundColor: Colors.red.shade400,
//                                       foregroundColor: Colors.white,
//                                       padding: const EdgeInsets.symmetric(vertical: 14),
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(30),
//                                       ),
//                                     ),
//                                     onPressed: busy || id < 0 ? null : () => _respond(id, false),
//                                     child: const Text(
//                                       'Reject',
//                                       style: TextStyle(
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 16,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//     );
//   }
// }
