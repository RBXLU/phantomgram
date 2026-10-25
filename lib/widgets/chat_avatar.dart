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
    final color = avatarColors[chat.id.abs() % avatarColors.length];
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

/// Telegram's avatar palette: saturated enough for white initials.
const avatarColors = [
  Color(0xFFE17076),
  Color(0xFFFAA774),
  Color(0xFFA695E7),
  Color(0xFF7BC862),
  Color(0xFF6EC9CB),
  Color(0xFF65AADD),
  Color(0xFFEE7AAE),
];

final _letter = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// First letters of the first two words that start with a letter or digit,
/// so "Работа 💼" gives "Р" and "Phantomgram — разработка" gives "PР".
String initials(String title) {
  final letters = <String>[];
  for (final word in title.trim().split(RegExp(r'\s+'))) {
    final first = word.runes.isEmpty ? '' : String.fromCharCode(word.runes.first);
    if (_letter.hasMatch(first)) letters.add(first);
    if (letters.length == 2) break;
  }
  if (letters.isEmpty) {
    final runes = title.trim().runes;
    return runes.isEmpty ? '?' : String.fromCharCode(runes.first);
  }
  return letters.join().toUpperCase();
}
