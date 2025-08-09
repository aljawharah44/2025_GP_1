import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './settings.dart';
import './home_page.dart';
import './sos_screen.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  int _selectedHour = 12;
  int _selectedMinute = 0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ReminderItem> reminders = [];
  bool isLoading = true;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _selectedFrequency = 'One time';
  String _selectedTimeFormat = 'AM';
  String? _editingReminderId;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  // Load reminders from Firestore
  Future<void> _loadReminders() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final querySnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('reminders')
            .orderBy('date')
            .get();

        setState(() {
          reminders = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return ReminderItem(
              id: doc.id,
              title: data['title'] ?? '',
              time: data['time'] ?? '',
              date: (data['date'] as Timestamp).toDate(),
              note: data['note'] ?? '',
              frequency: data['frequency'] ?? 'One time',
            );
          }).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading reminders: $e');
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Failed to load reminders');
    }
  }

  // Save reminder to Firestore
  Future<void> _saveReminderToFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      final parts = _dateController.text.split('/');
      final date = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );

      final reminderData = {
        'title': _titleController.text,
        'time': _timeController.text,
        'date': Timestamp.fromDate(date),
        'note': _noteController.text,
        'frequency': _selectedFrequency,
        'created_at': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .add(reminderData);

      // Add to local list
      setState(() {
        reminders.add(
          ReminderItem(
            id: docRef.id,
            title: _titleController.text,
            time: _timeController.text,
            date: date,
            note: _noteController.text,
            frequency: _selectedFrequency,
          ),
        );
        // Sort reminders by date
        reminders.sort((a, b) => a.date.compareTo(b.date));
      });

      _showSuccessSnackBar('Reminder saved successfully');
    } catch (e) {
      print('Error saving reminder: $e');
      _showErrorSnackBar('Failed to save reminder');
    }
  }

  // Update reminder in Firestore
  Future<void> _updateReminderInFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null || _editingReminderId == null) {
        _showErrorSnackBar('User not authenticated or no reminder selected');
        return;
      }

      final parts = _dateController.text.split('/');
      final date = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );

      final reminderData = {
        'title': _titleController.text,
        'time': _timeController.text,
        'date': Timestamp.fromDate(date),
        'note': _noteController.text,
        'frequency': _selectedFrequency,
        'updated_at': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .doc(_editingReminderId)
          .update(reminderData);

      // Update local list
      setState(() {
        final index = reminders.indexWhere((r) => r.id == _editingReminderId);
        if (index != -1) {
          reminders[index] = ReminderItem(
            id: _editingReminderId!,
            title: _titleController.text,
            time: _timeController.text,
            date: date,
            note: _noteController.text,
            frequency: _selectedFrequency,
          );
          // Sort reminders by date
          reminders.sort((a, b) => a.date.compareTo(b.date));
        }
      });

      _showSuccessSnackBar('Reminder updated successfully');
    } catch (e) {
      print('Error updating reminder: $e');
      _showErrorSnackBar('Failed to update reminder');
    }
  }

  // Delete reminder from Firestore
  Future<void> _deleteReminderFromFirestore(String reminderId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .doc(reminderId)
          .delete();

      // Remove from local list
      setState(() {
        reminders.removeWhere((reminder) => reminder.id == reminderId);
      });

      _showSuccessSnackBar('Reminder deleted successfully');
    } catch (e) {
      print('Error deleting reminder: $e');
      _showErrorSnackBar('Failed to delete reminder');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFF44336),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF6B1D73);
    const lightPurple = Color(0xFFB14ABA);

    // Separate today's reminders from others
    final todayReminders = reminders
        .where((reminder) => _isToday(reminder.date))
        .toList();
    final otherReminders = reminders
        .where((reminder) => !_isToday(reminder.date))
        .toList();

    return Scaffold(
      backgroundColor: purple,
      appBar: AppBar(
        backgroundColor: purple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reminders',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Purple background space
          Container(
            height: todayReminders.isNotEmpty ? 120 : 20,
            color: purple,
          ),
          // Today's reminders floating between purple and white
          if (todayReminders.isNotEmpty) ...[
            Transform.translate(
              offset: const Offset(0, -60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: todayReminders.map((reminder) {
                    final index = reminders.indexOf(reminder);
                    return _buildFloatingTodayCard(
                      reminder,
                      lightPurple,
                      index,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          // White container for other reminders
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFB14ABA),
                      ),
                    )
                  : reminders.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadReminders,
                      color: const Color(0xFFB14ABA),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(
                          top: 20,
                          left: 20,
                          right: 20,
                          bottom: 20,
                        ),
                        itemCount: otherReminders.length,
                        itemBuilder: (context, index) {
                          final reminder = otherReminders[index];
                          final originalIndex = reminders.indexOf(reminder);
                          return _buildRegularReminderCard(
                            reminder,
                            lightPurple,
                            originalIndex,
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Home
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.home_outlined,
                        size: 26,
                        color: Colors.black54,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Home',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                // Reminders (highlighted since we're on this page)
                GestureDetector(
                  onTap: () {
                    // Already on reminders page
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 26,
                        color: const Color(0xFFB14ABA),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Reminders',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFB14ABA),
                        ),
                      ),
                    ],
                  ),
                ),
                // Spacer for the center button
                const SizedBox(width: 55),
                // Emergency
                // Emergency
                GestureDetector(
                  onTap: () {
                    final user = _auth.currentUser;
                    final userName = user?.displayName ?? user?.email ?? 'User';

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SosScreen(userName: userName),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        size: 26,
                        color: Colors.black54,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Emergency',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                // Settings
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings, size: 26, color: Colors.black54),
                      const SizedBox(height: 2),
                      const Text(
                        'Settings',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Elevated black circular button
          Positioned(
            bottom: 25,
            child: GestureDetector(
              onTap: () {
                _showAddReminderDialog(context);
              },
              child: Container(
                width: 55,
                height: 55,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            'No reminders have been set yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap the + button to add your first reminder',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _showAddReminderDialog(BuildContext context) {
    // Clear the form when opening the dialog for new reminder
    if (_editingReminderId == null) {
      _clearForm();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 40,
              ),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fixed header
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 24),
                          Text(
                            _editingReminderId != null
                                ? "Edit Reminder"
                                : "Add Reminder",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B1D73),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _clearForm();
                              Navigator.pop(context);
                            },
                            child: const Icon(
                              Icons.close,
                              color: Color(0xFF6B1D73),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Scrollable content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFormField(
                              'Task Title*',
                              _titleController,
                              'Enter task title',
                            ),
                            const SizedBox(height: 20),
                            _buildDateField(setDialogState),
                            const SizedBox(height: 20),
                            _buildImprovedTimeField(setDialogState),
                            const SizedBox(height: 20),
                            _buildFormField(
                              'Note (optional)',
                              _noteController,
                              'Add a note...',
                              maxLines: 3,
                            ),
                            const SizedBox(height: 20),
                            _buildFrequencyField(setDialogState),
                            const SizedBox(height: 30),
                            _buildActionButtons(context, setDialogState),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTimePickerDialog(BuildContext context, StateSetter setDialogState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setTimeDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Select Time',
                style: TextStyle(
                  color: Color(0xFF6B1D73),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              content: Container(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Hour Dropdown
                        Column(
                          children: [
                            const Text(
                              'Hour',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFB14ABA),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<int>(
                                value: _selectedHour,
                                underline: const SizedBox(),
                                items: List.generate(12, (index) {
                                  int hour = index == 0 ? 12 : index;
                                  return DropdownMenuItem(
                                    value: hour,
                                    child: Text(
                                      hour.toString().padLeft(2, '0'),
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  );
                                }),
                                onChanged: (value) {
                                  setTimeDialogState(() {
                                    _selectedHour = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        // Minute Dropdown
                        Column(
                          children: [
                            const Text(
                              'Minute',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFB14ABA),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<int>(
                                value: _selectedMinute,
                                underline: const SizedBox(),
                                items: List.generate(60, (index) {
                                  return DropdownMenuItem(
                                    value: index,
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  );
                                }),
                                onChanged: (value) {
                                  setTimeDialogState(() {
                                    _selectedMinute = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        // AM/PM Dropdown
                        Column(
                          children: [
                            const Text(
                              'Period',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFB14ABA),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedTimeFormat,
                                underline: const SizedBox(),
                                items: ['AM', 'PM'].map((period) {
                                  return DropdownMenuItem(
                                    value: period,
                                    child: Text(
                                      period,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setTimeDialogState(() {
                                    _selectedTimeFormat = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Selected time display
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB14ABA).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')} $_selectedTimeFormat',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B1D73),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    final timeString =
                        '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')} $_selectedTimeFormat';
                    setDialogState(() {
                      _timeController.text = timeString;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B1D73),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB14ABA),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFB14ABA)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reminder Date*',
          style: TextStyle(
            color: Color(0xFFB14ABA),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _dateController,
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'Select date',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setDialogState(() {
                _dateController.text = '${date.day}/${date.month}/${date.year}';
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildImprovedTimeField(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reminder Time*',
          style: TextStyle(
            color: Color(0xFFB14ABA),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            _showTimePickerDialog(context, setDialogState);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _timeController.text.isEmpty
                      ? 'Select time'
                      : _timeController.text,
                  style: TextStyle(
                    fontSize: 16,
                    color: _timeController.text.isEmpty
                        ? Colors.grey.shade400
                        : Colors.black,
                  ),
                ),
                const Icon(Icons.access_time, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencyField(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reminder Frequency*',
          style: TextStyle(
            color: Color(0xFFB14ABA),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          children: [
            _buildFrequencyOption('One time', setDialogState),
            _buildFrequencyOption('Weekly', setDialogState),
            _buildFrequencyOption('Daily', setDialogState),
            _buildFrequencyOption('Custom', setDialogState),
          ],
        ),
      ],
    );
  }

  Widget _buildFrequencyOption(String option, StateSetter setDialogState) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: _selectedFrequency == option,
          activeColor: const Color(0xFFB14ABA),
          onChanged: (value) {
            if (value == true) {
              setDialogState(() {
                _selectedFrequency = option;
              });
            }
          },
        ),
        Text(option),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, StateSetter setDialogState) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              if (_titleController.text.isNotEmpty &&
                  _dateController.text.isNotEmpty &&
                  _timeController.text.isNotEmpty) {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(color: Color(0xFFB14ABA)),
                  ),
                );

                if (_editingReminderId != null) {
                  await _updateReminderInFirestore();
                } else {
                  await _saveReminderToFirestore();
                }

                // Close loading dialog
                Navigator.pop(context);
                // Close reminder dialog
                Navigator.pop(context);
                _clearForm();
              } else {
                _showErrorSnackBar('Please fill in all required fields');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB14ABA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              _editingReminderId != null ? 'Update' : 'Save',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              _clearForm();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFB14ABA)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Clear',
              style: TextStyle(
                color: Color(0xFFB14ABA),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _clearForm() {
    _titleController.clear();
    _dateController.clear();
    _timeController.clear();
    _noteController.clear();
    _selectedFrequency = 'One time';
    _selectedTimeFormat = 'AM';
    _selectedHour = 12; // Add this line
    _selectedMinute = 0; // Add this line
    _editingReminderId = null;
  }

  void _deleteReminder(int index) {
    final reminder = reminders[index];

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Delete Reminder'),
          content: Text('Are you sure you want to delete "${reminder.title}"?'),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteReminderFromFirestore(reminder.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B1D73),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
      },
    );
  }

  void _editReminder(int index) {
    final reminder = reminders[index];
    _editingReminderId = reminder.id;
    _titleController.text = reminder.title;
    _dateController.text =
        '${reminder.date.day}/${reminder.date.month}/${reminder.date.year}';
    _timeController.text = reminder.time;
    _noteController.text = reminder.note;
    _selectedFrequency = reminder.frequency;

    _showAddReminderDialog(context);
  }

  Widget _buildFloatingTodayCard(
    ReminderItem reminder,
    Color lightPurple,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB14ABA),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      reminder.time,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (reminder.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    reminder.note,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildFloatingActionButton(
                      'Edit',
                      const Color(0xFFB14ABA),
                      () => _editReminder(index),
                    ),
                    const SizedBox(width: 12),
                    _buildFloatingActionButton(
                      'Delete',
                      const Color(0xFFB14ABA),
                      () => _deleteReminder(index),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFB14ABA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF6B1D73),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    '${reminder.date.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFB14ABA),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _getMonthName(reminder.date.month),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${reminder.date.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(
    String text,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRegularReminderCard(
    ReminderItem reminder,
    Color lightPurple,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B1D73),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${reminder.date.day} ${_getMonthName(reminder.date.month)}, ${reminder.date.year}  ${reminder.time}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFB14ABA),
                    ),
                  ),
                  if (reminder.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      reminder.note,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                _buildActionButton(
                  'Edit',
                  const Color(0xFF6B1D73),
                  () => _editReminder(index),
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  'Delete',
                  const Color(0xFF6B1D73),
                  () => _deleteReminder(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

class ReminderItem {
  final String id;
  final String title;
  final String time;
  final DateTime date;
  final String note;
  final String frequency;

  ReminderItem({
    required this.id,
    required this.title,
    required this.time,
    required this.date,
    this.note = '',
    this.frequency = 'One time',
  });
}
