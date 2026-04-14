class Message {
  Message({
    required this.toId,
    required this.msg,
    required this.read,
    required this.type,
    required this.fromId,
    required this.sent,
    this.repliedTo,
    this.repliedMsg,
    this.repliedToUserId,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.messageLabel,
  });

  late final String toId;
  late final String msg;
  late final String read;
  late final String fromId;
  late final String sent;
  late final Type type;
  late final String? repliedTo;
  late final String? repliedMsg;
  late final String? repliedToUserId;
  // file metadata (optional)
  late final String? fileName;
  late final int? fileSize;
  late final String? mimeType;
  // educational message label (optional)
  MessageLabel? messageLabel;

  Message.fromJson(Map<String, dynamic> json) {
    toId = json['toId'].toString();
    msg = json['msg'].toString();
    read = json['read'].toString();
    final t = json['type']?.toString() ?? Type.text.name;
    if (t == Type.image.name) {
      type = Type.image;
    } else if (t == Type.file.name) {
      type = Type.file;
    } else {
      type = Type.text;
    }
    fromId = json['fromId'].toString();
    sent = json['sent'].toString();
    repliedTo = json['repliedTo']?.toString();
    repliedMsg = json['repliedMsg']?.toString();
    repliedToUserId = json['repliedToUserId']?.toString();
    fileName = json['fileName']?.toString();
    fileSize = json['fileSize'] is int ? json['fileSize'] as int : (json['fileSize'] != null ? int.tryParse(json['fileSize'].toString()) : null);
    mimeType = json['mimeType']?.toString();
    final lab = json['messageLabel']?.toString();
    if (lab != null) {
      if (lab == MessageLabel.reference.name) {
        messageLabel = MessageLabel.reference;
      } else if (lab == MessageLabel.question.name) {
        messageLabel = MessageLabel.question;
      } else if (lab == MessageLabel.explanation.name) {
        messageLabel = MessageLabel.explanation;
      } else if (lab == MessageLabel.summary.name) {
        messageLabel = MessageLabel.summary;
      } else if (lab == MessageLabel.spoiler.name) {
        messageLabel = MessageLabel.spoiler;
      } else {
        messageLabel = null;
      }
    } else {
      messageLabel = null;
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['toId'] = toId;
    data['msg'] = msg;
    data['read'] = read;
    data['type'] = type.name;
    data['fromId'] = fromId;
    data['sent'] = sent;
    if (repliedTo != null) data['repliedTo'] = repliedTo;
    if (repliedMsg != null) data['repliedMsg'] = repliedMsg;
    if (repliedToUserId != null) data['repliedToUserId'] = repliedToUserId;
    if (fileName != null) data['fileName'] = fileName;
    if (fileSize != null) data['fileSize'] = fileSize;
    if (mimeType != null) data['mimeType'] = mimeType;
    if (messageLabel != null) data['messageLabel'] = messageLabel!.name;
    return data;
  }
}

enum Type { text, image, file }

enum MessageLabel { reference, question, explanation, summary, spoiler }


// ai message
class AiMessage {
  String msg;
  final MessageType msgType;

  AiMessage({required this.msg, required this.msgType});
}

enum MessageType { user, bot }