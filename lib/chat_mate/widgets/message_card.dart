import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/apis.dart';
import '../helper/dialogs.dart';
import '../helper/my_date_util.dart';
import '../models/message.dart';

class MessageCard extends StatefulWidget {
  const MessageCard({
    super.key,
    required this.message,
    this.onReply,
    this.onTapReply,
    this.isHighlighted = false,
  });

  final Message message;
  final void Function(Message)? onReply;
  final void Function(String)? onTapReply;
  final bool isHighlighted;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isCached = false;

  static const _cacheTTL = Duration(days: 14);

  @override
  void initState() {
    super.initState();
    if (widget.message.type == Type.file) {
      _checkIfCached();
      _ensureCacheWithinSizeLimit();
    }
  }

  Future<void> _checkIfCached() async {
    try {
      final cacheBase = await getApplicationSupportDirectory();
      final cacheDir = Directory('${cacheBase.path}/chat_files');
      if (!await cacheDir.exists()) return;

      final safeName =
          '${widget.message.msg.hashCode}_${widget.message.fileName ?? 'file'}';
      final cachedFile = File('${cacheDir.path}/$safeName');
      if (await cachedFile.exists()) {
        final stat = await cachedFile.stat();
        final age = DateTime.now().difference(stat.modified);
        if (age <= _cacheTTL) {
          if (mounted) setState(() => _isCached = true);
          return;
        } else {
          try {
            await cachedFile.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _ensureCacheWithinSizeLimit() async {
    try {
      const maxBytes = 200 * 1024 * 1024;
      final cacheBase = await getApplicationSupportDirectory();
      final cacheDir = Directory('${cacheBase.path}/chat_files');
      if (!await cacheDir.exists()) return;

      final files = <File>[];
      await for (final entry in cacheDir.list()) {
        if (entry is File) files.add(entry);
      }

      final Map<File, FileStat> stats = {};
      int total = 0;
      for (final f in files) {
        try {
          final st = await f.stat();
          stats[f] = st;
          total += st.size;
        } catch (_) {}
      }

      if (total <= maxBytes) return;

      final entries = stats.entries.toList()
        ..sort((a, b) => a.value.modified.compareTo(b.value.modified));

      for (final e in entries) {
        if (total <= maxBytes) break;
        try {
          final f = e.key;
          final size = e.value.size;
          await f.delete();
          total -= size;
        } catch (_) {}
      }
    } catch (_) {}
  }

  bool get _hasReply =>
      widget.message.repliedTo != null &&
      widget.message.repliedMsg != null;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    bool isMe = APIs.user.uid == widget.message.fromId;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: widget.isHighlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.yellow.withOpacity(0.45),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: InkWell(
        onLongPress: () => _showBottomSheet(isMe),
        child: isMe ? _greenMessage() : _blueMessage(),
      ),
    );
    
  }

  Widget _buildReplyPreview(bool isMe) {
    if (!_hasReply) return const SizedBox.shrink();

    final bool isReplyingToSelf = widget.message.repliedToUserId == APIs.user.uid;
    final String senderName = isReplyingToSelf ? 'You' : 'Them';
    
    String displayText = widget.message.repliedMsg ?? '';
    String displayIcon = '';
    
    if (displayText.contains('http') && 
        (displayText.contains('.jpg') || 
         displayText.contains('.jpeg') || 
         displayText.contains('.png') ||
         displayText.contains('firebasestorage'))) {
      displayText = 'Photo';
      displayIcon = '🖼️';
    } else if (displayText.startsWith('📎')) {
      displayIcon = '📎';
      displayText = displayText.replaceFirst('📎 ', '');
    }

    return InkWell(
      onTap: () {
        final repliedTo = widget.message.repliedTo;
        if (repliedTo != null && widget.onTapReply != null) {
          widget.onTapReply!(repliedTo);
        }
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe 
            ? Colors.green.shade50.withOpacity(0.7)
            : Colors.blue.shade50.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe 
                ? const Color(0xFF4CAF50)
                : const Color(0xFF2196F3),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.reply,
                size: 14,
                color: isMe 
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF2196F3),
              ),
              const SizedBox(width: 4),
              Text(
                senderName,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isMe 
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF2196F3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (displayIcon.isNotEmpty) ...[
                Text(
                  displayIcon,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  displayText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.black87.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _blueMessage() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Container(
            padding: EdgeInsets.all(widget.message.type == Type.image
                ? MediaQuery.of(context).size.width * .03
                : MediaQuery.of(context).size.width * .04),
            margin: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * .04, vertical: MediaQuery.of(context).size.height * .01),
            decoration: BoxDecoration(
                color: const Color.fromARGB(255, 221, 245, 255),
                border: Border.all(color: Colors.lightBlue),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                    bottomRight: Radius.circular(30))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildReplyPreview(false),
                _buildLabelChip(),
                _buildMessageContent(),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(right: MediaQuery.of(context).size.width * .04),
          child: Text(
            MyDateUtil.getFormattedTime(
                context: context, time: widget.message.sent),
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _greenMessage() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(width: MediaQuery.of(context).size.width * .04),
            if (widget.message.read.isNotEmpty)
              const Icon(Icons.done_all_rounded, color: Colors.blue, size: 20),
            const SizedBox(width: 2),
            Text(
              MyDateUtil.getFormattedTime(
                  context: context, time: widget.message.sent),
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
        Flexible(
          child: Container(
            padding: EdgeInsets.all(widget.message.type == Type.image
                ? MediaQuery.of(context).size.width * .03
                : MediaQuery.of(context).size.width * .04),
            margin: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * .04, vertical: MediaQuery.of(context).size.height * .01),
            decoration: BoxDecoration(
                color: const Color.fromARGB(255, 218, 255, 176),
                border: Border.all(color: Colors.lightGreen),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                    bottomLeft: Radius.circular(30))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildReplyPreview(true),
                _buildLabelChip(),
                _buildMessageContent(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelChip() {
    final label = widget.message.messageLabel;
    if (label == null) return const SizedBox.shrink();

    String text;
    Color bg;
    IconData icon;

    switch (label) {
      case MessageLabel.reference:
        text = 'Reference';
        bg = Colors.indigo.shade100;
        icon = Icons.link;
        break;
      case MessageLabel.question:
        text = 'Question';
        bg = Colors.orange.shade100;
        icon = Icons.help_outline;
        break;
      case MessageLabel.explanation:
        text = 'Explanation';
        bg = Colors.green.shade100;
        icon = Icons.lightbulb_outline;
        break;
      case MessageLabel.summary:
        text = 'Summary';
        bg = Colors.teal.shade100;
        icon = Icons.article_outlined;
        break;
      case MessageLabel.spoiler:
        text = 'Spoiler';
        bg = Colors.red.shade100;
        icon = Icons.warning_amber_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.black54),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    switch (widget.message.type) {
      case Type.text:
        return Text(
          widget.message.msg,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
        );

      case Type.image:
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _ImageViewer(url: widget.message.msg),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(15)),
            child: CachedNetworkImage(
              imageUrl: widget.message.msg,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.image, size: 70),
            ),
          ),
        );

      case Type.file:
        return _buildFileMessage();
    }
  }

  Widget _buildFileMessage() {
    return GestureDetector(
      onTap: () async {
        if (_isDownloading) return;

        final url = widget.message.msg;
        final fileName = widget.message.fileName ?? 'file';

        try {
          await _downloadAndOpenFile(
            url,
            fileName,
            onProgress: (p) {
              if (mounted) {
                setState(() {
                  _isDownloading = true;
                  _downloadProgress = p;
                });
              }
            },
          );
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _isCached = true;
              _downloadProgress = 0.0;
            });
          }
        } catch (e) {
          log('Error opening file: $e');
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _downloadProgress = 0.0;
            });
            Dialogs.showSnackbar(
                context, 'Error opening file: ${e.toString()}');
          }
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getFileIcon(
                    widget.message.fileName ?? widget.message.mimeType ?? ''),
                size: 36,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isCached)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle,
                              size: 12, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Downloaded',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    widget.message.fileName ?? 'File',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.message.fileSize != null
                        ? _readableFileSize(widget.message.fileSize!)
                        : (widget.message.mimeType ?? 'Unknown type'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  if (_isDownloading)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.indigo),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.indigo,
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }

  void _showBottomSheet(bool isMe) {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20))),
        builder: (_) {
          return ListView(
            shrinkWrap: true,
            children: [
              Container(
                height: 4,
                margin: EdgeInsets.symmetric(
                    vertical: MediaQuery.of(context).size.height * .015, horizontal: MediaQuery.of(context).size.width * .4),
                decoration: const BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.all(Radius.circular(8))),
              ),
              widget.message.type == Type.text
                  ? _OptionItem(
                      icon: const Icon(Icons.copy_all_rounded,
                          color: Colors.blue, size: 26),
                      name: 'Copy Text',
                      onTap: (ctx) async {
                        await Clipboard.setData(
                                ClipboardData(text: widget.message.msg))
                            .then((value) {
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            Dialogs.showSnackbar(ctx, 'Text Copied!');
                          }
                        });
                      })
                  : (widget.message.type == Type.image
                      ? _OptionItem(
                          icon: const Icon(Icons.download_rounded,
                              color: Colors.blue, size: 26),
                          name: 'Save Image',
                          onTap: (ctx) async {
                            try {
                              log('Image Url: ${widget.message.msg}');
                              await _saveImageFallback(widget.message.msg);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                Dialogs.showSnackbar(
                                    ctx, 'Image Successfully Saved!');
                              }
                            } catch (e) {
                              log('ErrorWhileSavingImg: $e');
                              if (ctx.mounted) {
                                Dialogs.showSnackbar(
                                    ctx, 'Failed to save image');
                              }
                            }
                          })
                      : _OptionItem(
                          icon: const Icon(Icons.download_rounded,
                              color: Colors.blue, size: 26),
                          name: 'Download File',
                          onTap: (ctx) async {
                            Navigator.pop(ctx);
                            try {
                              await _downloadAndOpenFile(
                                widget.message.msg,
                                widget.message.fileName ?? 'file',
                                onProgress: (p) {
                                  if (mounted) {
                                    setState(() {
                                      _isDownloading = true;
                                      _downloadProgress = p;
                                    });
                                  }
                                },
                              );
                              if (mounted) {
                                setState(() {
                                  _isDownloading = false;
                                  _isCached = true;
                                  _downloadProgress = 0.0;
                                });
                                Dialogs.showSnackbar(
                                    context, 'File opened successfully');
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(() {
                                  _isDownloading = false;
                                  _downloadProgress = 0.0;
                                });
                                Dialogs.showSnackbar(
                                    context, 'Error: ${e.toString()}');
                              }
                            }
                          })),
              if (widget.message.type == Type.file)
                _OptionItem(
                    icon: const Icon(Icons.open_in_new,
                        color: Colors.blue, size: 26),
                    name: 'Open Externally',
                    onTap: (ctx) async {
                      if (ctx.mounted) Navigator.pop(ctx);
                      try {
                        await _openExternally(widget.message.msg,
                            widget.message.fileName ?? 'file');
                        if (mounted) {
                          Dialogs.showSnackbar(context, 'Opening file...');
                        }
                      } catch (e) {
                        if (mounted) {
                          Dialogs.showSnackbar(
                              context, 'Unable to open file: ${e.toString()}');
                        }
                      }
                    }),
              _OptionItem(
                  icon: const Icon(Icons.reply, color: Colors.blue, size: 26),
                  name: 'Reply',
                  onTap: (ctx) {
                    if (widget.onReply != null) widget.onReply!(widget.message);
                    if (ctx.mounted) Navigator.pop(ctx);
                  }),
              if (isMe)
                Divider(
                  color: Colors.black54,
                  endIndent: MediaQuery.of(context).size.width * .04,
                  indent: MediaQuery.of(context).size.width * .04,
                ),
              if (widget.message.type == Type.text && isMe)
                _OptionItem(
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 26),
                    name: 'Edit Message',
                    onTap: (ctx) {
                      if (ctx.mounted) {
                        _showMessageUpdateDialog(ctx);
                      }
                    }),
              if (isMe)
                _OptionItem(
                    icon: const Icon(Icons.delete_forever,
                        color: Colors.red, size: 26),
                    name: 'Delete Message',
                    onTap: (ctx) async {
                      await APIs.deleteMessage(widget.message).then((value) {
                        if (ctx.mounted) Navigator.pop(ctx);
                      });
                    }),
              Divider(
                color: Colors.black54,
                endIndent: MediaQuery.of(context).size.width * .04,
                indent: MediaQuery.of(context).size.width * .04,
              ),
              _OptionItem(
                  icon: const Icon(Icons.remove_red_eye, color: Colors.blue),
                  name:
                      'Sent At: ${MyDateUtil.getMessageTime(time: widget.message.sent)}',
                  onTap: (_) {}),
              _OptionItem(
                  icon: const Icon(Icons.remove_red_eye, color: Colors.green),
                  name: widget.message.read.isEmpty
                      ? 'Read At: Not seen yet'
                      : 'Read At: ${MyDateUtil.getMessageTime(time: widget.message.read)}',
                  onTap: (_) {}),
            ],
          );
        });
  }

  void _showMessageUpdateDialog(final BuildContext ctx) {
    String updatedMsg = widget.message.msg;

    showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
              contentPadding: const EdgeInsets.only(
                  left: 24, right: 24, top: 20, bottom: 10),
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20))),
              title: const Row(
                children: [
                  Icon(
                    Icons.message,
                    color: Colors.blue,
                    size: 28,
                  ),
                  Text(' Update Message')
                ],
              ),
              content: TextFormField(
                initialValue: updatedMsg,
                maxLines: null,
                onChanged: (value) => updatedMsg = value,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(15)))),
              ),
              actions: [
                MaterialButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                    )),
                MaterialButton(
                    onPressed: () {
                      APIs.updateMessage(widget.message, updatedMsg);
                      Navigator.pop(ctx);
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Update',
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                    ))
              ],
            ));
  }

  Future<void> _saveImageFallback(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final request = await HttpClient().getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        final dir = await getApplicationDocumentsDirectory();
        final file = File(
            '${dir.path}/chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(bytes);
      } else {
        throw Exception('Failed to download image');
      }
    } catch (e) {
      log('saveImageError: $e');
      rethrow;
    }
  }

  Future<void> _downloadAndOpenFile(String url, String filename,
      {void Function(double)? onProgress}) async {
    try {
      final cacheBase = await getApplicationSupportDirectory();
      final cacheDir = Directory('${cacheBase.path}/chat_files');
      if (!await cacheDir.exists()) await cacheDir.create(recursive: true);

      final safeName = '${url.hashCode}_$filename';
      final cachedFile = File('${cacheDir.path}/$safeName');

      if (await cachedFile.exists()) {
        final stat = await cachedFile.stat();
        final age = DateTime.now().difference(stat.modified);
        if (age > _cacheTTL) {
          try {
            await cachedFile.delete();
          } catch (_) {}
        }
      }

      if (await cachedFile.exists()) {
        log('Opening cached file: ${cachedFile.path}');
        final mime = widget.message.mimeType ?? _getMimeType(filename.split('.').last);
        try {
          final res = await OpenFile.open(cachedFile.path, type: mime);
          log('OpenFile result: ${res.type} ${res.message}');
          return;
        } catch (e) {
          log('OpenFile error: $e');
          final uri = Uri.file(cachedFile.path);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
          throw Exception('Could not open file');
        }
      }

      await _ensureCacheWithinSizeLimit();

      log('Downloading file from: $url');
      final uri = Uri.parse(url);
      final request = await HttpClient().getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final contentLength = response.contentLength;
        final sink = cachedFile.openWrite();
        int received = 0;

        await for (final chunk in response) {
          received += chunk.length;
          sink.add(chunk);
          if (contentLength != -1 && onProgress != null) {
            onProgress(received / contentLength.clamp(1, contentLength));
          }
        }
        await sink.close();

        log('File downloaded successfully: ${cachedFile.path}');

        final mime = widget.message.mimeType ?? _getMimeType(filename.split('.').last);
        try {
          final res = await OpenFile.open(cachedFile.path, type: mime);
          log('OpenFile result: ${res.type} ${res.message}');
        } catch (e) {
          log('OpenFile error: $e');
          final uri = Uri.file(cachedFile.path);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            throw Exception('No app found to open this file type');
          }
        }
      } else {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }
    } catch (e) {
      log('downloadAndOpenFileError: $e');
      rethrow;
    }
  }

  String _getMimeType(String extension) {
    final ext = extension.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _openExternally(String url, String filename) async {
    try {
      final cacheBase = await getApplicationSupportDirectory();
      final cacheDir = Directory('${cacheBase.path}/chat_files');
      final safeName = '${url.hashCode}_$filename';
      final cachedFile = File('${cacheDir.path}/$safeName');

      if (await cachedFile.exists()) {
        log('Opening cached file externally: ${cachedFile.path}');
        final mime = widget.message.mimeType ?? _getMimeType(filename.split('.').last);
        try {
          final res = await OpenFile.open(cachedFile.path, type: mime);
          log('OpenFile result: ${res.type} ${res.message}');
          return;
        } catch (e) {
          log('OpenFile failed: $e');
        }
      }

      try {
        log('Attempting to download and open file');
        await _downloadAndOpenFile(url, filename);
        return;
      } catch (e) {
        log('Download attempt failed: $e');
      }

      log('Attempting to launch URL in external app');
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      throw Exception('No suitable method to open file');
    } catch (e) {
      log('openExternallyError: $e');
      rethrow;
    }
  }

  IconData _getFileIcon(String nameOrMime) {
    final lower = nameOrMime.toLowerCase();
    if (lower.contains('.pdf') || lower.contains('pdf')) {
      return Icons.picture_as_pdf;
    }
    if (lower.contains('.xls') ||
        lower.contains('.xlsx') ||
        lower.contains('excel')) {
      return Icons.grid_on;
    }
    if (lower.contains('.doc') ||
        lower.contains('.docx') ||
        lower.contains('word')) {
      return Icons.description;
    }
    if (lower.contains('.ppt') ||
        lower.contains('.pptx') ||
        lower.contains('presentation')) {
      return Icons.slideshow;
    }
    if (lower.contains('image') ||
        lower.contains('.png') ||
        lower.contains('.jpg') ||
        lower.contains('.jpeg')) {
      return Icons.image;
    }
    if (lower.contains('.zip') ||
        lower.contains('.rar') ||
        lower.contains('compressed')) {
      return Icons.folder_zip;
    }
    if (lower.contains('.txt') || lower.contains('text')) {
      return Icons.text_snippet;
    }
    if (lower.contains('.mp3') ||
        lower.contains('.wav') ||
        lower.contains('audio')) {
      return Icons.audio_file;
    }
    if (lower.contains('.mp4') ||
        lower.contains('.avi') ||
        lower.contains('video')) {
      return Icons.video_file;
    }
    return Icons.insert_drive_file;
  }

  String _readableFileSize(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (bytes == 0) ? 0 : (math.log(bytes) / math.log(1024)).floor();
    final size = bytes / math.pow(1024, i);
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}

class _OptionItem extends StatelessWidget {
  final Icon icon;
  final String name;
  final Function(BuildContext) onTap;

  const _OptionItem(
      {required this.icon, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: () => onTap(context),
        child: Padding(
          padding: EdgeInsets.only(
              left: MediaQuery.of(context).size.width * .05,
              top: MediaQuery.of(context).size.height * .015,
              bottom: MediaQuery.of(context).size.height * .015),
          child: Row(children: [
            icon,
            Flexible(
                child: Text('    $name',
                    style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                        letterSpacing: 0.5)))
          ]),
        ));
  }
}

class _ImageViewer extends StatelessWidget {
  final String url;

  const _ImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: url,
            placeholder: (context, url) => const CircularProgressIndicator(),
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image, color: Colors.white, size: 100),
          ),
        ),
      ),
    );
  }
}