import 'dart:io';
// ignore: unnecessary_import
import 'dart:typed_data';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';

const Color kPrimaryColor = Color.fromARGB(255, 12, 215, 246);
const String kDefaultImagePrompt = "Describe this picture?";
const String kErrorMessage = "Sorry, I encountered an error. Please try again.";

class ChatBot extends StatefulWidget {
  const ChatBot({super.key});

  @override
  State<ChatBot> createState() => _ChatBotState();
}

class _ChatBotState extends State<ChatBot> {
  final Gemini gemini = Gemini.instance;
  List<ChatMessage> messages = [];
  bool _isLoading = false;

  ChatUser currentUser = ChatUser(id: "0", firstName: "User");
  ChatUser geminiUser = ChatUser(
    id: "1",
    firstName: "ChatBot",
    profileImage: 'assets/images/Shikshahub_logo.png'
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.5),
        centerTitle: true,
        title: const Text('Chatbot'),
      ),
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    return Stack(
      children: [
        DashChat(
          inputOptions: InputOptions(
            trailing: [
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: _isLoading ? null : _sendMediaMessage,
              )
            ],
            inputDisabled: _isLoading,
          ),
          currentUser: currentUser,
          onSend: _sendMessage,
          messages: messages,
          messageOptions: MessageOptions(
            showTime: true,
            containerColor: const Color(0xFFE8E8E8),
            messageTextBuilder: (
              ChatMessage message,
              ChatMessage? previousMessage,
              ChatMessage? nextMessage,
            ) {
              return InkWell(
                onLongPress: () => _copyMessageToClipboard(message.text),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildMessageContent(message.text),
                ),
              );
            },
          ),
        ),
        if (_isLoading)
          Positioned(
            bottom: 70,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      "Thinking...",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageContent(String text) {
    if (text.contains('```')) {
      List<Widget> widgets = [];
      List<String> parts = text.split(RegExp(r'```(\w*)\n'));
      
      for (int i = 0; i < parts.length; i++) {
        if (i % 2 == 0) {
          // Regular text
          if (parts[i].trim().isNotEmpty) {
            widgets.add(Text(
              _cleanMessageText(parts[i]),
              style: const TextStyle(fontSize: 16),
            ));
          }
        } else {
          // Code block
          widgets.add(Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  parts[i].replaceAll(RegExp(r'\n```$'), ''),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () => _copyMessageToClipboard(parts[i]),
                  ),
                ),
              ],
            ),
          ));
        }
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    } else {
      return Text(
        _cleanMessageText(text),
        style: const TextStyle(fontSize: 16),
      );
    }
  }

  String _cleanMessageText(String text) {
    if (text.contains('```')) {
      // Split the text into parts based on code blocks
      List<String> parts = text.split(RegExp(r'```(\w*)\n'));
      
      // Process each part
      for (int i = 0; i < parts.length; i++) {
        if (i % 2 == 0) {
          // Regular text parts
          parts[i] = parts[i]
            .replaceAll(RegExp(r'\*\*\*(.*?)\*\*\*'), r'$1')
            .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
            .replaceAll(RegExp(r'\*(.*?)\*'), r'$1')
            .replaceAll(RegExp(r'`(.*?)`'), r'$1')
            .trim();
        } else {
          // Code block parts - preserve formatting
          parts[i] = parts[i].replaceAll(RegExp(r'\n```$'), '').trim();
        }
      }
      
      return parts.join('\n');
    } else {
      // Handle non-code block text
      return text
        .replaceAll(RegExp(r'\*\*\*(.*?)\*\*\*'), r'$1')
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1')
        .replaceAll(RegExp(r'`(.*?)`'), r'$1')
        .trim();
    }
  }

  void _copyMessageToClipboard(String text) {
    String cleanText = _cleanMessageText(text);
    Clipboard.setData(ClipboardData(text: cleanText));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _sendMessage(ChatMessage chatMessage) {
    if (chatMessage.text.trim().isEmpty) {
      _showErrorMessage('Please enter a message.');
      return;
    }

    setState(() {
      messages = [chatMessage, ...messages];
      _isLoading = true;
    });

    try {
      String question = chatMessage.text;
      List<Uint8List>? images;

      if (chatMessage.medias?.isNotEmpty ?? false) {
        try {
          images = [File(chatMessage.medias!.first.url).readAsBytesSync()];
        } catch (e) {
          print('Error reading image: $e');
          _showErrorMessage('Failed to process the image.');
          return;
        }
      }

      gemini.streamGenerateContent(
        question,
        images: images,
      ).listen(
        (event) {
          _processGeminiResponse(event);
        },
        onError: (error) {
          print('Gemini API error: $error');
          _showErrorMessage('Sorry, I couldn\'t process that request. Please try again.');
        },
        onDone: () {
          setState(() {
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      print('Message sending error: $e');
      _showErrorMessage('An error occurred. Please try again later.');
    }
  }

  void _processGeminiResponse(dynamic event) {
    String response = "";
    try {
      if (event.content != null) {
        if (event.content.parts != null) {
          // Handle array of parts
          for (var part in event.content.parts) {
            if (part.text != null) {
              String text = part.text;
              
              // Check if this is a code block
              if (text.contains('```')) {
                // Preserve code block formatting
                response += text;
              } else {
                // For non-code blocks, handle regular text
                response += text;
              }
            }
          }
        } else if (event.content.text != null) {
          response = event.content.text;
        }
      } else if (event.text != null) {
        response = event.text;
      } else if (event is String) {
        response = event;
      }
    } catch (e) {
      print('Error processing Gemini response: $e');
      print('Event structure: ${event.toString()}');
      response = event.toString();
    }

    // Don't strip code blocks if they exist
    if (!response.contains('```') && 
        (response.trim().isEmpty || RegExp(r'^\$?\d+$').hasMatch(response.trim()))) {
      print('Invalid response received: $response');
      response = "I apologize, but I received an invalid response. Please try again.";
    }

    ChatMessage? lastMessage = messages.isNotEmpty ? messages.first : null;

    setState(() {
      if (lastMessage != null && lastMessage.user.id == geminiUser.id) {
        // Update existing message for streaming effect
        messages.removeAt(0);
        messages = [
          ChatMessage(
            user: geminiUser,
            createdAt: lastMessage.createdAt,
            text: lastMessage.text + response,
            medias: lastMessage.medias,
          ),
          ...messages
        ];
      } else {
        // Add new message
        messages = [
          ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: response,
          ),
          ...messages
        ];
      }
    });
  }

  void _showErrorMessage(String errorText) {
    setState(() {
      messages = [
        ChatMessage(
          user: geminiUser,
          createdAt: DateTime.now(),
          text: errorText,
        ),
        ...messages
      ];
      _isLoading = false;
    });
  }

  void _sendMediaMessage() async {
    try {
      ImagePicker picker = ImagePicker();
      XFile? file = await picker.pickImage(source: ImageSource.gallery);

      if (file != null) {
        // Show prompt input dialog
        final prompt = await _getImagePrompt(context);
        if (prompt != null && prompt.isNotEmpty) {
          ChatMessage chatMessage = ChatMessage(
            user: currentUser,
            createdAt: DateTime.now(),
            text: prompt,
            medias: [
              ChatMedia(
                url: file.path, 
                fileName: file.name, 
                type: MediaType.image
              )
            ],
          );
          _sendMessage(chatMessage);
        }
      }
    } catch (e) {
      print('Error selecting image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to select image'))
      );
    }
  }

  Future<String?> _getImagePrompt(BuildContext context) async {
    String prompt = kDefaultImagePrompt;
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add a prompt for this image'),
          content: TextField(
            onChanged: (value) {
              prompt = value;
            },
            decoration: const InputDecoration(
              hintText: "What would you like to ask about this image?"
            ),
            controller: TextEditingController(text: prompt),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, prompt),
              child: const Text('Send'),
            ),
          ],
        );
      }
    );
  }
}