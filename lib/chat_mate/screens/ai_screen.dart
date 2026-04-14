import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

import '../helper/dialogs.dart';
import '../models/message.dart';
import '../widgets/ai_message_card.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  //  final _c = ChatController();
  final _textC = TextEditingController();
  final _scrollC = ScrollController();

  final _list = <AiMessage>[
    AiMessage(msg: 'Hello, How can I help you?', msgType: MessageType.bot)
  ];

  Future<void> _askQuestion() async {
    _textC.text = _textC.text.trim();

    if (_textC.text.isNotEmpty) {
      //user
      _list.add(AiMessage(msg: _textC.text, msgType: MessageType.user));
      _list.add(AiMessage(msg: '', msgType: MessageType.bot));
      setState(() {});

      _scrollDown();

      final res = await _getAnswer(_textC.text);

      //ai bot
      _list.removeLast();
      _list.add(AiMessage(msg: res, msgType: MessageType.bot));
      _scrollDown();

      setState(() {});

      _textC.text = '';
      return;
    }

    Dialogs.showSnackbar(context, 'Ask Something!');
  }

  //for moving to end message
  void _scrollDown() {
    _scrollC.animateTo(_scrollC.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500), curve: Curves.ease);
  }

  //get answer from google gemini ai
  Future<String> _getAnswer(final String question) async {
    try {
      // Use the Gemini instance initialized in main.dart (Gemini.init)
      final gemini = Gemini.instance;

      final buffer = StringBuffer();
      final completer = Completer<String>();

      // Listen to the streaming response and aggregate text parts
      final sub = gemini.streamGenerateContent(question).listen((event) {
        try {
          final ev = event as dynamic;
          if (ev.content != null) {
            final content = ev.content;
            if (content.parts != null) {
              for (final part in content.parts as Iterable) {
                try {
                  final text = (part as dynamic).text;
                  if (text != null) buffer.write(text);
                } catch (_) {}
              }
            } else {
              try {
                final text = content.text as String?;
                if (text != null) buffer.write(text);
              } catch (_) {}
            }
          } else {
            try {
              final text = ev.text as String?;
              if (text != null) {
                buffer.write(text);
              // ignore: curly_braces_in_flow_control_structures
              } else if (event is String) buffer.write(event as String);
            } catch (_) {}
          }
        } catch (e) {
          log('ai_stream_event_parse_error: $e');
        }
      }, onError: (e) {
        log('ai_stream_error: $e');
        if (!completer.isCompleted) completer.completeError(e);
      }, onDone: () {
        if (!completer.isCompleted) completer.complete(buffer.toString());
      });

      final result = await completer.future;
      await sub.cancel();
      log('ai result: $result');
      return result.trim();
    } catch (e) {
      log('getAnswerGeminiE: $e');
      return 'Something went wrong (Try again in sometime)';
    }
  }

  @override
  void dispose() {
    _textC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //app bar
      appBar: AppBar(
        title: const Text('Your AI Assistant'),
      ),

      //send message field & btn
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          //text input field
          Expanded(
              child: TextFormField(
            controller: _textC,
            textAlign: TextAlign.center,
            onTapOutside: (e) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                filled: true,
                isDense: true,
                hintText: 'Ask me anything you want...',
                hintStyle: const TextStyle(fontSize: 14),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(50)))),
          )),

          //for adding some space
          const SizedBox(width: 8),

          //send button
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue,
            child: IconButton(
              onPressed: _askQuestion,
              icon: const Icon(Icons.rocket_launch_rounded,
                  color: Colors.white, size: 28),
            ),
          )
        ]),
      ),

      //body
      body: ListView(
        physics: const BouncingScrollPhysics(),
        controller: _scrollC,
        padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * .02, bottom: MediaQuery.of(context).size.height * .1),
        children: _list.map((e) => AiMessageCard(message: e)).toList(),
      ),
    );
  }
}