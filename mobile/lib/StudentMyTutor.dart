import 'package:flutter/material.dart';
import 'package:house_of_tutor/services/api_client.dart';

class StudentMyTutor extends StatefulWidget {
  const StudentMyTutor({super.key});

  @override
  State<StudentMyTutor> createState() => _StudentMyTutorState();
}

class _StudentMyTutorState extends State<StudentMyTutor> {
  bool isLoading = true;
  List<dynamic> tutorsList = [];
  String errorMessage = '';

  // ============================================================
  // THEME COLOR
  // ============================================================
  final Color primaryColor = const Color(0xff009688);

  @override
  void initState() {
    super.initState();
    fetchMyTutors();
  }

  // ============================================================
  // FETCH MY TUTORS
  // ============================================================
  Future<void> fetchMyTutors() async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
          errorMessage = '';
        });
      }

      final response = await ApiClient.get(
        '/api/Student/my-tutors',
      );

      if (response.statusCode == 200) {
        final data = await ApiClient.decodeJson(response);

        if (!mounted) return;

        setState(() {
          tutorsList = data is List ? data : [];
          isLoading = false;
        });
      } else {
        final msg = ApiClient.messageFromBody(response.body) ??
            'Failed to load tutors';

        if (!mounted) return;

        setState(() {
          errorMessage = msg;
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'An error occurred: $e';
        isLoading = false;
      });
    }
  }

  // ============================================================
  // SAVE GRADE
  // ============================================================
  Future<void> saveGrade(int courseId, String grade) async {
    if (grade.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a grade'),
        ),
      );
      return;
    }

    try {
      final response = await ApiClient.post(
        '/api/Student/save-grade',
        {
          'courseId': courseId,
          'grade': grade.trim(),
        },
      );

      if (response.statusCode == 200) {
        await fetchMyTutors();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grade saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final msg = ApiClient.messageFromBody(response.body) ??
            'Failed to save grade';

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving grade: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // GIVE FEEDBACK
  // ============================================================
  Future<void> giveFeedback(
    int tutorId,
    int courseId,
    int rating,
    String comment,
  ) async {
    try {
      final response = await ApiClient.post(
        '/api/Student/give-feedback',
        {
          'tutorId': tutorId,
          'courseId': courseId,

          // IMPORTANT:
          // Rating selected from 1 to 5 stars
          'rating': rating,

          'comment': comment.trim(),
        },
      );

      if (response.statusCode == 200) {
        await fetchMyTutors();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final msg = ApiClient.messageFromBody(response.body) ??
            'Failed to submit feedback';

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // UPDATE GRADE DIALOG
  // ============================================================
  void showGradeDialog(
    int courseId,
    String currentGrade,
  ) {
    final TextEditingController gradeController =
        TextEditingController(text: currentGrade);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Update Grade',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: TextField(
            controller: gradeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Enter Grade (e.g. A, B+)',
              prefixIcon: const Icon(
                Icons.school_outlined,
                color: Color(0xff009688),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final grade = gradeController.text.trim();

                Navigator.pop(dialogContext);

                saveGrade(courseId, grade);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // FEEDBACK DIALOG WITH STAR RATING
  // ============================================================
  void showFeedbackDialog(
    int tutorId,
    int courseId,
  ) {
    // Default rating = 5 stars
    int rating = 5;

    final TextEditingController commentController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    color: Color(0xff009688),
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Give Feedback',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // STAR RATING TITLE
                    // ==================================================
                    const Text(
                      'Rate your tutor',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ==================================================
                    // STAR RATING
                    // ==================================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (index) {
                          final int starNumber = index + 1;

                          return IconButton(
                            tooltip: '$starNumber Star',
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                rating = starNumber;
                              });
                            },
                            icon: Icon(
                              starNumber <= rating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber.shade700,
                              size: 34,
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 4),

                    // ==================================================
                    // RATING TEXT
                    // ==================================================
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$rating / 5 Stars',
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // COMMENT
                    // ==================================================
                    const Text(
                      'Your Comment',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: commentController,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Write your feedback...',
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(
                            bottom: 55,
                          ),
                          child: Icon(
                            Icons.comment_outlined,
                            color: Color(0xff009688),
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xff009688),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cancel',
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(
                    Icons.send,
                    size: 17,
                  ),
                  label: const Text(
                    'Submit',
                  ),
                  onPressed: () async {
                    // ==================================================
                    // COMMENT VALIDATION
                    // ==================================================
                    if (commentController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please write a comment',
                          ),
                        ),
                      );
                      return;
                    }

                    // Close dialog first
                    Navigator.pop(dialogContext);

                    // Send selected star rating
                    await giveFeedback(
                      tutorId,
                      courseId,
                      rating,
                      commentController.text,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // GET INITIALS
  // ============================================================
  String getInitials(String name) {
    if (name.trim().isEmpty) {
      return 'T';
    }

    final parts = name.trim().split(' ');

    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      // ============================================================
      // APP BAR
      // ============================================================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: Image.asset(
          'assets/images/logo.png',
          height: 30,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return const Text(
              'House of Tutor',
              style: TextStyle(
                color: Color(0xff009688),
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),

        centerTitle: true,
      ),

      // ============================================================
      // BODY
      // ============================================================
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 45,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton(
                          onPressed: fetchMyTutors,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // ==================================================
                      // PAGE TITLE
                      // ==================================================
                      const Text(
                        'My Tutors',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Track your coursework, grades, and tutor feedback',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // ==================================================
                      // TUTOR LIST
                      // ==================================================
                      Expanded(
                        child: tutorsList.isEmpty
                            ? RefreshIndicator(
                                color: primaryColor,
                                onRefresh: fetchMyTutors,
                                child: ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 150),
                                    Center(
                                      child: Text(
                                        'No assigned tutors found.',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                color: primaryColor,
                                onRefresh: fetchMyTutors,
                                child: ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: tutorsList.length,
                                  itemBuilder:
                                      (context, index) {
                                    final tutor =
                                        tutorsList[index];

                                    final String tutorName =
                                        tutor['tutorName']
                                                ?.toString() ??
                                            'Tutor';

                                    final String courseName =
                                        tutor['courseName']
                                                ?.toString() ??
                                            '';

                                    final String grade =
                                        tutor['grade']
                                                ?.toString() ??
                                            '-';

                                    final bool isCompleted =
                                        tutor['isCompleted'] ==
                                            true;

                                    final bool feedbackGiven =
                                        tutor['feedbackGiven'] ==
                                            true;

                                    return Container(
                                      margin:
                                          const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      padding:
                                          const EdgeInsets.all(
                                        14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(
                                          16,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 8,
                                            offset:
                                                const Offset(
                                              0,
                                              3,
                                            ),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          // ============================================
                                          // TUTOR HEADER
                                          // ============================================
                                          Row(
                                            children: [
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration:
                                                    BoxDecoration(
                                                  color: Colors
                                                      .teal
                                                      .shade50,
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                    12,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    getInitials(
                                                      tutorName,
                                                    ),
                                                    style:
                                                        const TextStyle(
                                                      color: Color(
                                                        0xff009688,
                                                      ),
                                                      fontWeight:
                                                          FontWeight
                                                              .bold,
                                                      fontSize:
                                                          17,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(
                                                width: 12,
                                              ),

                                              // Tutor name + course
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Text(
                                                      tutorName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow
                                                              .ellipsis,
                                                      style:
                                                          const TextStyle(
                                                        fontSize:
                                                            17,
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                        color: Colors
                                                            .black87,
                                                      ),
                                                    ),

                                                    const SizedBox(
                                                      height: 4,
                                                    ),

                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .book_outlined,
                                                          size: 14,
                                                          color: Colors
                                                              .grey,
                                                        ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        Expanded(
                                                          child:
                                                              Text(
                                                            courseName,
                                                            maxLines:
                                                                1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                TextStyle(
                                                              fontSize:
                                                                  13,
                                                              color: Colors
                                                                  .grey
                                                                  .shade600,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              const SizedBox(
                                                width: 8,
                                              ),

                                              // Grade
                                              Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                  horizontal: 10,
                                                  vertical: 7,
                                                ),
                                                decoration:
                                                    BoxDecoration(
                                                  color: Colors
                                                      .teal
                                                      .shade50,
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                    10,
                                                  ),
                                                  border:
                                                      Border.all(
                                                    color: Colors
                                                        .teal
                                                        .shade100,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    const Text(
                                                      'GRADE',
                                                      style:
                                                          TextStyle(
                                                        fontSize:
                                                            9,
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                        color: Color(
                                                          0xff009688,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 2,
                                                    ),
                                                    Text(
                                                      grade,
                                                      style:
                                                          const TextStyle(
                                                        fontSize:
                                                            15,
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                        color: Color(
                                                          0xff00796B,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),

                                          // ============================================
                                          // DIVIDER
                                          // ============================================
                                          const Padding(
                                            padding:
                                                EdgeInsets.symmetric(
                                              vertical: 11,
                                            ),
                                            child: Divider(
                                              height: 1,
                                            ),
                                          ),

                                          // ============================================
                                          // COURSE STATUS
                                          // ============================================
                                          Row(
                                            children: [
                                              if (isCompleted)
                                                Container(
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 9,
                                                    vertical: 5,
                                                  ),
                                                  decoration:
                                                      BoxDecoration(
                                                    color: Colors
                                                        .green
                                                        .shade50,
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                      20,
                                                    ),
                                                  ),
                                                  child:
                                                      const Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .check_circle,
                                                        color: Colors
                                                            .green,
                                                        size: 14,
                                                      ),
                                                      SizedBox(
                                                        width: 4,
                                                      ),
                                                      Text(
                                                        'Course Completed',
                                                        style:
                                                            TextStyle(
                                                          color: Colors
                                                              .green,
                                                          fontSize:
                                                              11,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else
                                                Container(
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 9,
                                                    vertical: 5,
                                                  ),
                                                  decoration:
                                                      BoxDecoration(
                                                    color: Colors
                                                        .orange
                                                        .shade50,
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                      20,
                                                    ),
                                                  ),
                                                  child:
                                                      const Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .schedule,
                                                        color: Colors
                                                            .orange,
                                                        size: 14,
                                                      ),
                                                      SizedBox(
                                                        width: 4,
                                                      ),
                                                      Text(
                                                        'In Progress',
                                                        style:
                                                            TextStyle(
                                                          color: Colors
                                                              .orange,
                                                          fontSize:
                                                              11,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),

                                          const SizedBox(
                                            height: 12,
                                          ),

                                          // ============================================
                                          // BUTTONS
                                          // ============================================
                                          Row(
                                            children: [
                                              // UPDATE GRADE
                                              Expanded(
                                                child:
                                                    OutlinedButton
                                                        .icon(
                                                  style:
                                                      OutlinedButton
                                                          .styleFrom(
                                                    foregroundColor:
                                                        primaryColor,
                                                    side:
                                                        BorderSide(
                                                      color:
                                                          primaryColor,
                                                    ),
                                                    minimumSize:
                                                        const Size(
                                                      0,
                                                      42,
                                                    ),
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 8,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                        10,
                                                      ),
                                                    ),
                                                  ),
                                                  icon:
                                                      const Icon(
                                                    Icons
                                                        .edit_outlined,
                                                    size: 17,
                                                  ),
                                                  label:
                                                      const Text(
                                                    'Update Grade',
                                                    style:
                                                        TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    showGradeDialog(
                                                      tutor[
                                                          'courseId'],
                                                      grade,
                                                    );
                                                  },
                                                ),
                                              ),

                                              const SizedBox(
                                                width: 9,
                                              ),

                                              // FEEDBACK
                                              Expanded(
                                                child: feedbackGiven
                                                    ? Container(
                                                        height: 42,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .teal
                                                              .shade50,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                            10,
                                                          ),
                                                        ),
                                                        child:
                                                            const Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .verified,
                                                              color:
                                                                  Color(
                                                                0xff009688,
                                                              ),
                                                              size:
                                                                  16,
                                                            ),
                                                            SizedBox(
                                                              width:
                                                                  5,
                                                            ),
                                                            Text(
                                                              'Feedback Given',
                                                              style:
                                                                  TextStyle(
                                                                color:
                                                                    Color(
                                                                  0xff00796B,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize:
                                                                    11,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                    : ElevatedButton
                                                        .icon(
                                                        style:
                                                            ElevatedButton
                                                                .styleFrom(
                                                          backgroundColor:
                                                              primaryColor,
                                                          foregroundColor:
                                                              Colors
                                                                  .white,
                                                          elevation:
                                                              0,
                                                          minimumSize:
                                                              const Size(
                                                            0,
                                                            42,
                                                          ),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal:
                                                                8,
                                                          ),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              10,
                                                            ),
                                                          ),
                                                        ),
                                                        icon:
                                                            const Icon(
                                                          Icons
                                                              .star_rate_outlined,
                                                          size:
                                                              18,
                                                        ),
                                                        label:
                                                            const Text(
                                                          'Feedback',
                                                          style:
                                                              TextStyle(
                                                            fontSize:
                                                                12,
                                                          ),
                                                        ),
                                                        onPressed:
                                                            () {
                                                          showFeedbackDialog(
                                                            tutor[
                                                                'tutorId'],
                                                            tutor[
                                                                'courseId'],
                                                          );
                                                        },
                                                      ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}