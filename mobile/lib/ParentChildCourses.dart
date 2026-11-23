
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:house_of_tutor/services/api_client.dart';
import 'package:house_of_tutor/ParentChildClasses.dart';

class ParentChildCourses extends StatefulWidget {
  final int studentId;

  ParentChildCourses({
    Key? key,
    required dynamic studentId,
  })  : studentId = studentId is int
            ? studentId
            : int.tryParse(studentId?.toString() ?? '') ?? 0,
        super(key: key);

  @override
  State<ParentChildCourses> createState() => _ParentChildCoursesState();
}

class _ParentChildCoursesState extends State<ParentChildCourses> {
  // =====================================================
  // COLORS
  // =====================================================

  final Color primaryColor = const Color(0xFF1E8E7E);
  final Color backgroundColor = const Color(0xFFF5F7FA);
  final Color textColor = const Color(0xFF263238);

  // =====================================================
  // VARIABLES
  // =====================================================

  List<dynamic> coursesList = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // Load child courses when screen opens.
    fetchChildCourses();
  }

  // =====================================================
  // GET CHILD COURSES API
  // =====================================================

  Future<void> fetchChildCourses() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiClient.get(
        '/api/Parent/child-courses/${widget.studentId}',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle API response as either a list or an object.
        List<dynamic> courses = [];

        if (data is List) {
          courses = data;
        } else if (data is Map) {
          final result =
              data['courses'] ?? data['data'] ?? data['result'] ?? [];

          if (result is List) {
            courses = result;
          }
        }

        setState(() {
          coursesList = courses;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });

        String message = 'Failed to load courses.';

        try {
          final data = json.decode(response.body);

          if (data is Map && data['message'] != null) {
            message = data['message'].toString();
          }
        } catch (_) {}

        showMessage(message);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('An error occurred: $e');
    }
  }

  // =====================================================
  // SHOW MESSAGE
  // =====================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryColor,
      ),
    );
  }

  // =====================================================
  // SAFE COURSE ID
  // =====================================================

  int getCourseId(dynamic course) {
    final rawId = course['courseId'] ?? course['id'];

    if (rawId is int) {
      return rawId;
    }

    return int.tryParse(rawId?.toString() ?? '') ?? 0;
  }

  // =====================================================
  // APP BAR WITH SAME LOGO
  // =====================================================

  PreferredSizeWidget buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,

      // Back button
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: primaryColor,
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),

      // Same logo and app name
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 34,
            height: 34,
            fit: BoxFit.contain,

            // Show icon if logo image is not found.
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.school,
                color: primaryColor,
                size: 30,
              );
            },
          ),

          const SizedBox(width: 8),

          const Text(
            'House of Tutor',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),

      centerTitle: true,
    );
  }

  // =====================================================
  // COURSE CARD
  // =====================================================

  Widget buildCourseCard(dynamic course, int index) {
    final String courseTitle =
        course['courseTitle']?.toString() ?? 'Unnamed Course';

    final int courseId = getCourseId(course);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: InkWell(
        borderRadius: BorderRadius.circular(16),

        // Open child classes screen when course is clicked.
        onTap: () {
          if (courseId <= 0) {
            showMessage('Invalid course ID.');
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParentChildClasses(
                studentId: widget.studentId,
                courseId: courseId,
                courseTitle: courseTitle,
              ),
            ),
          );
        },

        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),

              child: Row(
                children: [
                  // Course icon
                  Container(
                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Icon(
                      Icons.menu_book,
                      color: primaryColor,
                      size: 26,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Course information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COURSE #${index + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          courseTitle,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Next arrow
                  Container(
                    padding: const EdgeInsets.all(6),

                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),

                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade600,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              height: 1,
              color: Color(0xFFF0F0F0),
            ),

            // View classes button area
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'View Enrolled Classes',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),

                  Icon(
                    Icons.arrow_forward,
                    color: primaryColor,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // LOADING SCREEN
  // =====================================================

  Widget buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: CircularProgressIndicator(
          color: primaryColor,
        ),
      ),
    );
  }

  // =====================================================
  // EMPTY SCREEN
  // =====================================================

  Widget buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 55,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 12),

            Text(
              'No enrolled courses found.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // MAIN SCREEN
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      // AppBar with same logo.png
      appBar: buildAppBar(),

      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: fetchChildCourses,

        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen heading
              Text(
                'Enrolled Courses',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'Select a course subject to view detailed class schedules',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 20),

              // Loading, empty, or courses list
              if (isLoading)
                buildLoading()
              else if (coursesList.isEmpty)
                buildEmpty()
              else
                ListView.builder(
                  itemCount: coursesList.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),

                  itemBuilder: (context, index) {
                    return buildCourseCard(
                      coursesList[index],
                      index,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

























// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:house_of_tutor/services/api_client.dart';
// import 'package:house_of_tutor/ParentChildClasses.dart';

// class ParentChildCourses extends StatefulWidget {
//   final int studentId;

//   ParentChildCourses({
//     Key? key,
//     required dynamic studentId,
//   }) : studentId = studentId is int 
//           ? studentId 
//           : int.tryParse(studentId?.toString() ?? '') ?? 0,
//        super(key: key);

//   @override
//   _ParentChildCoursesState createState() => _ParentChildCoursesState();
// }

// class _ParentChildCoursesState extends State<ParentChildCourses> {
//   List<dynamic> coursesList = [];
//   bool isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     fetchChildCourses();
//   }

//   Future<void> fetchChildCourses() async {
//     setState(() {
//       isLoading = true;
//     });

//     try {
//       final response = await ApiClient.get('/api/Parent/child-courses/${widget.studentId}');
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         setState(() {
//           coursesList = data;
//           isLoading = false;
//         });
//       } else {
//         setState(() {
//           isLoading = false;
//         });
//         final data = json.decode(response.body);
//         _showSnackBar(data['message'] ?? "Failed to load courses.");
//       }
//     } catch (e) {
//       setState(() {
//         isLoading = false;
//       });
//       _showSnackBar("An error occurred: $e");
//     }
//   }

//   void _showSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8F9FA),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.teal),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         title: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Image.asset(
//               'assets/logo.png',
//               height: 24,
//               errorBuilder: (context, error, stackTrace) => const Icon(Icons.school, color: Colors.teal, size: 24),
//             ),
//             const SizedBox(width: 8),
//             const Text(
//               "House of Tutor",
//               style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
//             ),
//           ],
//         ),
//         centerTitle: true,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Title Header Section
//             const Text(
//               "Enrolled Courses",
//               style: TextStyle(
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87,
//               ),
//             ),
//             const SizedBox(height: 4),
//             const Text(
//               "Select a course subject to view detailed class schedules",
//               style: TextStyle(
//                 fontSize: 13,
//                 color: Colors.grey,
//               ),
//             ),
//             const SizedBox(height: 16),

//             // Main Content Area
//             isLoading
//                 ? const Center(
//                     child: Padding(
//                       padding: EdgeInsets.all(40.0),
//                       child: CircularProgressIndicator(color: Colors.teal),
//                     ),
//                   )
//                 : coursesList.isEmpty
//                     ? Center(
//                         child: Padding(
//                           padding: const EdgeInsets.all(40.0),
//                           child: Text(
//                             "No enrolled courses found.",
//                             style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
//                           ),
//                         ),
//                       )
//                     : ListView.builder(
//                         itemCount: coursesList.length,
//                         shrinkWrap: true,
//                         physics: const NeverScrollableScrollPhysics(),
//                         itemBuilder: (context, index) {
//                           final course = coursesList[index];
//                           final courseTitle = course['courseTitle'] ?? 'Unnamed Course';
//                           final courseNumber = index + 1;
                          
//                           // Safely parse courseId to prevent type casting or null errors
//                           final rawCourseId = course['courseId'] ?? course['id'];
//                           final courseId = rawCourseId is int 
//                               ? rawCourseId 
//                               : int.tryParse(rawCourseId?.toString() ?? '') ?? 0;

//                           return Container(
//                             margin: const EdgeInsets.only(bottom: 16),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(16),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.grey.withOpacity(0.08),
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 4),
//                                 ),
//                               ],
//                               border: Border.all(color: Colors.grey.shade200),
//                             ),
//                             child: InkWell(
//                               onTap: () {
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) => ParentChildClasses(
//                                       studentId: widget.studentId,
//                                       courseId: courseId,
//                                       courseTitle: courseTitle,
//                                     ),
//                                   ),
//                                 );
//                               },
//                               borderRadius: BorderRadius.circular(16),
//                               child: Column(
//                                 children: [
//                                   Padding(
//                                     padding: const EdgeInsets.all(16.0),
//                                     child: Row(
//                                       children: [
//                                         Container(
//                                           padding: const EdgeInsets.all(12),
//                                           decoration: BoxDecoration(
//                                             color: Colors.teal.shade50,
//                                             borderRadius: BorderRadius.circular(12),
//                                           ),
//                                           child: Icon(Icons.menu_book, color: Colors.teal.shade700, size: 24),
//                                         ),
//                                         const SizedBox(width: 16),
//                                         Expanded(
//                                           child: Column(
//                                             crossAxisAlignment: CrossAxisAlignment.start,
//                                             children: [
//                                               Text(
//                                                 "COURSE #$courseNumber",
//                                                 style: const TextStyle(
//                                                   fontSize: 11,
//                                                   fontWeight: FontWeight.bold,
//                                                   color: Colors.grey,
//                                                   letterSpacing: 0.5,
//                                                 ),
//                                               ),
//                                               const SizedBox(height: 4),
//                                               Text(
//                                                 courseTitle,
//                                                 style: const TextStyle(
//                                                   fontSize: 17,
//                                                   fontWeight: FontWeight.bold,
//                                                   color: Colors.black87,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//                                         Container(
//                                           padding: const EdgeInsets.all(6),
//                                           decoration: BoxDecoration(
//                                             color: Colors.grey.shade100,
//                                             shape: BoxShape.circle,
//                                           ),
//                                           child: Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 20),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                   const Divider(height: 1, color: Color(0xFFF0F0F0)),
//                                   Padding(
//                                     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
//                                     child: Row(
//                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                       children: const [
//                                         Text(
//                                           "View Enrolled Classes",
//                                           style: TextStyle(
//                                             color: Colors.teal,
//                                             fontWeight: FontWeight.w600,
//                                             fontSize: 13,
//                                           ),
//                                         ),
//                                         Icon(Icons.arrow_forward, color: Colors.teal, size: 16),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//           ],
//         ),
//       ),
//     );
//   }
// }