import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../api/apis.dart';
import '../models/channel.dart';
import '../models/chat_user.dart';

class ChannelMembersScreen extends StatefulWidget {
  final Channel channel;

  const ChannelMembersScreen({required this.channel, super.key});

  @override
  State<ChannelMembersScreen> createState() => _ChannelMembersScreenState();
}

class _ChannelMembersScreenState extends State<ChannelMembersScreen> {
  late Stream<List<ChatUser>> _membersStream;
  String _searchQuery = '';
  bool _isRemoving = false;

  static const Color primaryDark = Color(0xFF0A1929);
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color accentBlue = Color(0xFF42A5F5);
  static const Color cardDark = Color(0xFF132F4C);
  static const Color surfaceDark = Color(0xFF1A2332);

  @override
  void initState() {
    super.initState();
    _membersStream = APIs.getUsersByIds(widget.channel.members);
  }

  List<ChatUser> _filterMembers(List<ChatUser> members) {
    if (_searchQuery.isEmpty) return members;
    
    final query = _searchQuery.toLowerCase();
    return members.where((member) {
      return member.name.toLowerCase().contains(query) ||
             member.email.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _removeMember(String userId, String userName) async {
    if (_isRemoving) return;
    
    setState(() => _isRemoving = true);

    try {
      await APIs.firestore.collection('channels').doc(widget.channel.id).update({
        'members': FieldValue.arrayRemove([userId])
      });

      widget.channel.members.remove(userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('$userName removed from channel')),
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
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to remove: ${e.toString()}')),
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
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  void _confirmRemoveMember(String userId, String userName) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
                    ),
                    child: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 26),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Remove Member',
                      style: TextStyle(
                        fontSize: 22, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Are you sure you want to remove',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade400, height: 1.5),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryBlue.withOpacity(0.3)),
                ),
                child: Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w600, 
                    color: accentBlue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'from this channel?',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade400, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20, color: Colors.orange.shade300),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'They can rejoin if invited again',
                        style: TextStyle(fontSize: 14, color: Colors.orange.shade200, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isRemoving ? null : () => Navigator.pop(context),
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
                    onPressed: _isRemoving
                        ? null
                        : () {
                            Navigator.pop(context);
                            _removeMember(userId, userName);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: _isRemoving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.person_remove_rounded, size: 20),
                    label: Text(
                      _isRemoving ? 'Removing...' : 'Remove',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberDetails(ChatUser member) {
    final isCurrentUser = member.id == APIs.user.uid;
    final isCreator = widget.channel.createdBy == APIs.user.uid;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryBlue.withOpacity(0.3), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: surfaceDark,
                        backgroundImage: member.image.isNotEmpty ? NetworkImage(member.image) : null,
                        child: member.image.isEmpty
                            ? const Icon(Icons.person_rounded, size: 56, color: accentBlue)
                            : null,
                      ),
                    ),
                    if (member.id == widget.channel.createdBy)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: cardDark, width: 3),
                          ),
                          child: const Icon(Icons.star_rounded, size: 18, color: Colors.black87),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCurrentUser 
                        ? primaryBlue.withOpacity(0.2) 
                        : member.id == widget.channel.createdBy 
                            ? Colors.amber.withOpacity(0.2)
                            : surfaceDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCurrentUser 
                          ? primaryBlue.withOpacity(0.4)
                          : member.id == widget.channel.createdBy
                              ? Colors.amber.withOpacity(0.4)
                              : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    isCurrentUser ? 'You' : (member.id == widget.channel.createdBy ? 'Owner' : 'Member'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isCurrentUser 
                          ? accentBlue 
                          : member.id == widget.channel.createdBy
                              ? Colors.amber
                              : Colors.grey.shade400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surfaceDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.email_rounded, size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Text(
                            'Email Address',
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
                      Text(
                        member.email,
                        style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                      ),
                    ],
                  ),
                ),
                if (member.about.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surfaceDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 8),
                            Text(
                              'About',
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
                        Text(
                          member.about,
                          style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    if (isCreator && !isCurrentUser && member.id != widget.channel.createdBy) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmRemoveMember(member.id, member.name);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.person_remove_rounded, size: 20),
                          label: const Text('Remove', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCreator = widget.channel.createdBy == APIs.user.uid;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.channel.name,
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.people_rounded, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(
                  '${widget.channel.members.length} ${widget.channel.members.length == 1 ? 'member' : 'members'}',
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.w500, 
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: cardDark,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search members...',
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
            child: StreamBuilder<List<ChatUser>>(
              stream: _membersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: accentBlue,
                      strokeWidth: 3,
                    ),
                  );
                }

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
                            'Error loading members',
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

                final allMembers = snapshot.data ?? [];
                final filteredMembers = _filterMembers(allMembers);

                if (allMembers.isEmpty) {
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
                          child: Icon(Icons.group_outlined, size: 80, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No members yet',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Invite people to join this channel',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  );
                }

                if (filteredMembers.isEmpty) {
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
                          'No members found',
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
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: isTablet ? 16 : 0),
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = filteredMembers[index];
                    final isCurrentUser = member.id == APIs.user.uid;
                    final isOwner = member.id == widget.channel.createdBy;

                    return Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12 : 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 20 : 16,
                          vertical: 10,
                        ),
                        leading: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isOwner 
                                      ? Colors.amber.withOpacity(0.4)
                                      : primaryBlue.withOpacity(0.3), 
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: surfaceDark,
                                backgroundImage: member.image.isNotEmpty ? NetworkImage(member.image) : null,
                                child: member.image.isEmpty 
                                    ? Icon(Icons.person_rounded, size: 28, color: Colors.grey.shade500) 
                                    : null,
                              ),
                            ),
                            if (isOwner)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: cardDark, width: 2),
                                  ),
                                  child: const Icon(Icons.star_rounded, size: 12, color: Colors.black87),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                member.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700, 
                                  fontSize: 16, 
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: primaryBlue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: primaryBlue.withOpacity(0.4)),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    fontSize: 10, 
                                    color: accentBlue, 
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                            if (isOwner && !isCurrentUser) ...[
                              const SizedBox(width: 8),
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
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            member.email,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: isCreator && !isCurrentUser && !isOwner
                            ? Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                                  tooltip: 'Remove member',
                                  onPressed: _isRemoving ? null : () => _confirmRemoveMember(member.id, member.name),
                                ),
                              )
                            : const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        onTap: () => _showMemberDetails(member),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}