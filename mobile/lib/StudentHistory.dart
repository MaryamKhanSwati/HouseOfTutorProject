//import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:house_of_tutor/services/api_client.dart';

class StudentHistory extends StatefulWidget {
  const StudentHistory({super.key});

  @override
  State<StudentHistory> createState() => _StudentHistoryState();
}

class _StudentHistoryState extends State<StudentHistory> {
  bool isLoading = true;
  List<dynamic> historyList = [];
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchStudentHistory();
  }

  Future<void> fetchStudentHistory() async {
    try {
      final response = await ApiClient.get('/api/Student/student-class-history');

      if (response.statusCode == 200) {
        final jsonResponse = await ApiClient.decodeJson(response);
        setState(() {
          historyList = jsonResponse['data'] ?? [];
          isLoading = false;
        });
      } else {
        final msg = ApiClient.messageFromBody(response.body) ?? 'Failed to load class history';
        setState(() {
          errorMessage = msg;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Image.asset(
          'assets/images/logo.png',
          height: 30,
          errorBuilder: (context, error, stackTrace) => const Text(
            "House of Tutor",
            style: TextStyle(color: Color(0xff009688), fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xff009688)),
            )
          : errorMessage.isNotEmpty
              ? Center(
                  child: Text(errorMessage, style: const TextStyle(color: Colors.red)),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Class History",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Review your past sessions and request logs",
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: historyList.isEmpty
                            ? const Center(child: Text("No class history found."))
                            : ListView.builder(
                                itemCount: historyList.length,
                                itemBuilder: (context, index) {
                                  final item = historyList[index];
                                  String tutorName = item['tutor_name'] ?? 'Tutor';
                                  String initials = tutorName.isNotEmpty
                                      ? tutorName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                                      : 'T';

                                  String rawDate = item['class_date'] ?? '';
                                  String formattedDate = rawDate.isNotEmpty ? rawDate.split('T')[0] : '';
                                  String dayStr = item['day'] != null ? " (${item['day']})" : '';
                                  String timeStr = item['time'] ?? '';
                                  String requestType = item['request_type'] ?? 'Session';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 45,
                                              height: 45,
                                              decoration: BoxDecoration(
                                                color: Colors.teal.shade50,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  initials,
                                                  style: const TextStyle(
                                                    color: Color(0xff009688),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "TUTOR",
                                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    tutorName,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(Icons.info, size: 12, color: Colors.black54),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    "Complete",
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          child: Divider(height: 1),
                                        ),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.teal.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.book, size: 16, color: Color(0xff009688)),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Subject / Course",
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  item['course_name'] ?? '',
                                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey.shade200),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    "$formattedDate$dayStr",
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    timeStr,
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                                                  ),
                                                ],
                                              ),
                                              const Padding(
                                                padding: EdgeInsets.symmetric(vertical: 8),
                                                child: Divider(height: 1),
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(Icons.swap_horiz, size: 16, color: Colors.grey),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    "Mode: $requestType",
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}