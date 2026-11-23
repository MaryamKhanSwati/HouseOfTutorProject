
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:house_of_tutor/services/api_client.dart';

class StudentNotifications extends StatefulWidget {
  const StudentNotifications({super.key});

  @override
  State<StudentNotifications> createState() =>
      _StudentNotificationsState();
}

class _StudentNotificationsState extends State<StudentNotifications> {
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

  bool loading = true;

  List<Map<String, dynamic>> requests = [];

  int notificationCount = 0;

  String? errorMessage;

  final Set<int> busyIds = {};

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  // =========================================================
  // GET JSON VALUE
  // Supports snake_case and PascalCase/camelCase
  // =========================================================

  dynamic getValue(Map<String, dynamic> item, String key) {
    if (item.containsKey(key)) return item[key];

    final camelKey = key.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match.group(1)!.toUpperCase(),
    );

    if (item.containsKey(camelKey)) return item[camelKey];

    final pascalKey =
        camelKey[0].toUpperCase() + camelKey.substring(1);

    return item[pascalKey];
  }

  String getText(Map<String, dynamic> item, String key) {
    final value = getValue(item, key);
    return value?.toString() ?? '';
  }

  // =========================================================
  // GET REQUEST ID
  // =========================================================

  int getRequestId(Map<String, dynamic> item) {
    final value = getValue(item, 'request_id');

    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '') ?? -1;
  }

  // =========================================================
  // FORMAT DATE
  // =========================================================

  String formatDate(String value) {
    if (value.isEmpty) return '';

    final date = DateTime.tryParse(value);

    if (date == null) return value;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr',
      'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
  }

  // =========================================================
  // FORMAT TIME
  // =========================================================

  String formatTime(String value) {
    if (value.isEmpty) return '';

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
  // FETCH NOTIFICATIONS + BADGE COUNT
  //
  // API 1:
  // GET /api/Student/pre-reschedule-requests
  //
  // API 2:
  // GET /api/Student/notification-badge-count
  // =========================================================

  Future<void> fetchRequests() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      // Both APIs are called together.
      final responses = await Future.wait([
        ApiClient.get(
          '/api/Student/pre-reschedule-requests',
        ),
        ApiClient.get(
          '/api/Student/notification-badge-count',
        ),
      ]);

      final requestResponse = responses[0];
      final countResponse = responses[1];

      if (requestResponse.statusCode != 200) {
        throw Exception(
          ApiClient.messageFromBody(requestResponse.body) ??
              'Unable to load notifications',
        );
      }

      // ---------------------------------------------
      // PARSE REQUEST LIST
      // ---------------------------------------------

      final decoded = jsonDecode(
        utf8.decode(requestResponse.bodyBytes),
      );

      final List list;

      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map && decoded['data'] is List) {
        list = decoded['data'];
      } else {
        list = [];
      }

      final loadedRequests = list
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();

      // ---------------------------------------------
      // PARSE NOTIFICATION BADGE COUNT
      // ---------------------------------------------

      int count = loadedRequests.length;

      if (countResponse.statusCode == 200) {
        final countData = jsonDecode(
          utf8.decode(countResponse.bodyBytes),
        );

        if (countData is Map) {
          final value = countData['count'] ??
              countData['Count'];

          final parsedCount = int.tryParse(
            value?.toString() ?? '',
          );

          if (parsedCount != null) {
            count = parsedCount;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        requests = loadedRequests;
        notificationCount = count;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // =========================================================
  // SHOW CONFIRMATION DIALOG
  // =========================================================

  Future<void> showConfirmation(
    int requestId,
    String type,
    bool accept,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
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
                ? 'Are you sure you want to accept this $type request?'
                : 'Are you sure you want to reject this $type request?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: secondaryText),
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              style: ElevatedButton.styleFrom(
                backgroundColor:
                    accept ? primaryColor : Colors.red.shade500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              child: Text(
                accept ? 'Yes, Accept' : 'Yes, Reject',
              ),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      if (accept) {
        await acceptRequest(requestId, type);
      } else {
        await rejectRequest(requestId);
      }
    }
  }

  // =========================================================
  // ACCEPT REQUEST
  //
  // Preschedule:
  // POST /api/Student/accept-preschedule/{requestId}
  //
  // Reschedule:
  // POST /api/Student/accept-reschedule/{requestId}
  // =========================================================

  Future<void> acceptRequest(
    int requestId,
    String type,
  ) async {
    if (busyIds.contains(requestId)) return;

    setState(() {
      busyIds.add(requestId);
    });

    try {
      final endpoint = type.toLowerCase() == 'preschedule'
          ? '/api/Student/accept-preschedule/$requestId'
          : '/api/Student/accept-reschedule/$requestId';

      final response = await ApiClient.post(
        endpoint,
        {},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          requests.removeWhere(
            (item) => getRequestId(item) == requestId,
          );
        });

        showMessage(
          'Request accepted successfully!',
          Colors.green,
        );

        await fetchRequests();
      } else {
        final message =
            ApiClient.messageFromBody(response.body) ??
                'Unable to accept request';

        showMessage(message, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          'Network error. Please try again.',
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busyIds.remove(requestId);
        });
      }
    }
  }

  // =========================================================
  // REJECT REQUEST
  //
  // POST /api/Student/reject-request/{requestId}
  // =========================================================

  Future<void> rejectRequest(int requestId) async {
    if (busyIds.contains(requestId)) return;

    setState(() {
      busyIds.add(requestId);
    });

    try {
      final response = await ApiClient.post(
        '/api/Student/reject-request/$requestId',
        {},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          requests.removeWhere(
            (item) => getRequestId(item) == requestId,
          );
        });

        showMessage(
          'Request rejected successfully!',
          Colors.green,
        );

        await fetchRequests();
      } else {
        final message =
            ApiClient.messageFromBody(response.body) ??
                'Unable to reject request';

        showMessage(message, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          'Network error. Please try again.',
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busyIds.remove(requestId);
        });
      }
    }
  }

  // =========================================================
  // SNACKBAR
  // =========================================================

  void showMessage(String message, Color color) {
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
  // REQUEST TYPE BADGE
  // =========================================================

  Widget typeBadge(String type) {
    final isReschedule =
        type.toLowerCase() == 'reschedule';

    final color = isReschedule
        ? const Color(0xFFDC8A25)
        : const Color(0xFF7554B8);

    final background = isReschedule
        ? const Color(0xFFFFF3E4)
        : const Color(0xFFF1EBFF);

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
            color: color,
            size: 15,
          ),

          const SizedBox(width: 6),

          Text(
            isReschedule
                ? 'Reschedule Request'
                : 'Preschedule Request',

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
  // INFORMATION ROW
  // =========================================================

  Widget infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),

      child: Row(
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
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: secondaryText,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: textColor,
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
  // NOTIFICATION CARD
  // =========================================================

  Widget notificationCard(Map<String, dynamic> item) {
    final id = getRequestId(item);

    final type = getText(item, 'request_type');

    final tutor = getText(item, 'tutor_name');

    final course = getText(item, 'course_name');

    final day = getText(item, 'day');

    final date = formatDate(
      getText(item, 'class_date'),
    );

    final time = formatTime(
      getText(item, 'time'),
    );

    final busy = busyIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 17),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),

        border: Border.all(
          color: const Color(0xFFECEFF1),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),

            child: Row(
              children: [
                Expanded(
                  child: typeBadge(type),
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
                    color: Color(0xFFE09A2D),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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
          // CARD INFORMATION
          // ==========================================

          Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Tutor information
                Row(
                  children: [
                    CircleAvatar(
                      radius: 23,

                      backgroundColor:
                          primaryColor.withOpacity(0.1),

                      child: const Icon(
                        Icons.person_outline,
                        color: primaryColor,
                        size: 26,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Tutor',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            tutor.isEmpty ? 'Tutor' : tutor,

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

                const SizedBox(height: 22),

                infoRow(
                  Icons.menu_book_outlined,
                  'Course',
                  course,
                ),

                infoRow(
                  Icons.calendar_view_day_outlined,
                  'Day',
                  day,
                ),

                infoRow(
                  Icons.calendar_month_outlined,
                  'Class Date',
                  date,
                ),

                infoRow(
                  Icons.schedule_outlined,
                  'Class Time',
                  time,
                ),

                const SizedBox(height: 5),

                // ==================================
                // ACTION BUTTONS
                // ==================================

                Row(
                  children: [

                    // ACCEPT
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: busy || id < 0
                            ? null
                            : () => showConfirmation(
                                  id,
                                  type,
                                  true,
                                ),

                        icon: busy
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
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

                    // REJECT
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy || id < 0
                            ? null
                            : () => showConfirmation(
                                  id,
                                  type,
                                  false,
                                ),

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
  // EMPTY STATE
  // =========================================================

  Widget emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),

      children: [
        const SizedBox(height: 100),

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
              color: primaryColor,
              size: 65,
            ),
          ),
        ),

        const SizedBox(height: 25),

        const Center(
          child: Text(
            'All Caught Up!',

            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),

        const SizedBox(height: 10),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 35),

          child: Text(
            'You have no pending requests from your tutors. New requests will appear here.',

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

  Widget errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),

      children: [
        const SizedBox(height: 120),

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

        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),

          child: Text(
            errorMessage ?? 'Please try again.',

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
            onPressed: fetchRequests,
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
        elevation: 0,
        centerTitle: true,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),

          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 37,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.school_rounded,
                  color: primaryColor,
                  size: 32,
                );
              },
            ),

            const SizedBox(width: 9),

            const Text(
              'House of Tutor',

              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            onPressed: fetchRequests,
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

      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )

          : Column(
              children: [

                // ======================================
                // SUMMARY HEADER
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
                              'Your Notifications',

                              style: TextStyle(
                                color: textColor,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              '$notificationCount pending request${notificationCount == 1 ? '' : 's'}',

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
                          '$notificationCount',

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
                // NOTIFICATION LIST
                // ======================================

                Expanded(
                  child: RefreshIndicator(
                    color: primaryColor,
                    onRefresh: fetchRequests,

                    child: errorMessage != null
                        ? errorState()

                        : requests.isEmpty
                            ? emptyState()

                            : ListView.builder(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),

                                padding: const EdgeInsets.fromLTRB(
                                  16, 20, 16, 25,
                                ),

                                itemCount: requests.length,

                                itemBuilder: (context, index) {
                                  return notificationCard(
                                    requests[index],
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

// class StudentNotifications extends StatefulWidget {
//   const StudentNotifications({super.key});

//   @override
//   State<StudentNotifications> createState() =>
//       _StudentNotificationsState();
// }

// class _StudentNotificationsState
//     extends State<StudentNotifications> {

//   bool loading = true;

//   List requests = [];

//   @override
//   void initState() {
//     super.initState();
//     fetchRequests();
//   }

//   // ================= FETCH =================

//   Future<void> fetchRequests() async {

//     setState(() {
//       loading = true;
//     });

//     try {

//       final response = await ApiClient.get(
//         "/api/Student/pre-reschedule-requests",
//       );

//       print(response.body);

//       if (response.statusCode == 200) {

//         final data = jsonDecode(
//           utf8.decode(response.bodyBytes),
//         );

//         setState(() {
//           requests = data;
//         });
//       }

//     } catch (e) {

//       print(e);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(e.toString()),
//         ),
//       );
//     }

//     setState(() {
//       loading = false;
//     });
//   }

//   // ================= ACCEPT =================

//   Future<void> acceptRequest(
//     int requestId,
//     String type,
//   ) async {

//     try {

//       String endpoint = "";

//       if (type == "Preschedule") {

//         endpoint =
//             "/api/Student/accept-preschedule/$requestId";

//       } else {

//         endpoint =
//             "/api/Student/accept-reschedule/$requestId";
//       }

//       final response =
//           await ApiClient.post(endpoint, {});

//       print(response.body);

//       if (response.statusCode == 200) {

//         ScaffoldMessenger.of(context)
//             .showSnackBar(

//           const SnackBar(
//             content:
//                 Text("Request Accepted"),
//           ),
//         );

//         fetchRequests();

//       } else {

//         ScaffoldMessenger.of(context)
//             .showSnackBar(

//           const SnackBar(
//             content:
//                 Text("Accept Failed"),
//           ),
//         );
//       }

//     } catch (e) {

//       ScaffoldMessenger.of(context)
//           .showSnackBar(
//         SnackBar(
//           content: Text(e.toString()),
//         ),
//       );
//     }
//   }

//   // ================= REJECT =================

//   Future<void> rejectRequest(
//     int requestId,
//   ) async {

//     try {

//       final response = await ApiClient.post(
//         "/api/Student/reject-request/$requestId",
//         {},
//       );

//       print(response.body);

//       if (response.statusCode == 200) {

//         ScaffoldMessenger.of(context)
//             .showSnackBar(

//           const SnackBar(
//             content:
//                 Text("Request Rejected"),
//           ),
//         );

//         fetchRequests();

//       } else {

//         ScaffoldMessenger.of(context)
//             .showSnackBar(

//           const SnackBar(
//             content:
//                 Text("Reject Failed"),
//           ),
//         );
//       }

//     } catch (e) {

//       ScaffoldMessenger.of(context)
//           .showSnackBar(

//         SnackBar(
//           content: Text(e.toString()),
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {

//     return Scaffold(

//       backgroundColor:
//           const Color(0xfff5f5f5),

//       appBar: AppBar(

//         backgroundColor: Colors.white,

//         elevation: 1,

//         leading: IconButton(

//           icon: const Icon(
//             Icons.arrow_back,
//             color: Colors.black,
//           ),

//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),

//         centerTitle: true,

//         title: Column(
//           children: [

//             Image.asset(
//               "assets/images/logo.png",
//               height: 35,
//             ),

//             const SizedBox(height: 4),

//             const Text(

//               "House of Tutor",

//               style: TextStyle(
//                 color: Colors.teal,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ),

//       body: loading

//           ? const Center(
//               child:
//                   CircularProgressIndicator(),
//             )

//           : requests.isEmpty

//               ? const Center(

//                   child: Text(
//                     "No Requests Found",
//                     style: TextStyle(
//                       fontSize: 18,
//                     ),
//                   ),
//                 )

//               : ListView.builder(

//                   padding:
//                       const EdgeInsets.all(16),

//                   itemCount: requests.length,

//                   itemBuilder: (context, index) {

//                     final item = requests[index];

//                     return Container(

//                       margin:
//                           const EdgeInsets.only(
//                         bottom: 20,
//                       ),

//                       padding:
//                           const EdgeInsets.all(20),

//                       decoration: BoxDecoration(

//                         color: Colors.white,

//                         borderRadius:
//                             BorderRadius.circular(
//                                 24),

//                         boxShadow: [

//                           BoxShadow(

//                             color: Colors.black
//                                 .withOpacity(0.08),

//                             blurRadius: 8,

//                             offset:
//                                 const Offset(0, 3),
//                           )
//                         ],
//                       ),

//                       child: Column(

//                         crossAxisAlignment:
//                             CrossAxisAlignment.start,

//                         children: [

//                           // ================= TYPE =================

//                           Container(

//                             padding:
//                                 const EdgeInsets.symmetric(
//                               horizontal: 18,
//                               vertical: 8,
//                             ),

//                             decoration: BoxDecoration(

//                               color:
//                                   item["request_type"] ==
//                                           "Reschedule"
//                                       ? Colors.orange
//                                       : Colors.teal,

//                               borderRadius:
//                                   BorderRadius.circular(
//                                       30),
//                             ),

//                             child: Text(

//                               item["request_type"],

//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontWeight:
//                                     FontWeight.bold,
//                               ),
//                             ),
//                           ),

//                           const SizedBox(height: 22),

//                           // ================= TIME =================

//                           Text(

//                             "${item["day"]} , ${item["time"]}",

//                             style: const TextStyle(

//                               fontSize: 30,

//                               color: Colors.teal,

//                               fontWeight:
//                                   FontWeight.bold,
//                             ),
//                           ),

//                           const SizedBox(height: 18),

//                           // ================= DATE =================

//                           Text(

//                             "📅 Date : ${item["class_date"]}",

//                             style: const TextStyle(
//                               fontSize: 18,
//                             ),
//                           ),

//                           const SizedBox(height: 10),

//                           // ================= TUTOR =================

//                           Text(

//                             "🧑‍🏫 Tutor : ${item["tutor_name"]}",

//                             style: const TextStyle(
//                               fontSize: 18,
//                             ),
//                           ),

//                           const SizedBox(height: 10),

//                           // ================= COURSE =================

//                           Text(

//                             "📘 Course : ${item["course_name"]}",

//                             style: const TextStyle(
//                               fontSize: 18,
//                             ),
//                           ),

//                           const SizedBox(height: 18),

//                           const Text(

//                             "• Pending",

//                             style: TextStyle(

//                               color: Colors.orange,

//                               fontSize: 18,

//                               fontWeight:
//                                   FontWeight.bold,
//                             ),
//                           ),

//                           const SizedBox(height: 25),

//                           Row(
//                             children: [

//                               // ================= ACCEPT =================

//                               Expanded(

//                                 child: ElevatedButton(

//                                   style:
//                                       ElevatedButton
//                                           .styleFrom(

//                                     backgroundColor:
//                                         Colors.teal,

//                                     padding:
//                                         const EdgeInsets.symmetric(
//                                       vertical: 16,
//                                     ),

//                                     shape:
//                                         RoundedRectangleBorder(
//                                       borderRadius:
//                                           BorderRadius.circular(
//                                               40),
//                                     ),
//                                   ),

//                                   onPressed: () {

//                                     acceptRequest(

//                                       item["request_id"],

//                                       item["request_type"],
//                                     );
//                                   },

//                                   child: const Text(

//                                     "✓ Accept",

//                                     style: TextStyle(

//                                       color: Colors.white,

//                                       fontSize: 18,

//                                       fontWeight:
//                                           FontWeight.bold,
//                                     ),
//                                   ),
//                                 ),
//                               ),

//                               const SizedBox(width: 16),

//                               // ================= REJECT =================

//                               Expanded(

//                                 child: OutlinedButton(

//                                   style:
//                                       OutlinedButton
//                                           .styleFrom(

//                                     padding:
//                                         const EdgeInsets.symmetric(
//                                       vertical: 16,
//                                     ),

//                                     side: const BorderSide(
//                                       color: Colors.red,
//                                     ),

//                                     shape:
//                                         RoundedRectangleBorder(
//                                       borderRadius:
//                                           BorderRadius.circular(
//                                               40),
//                                     ),
//                                   ),

//                                   onPressed: () {

//                                     rejectRequest(
//                                       item["request_id"],
//                                     );
//                                   },

//                                   child: const Text(

//                                     "✕ Reject",

//                                     style: TextStyle(

//                                       color: Colors.red,

//                                       fontSize: 18,

//                                       fontWeight:
//                                           FontWeight.bold,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//     );
//   }
// }