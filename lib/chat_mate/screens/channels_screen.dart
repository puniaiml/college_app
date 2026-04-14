import 'package:flutter/material.dart';
import '../api/apis.dart';
import 'channel_chat_screen.dart';
import 'channel_members_screen.dart';
import '../models/channel.dart';
import '../helper/dialogs.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _descController = TextEditingController();
  final _inviteEmailController = TextEditingController();
  final _createFormKey = GlobalKey<FormState>();
  final _inviteFormKey = GlobalKey<FormState>();
  bool _isCreating = false;
  bool _isInviting = false;
  String _searchQuery = '';

  static const Color primaryDark = Color(0xFF0A1929);
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color accentBlue = Color(0xFF42A5F5);
  static const Color cardDark = Color(0xFF132F4C);
  static const Color surfaceDark = Color(0xFF1A2332);

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _descController.dispose();
    _inviteEmailController.dispose();
    super.dispose();
  }

  String? _validateChannelName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Channel name is required';
    }
    if (value.trim().length < 3) {
      return 'Channel name must be at least 3 characters';
    }
    if (value.trim().length > 50) {
      return 'Channel name must not exceed 50 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9\s\-_]+$').hasMatch(value)) {
      return 'Channel name can only contain letters, numbers, spaces, hyphens and underscores';
    }
    return null;
  }

  String? _validateSubject(String? value) {
    if (value != null && value.trim().length > 100) {
      return 'Subject must not exceed 100 characters';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    if (value != null && value.trim().length > 500) {
      return 'Description must not exceed 500 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  void _showCreateDialog() {
    _nameController.clear();
    _subjectController.clear();
    _descController.clear();
    _createFormKey.currentState?.reset();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _createFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: primaryBlue.withOpacity(0.3), width: 1),
                        ),
                        child: const Icon(Icons.tag_rounded, color: accentBlue, size: 26),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Create New Channel',
                          style: TextStyle(
                            fontSize: 22, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                        onPressed: _isCreating ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _nameController,
                    enabled: !_isCreating,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Channel Name *',
                      labelStyle: TextStyle(color: Colors.grey.shade400),
                      hintText: 'e.g., Product Updates',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: Icon(Icons.label_outline_rounded, color: Colors.grey.shade500),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade700),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade700),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: accentBlue, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      filled: true,
                      fillColor: surfaceDark,
                      counterStyle: TextStyle(color: Colors.grey.shade600),
                    ),
                    validator: _validateChannelName,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 50,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _subjectController,
                    enabled: !_isCreating,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Subject (Optional)',
                      labelStyle: TextStyle(color: Colors.grey.shade400),
                      hintText: 'Brief topic or purpose',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: Icon(Icons.subject_rounded, color: Colors.grey.shade500),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade700),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade700),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: accentBlue, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      filled: true,
                      fillColor: surfaceDark,
                      counterStyle: TextStyle(color: Colors.grey.shade600),
                    ),
                    validator: _validateSubject,
                    maxLength: 100,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _descController,
                    enabled: !_isCreating,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      labelStyle: TextStyle(color: Colors.grey.shade400),
                      hintText: 'What is this channel about?',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: Icon(Icons.description_outlined, color: Colors.grey.shade500),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade700),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade700),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: accentBlue, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      filled: true,
                      fillColor: surfaceDark,
                      alignLabelWithHint: true,
                      counterStyle: TextStyle(color: Colors.grey.shade600),
                    ),
                    validator: _validateDescription,
                    maxLines: 3,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isCreating ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isCreating ? null : _handleCreateChannel,
                        icon: _isCreating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.add_rounded, size: 20),
                        label: Text(
                          _isCreating ? 'Creating...' : 'Create Channel',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreateChannel() async {
    if (!_createFormKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final name = _nameController.text.trim();
      final subject = _subjectController.text.trim();
      final description = _descController.text.trim();

      await APIs.createChannel(name, subject: subject, description: description);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Channel "$name" created successfully')),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to create: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showInviteDialog(String channelId, String channelName) {
    _inviteEmailController.clear();
    _inviteFormKey.currentState?.reset();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _inviteFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
                      ),
                      child: const Icon(Icons.person_add_rounded, color: Colors.greenAccent, size: 26),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Invite Member',
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                      onPressed: _isInviting ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryBlue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 20, color: accentBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Inviting to: $channelName',
                          style: const TextStyle(fontSize: 14, color: accentBlue, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _inviteEmailController,
                  enabled: !_isInviting,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Email Address *',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    hintText: 'user@example.com',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: accentBlue, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    filled: true,
                    fillColor: surfaceDark,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isInviting ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isInviting ? null : () => _handleInviteUser(channelId),
                      icon: _isInviting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                      label: Text(
                        _isInviting ? 'Sending...' : 'Send Invite',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleInviteUser(String channelId) async {
    if (!_inviteFormKey.currentState!.validate()) return;

    setState(() => _isInviting = true);

    try {
      final email = _inviteEmailController.text.trim();
      await APIs.inviteUserToChannel(channelId, email);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Invitation sent to $email')),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to invite: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _handleJoinChannel(String channelId) async {
    try {
      await APIs.joinChannel(channelId);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(child: Text('Successfully joined the channel')),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to join: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  List<dynamic> _filterChannels(List<dynamic> docs) {
    if (_searchQuery.isEmpty) return docs;
    
    return docs.where((doc) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      final channel = Channel.fromJson(data);
      final query = _searchQuery.toLowerCase();
      
      return channel.name.toLowerCase().contains(query) ||
            channel.subject.toLowerCase().contains(query) ||
            channel.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        title: const Text(
          'Channels',
          style: TextStyle(
            color: Colors.white, 
            fontSize: 22, 
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: accentBlue, size: 26),
            onPressed: _showCreateDialog,
            tooltip: 'Create Channel',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: cardDark,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search channels...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: Colors.grey.shade400),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: APIs.getChannelsStream(),
              builder: (context, AsyncSnapshot snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Error loading channels',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            snapshot.error.toString(),
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: accentBlue,
                      strokeWidth: 3,
                    ),
                  );
                }

                final allDocs = snapshot.data.docs;
                final filteredDocs = _filterChannels(allDocs);

                if (allDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: surfaceDark,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.forum_outlined, size: 80, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No channels yet',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first channel to get started',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton.icon(
                          onPressed: _showCreateDialog,
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('Create Channel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: surfaceDark,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No channels found',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No results for "$_searchQuery"',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: isTablet ? 16 : 8),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = Map<String, dynamic>.from(filteredDocs[index].data() as Map);
                    final channel = Channel.fromJson(data);
                    final members = List<String>.from(data['members'] ?? []);
                    final isMember = members.contains(APIs.user.uid);
                    final isCreator = channel.createdBy == APIs.user.uid;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isMember 
                              ? primaryBlue.withOpacity(0.3)
                              : Colors.white.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 20 : 16,
                          vertical: 12,
                        ),
                        leading: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isMember 
                                ? primaryBlue.withOpacity(0.15) 
                                : surfaceDark,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isMember 
                                  ? primaryBlue.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            isMember ? Icons.tag_rounded : Icons.tag_outlined,
                            color: isMember ? accentBlue : Colors.grey.shade500,
                            size: 26,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                channel.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700, 
                                  fontSize: 17, 
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isCreator)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                ),
                                child: const Text(
                                  'OWNER',
                                  style: TextStyle(
                                    fontSize: 10, 
                                    color: Colors.amber, 
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            if (isMember && !isCreator)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                                ),
                                child: const Text(
                                  'MEMBER',
                                  style: TextStyle(
                                    fontSize: 10, 
                                    color: Colors.greenAccent, 
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (channel.subject.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                channel.subject,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600, 
                                  fontSize: 14, 
                                  color: Colors.grey.shade300,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (channel.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                channel.description,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.people_rounded, size: 15, color: Colors.grey.shade500),
                                const SizedBox(width: 6),
                                Text(
                                  '${members.length} ${members.length == 1 ? 'member' : 'members'}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: isTablet
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: _buildActionButtons(channel, isMember, isCreator),
                              )
                            : PopupMenuButton(
                                color: cardDark,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400),
                                itemBuilder: (context) => _buildPopupMenuItems(channel, isMember, isCreator),
                              ),
                        onTap: isMember
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ChannelChatScreen(channel: channel)),
                                )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Create', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  List<Widget> _buildActionButtons(Channel channel, bool isMember, bool isCreator) {
    return [
      if (isMember && isCreator) ...[
        Container(
          decoration: BoxDecoration(
            color: surfaceDark,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.group_rounded, size: 20, color: accentBlue),
            tooltip: 'View members',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChannelMembersScreen(channel: channel)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: surfaceDark,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.person_add_rounded, size: 20, color: Colors.greenAccent),
            tooltip: 'Invite members',
            onPressed: () => _showInviteDialog(channel.id, channel.name),
          ),
        ),
        const SizedBox(width: 12),
      ],
      if (isMember)
        ElevatedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChannelChatScreen(channel: channel)),
          ),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          label: const Text('Open', style: TextStyle(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        )
      else
        OutlinedButton.icon(
          onPressed: () => _handleJoinChannel(channel.id),
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('Join', style: TextStyle(fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: accentBlue,
            side: const BorderSide(color: accentBlue, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
    ];
  }

  List<PopupMenuEntry> _buildPopupMenuItems(Channel channel, bool isMember, bool isCreator) {
    return [
      if (isMember) ...[
        PopupMenuItem(
          onTap: () => Future.delayed(
            Duration.zero,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelChatScreen(channel: channel))),
          ),
          child: const Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 20, color: accentBlue),
              SizedBox(width: 12),
              Text('Open Chat', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        if (isCreator) ...[
          PopupMenuItem(
            onTap: () => Future.delayed(
              Duration.zero,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelMembersScreen(channel: channel))),
            ),
            child: const Row(
              children: [
                Icon(Icons.group_rounded, size: 20, color: accentBlue),
                SizedBox(width: 12),
                Text('View Members', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          PopupMenuItem(
            onTap: () => Future.delayed(Duration.zero, () => _showInviteDialog(channel.id, channel.name)),
            child: const Row(
              children: [
                Icon(Icons.person_add_rounded, size: 20, color: Colors.greenAccent),
                SizedBox(width: 12),
                Text('Invite Members', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ] else
        PopupMenuItem(
          onTap: () => Future.delayed(Duration.zero, () => _handleJoinChannel(channel.id)),
          child: const Row(
            children: [
              Icon(Icons.login_rounded, size: 20, color: accentBlue),
              SizedBox(width: 12),
              Text('Join Channel', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
    ];
  }
}