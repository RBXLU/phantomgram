import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/services.dart';
import '../../core/td_client.dart';
import '../../core/td_text.dart';
import '../../ui/feedback.dart';
import '../../ui/glass.dart';
import '../../ui/ios_page.dart';
import '../../ui/look.dart';
import '../../widgets/chat_avatar.dart';
import '../chat/chat_screen.dart';
import '../settings/settings_screen.dart';
import 'chat_store.dart';

/// Chats / Archive / Settings behind a floating glass tab bar. On wide
/// windows (desktop, iPad) the open chat sits next to the list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const wideLayout = 900.0;
  static const sidebarWidth = 400.0;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int? _selectedChat;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final look = Look.of(context);
    final wide = MediaQuery.sizeOf(context).width >= HomeScreen.wideLayout;

    void open(int chatId) {
      if (wide) {
        setState(() => _selectedChat = chatId);
      } else {
        Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => ChatScreen(chatId: chatId)));
      }
    }

    final tabs = Stack(
      children: [
        IndexedStack(
          index: _tab,
          children: [
            ChatListPage(list: chatListMain, title: 'Чаты', onOpen: open, selected: wide ? _selectedChat : null),
            ChatListPage(list: chatListArchive, title: 'Архив', onOpen: open, selected: wide ? _selectedChat : null),
            const SettingsScreen(),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom + 8,
          child: Center(
            child: ListenableBuilder(
              listenable: s.chats,
              builder: (context, _) => GlassTabBar(
                index: _tab,
                onTap: (i) => setState(() => _tab = i),
                items: [
                  (CupertinoIcons.chat_bubble_2_fill, 'Чаты', _unreadChats(s.chats, 'main')),
                  (CupertinoIcons.archivebox_fill, 'Архив', 0),
                  (CupertinoIcons.gear_alt_fill, 'Настройки', 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (!wide) return tabs;
    final selected = _selectedChat;
    return Row(
      children: [
        SizedBox(width: HomeScreen.sidebarWidth, child: tabs),
        Container(width: 0.5, color: look.separator),
        Expanded(
          child: selected == null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    const WallpaperBackground(),
                    Center(
                      child: GlassPill(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('Выберите чат', style: TextStyle(fontSize: 15, color: look.label)),
                      ),
                    ),
                  ],
                )
              : ChatScreen(key: ValueKey(selected), chatId: selected, embedded: true),
        ),
      ],
    );
  }

  static int _unreadChats(ChatStore store, String list) =>
      store.listChats(list).where((c) => !c.isMuted && (c.unreadCount > 0 || c.isMarkedUnread)).length;
}

class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key, required this.items, required this.index, required this.onTap});

  final List<(IconData, String, int)> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    return Glass(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, (icon, label, badge)) in items.indexed)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 92,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: i == index ? look.fill : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(icon, size: 25, color: i == index ? look.accent : look.label),
                        if (badge > 0)
                          Positioned(
                            right: -12,
                            top: -4,
                            child: _Badge(text: '$badge', color: LookData.destructive),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: i == index ? look.accent : look.label,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key, required this.list, required this.title, required this.onOpen, this.selected});

  final TdObject list;
  final String title;
  final ValueChanged<int> onOpen;
  final int? selected;

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _scroll = ScrollController();
  String _query = '';
  bool _loading = false;

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
    final s = AppScope.of(context);
    final look = Look.of(context);
    final key = chatListKey(widget.list);
    return ListenableBuilder(
      listenable: s.chats,
      builder: (context, _) {
        final q = _query.trim().toLowerCase();
        final chats = s.chats.listChats(key).where((c) => q.isEmpty || c.title.toLowerCase().contains(q)).toList();
        final connecting = connectionLabel(s.chats.connectionState);
        final ghost = s.settings.ghost.enabled;
        return IosPage(
          title: widget.title,
          largeTitle: true,
          showBack: false,
          background: look.bg,
          controller: _scroll,
          bottomInset: 84,
          subtitle: connecting == null
              ? null
              : Row(
                  children: [
                    const CupertinoActivityIndicator(radius: 7),
                    const SizedBox(width: 6),
                    Text(connecting, style: TextStyle(fontSize: 15, color: look.secondaryLabel)),
                  ],
                ),
          actions: [
            GlassButton(
              icon: ghost ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye,
              active: ghost,
              semanticLabel: 'Призрачный режим',
              onPressed: () {
                s.settings.update((st) => st.ghost.enabled = !ghost);
                showToast(
                  context,
                  !ghost ? 'Призрачный режим включён' : 'Призрачный режим выключен',
                  icon: !ghost ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye,
                );
              },
            ),
          ],
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: CupertinoSearchTextField(
                  placeholder: 'Поиск',
                  borderRadius: BorderRadius.circular(999),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            if (chats.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    q.isNotEmpty
                        ? 'Ничего не найдено'
                        : key == 'archive'
                        ? 'Архив пуст'
                        : 'Загрузка чатов…',
                    style: TextStyle(color: look.secondaryLabel, fontSize: 15),
                  ),
                ),
              )
            else
              SlidableAutoCloseBehavior(
                child: SliverList.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, i) => ChatRow(
                    chat: chats[i],
                    listKey: key,
                    selected: chats[i].id == widget.selected,
                    onOpen: () => widget.onOpen(chats[i].id),
                  ),
                ),
              ),
          ],
        );
      },
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

