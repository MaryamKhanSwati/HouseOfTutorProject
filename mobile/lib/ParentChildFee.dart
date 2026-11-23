import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:house_of_tutor/services/api_client.dart';

class ParentChildFee extends StatefulWidget {
  const ParentChildFee({Key? key}) : super(key: key);

  @override
  State<ParentChildFee> createState() => _ParentChildFeeState();
}

class _ParentChildFeeState extends State<ParentChildFee> {
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

  bool isLoading = true;
  bool isSendingPayment = false;

  Map<String, dynamic> feeData = {};
  List<dynamic> childrenList = [];

  int? selectedStudentId;

  // =====================================================
  // INIT STATE
  // =====================================================

  @override
  void initState() {
    super.initState();
    fetchChildrenFee();
  }

  // =====================================================
  // HELPER: CONVERT VALUE TO DOUBLE
  // =====================================================

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0.0;
  }

  // =====================================================
  // HELPER: CONVERT VALUE TO INT
  // =====================================================

  int? _toInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    return int.tryParse(value.toString());
  }

  // =====================================================
  // FETCH CHILDREN FEE API
  // =====================================================

  Future<void> fetchChildrenFee() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiClient.get(
        '/api/Parent/children-fee',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);

        if (decodedData is! Map) {
          throw Exception('Invalid fee response from server.');
        }

        final data = Map<String, dynamic>.from(decodedData);

        final dynamic childrenData = data['children'];

        final List<dynamic> loadedChildren =
            childrenData is List ? childrenData : [];

        int? newSelectedId = selectedStudentId;

        // Select the first child by default.
        if (loadedChildren.isNotEmpty) {
          final selectedExists = loadedChildren.any((child) {
            if (child is! Map) return false;

            return _toInt(child['studentId']) == selectedStudentId;
          });

          if (!selectedExists) {
            final firstChild = loadedChildren.first;

            if (firstChild is Map) {
              newSelectedId = _toInt(firstChild['studentId']);
            }
          }
        } else {
          newSelectedId = null;
        }

        setState(() {
          feeData = data;
          childrenList = loadedChildren;
          selectedStudentId = newSelectedId;
          isLoading = false;
        });
      } else {
        String message = 'Failed to load fee statement.';

        try {
          final errorData = jsonDecode(response.body);

          if (errorData is Map) {
            message = (errorData['message'] ??
                    errorData['Message'] ??
                    message)
                .toString();
          }
        } catch (_) {
          if (response.body.isNotEmpty) {
            message = response.body;
          }
        }

        setState(() {
          isLoading = false;
        });

        _showSnackBar(message);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showSnackBar('An error occurred: $e');
    }
  }

  // =====================================================
  // SEND PAYMENT API
  // =====================================================

  Future<void> sendPayment(int feeId, double amount) async {
    if (isSendingPayment) return;

    setState(() {
      isSendingPayment = true;
    });

    try {
      final response = await ApiClient.post(
        '/send-payment',
        jsonEncode({
          'feeId': feeId,
          'amount': amount,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        String message = 'Payment sent successfully.';

        try {
          final data = jsonDecode(response.body);

          if (data is Map) {
            message = (data['message'] ?? message).toString();
          }
        } catch (_) {}

        _showSnackBar(message);

        // Refresh fee information after payment.
        await fetchChildrenFee();
      } else {
        String message = 'Payment failed.';

        try {
          final data = jsonDecode(response.body);

          if (data is Map) {
            message = (data['message'] ??
                    data['Message'] ??
                    message)
                .toString();
          }
        } catch (_) {
          if (response.body.isNotEmpty) {
            message = response.body;
          }
        }

        _showSnackBar(message);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Payment error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSendingPayment = false;
        });
      }
    }
  }

  // =====================================================
  // SHOW SNACKBAR
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
  // GET SELECTED CHILD
  // =====================================================

  Map<String, dynamic>? _getSelectedStudent() {
    if (childrenList.isEmpty) return null;

    for (final child in childrenList) {
      if (child is Map &&
          _toInt(child['studentId']) == selectedStudentId) {
        return Map<String, dynamic>.from(child);
      }
    }

    if (childrenList.first is Map) {
      return Map<String, dynamic>.from(childrenList.first);
    }

    return null;
  }

  // =====================================================
  // PAYMENT DIALOG
  // =====================================================

  void _showPaymentDialog(
    bool isFullPayment,
    Map<String, dynamic> selectedChild,
    dynamic courseFee,
  ) {
    if (courseFee is! Map) return;

    final Map<String, dynamic> fee =
        Map<String, dynamic>.from(courseFee);

    final double remainingBalance =
        _toDouble(fee['remaining']);

    final int? feeId = _toInt(fee['feeId']);

    if (feeId == null) {
      _showSnackBar('Fee ID not found.');
      return;
    }

    if (remainingBalance <= 0) {
      _showSnackBar('No remaining balance.');
      return;
    }

    final TextEditingController amountController =
        TextEditingController();

    if (isFullPayment) {
      amountController.text = remainingBalance.toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Column(
            children: [
              Text(
                isFullPayment
                    ? 'Full Fee Payment'
                    : 'Partial Fee Payment',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                (selectedChild['studentName'] ?? 'Student').toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Remaining balance
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5F3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFC8E5DF),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Balance Due',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Rs. ${remainingBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Enter Payment Amount',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: amountController,
                enabled: !isFullPayment,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  prefixText: 'Rs. ',
                  filled: true,
                  fillColor: const Color(0xFFF7F9FA),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: borderColor,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: borderColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                amountController.dispose();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              onPressed: isSendingPayment
                  ? null
                  : () {
                      final double? enteredAmount =
                          double.tryParse(amountController.text.trim());

                      if (enteredAmount == null ||
                          enteredAmount <= 0) {
                        _showSnackBar(
                          'Please enter a valid amount.',
                        );
                        return;
                      }

                      if (enteredAmount > remainingBalance) {
                        _showSnackBar(
                          'Amount exceeds remaining balance.',
                        );
                        return;
                      }

                      Navigator.pop(dialogContext);
                      amountController.dispose();

                      sendPayment(feeId, enteredAmount);
                    },
              child: const Text('Confirm Payment'),
            ),
          ],
        );
      },
    ).then((_) {
      // Dispose controller if dialog is closed using back button.
      amountController.dispose();
    });
  }

  // =====================================================
  // APP BAR LOGO
  // =====================================================

  Widget _buildLogo() {
    return Image.asset(
      'assets/logo.png',
      width: 34,
      height: 34,
      fit: BoxFit.contain,
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
          'Family Statement',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),

        SizedBox(height: 5),

        Text(
          'View and manage your children\'s fee details.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // =====================================================
  // OVERALL FAMILY STATEMENT CARD
  // =====================================================

  Widget _buildFamilyStatementCard() {
    final double totalFamilyFee =
        _toDouble(feeData['totalFee']);

    final double totalFamilyPaid =
        _toDouble(feeData['totalPaid']);

    final double totalFamilyRemaining =
        _toDouble(feeData['totalRemaining']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2935),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'OVERALL STATEMENT',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),

              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          const Text(
            'Total Family Balance',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Rs. ${totalFamilyRemaining.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 27,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Total Fee: Rs. ${totalFamilyFee.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              color: Colors.white24,
              height: 1,
            ),
          ),

          Row(
            children: [
              Expanded(
                child: _buildDarkAmount(
                  title: 'Paid',
                  amount: totalFamilyPaid,
                  amountColor: Colors.greenAccent,
                ),
              ),

              Container(
                height: 35,
                width: 1,
                color: Colors.white24,
              ),

              Expanded(
                child: _buildDarkAmount(
                  title: 'Remaining',
                  amount: totalFamilyRemaining,
                  amountColor: Colors.redAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          const Center(
            child: Text(
              'Select a student below to view breakdown',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // DARK CARD AMOUNT
  // =====================================================

  Widget _buildDarkAmount({
    required String title,
    required double amount,
    required Color amountColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white60,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          'Rs. ${amount.toStringAsFixed(2)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: amountColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // =====================================================
  // STUDENT SELECTOR
  // =====================================================

  Widget _buildStudentSelector() {
    if (childrenList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Student',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),

        const SizedBox(height: 11),

        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: childrenList.length,
            itemBuilder: (context, index) {
              final child = childrenList[index];

              if (child is! Map) {
                return const SizedBox.shrink();
              }

              final int? childId = _toInt(child['studentId']);

              final bool isSelected =
                  childId == selectedStudentId;

              final String studentName =
                  (child['studentName'] ?? 'Student').toString();

              return Padding(
                padding: const EdgeInsets.only(right: 9),
                child: ChoiceChip(
                  label: Text(studentName),
                  selected: isSelected,
                  selectedColor: primaryColor,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(
                      color: isSelected
                          ? primaryColor
                          : borderColor,
                    ),
                  ),
                  onSelected: (selected) {
                    if (!selected || childId == null) return;

                    setState(() {
                      selectedStudentId = childId;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // =====================================================
  // STUDENT BREAKDOWN CARD
  // =====================================================

  Widget _buildStudentBreakdown(
    Map<String, dynamic> student,
  ) {
    final String studentName =
        (student['studentName'] ?? 'Student').toString();

    final double total =
        _toDouble(student['totalFee']);

    final double paid =
        _toDouble(student['totalPaid']);

    final double remaining =
        _toDouble(student['totalRemaining']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$studentName\'s Breakdown',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5F3),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Text(
                  'Fee Overview',
                  style: TextStyle(
                    fontSize: 10,
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: borderColor,
            ),
          ),

          Row(
            children: [
              Expanded(
                child: _buildAmountColumn(
                  'Total',
                  total,
                  textColor,
                ),
              ),

              Expanded(
                child: _buildAmountColumn(
                  'Paid',
                  paid,
                  Colors.green,
                ),
              ),

              Expanded(
                child: _buildAmountColumn(
                  'Remaining',
                  remaining,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // AMOUNT COLUMN
  // =====================================================

  Widget _buildAmountColumn(
    String title,
    double amount,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          'Rs. ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // =====================================================
  // COURSE BREAKDOWN CARD
  // =====================================================

  Widget _buildCourseCard(
    dynamic courseFee,
    Map<String, dynamic> currentStudent,
  ) {
    if (courseFee is! Map) {
      return const SizedBox.shrink();
    }

    final Map<String, dynamic> fee =
        Map<String, dynamic>.from(courseFee);

    final String courseName =
        (fee['course'] ?? 'Course').toString();

    final String tutorName =
        (fee['tutor'] ?? 'Instructor').toString();

    final double total =
        _toDouble(fee['totalFee']);

    final double paid =
        _toDouble(fee['paid']);

    final double remaining =
        _toDouble(fee['remaining']);

    final bool isPaid = remaining <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // COURSE NAME AND STATUS
          Row(
            children: [
              Expanded(
                child: Text(
                  courseName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isPaid
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPaid
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),

                    const SizedBox(width: 5),

                    Text(
                      isPaid ? 'Paid' : 'Pending',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPaid
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          // TUTOR NAME
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 15,
                color: Colors.grey.shade600,
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  tutorName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: borderColor,
            ),
          ),

          // COURSE FEE DETAILS
          Row(
            children: [
              Expanded(
                child: _buildAmountColumn(
                  'Total',
                  total,
                  textColor,
                ),
              ),

              Expanded(
                child: _buildAmountColumn(
                  'Paid',
                  paid,
                  Colors.green,
                ),
              ),

              Expanded(
                child: _buildAmountColumn(
                  'Remaining',
                  remaining,
                  Colors.red,
                ),
              ),
            ],
          ),

          // PAYMENT BUTTONS
          if (!isPaid) ...[
            const SizedBox(height: 17),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSendingPayment
                        ? null
                        : () {
                            _showPaymentDialog(
                              true,
                              currentStudent,
                              fee,
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text(
                      'Pay Full',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: OutlinedButton(
                    onPressed: isSendingPayment
                        ? null
                        : () {
                            _showPaymentDialog(
                              false,
                              currentStudent,
                              fee,
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: const BorderSide(
                        color: primaryColor,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text(
                      'Partial Pay',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // =====================================================
  // EMPTY STATE
  // =====================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 52,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 12),

          const Text(
            'No Fee Records Found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'There are no children or fee records available.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: fetchChildrenFee,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
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
    final Map<String, dynamic>? currentStudent =
        _getSelectedStudent();

    final dynamic coursesData =
        currentStudent?['courses'];

    final List<dynamic> courses =
        coursesData is List ? coursesData : [];

    return Scaffold(
      backgroundColor: backgroundColor,

      // APP BAR WITH SAME LOGO
      appBar: _buildAppBar(),

      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: fetchChildrenFee,

        child: isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(
                    child: CircularProgressIndicator(
                      color: primaryColor,
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // PAGE HEADER
                  _buildPageHeader(),

                  const SizedBox(height: 18),

                  if (childrenList.isEmpty)
                    _buildEmptyState()
                  else ...[
                    // FAMILY STATEMENT
                    _buildFamilyStatementCard(),

                    const SizedBox(height: 22),

                    // STUDENT SELECTOR
                    _buildStudentSelector(),

                    const SizedBox(height: 18),

                    // SELECTED STUDENT BREAKDOWN
                    if (currentStudent != null) ...[
                      _buildStudentBreakdown(currentStudent),

                      const SizedBox(height: 22),

                      // COURSE BREAKDOWN HEADING
                      const Text(
                        'Course Breakdown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),

                      const SizedBox(height: 13),

                      if (courses.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: const Center(
                            child: Text(
                              'No course fee records found.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        ...courses.map(
                          (courseFee) => _buildCourseCard(
                            courseFee,
                            currentStudent,
                          ),
                        ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}
















// import 'package:flutter/material.dart';
// import 'package:house_of_tutor/ParentChildCourses.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:house_of_tutor/services/api_client.dart';

// class ParentChildFee extends StatefulWidget {
//   const ParentChildFee({Key? key}) : super(key: key);

//   @override
//   _ParentChildFeeState createState() => _ParentChildFeeState();
// }

// class _ParentChildFeeState extends State<ParentChildFee> {
//   bool isLoading = true;
//   Map<String, dynamic> feeData = {};
//   List<dynamic> childrenList = [];
//   int? selectedStudentId;

//   @override
//   void initState() {
//     super.initState();
//     fetchChildrenFee();
//   }

//   Future<void> fetchChildrenFee() async {
//     setState(() {
//       isLoading = true;
//     });

//     try {
//       final response = await ApiClient.get('/api/Parent/children-fee');
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         setState(() {
//           feeData = data;
//           childrenList = data['children'] ?? [];
//           if (childrenList.isNotEmpty) {
//             // Default to first student if not selected
//             selectedStudentId ??= childrenList[0]['studentId'];
//           }
//           isLoading = false;
//         });
//       } else {
//         setState(() {
//           isLoading = false;
//         });
//         final data = json.decode(response.body);
//         _showSnackBar(data['message'] ?? "Failed to load fee statement.");
//       }
//     } catch (e) {
//       setState(() {
//         isLoading = false;
//       });
//       _showSnackBar("An error occurred: $e");
//     }
//   }

//   Future<void> sendPayment(int feeId, double amount) async {
//     try {
//       final response = await ApiClient.post(
//         '/send-payment',
//         jsonEncode({
//           'feeId': feeId,
//           'amount': amount,
//         }),
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         _showSnackBar(data['message'] ?? "Payment Sent Successfully.");
//         fetchChildrenFee(); // Refresh data
//       } else {
//         final data = json.decode(response.body);
//         _showSnackBar(data['message'] ?? data.toString());
//       }
//     } catch (e) {
//       _showSnackBar("An error occurred: $e");
//     }
//   }

//   void _showSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }

//   void _showPaymentDialog(bool isFullPayment, Map<String, dynamic> selectedChild, dynamic courseFee) {
//     final TextEditingController amountController = TextEditingController();
//     final double remainingBalance = (courseFee['remaining'] ?? 0).toDouble();

//     if (isFullPayment) {
//       amountController.text = remainingBalance.toString();
//     } else {
//       amountController.text = "";
//     }

//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           title: Column(
//             children: [
//               Text(
//                 isFullPayment ? "Full Fee Payment" : "Partial Fee Payment",
//                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 selectedChild['studentName'] ?? '',
//                 style: const TextStyle(fontSize: 13, color: Colors.grey),
//               ),
//             ],
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade50,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Colors.grey.shade200),
//                 ),
//                 child: Column(
//                   children: [
//                     const Text("Total Balance Due", style: TextStyle(fontSize: 11, color: Colors.grey)),
//                     const SizedBox(height: 4),
//                     Text(
//                       "Rs. ${remainingBalance.toStringAsFixed(0)}",
//                       style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 16),
//               const Text("Enter Payment Amount", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
//               const SizedBox(height: 8),
//               TextField(
//                 controller: amountController,
//                 keyboardType: TextInputType.number,
//                 enabled: !isFullPayment,
//                 decoration: InputDecoration(
//                   hintText: "0.00",
//                   filled: true,
//                   fillColor: Colors.grey.shade50,
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide(color: Colors.grey.shade300),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.teal,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//               ),
//               onPressed: () {
//                 final double? enteredAmount = double.tryParse(amountController.text);
//                 if (enteredAmount == null || enteredAmount <= 0) {
//                   _showSnackBar("Please enter a valid amount.");
//                   return;
//                 }
//                 if (enteredAmount > remainingBalance) {
//                   _showSnackBar("Amount exceeds remaining balance.");
//                   return;
//                 }
//                 Navigator.pop(context);
//                 sendPayment(courseFee['feeId'], enteredAmount);
//               },
//               child: const Text("Confirm Payment", style: TextStyle(color: Colors.white)),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     Map<String, dynamic>? currentStudent;
//     if (childrenList.isNotEmpty) {
//       currentStudent = childrenList.firstWhere(
//         (child) => child['studentId'] == selectedStudentId,
//         orElse: () => childrenList[0],
//       );
//     }

//     final double totalFamilyFee = (feeData['totalFee'] ?? 0).toDouble();
//     final double totalFamilyPaid = (feeData['totalPaid'] ?? 0).toDouble();
//     final double totalFamilyRemaining = (feeData['totalRemaining'] ?? 0).toDouble();

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
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator(color: Colors.teal))
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     "Family Statement",
//                     style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
//                   ),
//                   const SizedBox(height: 16),

//                   // Overall Statement Dark Card
//                   Container(
//                     padding: const EdgeInsets.all(20),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF1E2430),
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text(
//                               "OVERALL STATEMENT",
//                               style: TextStyle(fontSize: 11, color: Colors.grey, letterSpacing: 1),
//                             ),
//                             Container(
//                               padding: const EdgeInsets.all(8),
//                               decoration: BoxDecoration(
//                                 color: Colors.white.withOpacity(0.1),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 18),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 4),
//                         const Text(
//                           "Total Family Balance",
//                           style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           "Rs. ${totalFamilyRemaining.toStringAsFixed(0)}",
//                           style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
//                         ),
//                         const Padding(
//                           padding: EdgeInsets.symmetric(vertical: 16.0),
//                           child: Divider(color: Colors.white24, height: 1),
//                         ),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text("Paid", style: TextStyle(fontSize: 12, color: Colors.grey)),
//                                 const SizedBox(height: 2),
//                                 Text(
//                                   "Rs. ${totalFamilyPaid.toStringAsFixed(0)}",
//                                   style: const TextStyle(fontSize: 15, color: Colors.greenAccent, fontWeight: FontWeight.bold),
//                                 ),
//                               ],
//                             ),
//                             Container(height: 30, width: 1, color: Colors.white24),
//                             Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text("Remaining", style: TextStyle(fontSize: 12, color: Colors.grey)),
//                                 const SizedBox(height: 2),
//                                 Text(
//                                   "Rs. ${totalFamilyRemaining.toStringAsFixed(0)}",
//                                   style: const TextStyle(fontSize: 15, color: Colors.redAccent, fontWeight: FontWeight.bold),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 16),
//                         const Center(
//                           child: Text(
//                             "Select a student below to view breakdown",
//                             style: TextStyle(fontSize: 11, color: Colors.grey),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 20),

//                   // Modern Horizontal Student Selector Chips
//                   const Text(
//                     "Select Student",
//                     style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
//                   ),
//                   const SizedBox(height: 10),
//                   SizedBox(
//                     height: 50,
//                     child: ListView.builder(
//                       scrollDirection: Axis.horizontal,
//                       itemCount: childrenList.length,
//                       itemBuilder: (context, index) {
//                         final child = childrenList[index];
//                         final bool isSelected = child['studentId'] == selectedStudentId;
//                         return Padding(
//                           padding: const EdgeInsets.only(right: 10.0),
//                           child: ChoiceChip(
//                             label: Text(child['studentName'] ?? 'Student'),
//                             selected: isSelected,
//                             selectedColor: Colors.teal,
//                             backgroundColor: Colors.white,
//                             labelStyle: TextStyle(
//                               color: isSelected ? Colors.white : Colors.black87,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 13,
//                             ),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(25),
//                               side: BorderSide(
//                                 color: isSelected ? Colors.teal : Colors.grey.shade300,
//                               ),
//                             ),
//                             onSelected: (bool selected) {
//                               setState(() {
//                                 selectedStudentId = child['studentId'];
//                               });
//                             },
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                   const SizedBox(height: 16),

//                   // Selected Student Breakdown Summary Card
//                   if (currentStudent != null) ...[
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(16),
//                         border: Border.all(color: Colors.grey.shade200),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.grey.withOpacity(0.05),
//                             blurRadius: 6,
//                             offset: const Offset(0, 2),
//                           ),
//                         ],
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 "${currentStudent['studentName']}'s Breakdown",
//                                 style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
//                               ),
//                               Container(
//                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                                 decoration: BoxDecoration(
//                                   color: Colors.teal.shade50,
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 child: Text(
//                                   "Fee Overview",
//                                   style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const Padding(
//                             padding: EdgeInsets.symmetric(vertical: 12.0),
//                             child: Divider(height: 1, color: Color(0xFFF0F0F0)),
//                           ),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text("Total", style: TextStyle(fontSize: 11, color: Colors.grey)),
//                                   const SizedBox(height: 2),
//                                   Text(
//                                     "Rs. ${currentStudent['totalFee']}",
//                                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
//                                   ),
//                                 ],
//                               ),
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text("Paid", style: TextStyle(fontSize: 11, color: Colors.grey)),
//                                   const SizedBox(height: 2),
//                                   Text(
//                                     "Rs. ${currentStudent['totalPaid']}",
//                                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
//                                   ),
//                                 ],
//                               ),
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text("Remaining", style: TextStyle(fontSize: 11, color: Colors.grey)),
//                                   const SizedBox(height: 2),
//                                   Text(
//                                     "Rs. ${currentStudent['totalRemaining']}",
//                                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 20),

//                     // Course Breakdown Header
//                     const Text(
//                       "Course Breakdown",
//                       style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
//                     ),
//                     const SizedBox(height: 12),

//                     // Courses list builder
//                     ...(currentStudent['courses'] as List<dynamic>).map((courseFee) {
//                       final bool isPaid = (courseFee['remaining'] ?? 0) <= 0;
//                       return Container(
//                         margin: const EdgeInsets.only(bottom: 16),
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(color: Colors.grey.shade200),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.grey.withOpacity(0.05),
//                               blurRadius: 6,
//                               offset: const Offset(0, 2),
//                             ),
//                           ],
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(
//                                   courseFee['course'] ?? 'Course',
//                                   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
//                                 ),
//                                 Container(
//                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                                   decoration: BoxDecoration(
//                                     color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                   child: Row(
//                                     mainAxisSize: MainAxisSize.min,
//                                     children: [
//                                       Container(
//                                         width: 6,
//                                         height: 6,
//                                         decoration: BoxDecoration(
//                                           shape: BoxShape.circle,
//                                           color: isPaid ? Colors.green : Colors.orange,
//                                         ),
//                                       ),
//                                       const SizedBox(width: 6),
//                                       Text(
//                                         isPaid ? "Paid" : "Pending",
//                                         style: TextStyle(
//                                           fontSize: 11,
//                                           fontWeight: FontWeight.bold,
//                                           color: isPaid ? Colors.green.shade700 : Colors.orange.shade800,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 4),
//                             Row(
//                               children: [
//                                 Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
//                                 const SizedBox(width: 4),
//                                 Text(
//                                   courseFee['tutor'] ?? 'Instructor',
//                                   style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
//                                 ),
//                               ],
//                             ),
//                             const Padding(
//                               padding: EdgeInsets.symmetric(vertical: 12.0),
//                               child: Divider(height: 1, color: Color(0xFFF0F0F0)),
//                             ),
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     const Text("Total", style: TextStyle(fontSize: 10, color: Colors.grey)),
//                                     const SizedBox(height: 2),
//                                     Text("Rs. ${courseFee['totalFee']}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
//                                   ],
//                                 ),
//                                 Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     const Text("Paid", style: TextStyle(fontSize: 10, color: Colors.grey)),
//                                     const SizedBox(height: 2),
//                                     Text("Rs. ${courseFee['paid']}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
//                                   ],
//                                 ),
//                                 Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     const Text("Remaining", style: TextStyle(fontSize: 10, color: Colors.grey)),
//                                     const SizedBox(height: 2),
//                                     Text("Rs. ${courseFee['remaining']}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                             if (!isPaid) ...[
//                               const SizedBox(height: 16),
//                               Row(
//                                 children: [
//                                   Expanded(
//                                     child: ElevatedButton(
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: Colors.teal,
//                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                                       ),
//                                       onPressed: () => _showPaymentDialog(true, currentStudent!, courseFee),
//                                       child: const Text("Pay Full", style: TextStyle(color: Colors.white, fontSize: 12)),
//                                     ),
//                                   ),
//                                   const SizedBox(width: 12),
//                                   Expanded(
//                                     child: OutlinedButton(
//                                       style: OutlinedButton.styleFrom(
//                                         side: const BorderSide(color: Colors.teal),
//                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                                       ),
//                                       onPressed: () => _showPaymentDialog(false, currentStudent!, courseFee),
//                                       child: const Text("Partial Pay", style: TextStyle(color: Colors.teal, fontSize: 12)),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ],
//                         ),
//                       );
//                     }).toList(),
//                   ],
//                 ],
//               ),
//             ),
//     );
//   }
// }