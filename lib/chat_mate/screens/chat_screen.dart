import 'dart:developer';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:flutter_animate/flutter_animate.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../api/apis.dart';
import '../helper/my_date_util.dart';
import '../models/chat_user.dart';
import '../models/message.dart';
import '../widgets/message_card.dart';
import '../widgets/profile_image.dart';
import '../widgets/focus_badge.dart';
import '../helper/dialogs.dart';
import 'view_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final ChatUser user;

  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  List<Message> _list = [];
  final _textController = TextEditingController();
  bool _showEmoji = false, _isUploading = false;
  MessageLabel? _selectedLabel;
  final Map<String, double> _uploadProgress = {};
  final Map<String, String> _uploadFileNames = {};
  Message? _replyingTo;
  late AnimationController _inputAnimationController;
  late Animation<double> _inputAnimation;
  final FocusNode _textFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  final Map<String, bool> _highlightedMessages = {};
  bool _isFirstLoad = true;

  // Responsive properties
  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _screenHeight => MediaQuery.of(context).size.height;
  bool get _isTablet => _screenWidth > 600;
  bool get _isSmallDevice => _screenWidth < 360;

  double get _appBarHeight => _isTablet ? 80 : 65;
  double get _profileSize => _isTablet ? 50 : 42;
  double get _iconSize => _isSmallDevice ? 20 : (_isTablet ? 24 : 22);
  double get _inputIconSize => _isSmallDevice ? 20 : 22;
  double get _sendButtonSize => _isSmallDevice ? 38 : (_isTablet ? 48 : 44);

  @override
  void initState() {
    super.initState();
    APIs.clearUnreadForConversation(widget.user.id);
    _inputAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _inputAnimation = CurvedAnimation(
      parent: _inputAnimationController,
      curve: Curves.easeInOut,
    );
    _inputAnimationController.forward();

    // Add listener to text controller for proper state updates
    _textController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    APIs.clearUnreadForConversation(widget.user.id);
    _textController.dispose();
    _textFocusNode.dispose();
    _inputAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setReplyMessage(Message message) {
    setState(() {
      _replyingTo = message;
      _showEmoji = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _textFocusNode.requestFocus();
    });
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        if (_showEmoji) setState(() => _showEmoji = false);
      },
      child: WillPopScope(
        onWillPop: () async {
          if (_showEmoji) {
            setState(() => _showEmoji = false);
            return false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF0F3F8),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(_appBarHeight),
            child: _appBar(),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: APIs.getAllMessages(widget.user),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          _isFirstLoad) {
                        return _buildLoadingIndicator();
                      }

                      final qs = snapshot.data;

                      if (qs == null || qs.docs.isEmpty) {
                        if (_list.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _list.clear());
                          });
                        }
                        return _buildEmptyState();
                      }

                      if (_isFirstLoad) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _list = qs.docs
                                  .map((e) => Message.fromJson(
                                      e.data() as Map<String, dynamic>))
                                  .toList();
                              _isFirstLoad = false;
                            });
                          }
                        });
                        return _buildLoadingIndicator();
                      }

                      if (qs.docChanges.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _handleDocumentChanges(qs.docChanges);
                        });
                      }

                      return _buildMessageList();
                    },
                  ),
                ),
                if (_isUploading) _buildUploadProgress(),
                if (_replyingTo != null) _buildReplyPreview(),
                AnimatedBuilder(
                  animation: _inputAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, (1 - _inputAnimation.value) * 50),
                      child: Opacity(
                        opacity: _inputAnimation.value,
                        child: _chatInput(),
                      ),
                    );
                  },
                ),
                if (_showEmoji)
                  SizedBox(
                    height: _screenHeight * .35,
                    child: EmojiPicker(
                      textEditingController: _textController,
                      config: Config(
                        height: _screenHeight * .35,
                        emojiViewConfig: EmojiViewConfig(
                          columns: _isTablet ? 9 : 7,
                          emojiSizeMax: _isTablet ? 32.0 : 28.0,
                          verticalSpacing: 0,
                          horizontalSpacing: 0,
                          gridPadding: EdgeInsets.zero,
                          backgroundColor: const Color(0xFFF2F2F2),
                          noRecents: Text(
                            'No Recents',
                            style: GoogleFonts.inter(
                              fontSize: _isTablet ? 22 : 20,
                              color: Colors.black26,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          loadingIndicator: const SizedBox.shrink(),
                          recentsLimit: 28,
                          replaceEmojiOnLimitExceed: false,
                          buttonMode: ButtonMode.MATERIAL,
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          initCategory: Category.RECENT,
                          indicatorColor: const Color(0xFF667EEA),
                          iconColor: Colors.grey,
                          iconColorSelected: const Color(0xFF667EEA),
                          backspaceColor: const Color(0xFF667EEA),
                          categoryIcons: const CategoryIcons(),
                          tabIndicatorAnimDuration: kTabScrollDuration,
                        ),
                        skinToneConfig: const SkinToneConfig(
                          enabled: true,
                          dialogBackgroundColor: Colors.white,
                          indicatorColor: Colors.grey,
                        ),
                        searchViewConfig: SearchViewConfig(
                          backgroundColor: const Color(0xFFF2F2F2),
                          buttonIconColor: const Color(0xFF667EEA),
                          hintText: 'Search emoji',
                          hintTextStyle: GoogleFonts.inter(
                            color: Colors.grey,
                          ),
                        ),
                        checkPlatformCompatibility: true,
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
          final existingIndex =
              updatedList.indexWhere((m) => m.sent == msg.sent);
          if (existingIndex == -1) {
            final idx = change.newIndex.clamp(0, updatedList.length);
            updatedList.insert(idx, msg);
            needsUpdate = true;
          }
          break;

        case DocumentChangeType.modified:
          final existingIndex =
              updatedList.indexWhere((m) => m.sent == msg.sent);
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

  Widget _buildLoadingIndicator() {
    return Center(
      child: Container(
        width: _isTablet ? 56 : 48,
        height: _isTablet ? 56 : 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: SizedBox(
            width: _isTablet ? 28 : 24,
            height: _isTablet ? 28 : 24,
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 2.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0F3F8), Color(0xFFE8EDF5)],
        ),
      ),
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        itemCount: _list.length,
        padding: EdgeInsets.only(
          top: _screenHeight * .01,
          left: _isTablet ? 20 : 0,
          right: _isTablet ? 20 : 0,
        ),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final msg = _list[index];
          final keyId = msg.sent;
          _messageKeys.putIfAbsent(keyId, () => GlobalKey());
          return MessageCard(
            key: _messageKeys[keyId],
            message: msg,
            onReply: _setReplyMessage,
            onTapReply: _scrollToAndHighlight,
            isHighlighted: _highlightedMessages[msg.sent] == true,
          );
        },
      ),
    );
  }

  Future<void> _scrollToAndHighlight(String repliedTo) async {
    try {
      final key = _messageKeys[repliedTo];
      if (key?.currentContext != null) {
        await Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      } else {
        final idx = _list.indexWhere((m) => m.sent == repliedTo);
        if (idx != -1 && _scrollController.hasClients) {
          _scrollController.animateTo(
            idx * 120.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      }

      if (mounted) {
        setState(() => _highlightedMessages[repliedTo] = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _highlightedMessages.remove(repliedTo));
      }
    } catch (e) {
      log('scrollToAndHighlightError: $e');
    }
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0F3F8), Color(0xFFE8EDF5)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(_isTablet ? 36 : 28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.3),
                    blurRadius: 32,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                Icons.waving_hand_rounded,
                size: _isTablet ? 64 : 52,
                color: Colors.white,
              ),
            ),
            SizedBox(height: _isTablet ? 32 : 24),
            Text(
              'Say Hi! 👋',
              style: GoogleFonts.inter(
                fontSize: _isTablet ? 30 : (_isSmallDevice ? 22 : 26),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2D3436),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start your conversation',
              style: GoogleFonts.inter(
                fontSize: _isTablet ? 18 : (_isSmallDevice ? 14 : 16),
                color: const Color(0xFF636E72),
                fontWeight: FontWeight.w400,
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

  Widget _buildUploadProgress() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _screenWidth * 0.04,
        vertical: 6,
      ),
      constraints: BoxConstraints(
        maxWidth: _isTablet ? 800 : double.infinity,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _isTablet ? 20 : 16,
        vertical: _isTablet ? 14 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _uploadProgress.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                SizedBox(
                  width: _isTablet ? 22 : 18,
                  height: _isTablet ? 22 : 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    value: entry.value,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _uploadFileNames[entry.key] ?? 'File',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: _isTablet ? 14 : 12,
                          color: const Color(0xFF2D3436),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Uploading... ${(entry.value * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: _isTablet ? 12 : 11,
                          color: const Color(0xFF667EEA),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _cancelUpload(entry.key),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.cancel,
                      size: _isTablet ? 20 : 16,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Future<void> _cancelUpload(String key) async {
    try {
      await APIs.cancelUpload(key);
      if (mounted) {
        Dialogs.showSnackbar(context, 'Upload cancelled');
        setState(() {
          _uploadProgress.remove(key);
          _uploadFileNames.remove(key);
          _isUploading = _uploadProgress.isNotEmpty;
        });
      }
    } catch (e) {
      log('Cancel upload error: $e');
    }
  }

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();

    String displayText = '';
    String displayIcon = '';

    switch (_replyingTo!.type) {
      case Type.text:
        displayText = _replyingTo!.msg;
        break;
      case Type.image:
        displayText = 'Photo';
        displayIcon = '🖼️';
        break;
      case Type.file:
        displayText = _replyingTo!.fileName ?? 'File';
        displayIcon = '📎';
        break;
    }

    final bool isMe = _replyingTo!.fromId == APIs.user.uid;
    final String senderName = isMe ? 'You' : widget.user.name.split(' ')[0];

    return Container(
      margin: EdgeInsets.fromLTRB(_screenWidth * 0.04, 6, _screenWidth * 0.04, 4),
      constraints: BoxConstraints(
        maxWidth: _isTablet ? 800 : double.infinity,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF667EEA).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _scrollToAndHighlight(_replyingTo!.sent),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _isTablet ? 14 : 12,
              vertical: _isTablet ? 10 : 8,
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: _isTablet ? 48 : 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.reply_rounded,
                            size: _isTablet ? 15 : 13,
                            color: const Color(0xFF667EEA),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            senderName,
                            style: GoogleFonts.inter(
                              fontSize: _isTablet ? 13 : 11,
                              color: const Color(0xFF667EEA),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (displayIcon.isNotEmpty) ...[
                            Text(displayIcon,
                                style:
                                    TextStyle(fontSize: _isTablet ? 16 : 14)),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              displayText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: _isTablet ? 14 : 12,
                                color: const Color(0xFF636E72),
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _cancelReply,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        size: _isTablet ? 20 : 18,
                        color: const Color(0xFF95A5A6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.3, end: 0);
  }

  Widget _appBar() {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ViewProfileScreen(user: widget.user),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _isTablet ? 12 : 8,
              vertical: _isTablet ? 10 : 8,
            ),
            child: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(_isTablet ? 11 : 9),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: _iconSize - 2,
                        ),
                      ),
                    ),
                  ),
                ),
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ProfileImage(
                        size: _profileSize,
                        url: widget.user.image,
                      ),
                    ),
                    if (widget.user.isOnline)
                      Positioned(
                        bottom: 1,
                        right: 1,
                        child: Container(
                          width: _isTablet ? 14 : 12,
                          height: _isTablet ? 14 : 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E676).withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: _isTablet ? 16 : 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.name, // Using widget.user directly
                        style: GoogleFonts.inter(
                          fontSize: _isTablet ? 19 : (_isSmallDevice ? 15 : 17),
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: _isTablet ? 4 : 2),
                      Text(
                        widget.user.isOnline
                            ? 'Online'
                            : MyDateUtil.getLastActiveTime(
                                context: context,
                                lastActive: widget.user.lastActive,
                              ),
                        style: GoogleFonts.inter(
                          fontSize: _isTablet ? 14 : (_isSmallDevice ? 11 : 12),
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _chatInput() {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(
          vertical: _isTablet ? 10 : 8,
          horizontal: _screenWidth * 0.04,
        ),
        constraints: BoxConstraints(
          maxWidth: _isTablet ? 800 : double.infinity,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFE8EDF5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: _isTablet ? 8 : 6,
                bottom: _isTablet ? 8 : 6,
              ),
              child: _buildModernIconButton(
                icon: _showEmoji
                    ? Icons.keyboard_rounded
                    : Icons.emoji_emotions_outlined,
                color: _showEmoji
                    ? const Color(0xFF667EEA)
                    : const Color(0xFF95A5A6),
                isActive: _showEmoji,
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _showEmoji = !_showEmoji);
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: _isTablet ? 4 : 2,
                bottom: _isTablet ? 8 : 6,
              ),
              child: _buildModernIconButton(
                icon: Icons.label_outline,
                color: _selectedLabel != null
                    ? const Color(0xFF667EEA)
                    : const Color(0xFF95A5A6),
                isActive: _selectedLabel != null,
                tooltip: 'Tag message',
                onPressed: _showLabelPicker,
              ),
            ),
            Expanded(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: _isTablet ? 120 : 100,
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _textFocusNode,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  minLines: 1,
                  onTap: () {
                    if (_showEmoji) setState(() => _showEmoji = false);
                  },
                  style: GoogleFonts.inter(
                    fontSize: _isTablet ? 16 : (_isSmallDevice ? 14 : 15),
                    color: const Color(0xFF2D3436),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: _replyingTo != null
                        ? 'Reply to ${_replyingTo!.fromId == APIs.user.uid ? "yourself" : widget.user.name.split(' ')[0]}...'
                        : 'Message...',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFFB2BEC3),
                      fontSize: _isTablet ? 16 : (_isSmallDevice ? 14 : 15),
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: _isTablet ? 12 : 8,
                      vertical: _isTablet ? 14 : 12,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                right: _isTablet ? 6 : 4,
                bottom: _isTablet ? 6 : 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModernIconButton(
                    icon: Icons.image_outlined,
                    color: const Color(0xFF667EEA),
                    tooltip: 'Photo',
                    onPressed: _handleImagePicker,
                  ),
                  SizedBox(width: _isTablet ? 4 : 2),
                  _buildModernIconButton(
                    icon: Icons.attach_file_rounded,
                    color: const Color(0xFF4A90E2),
                    tooltip: 'File',
                    onPressed: _handleFilePicker,
                  ),
                  SizedBox(width: _isTablet ? 4 : 2),
                  _buildModernIconButton(
                    icon: Icons.camera_alt_outlined,
                    color: const Color(0xFF764BA2),
                    tooltip: 'Camera',
                    onPressed: _handleCamera,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                right: _isTablet ? 6 : 4,
                bottom: _isTablet ? 6 : 4,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _sendButtonSize,
                height: _sendButtonSize,
                decoration: BoxDecoration(
                  gradient: _textController.text.trim().isNotEmpty
                      ? const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: _textController.text.trim().isEmpty
                      ? const Color(0xFFE8EDF5)
                      : null,
                  shape: BoxShape.circle,
                  boxShadow: _textController.text.trim().isNotEmpty
                      ? [
                          BoxShadow(
                            color: const Color(0xFF667EEA).withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _textController.text.trim().isNotEmpty
                        ? _handleSendMessage
                        : null,
                    borderRadius: BorderRadius.circular(50),
                    child: Center(
                      child: Icon(
                        Icons.send_rounded,
                        color: _textController.text.trim().isNotEmpty
                            ? Colors.white
                            : const Color(0xFFB2BEC3),
                        size: _inputIconSize + 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isActive = false,
    String? tooltip,
  }) {
    final double size = _isTablet ? 40 : (_isSmallDevice ? 34 : 36);
    final double iconSize = _isTablet ? 22 : (_isSmallDevice ? 19 : 20);

    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.12) : Colors.transparent,
        shape: BoxShape.circle,
        border: isActive
            ? Border.all(color: color.withOpacity(0.2), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(50),
          splashColor: color.withOpacity(0.2),
          highlightColor: color.withOpacity(0.1),
          child: Center(
            child: Icon(
              icon,
              color: color,
              size: iconSize,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(
        message: tooltip,
        child: button,
      );
    }

    return button;
  }

  Future<void> _handleImagePicker() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(imageQuality: 70);

      if (images.isEmpty) return;

      for (var image in images) {
        await _uploadImage(image);
      }
    } catch (e) {
      log('imagePickerError: $e');
      if (mounted) Dialogs.showSnackbar(context, 'Failed to pick images');
    }
  }

  Future<void> _uploadImage(XFile image) async {
    final fileName = image.path.split(Platform.pathSeparator).last;
    log('Image Path: ${image.path}');

    if (mounted) {
      setState(() {
        _isUploading = true;
        _uploadProgress[image.path] = 0.0;
        _uploadFileNames[image.path] = fileName;
      });
    }

    try {
      await APIs.sendChatImage(
        widget.user,
        File(image.path),
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress[image.path] = p);
        },
        uploadKey: image.path,
      );
    } catch (e) {
      log('Image upload error: $e');
      if (mounted) Dialogs.showSnackbar(context, 'Failed to upload $fileName');
    } finally {
      if (mounted) {
        setState(() {
          _uploadProgress.remove(image.path);
          _uploadFileNames.remove(image.path);
          _isUploading = _uploadProgress.isNotEmpty;
        });
      }
    }
  }

  Future<void> _handleFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return;

      for (final file in result.files) {
        if (file.path == null) continue;
        if (file.size > 50 * 1024 * 1024) {
          if (mounted) {
            Dialogs.showSnackbar(
                context, '${file.name} is too large (max 50MB)');
          }
          continue;
        }
        await _uploadFile(file);
      }
    } catch (e) {
      log('filePickerError: $e');
      if (mounted) Dialogs.showSnackbar(context, 'Failed to pick files');
    }
  }

  Future<void> _uploadFile(PlatformFile file) async {
    final localPath = file.path!;
    final fileName = file.name;

    log('File Path: $localPath, Size: ${file.size} bytes');

    if (mounted) {
      setState(() {
        _isUploading = true;
        _uploadProgress[localPath] = 0.0;
        _uploadFileNames[localPath] = fileName;
      });
    }

    try {
      await APIs.sendFile(
        widget.user,
        File(localPath),
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress[localPath] = p);
        },
        uploadKey: localPath,
      );
    } catch (e) {
      log('File upload error: $e');
      if (mounted) Dialogs.showSnackbar(context, 'Failed to upload $fileName');
    } finally {
      if (mounted) {
        setState(() {
          _uploadProgress.remove(localPath);
          _uploadFileNames.remove(localPath);
          _isUploading = _uploadProgress.isNotEmpty;
        });
      }
    }
  }

  Future<void> _handleCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (image == null) return;

      await _uploadImage(image);
    } catch (e) {
      log('cameraError: $e');
      if (mounted) Dialogs.showSnackbar(context, 'Failed to capture photo');
    }
  }

  void _showLabelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Tag Message',
                style: GoogleFonts.inter(
                  fontSize: _isTablet ? 20 : 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _isTablet ? 24 : 16,
                  vertical: 12,
                ),
                child: Wrap(
                  spacing: _isTablet ? 12 : 10,
                  runSpacing: _isTablet ? 12 : 10,
                  alignment: WrapAlignment.center,
                  children: MessageLabel.values.map((lab) {
                    String title;
                    IconData icon;
                    Color chipColor;

                    switch (lab) {
                      case MessageLabel.reference:
                        title = 'Reference';
                        icon = Icons.link;
                        chipColor = const Color(0xFF4A90E2);
                        break;
                      case MessageLabel.question:
                        title = 'Question';
                        icon = Icons.help_outline;
                        chipColor = const Color(0xFFFF6B6B);
                        break;
                      case MessageLabel.explanation:
                        title = 'Explanation';
                        icon = Icons.lightbulb_outline;
                        chipColor = const Color(0xFFFFA726);
                        break;
                      case MessageLabel.summary:
                        title = 'Summary';
                        icon = Icons.article_outlined;
                        chipColor = const Color(0xFF667EEA);
                        break;
                      case MessageLabel.spoiler:
                        title = 'Spoiler';
                        icon = Icons.warning_amber_outlined;
                        chipColor = const Color(0xFF9C27B0);
                        break;
                    }

                    final active = _selectedLabel == lab;

                    return Material(
                      color: active
                          ? chipColor.withOpacity(0.15)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedLabel = _selectedLabel == lab ? null : lab;
                          });
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: _isTablet ? 18 : 14,
                            vertical: _isTablet ? 12 : 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: active
                                  ? chipColor
                                  : Colors.grey[300]!,
                              width: active ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: _isTablet ? 20 : 18,
                                color: active ? chipColor : Colors.grey[600],
                              ),
                              SizedBox(width: _isTablet ? 8 : 6),
                              Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: _isTablet ? 15 : 14,
                                  fontWeight:
                                      active ? FontWeight.w600 : FontWeight.w500,
                                  color: active ? chipColor : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _handleSendMessage() {
    if (_textController.text.trim().isEmpty) return;

    final msgText = _textController.text.trim();
    final repliedTo = _replyingTo?.sent;
    final repliedMsg = _replyingTo?.msg;
    final repliedToUserId = _replyingTo?.fromId;

    try {
      if (_list.isEmpty) {
        APIs.sendFirstMessage(
          widget.user,
          msgText,
          Type.text,
          repliedToMessageId: repliedTo,
          repliedMsg: repliedMsg,
          repliedToUserId: repliedToUserId,
          messageLabel: _selectedLabel,
        );
      } else {
        APIs.sendMessage(
          widget.user,
          msgText,
          Type.text,
          repliedToMessageId: repliedTo,
          repliedMsg: repliedMsg,
          repliedToUserId: repliedToUserId,
          messageLabel: _selectedLabel,
        );
      }

      _textController.clear();
      setState(() {
        _replyingTo = null;
        _selectedLabel = null;
      });
    } catch (e) {
      log('sendMessageError: $e');
      if (mounted) Dialogs.showSnackbar(context, 'Failed to send message');
    }
  }
}