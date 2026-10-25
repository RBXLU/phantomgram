import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../features/chats/chat_store.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.chat, required this.store, this.radius = 24});

  final ChatInfo chat;
  final ChatStore store;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fileId = chat.smallPhotoFileId;
    final path = fileId == null ? null : store.filePath(fileId);
    ImageProvider? image;
    if (path != null) {
      image = FileImage(File(path));
    } else if (chat.minithumbnail != null) {
      image = MemoryImage(base64Decode(chat.minithumbnail!));
    }
    final color = Colors.primaries[chat.id.abs() % Colors.primaries.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundImage: image,
      child: Text(
        initials(chat.title),
        style: TextStyle(color: Colors.white, fontSize: radius * 0.7, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String initials(String title) {
  final words = title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final first = String.fromCharCodes(words.first.runes.take(1));
  final second = words.length > 1 ? String.fromCharCodes(words[1].runes.take(1)) : '';
  return (first + second).toUpperCase();
}
