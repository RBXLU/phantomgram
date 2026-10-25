import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/td_client.dart';
import '../../core/td_text.dart';
import '../../widgets/chat_avatar.dart';
import '../chat/chat_screen.dart';
import '../settings/settings_screen.dart';
import 'chat_store.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: ListenableBuilder(
            listenable: s.chats,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Phantomgram'),
                if (connectionLabel(s.chats.connectionState) case final label?)
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          actions: [
            ListenableBuilder(
              listenable: s.settings,
              builder: (context, _) {
                final on = s.settings.ghost.enabled;
                return IconButton(
                  tooltip: on ? 'Призрачный режим включён' : 'Призрачный режим выключен',
                  isSelected: on,
                  icon: const Icon(Icons.visibility_outlined),
                  selectedIcon: const Icon(Icons.visibility_off),
                  onPressed: () {
                    s.settings.update((st) => st.ghost.enabled = !on);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            !on
                                ? 'Призрачный режим: вас не видно в сети, сообщения не отмечаются прочитанными'
                                : 'Призрачный режим выключен',
                          ),
                        ),
                      );
                  },
                );
              },
            ),
            IconButton(
              tooltip: 'Настройки',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Чаты'),
              Tab(text: 'Архив'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ChatListView(list: chatListMain),
            ChatListView(list: chatListArchive),
          ],
        ),
      ),
    );
  }
}

String? connectionLabel(String state) => switch (state) {
  'connectionStateWaitingForNetwork' => 'Ожидание сети…',
  'connectionStateConnectingToProxy' => 'Подключение к прокси…',
  'connectionStateConnecting' => 'Подключение…',
  'connectionStateUpdating' => 'Обновление…',
  _ => null,
};

class ChatListView extends StatefulWidget {
  const ChatListView({super.key, required this.list});

  final TdObject list;

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
  }

  Future<void> _loadMore() async {
    if (_loading || !mounted) return;
    _loading = true;
    await AppScope.of(context).chats.loadMore(widget.list);
    _loading = false;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final store = AppScope.of(context).chats;
    final key = chatListKey(widget.list);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final chats = store.listChats(key);
        if (chats.isEmpty) {
          return Center(child: Text(key == 'archive' ? 'Архив пуст' : 'Загрузка чатов…'));
        }
        return ListView.builder(
          controller: _scroll,
          itemCount: chats.length,
          itemBuilder: (context, i) => ChatTile(chat: chats[i], listKey: key),
        );
      },
    );
  }
}

class ChatTile extends StatelessWidget {
  const ChatTile({super.key, required this.chat, required this.listKey});

  final ChatInfo chat;
  final String listKey;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final store = s.chats;
    final theme = Theme.of(context);
    final last = chat.lastMessage;
    final localPin = store.isLocallyPinned(chat.id);
    final serverPin = chat.positions[listKey]?.isPinned ?? false;
    final unread = chat.unreadCount;

    String preview = '';
    if (last != null) {
      preview = contentText(last['content'] as Map);
      if (chat.kind == ChatKind.group) {
        final name = last['is_outgoing'] == true ? 'Вы' : store.senderName(last['sender_id'] as Map?);
        if (name.isNotEmpty) preview = '$name: $preview';
      }
    }

    return ListTile(
      leading: ChatAvatar(chat: chat, store: store),
      title: Row(
        children: [
          if (chat.kind == ChatKind.secret)
            const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.lock, size: 16)),
          if (chat.kind == ChatKind.channel)
            const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.campaign_outlined, size: 16)),
          Expanded(child: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (chat.isMuted) Icon(Icons.volume_off, size: 14, color: theme.hintColor),
          if (last != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(formatShortDate(last['date'] as int), style: theme.textTheme.bodySmall),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(child: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (chat.unreadMentions > 0) _Badge(text: '@', color: theme.colorScheme.primary),
          if (unread > 0 || chat.isMarkedUnread)
            _Badge(
              text: unread > 0 ? '$unread' : '',
              color: chat.isMuted ? theme.disabledColor : theme.colorScheme.primary,
            )
          else if (localPin || serverPin)
            Icon(Icons.push_pin, size: 16, color: localPin ? theme.colorScheme.tertiary : theme.hintColor),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatScreen(chatId: chat.id))),
      onLongPress: () => _menu(context),
    );
  }

  Future<void> _menu(BuildContext context) async {
    final s = AppScope.of(context);
    final localPin = s.chats.isLocallyPinned(chat.id);
    final inArchive = listKey == 'archive';
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(chat.title, style: Theme.of(context).textTheme.titleMedium)),
            ListTile(
              leading: Icon(localPin ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(localPin ? 'Открепить (локально)' : 'Закрепить локально — без лимита'),
              onTap: () => Navigator.pop(context, 'pin'),
            ),
            ListTile(
              leading: Icon(inArchive ? Icons.unarchive_outlined : Icons.archive_outlined),
              title: Text(inArchive ? 'Вернуть из архива' : 'В архив'),
              onTap: () => Navigator.pop(context, 'archive'),
            ),
            if (chat.lastMessage != null)
              ListTile(
                leading: const Icon(Icons.done_all),
                title: const Text('Отметить прочитанным'),
                onTap: () => Navigator.pop(context, 'read'),
              ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'pin':
        s.settings.toggleLocalPin(chat.id);
      case 'archive':
        inArchive ? await s.antispam.moveToMain(chat.id) : await s.antispam.moveToArchive(chat.id);
      case 'read':
        await s.ghost.markRead(chat.id, chat.lastMessage!['id'] as int);
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
