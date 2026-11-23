import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:house_of_tutor/services/api_client.dart';

class ParentChildTutor extends StatefulWidget {
  final Map<String, dynamic> child;

  const ParentChildTutor({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<ParentChildTutor> createState() => _ParentChildTutorState();
}

class _ParentChildTutorState extends State<ParentChildTutor> {
  // =====================================================
  // COLORS
  // =====================================================

  static const Color primaryColor = Color(0xFF1E8E7E);
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color textColor = Color(0xFF263238);
  static const Color borderColor = Color(0xFFE8ECEF);

  // =====================================================
  // VARIABLES
  // =====================================================

  List<dynamic> tutorsList = [];

  bool isLoading = true;

  // =====================================================
  // INIT STATE
  // =====================================================

  @override
  void initState() {
    super.initState();
    fetchChildTutors();
  }

  // =====================================================
  // GET CHILD ID
  // =====================================================

  int? _getStudentId() {
    final id = widget.child['studentId'] ??
        widget.child['student_id'] ??
        widget.child['StudentId'];

    if (id == null) return null;

    return int.tryParse(id.toString());
  }

  // =====================================================
  // FETCH CHILD TUTORS API
  // =====================================================

  Future<void> fetchChildTutors() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final studentId = _getStudentId();

      if (studentId == null) {
        throw Exception('Student ID not found.');
      }

      // API CALL
      final response = await ApiClient.get(
        '/api/Parent/child-tutors/$studentId',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);

        List<dynamic> loadedTutors = [];

        // API may return a direct list.
        if (decodedData is List) {
          loadedTutors = decodedData;
        }
        // API may return a list inside an object.
        else if (decodedData is Map) {
          final data = decodedData['tutors'] ??
              decodedData['data'] ??
              decodedData['result'];

          if (data is List) {
            loadedTutors = data;
          }
        }

        setState(() {
          tutorsList = loadedTutors;
          isLoading = false;
        });
      } else {
        String errorMessage = 'Failed to load tutors.';

        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);

            if (errorData is Map) {
              errorMessage = (errorData['message'] ??
                      errorData['Message'] ??
                      errorData['error'] ??
                      errorMessage)
                  .toString();
            } else {
              errorMessage = errorData.toString();
            }
          } catch (_) {
            errorMessage = response.body;
          }
        }

        setState(() {
          tutorsList = [];
          isLoading = false;
        });

        _showSnackBar(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        tutorsList = [];
        isLoading = false;
      });

      _showSnackBar('An error occurred: $e');
    }
  }

  // =====================================================
  // SHOW MESSAGE
  // =====================================================

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =====================================================
  // GET SAFE STRING VALUE
  // =====================================================

  String _getValue(
    dynamic data,
    String key, {
    String defaultValue = 'Not Available',
  }) {
    if (data is! Map) return defaultValue;

    final value = data[key];

    if (value == null || value.toString().trim().isEmpty) {
      return defaultValue;
    }

    return value.toString();
  }

  // =====================================================
  // GET TUTOR INITIALS
  // =====================================================

  String _getInitials(String name) {
    if (name.trim().isEmpty || name == 'Unknown Tutor') {
      return 'T';
    }

    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    return parts[0][0].toUpperCase();
  }

  // =====================================================
  // BUILD LOGO
  // =====================================================

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo.png',
      width: 34,
      height: 34,
      fit: BoxFit.contain,

      // If logo is not found, show fallback icon.
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          Icons.school_rounded,
          color: primaryColor,
          size: 30,
        );
      },
    );
  }

  // =====================================================
  // APP BAR
  // =====================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,

      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: primaryColor,
          size: 20,
        ),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),

      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLogo(),

          const SizedBox(width: 8),

          const Text(
            'House of Tutor',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // PAGE HEADER
  // =====================================================

  Widget _buildPageHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assigned Tutors',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),

        SizedBox(height: 5),

        Text(
          'View tutors assigned to your child.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // =====================================================
  // LOADING SCREEN
  // =====================================================

  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(
          color: primaryColor,
        ),
      ),
    );
  }

  // =====================================================
  // EMPTY SCREEN
  // =====================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 45,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.school_outlined,
            size: 55,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 14),

          const Text(
            'No Assigned Tutors',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'There are currently no tutors assigned to your child.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 18),

          ElevatedButton.icon(
            onPressed: fetchChildTutors,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 11,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // SMALL INFORMATION ROW
  // =====================================================

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: primaryColor,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              '$title: $value',
              style: const TextStyle(
                fontSize: 13,
                color: textColor,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // TUTOR CARD
  // =====================================================

  Widget _buildTutorCard(dynamic tutor) {
    final fullName = _getValue(
      tutor,
      'fullName',
      defaultValue: 'Unknown Tutor',
    );

    final email = _getValue(tutor, 'email');

    final phone = _getValue(tutor, 'phone');

    final qualification = _getValue(
      tutor,
      'qualification',
      defaultValue: 'Not Provided',
    );

    final experience = _getValue(
      tutor,
      'experience',
      defaultValue: '0',
    );

    final radius = _getValue(
      tutor,
      'radius',
      defaultValue: '0',
    );

    // Get assigned courses safely.
    final dynamic courseData =
        tutor is Map ? tutor['coursesTeaching'] : null;

    final List<dynamic> coursesTeaching =
        courseData is List ? courseData : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------
          // TUTOR NAME AND QUALIFICATION
          // ---------------------------------------------

          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F4F1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _getInitials(fullName),
                  style: const TextStyle(
                    color: primaryColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F4F1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        qualification,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ---------------------------------------------
          // EXPERIENCE AND COVERAGE
          // ---------------------------------------------

          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 13,
              horizontal: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.work_outline_rounded,
                        size: 20,
                        color: primaryColor,
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Experience',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        '$experience Years',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  height: 40,
                  width: 1,
                  color: borderColor,
                ),

                Expanded(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: primaryColor,
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Coverage',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        '$radius KM Radius',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 17),

          // ---------------------------------------------
          // CONTACT INFORMATION
          // ---------------------------------------------

          _buildInfoRow(
            icon: Icons.email_outlined,
            title: 'Email',
            value: email,
          ),

          _buildInfoRow(
            icon: Icons.phone_outlined,
            title: 'Phone',
            value: phone,
          ),

          const Divider(
            height: 22,
            color: borderColor,
          ),

          // ---------------------------------------------
          // ASSIGNED COURSES
          // ---------------------------------------------

          const Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 19,
                color: primaryColor,
              ),

              SizedBox(width: 8),

              Text(
                'Assigned Courses',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (coursesTeaching.isEmpty)
            Text(
              'No courses available.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: coursesTeaching.map<Widget>((course) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5F3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFC8E5DF),
                    ),
                  ),
                  child: Text(
                    course.toString(),
                    style: const TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // =====================================================
  // BUILD SCREEN
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      // APP BAR WITH HOUSE OF TUTOR LOGO
      appBar: _buildAppBar(),

      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: fetchChildTutors,

        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // PAGE TITLE
            _buildPageHeader(),

            const SizedBox(height: 20),

            // LOADING / EMPTY / TUTOR LIST
            if (isLoading)
              _buildLoading()
            else if (tutorsList.isEmpty)
              _buildEmptyState()
            else ...[
              // NUMBER OF TUTORS
              Row(
                children: [
                  const Text(
                    'Your Child\'s Tutors',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),

                  const Spacer(),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F4F1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${tutorsList.length} Tutors',
                      style: const TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // TUTOR CARDS
              ...tutorsList.map(
                (tutor) => _buildTutorCard(tutor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}





















// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:house_of_tutor/services/api_client.dart';

// class ParentChildTutor extends StatefulWidget {
//   final Map<String, dynamic> child;

//   const ParentChildTutor({
//     Key? key,
//     required this.child,
//   }) : super(key: key);

//   @override
//   _ParentChildTutorState createState() => _ParentChildTutorState();
// }

// class _ParentChildTutorState extends State<ParentChildTutor> {
//   List<dynamic> tutorsList = [];
//   bool isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     fetchChildTutors();
//   }

//   Future<void> fetchChildTutors() async {
//     setState(() {
//       isLoading = true;
//     });

//     try {
//       final studentId = widget.child['studentId'];
//       final response = await ApiClient.get('/api/Parent/child-tutors/$studentId');
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         setState(() {
//           tutorsList = data is List ? data : [];
//           isLoading = false;
//         });
//       } else {
//         setState(() {
//           isLoading = false;
//         });
//         String errorMessage = "Failed to load tutors.";
//         if (response.body.isNotEmpty) {
//           try {
//             final data = json.decode(response.body);
//             errorMessage = data['message'] ?? errorMessage;
//           } catch (_) {
//             errorMessage = response.body;
//           }
//         }
//         _showSnackBar(errorMessage);
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

//   String _getInitials(String name) {
//     if (name.isEmpty) return "T";
//     List<String> parts = name.trim().split(' ');
//     if (parts.length >= 2) {
//       return "${parts[0][0]}${parts[1][0]}".toUpperCase();
//     }
//     return parts[0][0].toUpperCase();
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
//               "Assigned Tutors",
//               style: TextStyle(
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87,
//               ),
//             ),
//             const SizedBox(height: 4),
//             const Text(
//               "Manage and view academic instructors for your child",
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
//                 : tutorsList.isEmpty
//                     ? Center(
//                         child: Padding(
//                           padding: const EdgeInsets.all(40.0),
//                           child: Text(
//                             "No assigned tutors found.",
//                             style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
//                           ),
//                         ),
//                       )
//                     : ListView.builder(
//                         itemCount: tutorsList.length,
//                         shrinkWrap: true,
//                         physics: const NeverScrollableScrollPhysics(),
//                         itemBuilder: (context, index) {
//                           final tutor = tutorsList[index];
//                           final fullName = tutor['fullName'] ?? 'Unknown Tutor';
//                           final email = tutor['email'] ?? 'Not Available';
//                           final phone = tutor['phone'] ?? 'Not Available';
//                           final qualification = tutor['qualification'] ?? 'N/A';
//                           final experience = tutor['experience']?.toString() ?? '0';
//                           final radius = tutor['radius']?.toString() ?? '0';
//                           List<dynamic> coursesTeaching = tutor['coursesTeaching'] ?? [];

//                           return Container(
//                             margin: const EdgeInsets.only(bottom: 16),
//                             padding: const EdgeInsets.all(16),
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
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 // Tutor Header Info
//                                 Row(
//                                   children: [
//                                     Container(
//                                       padding: const EdgeInsets.all(16),
//                                       decoration: BoxDecoration(
//                                         color: Colors.teal.shade50,
//                                         shape: BoxShape.circle,
//                                       ),
//                                       child: Text(
//                                         _getInitials(fullName),
//                                         style: TextStyle(
//                                           color: Colors.teal.shade700,
//                                           fontWeight: FontWeight.bold,
//                                           fontSize: 16,
//                                         ),
//                                       ),
//                                     ),
//                                     const SizedBox(width: 12),
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: [
//                                           Text(
//                                             fullName,
//                                             style: const TextStyle(
//                                               fontSize: 18,
//                                               fontWeight: FontWeight.bold,
//                                               color: Colors.black87,
//                                             ),
//                                           ),
//                                           const SizedBox(height: 4),
//                                           Container(
//                                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                                             decoration: BoxDecoration(
//                                               color: Colors.teal.shade50,
//                                               borderRadius: BorderRadius.circular(6),
//                                             ),
//                                             child: Row(
//                                               mainAxisSize: MainAxisSize.min,
//                                               children: [
//                                                 Icon(Icons.school_outlined, size: 12, color: Colors.teal.shade700),
//                                                 const SizedBox(width: 4),
//                                                 Text(
//                                                   qualification,
//                                                   style: TextStyle(color: Colors.teal.shade700, fontSize: 11, fontWeight: FontWeight.w600),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 16),

//                                 // Experience and Coverage Info Box
//                                 Container(
//                                   padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//                                   decoration: BoxDecoration(
//                                     color: Colors.grey.shade50,
//                                     borderRadius: BorderRadius.circular(12),
//                                     border: Border.all(color: Colors.grey.shade200),
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       Expanded(
//                                         child: Column(
//                                           children: [
//                                             Icon(Icons.work_outline, size: 18, color: Colors.grey.shade600),
//                                             const SizedBox(height: 4),
//                                             const Text(
//                                               "Experience",
//                                               style: TextStyle(fontSize: 11, color: Colors.grey),
//                                             ),
//                                             const SizedBox(height: 2),
//                                             Text(
//                                               "$experience Years",
//                                               style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       Container(height: 30, width: 1, color: Colors.grey.shade300),
//                                       Expanded(
//                                         child: Column(
//                                           children: [
//                                             Icon(Icons.location_on_outlined, size: 18, color: Colors.grey.shade600),
//                                             const SizedBox(height: 4),
//                                             const Text(
//                                               "Coverage",
//                                               style: TextStyle(fontSize: 11, color: Colors.grey),
//                                             ),
//                                             const SizedBox(height: 2),
//                                             Text(
//                                               "$radius KM Radius",
//                                               style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 const SizedBox(height: 16),

//                                 // Contact Info Rows
//                                 Row(
//                                   children: [
//                                     Icon(Icons.email_outlined, size: 16, color: Colors.grey.shade600),
//                                     const SizedBox(width: 8),
//                                     Text(
//                                       email,
//                                       style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 8),
//                                 Row(
//                                   children: [
//                                     Icon(Icons.phone_outlined, size: 16, color: Colors.grey.shade600),
//                                     const SizedBox(width: 8),
//                                     Text(
//                                       phone,
//                                       style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
//                                     ),
//                                   ],
//                                 ),
//                                 const Padding(
//                                   padding: EdgeInsets.symmetric(vertical: 12.0),
//                                   child: Divider(height: 1, color: Color(0xFFF0F0F0)),
//                                 ),

//                                 // Assigned Courses Section
//                                 const Row(
//                                   children: [
//                                     Icon(Icons.menu_book_outlined, size: 16, color: Colors.teal),
//                                     SizedBox(width: 6),
//                                     Text(
//                                       "Assigned Courses",
//                                       style: TextStyle(
//                                         fontSize: 13,
//                                         fontWeight: FontWeight.bold,
//                                         color: Colors.black87,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 10),
//                                 Wrap(
//                                   spacing: 8.0,
//                                   runSpacing: 6.0,
//                                   children: coursesTeaching.map<Widget>((course) {
//                                     return Container(
//                                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                                       decoration: BoxDecoration(
//                                         color: Colors.teal.shade50.withOpacity(0.5),
//                                         borderRadius: BorderRadius.circular(16),
//                                         border: Border.all(color: Colors.teal.shade200),
//                                       ),
//                                       child: Text(
//                                         course.toString(),
//                                         style: TextStyle(
//                                           color: Colors.teal.shade800,
//                                           fontSize: 12,
//                                           fontWeight: FontWeight.w600,
//                                         ),
//                                       ),
//                                     );
//                                   }).toList(),
//                                 ),
//                               ],
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
