import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../api/apis.dart';
import '../helper/dialogs.dart';
import '../models/chat_user.dart';
import '../widgets/chat_user_card.dart';
import '../widgets/profile_image.dart';
import '../services/profile_sync_service.dart';
import '../widgets/dialogs/profile_completion_dialog.dart';
import 'ai_screen.dart';
import 'profile_screen.dart';
import 'channels_screen.dart';

class ChatMateHomeScreen extends StatefulWidget {
  const ChatMateHomeScreen({super.key});

  @override
  State<ChatMateHomeScreen> createState() => _ChatMateHomeScreenState();
}

class _ChatMateHomeScreenState extends State<ChatMateHomeScreen>
    with TickerProviderStateMixin {
  List<ChatUser> _list = [];
  final List<ChatUser> _searchList = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    APIs.getSelfInfo();

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    );
    _fabAnimationController.forward();

    Future.delayed(const Duration(milliseconds: 500), () {
      _checkProfileCompletion();
    });

    SystemChannels.lifecycle.setMessageHandler((message) {
      log('Message: $message');

      if (APIs.auth.currentUser != null) {
        if (message.toString().contains('resume')) {
          APIs.updateActiveStatus(true);
        }
        if (message.toString().contains('pause')) {
          APIs.updateActiveStatus(false);
        }
      }

      return Future.value(message);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: FocusScope.of(context).unfocus,
      child: WillPopScope(
        onWillPop: () async {
          if (_isSearching) {
            setState(() {
              _isSearching = false;
              _searchController.clear();
              _searchList.clear();
            });
            return false;
          }

          if (Navigator.canPop(context)) {
            return true;
          }

          return false;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF0F3F8),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: _buildAppBar(),
          ),
          floatingActionButton: AnimatedBuilder(
            animation: _fabAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _fabAnimation.value,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C5CE7).withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AiScreen()),
                        );
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(12),
                        child: Lottie.asset('assets/lottie/ai.json'),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          body: Column(
            children: [
              if (_isSearching) _buildSearchBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(user: APIs.me),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: ProfileImage(size: 36),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ChatMate',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stay connected',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              _buildAppBarButton(
                icon: _isSearching
                    ? CupertinoIcons.xmark_circle_fill
                    : CupertinoIcons.search,
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _searchList.clear();
                    }
                  });
                },
              ),
              const SizedBox(width: 10),
              _buildAppBarButton(
                icon: CupertinoIcons.ellipsis_vertical,
                onPressed: _showMenuOptions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: const Color(0xFF2D3436),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search by name or email...',
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFFB2BEC3),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: const Icon(
              CupertinoIcons.search,
              color: Color(0xFF667EEA),
              size: 22,
            ),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: Color(0xFFDFE6E9),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchList.clear();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: const Color(0xFFF8F9FD),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
        onChanged: (val) {
          _searchList.clear();
          val = val.toLowerCase();

          for (var i in _list) {
            if (i.name.toLowerCase().contains(val) ||
                i.email.toLowerCase().contains(val)) {
              _searchList.add(i);
            }
          }
          setState(() {});
        },
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 300))
        .slideY(begin: -0.3, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildBody() {
    return StreamBuilder(
      stream: APIs.getMyUsersId(),
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
          case ConnectionState.none:
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loading conversations...',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFF636E72),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );

          case ConnectionState.active:
          case ConnectionState.done:
            final ids = snapshot.data?.docs.map((e) => e.id).toList() ?? [];
            return StreamBuilder<List<ChatUser>>(
              stream: APIs.getUsersByIds(ids),
              builder: (context, snapshot) {
                final data = snapshot.data ?? [];
                _list = data;

                if (_list.isNotEmpty) {
                  final displayList = _isSearching ? _searchList : _list;

                  if (_isSearching &&
                      _searchList.isEmpty &&
                      _searchController.text.isNotEmpty) {
                    return _buildEmptyState(
                      icon: CupertinoIcons.search,
                      title: 'No results found',
                      subtitle: 'Try searching with a different keyword',
                      gradient: const [Color(0xFFFEAC5E), Color(0xFFC779D0)],
                    );
                  }

                  return ListView.builder(
                    itemCount: displayList.length,
                    padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * .01),
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final currentUser = displayList[index];
                      log('Building card for user: ${currentUser.name} (${currentUser.id})');
                      return ChatUserCard(
                        key: ValueKey(currentUser.id),
                        user: currentUser,
                        onLongPress: () {
                          log('Long pressed user: ${currentUser.name} (${currentUser.id})');
                          _showChatUserOptions(currentUser);
                        },
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 50 * (index % 10)),
                            duration: const Duration(milliseconds: 400),
                          )
                          .slideX(
                              begin: 0.15, end: 0, curve: Curves.easeOutCubic);
                    },
                  );
                } else {
                  return _buildEmptyState(
                    icon: CupertinoIcons.chat_bubble_2_fill,
                    title: 'No Connections Yet',
                    subtitle: 'Start by adding users to begin chatting',
                    gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
                  );
                }
              },
            );
        }
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF0F3F8),
            Color(0xFFE8EDF5),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withOpacity(0.3),
                    blurRadius: 32,
                    spreadRadius: 8,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 68,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2D3436),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF636E72),
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: const Duration(milliseconds: 600)).scale(
            delay: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
          ),
    );
  }

  void _showMenuOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1E8ED),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildMenuOption(
                icon: CupertinoIcons.person_circle,
                title: 'Profile',
                subtitle: 'View and edit your profile',
                gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(user: APIs.me),
                    ),
                  );
                },
              ),
              _buildMenuOption(
                icon: Icons.forum,
                title: 'Channels',
                subtitle: 'Browse and join channels',
                gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChannelsScreen()),
                  );
                },
              ),
              _buildMenuOption(
                icon: CupertinoIcons.person_add_solid,
                title: 'Add User',
                subtitle: 'Connect with someone new',
                gradient: const [Color(0xFFFEAC5E), Color(0xFFC779D0)],
                onTap: () {
                  Navigator.pop(context);
                  _addChatUserDialog();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradient[0].withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF636E72),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: Color(0xFFB2BEC3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatUserOptions(ChatUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1E8ED),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE1E8ED),
                          width: 2,
                        ),
                        image: user.image.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(user.image),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: user.image.isEmpty
                          ? const Icon(
                              CupertinoIcons.person_fill,
                              color: Color(0xFFB2BEC3),
                              size: 24,
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name.isNotEmpty ? user.name : 'Unknown User',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2D3436),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF636E72),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, color: Color(0xFFE1E8ED)),
              _buildChatOption(
                icon: CupertinoIcons.trash,
                title: 'Clear Chat History',
                subtitle: 'Delete all messages with this user',
                color: const Color(0xFFFF6B6B),
                onTap: () {
                  Navigator.pop(context);
                  _confirmClearChat(user);
                },
              ),
              _buildChatOption(
                icon: CupertinoIcons.xmark_circle,
                title: 'Remove User',
                subtitle: 'Remove this user from your chat list',
                color: const Color(0xFFEE5A6F),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteUser(user);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildChatOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF636E72),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearChat(ChatUser user) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(0.25),
                blurRadius: 40,
                offset: const Offset(0, 20),
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.trash,
                        color: Color(0xFFFF6B6B),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Clear Chat History?',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D3436),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Text(
                      'All messages with ${user.name.isNotEmpty ? user.name : 'this user'} will be permanently deleted. This action cannot be undone.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFF636E72),
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE1E8ED),
                                width: 1.5,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(dialogContext),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    'Cancel',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF636E72),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFFF6B6B).withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  Navigator.pop(dialogContext);
                                  await _clearChatHistory(user);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    'Clear',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .scale(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: const Duration(milliseconds: 200)),
      ),
    );
  }

  void _confirmDeleteUser(ChatUser user) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEE5A6F).withOpacity(0.25),
                blurRadius: 40,
                offset: const Offset(0, 20),
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFEE5A6F).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEE5A6F).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.xmark_circle,
                        color: Color(0xFFEE5A6F),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Remove User?',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D3436),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Text(
                      '${user.name.isNotEmpty ? user.name : 'This user'} will be removed from your chat list. All messages will also be deleted.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFF636E72),
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE1E8ED),
                                width: 1.5,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(dialogContext),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    'Cancel',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF636E72),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFEE5A6F),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFEE5A6F).withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  Navigator.pop(dialogContext);
                                  await _deleteChatUser(user);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    'Remove',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .scale(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: const Duration(milliseconds: 200)),
      ),
    );
  }

  Future<void> _clearChatHistory(ChatUser user) async {
    try {
      Dialogs.showLoading(context);
      
      final conversationId = APIs.getConversationID(user.id);
      final messagesRef = APIs.firestore
          .collection('chats/$conversationId/messages');
      
      final snapshot = await messagesRef.get();
      
      if (snapshot.docs.isEmpty) {
        Navigator.pop(context);
        Dialogs.showSnackbar(context, 'No messages to clear');
        return;
      }
      
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      
      await APIs.clearUnreadForConversation(user.id);
      
      Navigator.pop(context);
      Dialogs.showSnackbar(context, 'Chat history cleared successfully');
    } catch (e) {
      Navigator.pop(context);
      log('clearChatHistoryError: $e');
      Dialogs.showSnackbar(context, 'Failed to clear chat history');
    }
  }

  Future<void> _deleteChatUser(ChatUser user) async {
    try {
      Dialogs.showLoading(context);
      
      await _clearChatHistory(user);
      
      await APIs.firestore
          .collection('users')
          .doc(APIs.user.uid)
          .collection('my_users')
          .doc(user.id)
          .delete();
      
      await APIs.firestore
          .collection('users')
          .doc(user.id)
          .collection('my_users')
          .doc(APIs.user.uid)
          .delete();
      
      Navigator.pop(context);
      Dialogs.showSnackbar(context, 'User removed successfully');
    } catch (e) {
      Navigator.pop(context);
      log('deleteChatUserError: $e');
      Dialogs.showSnackbar(context, 'Failed to remove user');
    }
  }

  void _addChatUserDialog() {
    String email = '';
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withOpacity(0.25),
                blurRadius: 40,
                offset: const Offset(0, 20),
                spreadRadius: 5,
              ),
            ],
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.person_add_solid,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New User',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Connect with someone new',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email Address',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF2D3436),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        maxLines: null,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (value) => email = value,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: const Color(0xFF2D3436),
                          fontWeight: FontWeight.w500,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an email address';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          if (value.trim().toLowerCase() ==
                              APIs.user.email?.toLowerCase()) {
                            return 'You cannot add yourself';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'user@example.com',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFFB2BEC3),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Container(
                            padding: const EdgeInsets.all(14),
                            child: const Icon(
                              CupertinoIcons.mail_solid,
                              color: Color(0xFF667EEA),
                              size: 20,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FD),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE1E8ED),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF667EEA),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF6B6B),
                              width: 1.5,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF6B6B),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE1E8ED),
                                  width: 1.5,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.pop(dialogContext),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Text(
                                      'Cancel',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF636E72),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF667EEA),
                                    Color(0xFF764BA2)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF667EEA)
                                        .withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    if (formKey.currentState!.validate()) {
                                      Navigator.pop(dialogContext);
                                      Dialogs.showLoading(context);
                                      try {
                                        final success = await APIs.addChatUser(
                                            email.trim());
                                        Navigator.pop(context);
                                        if (success) {
                                          Dialogs.showSnackbar(
                                            context,
                                            'User added successfully!',
                                          );
                                        } else {
                                          Dialogs.showSnackbar(
                                            context,
                                            'User does not exist or is already added',
                                          );
                                        }
                                      } catch (e) {
                                        Navigator.pop(context);
                                        Dialogs.showSnackbar(
                                          context,
                                          'Failed to add user',
                                        );
                                      }
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Text(
                                      'Add User',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .scale(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: const Duration(milliseconds: 200)),
      ),
    );
  }

  void _checkProfileCompletion() async {
    if (!mounted) return;

    try {
      log('🔄 Attempting profile sync from main app...');
      await ProfileSyncService.syncProfileFromMainApp(APIs.user.uid);
    } catch (e) {
      log('Profile sync error: $e');
    }

    if (APIs.me.isProfileComplete()) {
      log('✅ Profile is complete');
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProfileCompletionDialog(
          user: APIs.me,
          onProfileUpdated: () {
            if (mounted) {
              setState(() {});
            }
          },
        ),
      );
    }
  }
}