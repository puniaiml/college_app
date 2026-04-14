import 'dart:developer';
import 'package:flutter/material.dart';

import '../api/apis.dart';
import '../helper/my_date_util.dart';
import '../../main.dart';
import '../models/chat_user.dart';
import '../models/message.dart';
import '../screens/chat_screen.dart';
import 'dialogs/profile_dialog.dart';
import 'profile_image.dart';

class ChatUserCard extends StatefulWidget {
  final ChatUser user;
  final VoidCallback? onLongPress;

  const ChatUserCard({
    super.key,
    required this.user,
    this.onLongPress,
  });

  @override
  State<ChatUserCard> createState() => _ChatUserCardState();
}

class _ChatUserCardState extends State<ChatUserCard> {
  Message? _message;

  String _buildLastMessagePreview(Message message) {
    if (message.type == Type.image) return 'Image';

    if (message.type == Type.file) {
      final name = message.fileName ?? '';
      if (name.isEmpty) return '[File]';
      const maxLen = 30;
      if (name.length <= maxLen) return name;
      return '${name.substring(0, maxLen - 3)}...';
    }

    final text = message.msg;
    if ((text.startsWith('http://') || text.startsWith('https://')) &&
        (message.fileName != null && message.fileName!.isNotEmpty)) {
      final name = message.fileName!;
      const maxLen = 30;
      if (name.length <= maxLen) return name;
      return '${name.substring(0, maxLen - 3)}...';
    }

    const maxPreview = 40;
    if (text.length <= maxPreview) return text;
    return '${text.substring(0, maxPreview - 3)}...';
  }

  @override
  Widget build(BuildContext context) {
    log('ChatUserCard build for: ${widget.user.name} (${widget.user.id})');
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * .04, vertical: 4),
      elevation: 0.5,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(15)),
      ),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        onTap: () {
          log('🔵 Tapped user card: ${widget.user.name} (${widget.user.id})');
          log('🔵 Navigating to ChatScreen with user ID: ${widget.user.id}');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(user: widget.user),
            ),
          );
        },
        onLongPress: widget.onLongPress,
        child: StreamBuilder(
          stream: APIs.getLastMessage(widget.user),
          builder: (context, snapshot) {
            final data = snapshot.data?.docs;
            final list =
                data?.map((e) => Message.fromJson(e.data())).toList() ?? [];
            if (list.isNotEmpty) _message = list[0];

            return ListTile(
              leading: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => ProfileDialog(user: widget.user),
                  );
                },
                child: ProfileImage(
                  size: MediaQuery.of(context).size.height * .055,
                  url: widget.user.image,
                ),
              ),
              title: Text(widget.user.name),
              subtitle: Text(
                _message != null
                    ? _buildLastMessagePreview(_message!)
                    : widget.user.about,
                maxLines: 1,
              ),
              trailing: _message == null
                  ? null
                  : _message!.read.isEmpty && _message!.fromId != APIs.user.uid
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 0, 230, 119),
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                          ),
                        )
                      : Text(
                          MyDateUtil.getLastMessageTime(
                            context: context,
                            time: _message!.sent,
                          ),
                          style: const TextStyle(color: Colors.black54),
                        ),
            );
          },
        ),
      ),
    );
  }
}