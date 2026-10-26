import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../features/chats/chat_store.dart';
import '../ui/glass.dart';

/// Downloaded photo if TDLib has it, the blurred mini-thumbnail meanwhile.
ImageProvider? photoImage(ChatStore store, int? fileId, String? minithumbnail) {
  final path = fileId == null ? null : store.filePath(fileId);
  if (path != null) return FileImage(File(path));
  if (minithumbnail != null) return MemoryImage(base64Decode(minithumbnail));
  return null;
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.chat, required this.store, this.size = 56});

  final ChatInfo chat;
  final ChatStore store;
  final double size;

  @override
  Widget build(BuildContext context) => Avatar(
    id: chat.id,
    title: chat.title,
    size: size,
    image: photoImage(store, chat.smallPhotoFileId, chat.minithumbnail),
  );
}