class ChatRow extends StatelessWidget {
  const ChatRow({super.key, required this.chat, required this.listKey, required this.onOpen, this.selected = false});

  final ChatInfo chat;
  final String listKey;
  final VoidCallback onOpen;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final look = Look.of(context);
    final store = s.chats;
    final last = chat.lastMessage;
    final localPin = store.isLocallyPinned(chat.id);
    final pinned = localPin || (chat.positions[listKey]?.isPinned ?? false);
    final unread = chat.unreadCount;
    final hasUnread = unread > 0 || chat.isMarkedUnread;
    final inArchive = listKey == 'archive';
    final rowHeight = look.compact ? 68.0 : 78.0;

    var sender = '';
    var preview = '';
    if (last != null) {
      preview = contentText(last['content'] as Map);
      if (chat.kind == ChatKind.group) {
        sender = last['is_outgoing'] == true ? 'Вы' : store.senderName(last['sender_id'] as Map?);
      }
    }
    final outgoing = last?['is_outgoing'] == true;
    final read = outgoing && (last!['id'] as int) <= (chat.raw['last_read_outbox_message_id'] as int? ?? 0);

    final row = Container(
      height: rowHeight,
      color: selected ? look.accent.withValues(alpha: 0.14) : look.bg,
      padding: const EdgeInsets.only(left: 14),
      child: Row(
        children: [
          ChatAvatar(chat: chat, store: store, size: look.compact ? 50 : 58),
          const SizedBox(width: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: look.separator, width: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (chat.kind == ChatKind.secret)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(CupertinoIcons.lock_fill, size: 15, color: LookData.green),
                          ),
                        if (chat.kind == ChatKind.channel)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(CupertinoIcons.speaker_2_fill, size: 15, color: look.label),
                          ),
                        if (chat.kind == ChatKind.group)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(CupertinoIcons.person_2_fill, size: 15, color: look.label),
                          ),
                        // Title and mute icon take what is left; time stays right-aligned.
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  chat.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: look.label),
                                ),
                              ),
                              if (chat.isMuted)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(CupertinoIcons.bell_slash_fill, size: 13, color: look.tertiaryLabel),
                                ),
                            ],
                          ),
                        ),
                        if (outgoing) Checks(read: read, color: look.accent, size: 15),
                        if (last != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              formatShortDate(last['date'] as int),
                              style: TextStyle(fontSize: 15, color: look.secondaryLabel),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (sender.isNotEmpty)
                                  TextSpan(
                                    text: '$sender\n',
                                    style: TextStyle(color: look.label),
                                  ),
                                TextSpan(text: preview),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, height: 1.25, color: look.secondaryLabel),
                          ),
                        ),
                        if (chat.unreadMentions > 0) _Badge(text: '@', color: look.accent),
                        if (hasUnread)
                          _Badge(
                            text: unread > 0 ? '$unread' : '',
                            color: chat.isMuted ? look.tertiaryLabel : look.accent,
                          )
                        else if (pinned)
                          Padding(
                            padding: const EdgeInsets.only(left: 6, top: 2),
                            child: Icon(CupertinoIcons.pin_fill, size: 15, color: look.tertiaryLabel),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Slidable(
      key: ValueKey(chat.id),
      groupTag: listKey,
      startActionPane: last == null
          ? null
          : ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.24,
              children: [
                _SwipeAction(
                  label: 'Прочитано',
                  icon: CupertinoIcons.chat_bubble_text_fill,
                  color: look.accent,
                  onTap: () => s.ghost.markRead(chat.id, last['id'] as int),
                ),
              ],
            ),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.48,
        children: [
          _SwipeAction(
            label: localPin ? 'Открепить' : 'Закрепить',
            icon: localPin ? CupertinoIcons.pin_slash_fill : CupertinoIcons.pin_fill,
            color: LookData.orange,
            onTap: () => s.settings.toggleLocalPin(chat.id),
          ),
          _SwipeAction(
            label: inArchive ? 'Вернуть' : 'В архив',
            icon: CupertinoIcons.archivebox_fill,
            color: const Color(0xFF8E8E93),
            onTap: () => inArchive ? s.antispam.moveToMain(chat.id) : s.antispam.moveToArchive(chat.id),
          ),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        onLongPress: () => _menu(context, localPin, inArchive),
        child: row,
      ),
    );
  }

  Future<void> _menu(BuildContext context, bool localPin, bool inArchive) async {
    final s = AppScope.of(context);
    final action = await actionSheet<String>(
      context,
      title: chat.title,
      actions: [
        SheetAction(localPin ? 'Открепить' : 'Закрепить (без лимита, на этом устройстве)', 'pin'),
        SheetAction(inArchive ? 'Вернуть из архива' : 'В архив', 'archive'),
        if (chat.lastMessage != null) const SheetAction('Отметить прочитанным', 'read'),
      ],
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

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: () {
        Slidable.of(context)?.close();
        onTap();
      },
      child: ColoredBox(
        color: color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFFFFFFF), size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 6, top: 1),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14, fontWeight: FontWeight.w500),
    ),
  );
}
