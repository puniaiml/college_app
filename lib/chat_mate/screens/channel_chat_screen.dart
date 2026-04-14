import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../api/apis.dart';
import '../models/channel.dart';
import '../models/message.dart';
import '../widgets/message_card.dart';
import 'assignments_screen.dart';
import 'resources_screen.dart';

class ChannelChatScreen extends StatefulWidget {
  final Channel channel;

  const ChannelChatScreen({super.key, required this.channel});

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  MessageLabel? _selectedLabel;
  bool _isSending = false;
  bool _showScrollToBottom = false;
  bool _hasText = false;
  List<Message> _list = [];
  bool _isFirstLoad = true;

  static const Color primaryDark = Color(0xFF0A1929);
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color accentBlue = Color(0xFF42A5F5);
  static const Color cardDark = Color(0xFF132F4C);
  static const Color surfaceDark = Color(0xFF1A2332);
  static const Color inputBg = Color(0xFF1E3A5F);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });
    _scrollController.addListener(_scrollListener);
    _controller.addListener(_textListener);
  }

  @override
  void dispose() {
    _controller.removeListener(_textListener);
    _scrollController.removeListener(_scrollListener);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final shouldShow = _scrollController.position.pixels > 100;
      if (shouldShow != _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = shouldShow;
        });
      }
    }
  }

  void _textListener() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleDocumentChanges(List<DocumentChange> changes) {
    if (changes.isEmpty || !mounted) return;

    bool needsUpdate = false;
    final updatedList = List<Message>.from(_list);

    for (final change in changes) {
      final data = change.doc.data();
      if (data == null) continue;

      final msg = Message.fromJson(data as Map<String, dynamic>);

      switch (change.type) {
        case DocumentChangeType.added:
          final existingIndex = updatedList.indexWhere((m) => m.sent == msg.sent);
          if (existingIndex == -1) {
            final idx = change.newIndex.clamp(0, updatedList.length);
            updatedList.insert(idx, msg);
            needsUpdate = true;
          }
          break;

        case DocumentChangeType.modified:
          final existingIndex = updatedList.indexWhere((m) => m.sent == msg.sent);
          if (existingIndex != -1) {
            updatedList[existingIndex] = msg;
            needsUpdate = true;
          }
          break;

        case DocumentChangeType.removed:
          final previousLength = updatedList.length;
          updatedList.removeWhere((m) => m.sent == msg.sent);
          if (updatedList.length != previousLength) needsUpdate = true;
          break;
      }
    }

    if (needsUpdate && mounted) {
      setState(() {
        _list = updatedList;
      });
    }
  }

  String? _validateMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Message cannot be empty';
    }
    if (value.trim().isEmpty) {
      return 'Message must contain at least 1 character';
    }
    if (value.trim().length > 5000) {
      return 'Message is too long (max 5000 characters)';
    }
    if (value.trim().replaceAll(RegExp(r'\s+'), '').isEmpty) {
      return 'Message cannot contain only whitespace';
    }
    return null;
  }

  Future<void> _send() async {
    if (!mounted) return;
    
    final txt = _controller.text.trim();
    final validation = _validateMessage(txt);
    
    if (validation != null) {
      _showErrorSnackBar(validation);
      return;
    }

    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      await APIs.sendChannelMessage(
        widget.channel.id,
        txt,
        Type.text,
        messageLabel: _selectedLabel,
      );
      
      if (!mounted) return;
      
      _controller.clear();
      setState(() => _selectedLabel = null);
      
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scrollToBottom();
      });
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to send: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLabelPicker() {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 400;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(isSmall ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmall ? 8 : 10),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.label_rounded, 
                    color: accentBlue, 
                    size: isSmall ? 20 : 22,
                  ),
                ),
                SizedBox(width: isSmall ? 10 : 14),
                Expanded(
                  child: Text(
                    'Select Message Label',
                    style: TextStyle(
                      fontSize: isSmall ? 18 : 20, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: isSmall ? 16 : 20),
            Wrap(
              spacing: isSmall ? 8 : 10,
              runSpacing: isSmall ? 8 : 10,
              children: MessageLabel.values.map((label) {
                final isSelected = _selectedLabel == label;
                return InkWell(
                  onTap: () {
                    setState(() => _selectedLabel = isSelected ? null : label);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmall ? 14 : 16, 
                      vertical: isSmall ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryBlue : surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? accentBlue : Colors.grey.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.check_circle_rounded, 
                              color: Colors.white, 
                              size: isSmall ? 16 : 18,
                            ),
                          ),
                        Text(
                          label.name.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade300,
                            fontWeight: FontWeight.w700,
                            fontSize: isSmall ? 12 : 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_selectedLabel != null) ...[
              SizedBox(height: isSmall ? 12 : 16),
              TextButton.icon(
                onPressed: () {
                  setState(() => _selectedLabel = null);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.redAccent),
                label: const Text(
                  'Clear Label',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showChannelInfo() {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 400;
    
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: size.width > 600 ? 520 : size.width * 0.9,
            maxHeight: size.height * 0.8,
          ),
          padding: EdgeInsets.all(isSmall ? 20 : 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmall ? 12 : 14),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: primaryBlue.withOpacity(0.3), width: 1),
                      ),
                      child: Icon(
                        Icons.info_outline_rounded, 
                        color: accentBlue, 
                        size: isSmall ? 24 : 26,
                      ),
                    ),
                    SizedBox(width: isSmall ? 12 : 16),
                    Expanded(
                      child: Text(
                        widget.channel.name,
                        style: TextStyle(
                          fontSize: isSmall ? 20 : 22, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: isSmall ? 20 : 24),
                if (widget.channel.subject.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.subject_rounded, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Text(
                        'Subject',
                        style: TextStyle(
                          fontSize: 12, 
                          color: Colors.grey.shade500, 
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Text(
                      widget.channel.subject,
                      style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (widget.channel.description.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.description_outlined, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 12, 
                          color: Colors.grey.shade500, 
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Text(
                      widget.channel.description,
                      style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Row(
                  children: [
                    Icon(Icons.people_rounded, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text(
                      'Members',
                      style: TextStyle(
                        fontSize: 12, 
                        color: Colors.grey.shade500, 
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showMembersDialog();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.people_rounded, size: 20, color: accentBlue),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${widget.channel.members.length} ${widget.channel.members.length == 1 ? 'member' : 'members'}',
                          style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade500),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMembersDialog() {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 400;
    
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: size.width > 600 ? 520 : size.width * 0.9,
            maxHeight: size.height * 0.7,
          ),
          padding: EdgeInsets.all(isSmall ? 20 : 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmall ? 12 : 14),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primaryBlue.withOpacity(0.3), width: 1),
                    ),
                    child: Icon(
                      Icons.people_rounded, 
                      color: accentBlue, 
                      size: isSmall ? 24 : 26,
                    ),
                  ),
                  SizedBox(width: isSmall ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Channel Members',
                          style: TextStyle(
                            fontSize: isSmall ? 20 : 22, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '${widget.channel.members.length} ${widget.channel.members.length == 1 ? 'member' : 'members'}',
                          style: TextStyle(
                            fontSize: 13, 
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: isSmall ? 16 : 20),
              Expanded(
                child: widget.channel.members.isEmpty
                    ? Center(
                        child: Text(
                          'No members',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.channel.members.length,
                        itemBuilder: (context, index) {
                          final memberId = widget.channel.members[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(isSmall ? 12 : 14),
                            decoration: BoxDecoration(
                              color: surfaceDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: isSmall ? 20 : 22,
                                  backgroundColor: primaryBlue.withOpacity(0.2),
                                  child: Text(
                                    memberId.isNotEmpty ? memberId[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: accentBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmall ? 16 : 18,
                                    ),
                                  ),
                                ),
                                SizedBox(width: isSmall ? 12 : 14),
                                Expanded(
                                  child: Text(
                                    memberId,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmall ? 14 : 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildDateDivider(String timestamp, String? previousTimestamp) {
    final int ts = int.tryParse(timestamp) ?? 0;
    if (ts == 0) return const SizedBox.shrink();
    
    final DateTime msgTime = DateTime.fromMillisecondsSinceEpoch(ts);
    
    if (previousTimestamp != null) {
      final int prevTs = int.tryParse(previousTimestamp) ?? 0;
      if (prevTs != 0) {
        final DateTime prevTime = DateTime.fromMillisecondsSinceEpoch(prevTs);
        
        if (msgTime.year == prevTime.year &&
            msgTime.month == prevTime.month &&
            msgTime.day == prevTime.day) {
          return const SizedBox.shrink();
        }
      }
    }

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final DateTime msgDay = DateTime(msgTime.year, msgTime.month, msgTime.day);

    String dateText;
    if (msgDay == today) {
      dateText = 'Today';
    } else if (msgDay == yesterday) {
      dateText = 'Yesterday';
    } else if (msgTime.year == now.year) {
      dateText = DateFormat('MMMM dd').format(msgTime);
    } else {
      dateText = DateFormat('MMMM dd, yyyy').format(msgTime);
    }

    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 400;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 12 : 16, 
            vertical: isSmall ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: surfaceDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: isSmall ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isSmall = size.width < 400;

    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: primaryDark,
        appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _showChannelInfo,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(isSmall ? 6 : 8),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tag_rounded, 
                  size: isSmall ? 16 : 18, 
                  color: accentBlue,
                ),
              ),
              SizedBox(width: isSmall ? 8 : 12),
              Flexible(
                child: Text(
                  widget.channel.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmall ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (size.width > 360)
            IconButton(
              icon: const Icon(Icons.people_outline_rounded, color: accentBlue),
              tooltip: 'View Members',
              onPressed: _showMembersDialog,
            ),
          PopupMenuButton(
            color: cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade300),
            itemBuilder: (context) => [
              if (size.width <= 360)
                PopupMenuItem(
                  onTap: () {
                    Future.delayed(Duration.zero, _showMembersDialog);
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.people_rounded, size: 20, color: accentBlue),
                      SizedBox(width: 12),
                      Text('Members', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              PopupMenuItem(
                onTap: () {
                  Future.delayed(
                    Duration.zero,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AssignmentsScreen(channel: widget.channel)),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.assignment_rounded, size: 20, color: accentBlue),
                    SizedBox(width: 12),
                    Text('Assignments', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () {
                  Future.delayed(
                    Duration.zero,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ResourcesScreen(channel: widget.channel)),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.library_books_rounded, size: 20, color: accentBlue),
                    SizedBox(width: 12),
                    Text('Resources', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: _showChannelInfo,
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20, color: accentBlue),
                    SizedBox(width: 12),
                    Text('Channel Info', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(width: isSmall ? 2 : 4),
        ],
      ),
      body: Column(
        children: [
          if (_selectedLabel != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 12 : 16, 
                vertical: isSmall ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.12),
                border: Border(
                  bottom: BorderSide(color: primaryBlue.withOpacity(0.25), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.label_rounded, 
                      size: isSmall ? 14 : 15, 
                      color: accentBlue,
                    ),
                  ),
                  SizedBox(width: isSmall ? 8 : 10),
                  Text(
                    'Label: ${_selectedLabel!.name.toUpperCase()}',
                    style: TextStyle(
                      color: accentBlue, 
                      fontWeight: FontWeight.w700,
                      fontSize: isSmall ? 11.5 : 12.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => setState(() => _selectedLabel = null),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded, 
                        size: isSmall ? 15 : 16, 
                        color: accentBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: APIs.getChannelMessages(widget.channel.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _isFirstLoad) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: accentBlue,
                      strokeWidth: 2.5,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(isSmall ? 24 : 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(isSmall ? 16 : 18),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.error_outline_rounded, 
                              size: isSmall ? 40 : 48, 
                              color: Colors.redAccent,
                            ),
                          ),
                          SizedBox(height: isSmall ? 12 : 16),
                          Text(
                            'Failed to load messages',
                            style: TextStyle(
                              fontSize: isSmall ? 16 : 17, 
                              fontWeight: FontWeight.w600, 
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: isSmall ? 6 : 8),
                          Text(
                            'Please check your connection',
                            style: TextStyle(
                              fontSize: isSmall ? 12 : 13, 
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final qs = snapshot.data;

                if (qs == null || qs.docs.isEmpty) {
                  if (_list.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _list.clear());
                    });
                  }
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSmall ? 18 : 20),
                          decoration: BoxDecoration(
                            color: surfaceDark,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded, 
                            size: isSmall ? 56 : 64, 
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: isSmall ? 12 : 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: isSmall ? 16 : 18, 
                            fontWeight: FontWeight.w600, 
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: isSmall ? 4 : 6),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            fontSize: isSmall ? 12.5 : 13.5, 
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (_isFirstLoad) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _list = qs.docs
                            .map((e) => Message.fromJson(e.data()))
                            .toList();
                        _isFirstLoad = false;
                      });
                    }
                  });
                  return const Center(
                    child: CircularProgressIndicator(
                      color: accentBlue,
                      strokeWidth: 2.5,
                    ),
                  );
                }

                if (qs.docChanges.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _handleDocumentChanges(qs.docChanges);
                  });
                }

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        left: isTablet ? 24 : (isSmall ? 8 : 12),
                        right: isTablet ? 24 : (isSmall ? 8 : 12),
                        top: isSmall ? 8 : 12,
                        bottom: isSmall ? 8 : 12,
                      ),
                      itemCount: _list.length,
                      itemBuilder: (context, index) {
                        final msg = _list[index];
                        final previousTimestamp = index < _list.length - 1 
                            ? _list[index + 1].sent 
                            : null;
                        
                        return Column(
                          key: ValueKey(msg.sent),
                          children: [
                            _buildDateDivider(msg.sent, previousTimestamp),
                            MessageCard(message: msg),
                          ],
                        );
                      },
                    ),
                    if (_showScrollToBottom)
                      Positioned(
                        bottom: isSmall ? 12 : 16,
                        right: isSmall ? 12 : 16,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [primaryBlue, accentBlue],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _scrollToBottom,
                              customBorder: const CircleBorder(),
                              child: Container(
                                padding: EdgeInsets.all(isSmall ? 10 : 12),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded, 
                                  color: Colors.white, 
                                  size: isSmall ? 22 : 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cardDark,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: isTablet ? 20 : (isSmall ? 10 : 14),
              right: isTablet ? 20 : (isSmall ? 10 : 14),
              top: isSmall ? 8 : 10,
              bottom: isSmall ? 8 : 10,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _selectedLabel != null 
                          ? primaryBlue.withOpacity(0.15)
                          : surfaceDark,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedLabel != null
                            ? primaryBlue.withOpacity(0.4)
                            : Colors.grey.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isSending ? null : _showLabelPicker,
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: EdgeInsets.all(isSmall ? 9 : 11),
                          child: Icon(
                            _selectedLabel != null 
                                ? Icons.label_rounded 
                                : Icons.label_outline_rounded,
                            color: _selectedLabel != null 
                                ? accentBlue 
                                : Colors.grey.shade400,
                            size: isSmall ? 20 : 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmall ? 8 : 10),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(isSmall ? 24 : 28),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              enabled: !_isSending,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmall ? 14.5 : 15.5,
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type your message...',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: isSmall ? 14 : 15,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.only(
                                  left: isSmall ? 16 : 20,
                                  right: _hasText || _isSending ? (isSmall ? 4 : 6) : (isSmall ? 16 : 20),
                                  top: isSmall ? 12 : 14,
                                  bottom: isSmall ? 12 : 14,
                                ),
                                counterText: '',
                              ),
                              minLines: 1,
                              maxLines: 5,
                              maxLength: 5000,
                              textCapitalization: TextCapitalization.sentences,
                              onSubmitted: (_) {
                                if (_hasText && !_isSending) {
                                  _send();
                                }
                              },
                            ),
                          ),
                          if (_hasText && !_isSending)
                            Padding(
                              padding: EdgeInsets.only(
                                right: isSmall ? 6 : 8, 
                                bottom: isSmall ? 6 : 8,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [primaryBlue, accentBlue],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentBlue.withOpacity(0.35),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _send,
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      padding: EdgeInsets.all(isSmall ? 9 : 10),
                                      child: Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: isSmall ? 18 : 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_isSending)
                            Padding(
                              padding: EdgeInsets.only(
                                right: isSmall ? 14 : 16, 
                                bottom: isSmall ? 14 : 16,
                              ),
                              child: SizedBox(
                                width: isSmall ? 18 : 20,
                                height: isSmall ? 18 : 20,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: accentBlue,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      )],
        ),
      ),
    );
  }
}