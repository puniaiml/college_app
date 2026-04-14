import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api/apis.dart';
import '../models/channel.dart';
import '../models/assignment.dart';
import '../helper/dialogs.dart';

class AssignmentsScreen extends StatefulWidget {
  final Channel channel;

  const AssignmentsScreen({required this.channel, super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    _titleController.clear();
    _descController.clear();
    _selectedDate = null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Assignment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g., Project Submission'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description', hintText: 'Assignment details'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Due Date: ${_selectedDate != null ? _selectedDate!.toString().split(' ')[0] : 'Not set'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _selectedDate = date);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = _titleController.text.trim();
                if (title.isEmpty || _selectedDate == null) {
                  Dialogs.showSnackbar(context, 'Please fill all fields');
                  return;
                }
                final dateStr = _selectedDate!.toString().split(' ')[0];
                await APIs.createAssignment(widget.channel.id, title, _descController.text.trim(), dateStr);
                if (mounted) {
                  Navigator.pop(context);
                  Dialogs.showSnackbar(context, 'Assignment created!');
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  bool _isOverdue(String dueDate) {
    try {
      final due = DateTime.parse(dueDate);
      return due.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreator = widget.channel.createdBy == APIs.user.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.channel.name} - Assignments'),
      ),
      body: StreamBuilder(
        stream: APIs.getChannelAssignments(widget.channel.id),
        builder: (context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No assignments yet',
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = Map<String, dynamic>.from(docs[index].data() as Map);
              final assignment = Assignment.fromJson(data);
              final isOverdue = _isOverdue(assignment.dueDate);

              return Container(
                decoration: BoxDecoration(
                  color: assignment.isCompleted
                      ? Colors.green[50]
                      : (isOverdue ? Colors.red[50] : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: assignment.isCompleted
                        ? Colors.green[200]!
                        : (isOverdue ? Colors.red[200]! : Colors.grey[300]!),
                    width: 1.5,
                  ),
                ),
                child: ListTile(
                  leading: Checkbox(
                    value: assignment.isCompleted,
                    onChanged: (val) async {
                      await APIs.toggleAssignmentCompletion(
                          widget.channel.id, assignment.id, val ?? false);
                    },
                  ),
                  title: Text(
                    assignment.title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: assignment.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        assignment.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: isOverdue ? Colors.red : Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Due: ${_formatDate(assignment.dueDate)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isOverdue ? Colors.red : Colors.blue,
                              fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          if (isOverdue && !assignment.isCompleted)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'OVERDUE',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  trailing: isCreator
                      ? IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await APIs.deleteAssignment(widget.channel.id, assignment.id);
                            if (mounted) Dialogs.showSnackbar(context, 'Assignment deleted');
                          },
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isCreator
          ? FloatingActionButton(
              onPressed: _showCreateDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
