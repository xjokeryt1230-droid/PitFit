import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_service.dart';
import 'user_profile.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ChatService _service = ChatService();
  final UserProfileService _profiles = UserProfileService();

  @override
  void initState() {
    super.initState();
    _ensureMyProfile();
  }

  Future<void> _ensureMyProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _profiles.ensureCurrentUser(
        uid: user.uid,
        displayName:
            user.displayName ?? user.email?.split('@').first ?? 'Użytkownik',
        photoUrl: user.photoURL ?? '',
      );
    } catch (e) {
      debugPrint('Nie udało się utworzyć profilu: $e');
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Błąd: $error')));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showPrivateChatDialog() async {
    final uid = await showDialog<String>(
      context: context,
      builder: (_) => const _PrivateChatDialog(),
    );

    if (!mounted || uid == null || uid.isEmpty) return;

    try {
      final chatId = await _service.createPrivateChat(uid);
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatConversationScreen(chatId: chatId, service: _service),
        ),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showGroupDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _GroupChatDialog(),
    );

    if (!mounted || result == null) return;

    try {
      final members = List<String>.from(result['members'] ?? []);

      final chatId = await _service.createGroup(
        name: result['name'] ?? '',
        memberUids: members,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatConversationScreen(chatId: chatId, service: _service),
        ),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showAddFriendDialog() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _AddFriendDialog(),
    );

    if (!mounted || code == null || code.trim().isEmpty) return;

    try {
      final uid = await _service.findUserByFriendCode(code.trim());
      await _service.sendFriendRequest(uid);

      if (!mounted) return;
      _showMessage('Wysłano zaproszenie do znajomych!');
    } catch (e) {
      _showError(e);
    }
  }

  void _openFriendRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FriendRequestsScreen(service: _service, profiles: _profiles),
      ),
    );
  }

  void _openFriends() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendsScreen(service: _service, profiles: _profiles),
      ),
    );
  }

  void _openChat(String chatId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatConversationScreen(chatId: chatId, service: _service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFFD54F);
    const navy = Color(0xFF101827);
    const card = Color(0xFF1C2738);

    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        elevation: 0,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PITFIT',
              style: TextStyle(
                color: yellow,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Wiadomości',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Znajomi',
            onPressed: _openFriends,
            icon: const Icon(Icons.people_alt_outlined, color: yellow),
          ),
          IconButton(
            tooltip: 'Zaproszenia',
            onPressed: _openFriendRequests,
            icon: const Icon(Icons.person_add_alt_1, color: yellow),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: PopupMenuButton<String>(
        tooltip: 'Nowa rozmowa',
        offset: const Offset(0, -8),
        color: card,
        icon: const Icon(Icons.add_comment_rounded, color: navy),
        style: IconButton.styleFrom(
          backgroundColor: yellow,
          padding: const EdgeInsets.all(16),
        ),
        onSelected: (value) {
          switch (value) {
            case 'friend':
              _showAddFriendDialog();
              break;
            case 'requests':
              _openFriendRequests();
              break;
            case 'friends':
              _openFriends();
              break;
            case 'private':
              _showPrivateChatDialog();
              break;
            case 'group':
              _showGroupDialog();
              break;
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'friend',
            child: ListTile(
              leading: Icon(Icons.person_add_alt_1, color: yellow),
              title: Text('Dodaj znajomego'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'requests',
            child: ListTile(
              leading: Icon(Icons.mark_email_unread_outlined, color: yellow),
              title: Text('Zaproszenia'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'friends',
            child: ListTile(
              leading: Icon(Icons.people_outline, color: yellow),
              title: Text('Znajomi'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: 'private',
            child: ListTile(
              leading: Icon(Icons.chat_bubble_outline, color: yellow),
              title: Text('Rozmowa prywatna'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'group',
            child: ListTile(
              leading: Icon(Icons.groups_outlined, color: yellow),
              title: Text('Utwórz grupę'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.watchChats(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nie udało się pobrać rozmów:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: yellow),
            );
          }

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: yellow.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.forum_outlined,
                          color: yellow,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Twoja społeczność czeka!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'Nie masz jeszcze rozmów. Dodaj znajomego '
                        'lub rozpocznij nowy czat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _showAddFriendDialog,
                        style: FilledButton.styleFrom(
                          backgroundColor: yellow,
                          foregroundColor: navy,
                        ),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Dodaj znajomego'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF26364D), card],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: yellow.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_rounded, color: yellow, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bądź w kontakcie',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${chats.length} ${chats.length == 1 ? 'rozmowa' : 'rozmów'}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.bolt_rounded, color: yellow, size: 25),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'TWOJE ROZMOWY',
                  style: TextStyle(
                    color: yellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              ...chats.map((doc) {
                final data = doc.data();
                final isGroup = data['type'] == 'group';

                final participants = List<String>.from(
                  data['participants'] ?? [],
                );

                final me = FirebaseAuth.instance.currentUser?.uid;
                final others = participants.where((uid) => uid != me).toList();

                final lastMessage = data['lastMessage'] as String? ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: isGroup
                        ? ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: yellow.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.groups_rounded,
                                color: yellow,
                              ),
                            ),
                            title: Text(
                              data['title'] as String? ?? 'Grupa',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              lastMessage.isEmpty
                                  ? 'Brak wiadomości'
                                  : lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white60),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: yellow,
                            ),
                            onTap: () => _openChat(doc.id),
                          )
                        : others.isEmpty
                        ? ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFF34445B),
                              child: Icon(Icons.person, color: yellow),
                            ),
                            title: const Text(
                              'Rozmowa prywatna',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              lastMessage.isEmpty
                                  ? 'Brak wiadomości'
                                  : lastMessage,
                              style: const TextStyle(color: Colors.white60),
                            ),
                            onTap: () => _openChat(doc.id),
                          )
                        : _ChatContactTile(
                            key: ValueKey(doc.id),
                            uid: others.first,
                            lastMessage: lastMessage,
                            profiles: _profiles,
                            onTap: () => _openChat(doc.id),
                          ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// DODAWANIE ZNAJOMEGO

class _AddFriendDialog extends StatefulWidget {
  const _AddFriendDialog();

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFFD54F);
    const navy = Color(0xFF101827);
    const card = Color(0xFF1C2738);

    return AlertDialog(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: yellow.withValues(alpha: 0.25)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      title: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: yellow.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: yellow,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Text(
              'Dodaj znajomego',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Zamknij',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wpisz kod znajomego, aby wysłać mu zaproszenie do społeczności PitFit.',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
            decoration: InputDecoration(
              labelText: 'Kod znajomego',
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: 'PFABC123',
              hintStyle: const TextStyle(
                color: Colors.white30,
                letterSpacing: 1.5,
              ),
              prefixIcon: const Icon(Icons.key_rounded, color: yellow),
              filled: true,
              fillColor: navy,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: yellow, width: 1.4),
              ),
            ),
            onSubmitted: (_) {
              final code = _controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(context, code);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj', style: TextStyle(color: Colors.white60)),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context, _controller.text.trim());
          },
          style: FilledButton.styleFrom(
            backgroundColor: yellow,
            foregroundColor: navy,
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text(
            'Wyślij zaproszenie',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

// ZAPROSZENIA DO ZNAJOMYCH

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({
    super.key,
    required this.service,
    required this.profiles,
  });

  final ChatService service;
  final UserProfileService profiles;

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFFD54F);
    const navy = Color(0xFF101827);
    const card = Color(0xFF1C2738);

    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Zaproszenia',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.watchIncomingRequests(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Błąd zaproszeń:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: yellow),
            );
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        color: yellow,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Wszystko na bieżąco!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Nie masz nowych zaproszeń do znajomych.\n'
                      'Gdy ktoś Cię zaprosi, zobaczysz je tutaj.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: yellow.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: yellow,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NOWE ZAPROSZENIA',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${requests.length} ${requests.length == 1 ? 'oczekujące zaproszenie' : 'oczekujących zaproszeń'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.bolt_rounded, color: yellow, size: 25),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'OCZEKUJĄCE',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              ...requests.map((request) {
                final data = request.data();
                final fromUid = data['fromUid'] as String? ?? '';

                return FutureBuilder<UserProfile>(
                  future: profiles.getProfile(fromUid),
                  builder: (context, profileSnapshot) {
                    final profile = profileSnapshot.data;
                    final name = profile?.displayName ?? 'Użytkownik';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              UserAvatar(photoUrl: profile?.photoUrl ?? ''),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'Wysłał Ci zaproszenie do znajomych',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await service.rejectFriendRequest(
                                        request.id,
                                      );

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Odrzucono zaproszenie.',
                                                ),
                                              ),
                                            );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Błąd: $e')),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Odrzuć'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    try {
                                      await service.acceptFriendRequest(
                                        request.id,
                                      );

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Dodano do znajomych!',
                                                ),
                                              ),
                                            );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Błąd: $e')),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Akceptuj'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: yellow,
                                    foregroundColor: navy,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// LISTA ZNAJOMYCH

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({
    super.key,
    required this.service,
    required this.profiles,
  });

  final ChatService service;
  final UserProfileService profiles;

  Future<void> _startChat(BuildContext context, String uid) async {
    try {
      final chatId = await service.createPrivateChat(uid);

      if (!context.mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatConversationScreen(chatId: chatId, service: service),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się rozpocząć czatu: $e')),
      );
    }
  }

  Future<void> _removeFriend(
    BuildContext context,
    String uid,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Usuń znajomego?'),
        content: Text('Czy chcesz usunąć użytkownika $name ze znajomych?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await service.removeFriend(uid);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Usunięto znajomego.')));
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się usunąć znajomego: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFFD54F);
    const navy = Color(0xFF101827);
    const card = Color(0xFF1C2738);

    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Znajomi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.watchFriends(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Błąd listy znajomych:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: yellow),
            );
          }

          final friends = snapshot.data?.docs ?? [];

          if (friends.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.people_outline_rounded,
                        color: yellow,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Twoja ekipa czeka!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Nie masz jeszcze znajomych.\n'
                      'Naciśnij + i wybierz „Dodaj znajomego”.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: yellow.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: yellow,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TWOJA EKIPA',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${friends.length} ${friends.length == 1
                                ? 'znajomy'
                                : friends.length >= 2 && friends.length <= 4
                                ? 'znajomych'
                                : 'znajomych'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.bolt_rounded, color: yellow, size: 25),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'ZNAJOMI',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              ...friends.map((friend) {
                final data = friend.data();
                final uid = data['uid'] as String? ?? '';

                if (uid.isEmpty) {
                  return const SizedBox.shrink();
                }

                return FutureBuilder<UserProfile>(
                  future: profiles.getProfile(uid),
                  builder: (context, profileSnapshot) {
                    final profile = profileSnapshot.data;
                    final name = profile?.displayName ?? 'Użytkownik';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          leading: UserAvatar(
                            photoUrl: profile?.photoUrl ?? '',
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.circle, color: yellow, size: 8),
                                SizedBox(width: 7),
                                Text(
                                  'Znajomy',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onTap: () => _startChat(context, uid),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Opcje znajomego',
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white70,
                            ),
                            color: card,
                            onSelected: (value) {
                              if (value == 'chat') {
                                _startChat(context, uid);
                              } else if (value == 'remove') {
                                _removeFriend(context, uid, name);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'chat',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: yellow,
                                      size: 19,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Rozpocznij czat',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_remove_outlined,
                                      color: Colors.redAccent,
                                      size: 19,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Usuń ze znajomych',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ELEMENT LISTY CZATÓW

class _ChatContactTile extends StatelessWidget {
  const _ChatContactTile({
    super.key,
    required this.uid,
    required this.lastMessage,
    required this.onTap,
    required this.profiles,
  });

  final String uid;
  final String lastMessage;
  final VoidCallback onTap;
  final UserProfileService profiles;

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFFD54F);
    const card = Color(0xFF1C2738);

    return FutureBuilder<UserProfile>(
      future: profiles.getProfile(uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 7,
          ),
          leading: Stack(
            children: [
              UserAvatar(photoUrl: profile?.photoUrl ?? ''),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: yellow,
                    shape: BoxShape.circle,
                    border: Border.all(color: card, width: 2),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            profile?.displayName ?? 'Użytkownik',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              lastMessage.isEmpty ? 'Brak wiadomości' : lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: yellow),
          onTap: onTap,
        );
      },
    );
  }
}

// DIALOG ROZMOWY PRYWATNEJ

class _PrivateChatDialog extends StatefulWidget {
  const _PrivateChatDialog();

  @override
  State<_PrivateChatDialog> createState() => _PrivateChatDialogState();
}

class _PrivateChatDialogState extends State<_PrivateChatDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFFD54F);
    const navy = Color(0xFF101827);
    const card = Color(0xFF1C2738);

    return AlertDialog(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: yellow.withValues(alpha: 0.25)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      title: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: yellow.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: yellow,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Text(
              'Nowa rozmowa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Zamknij',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wpisz identyfikator UID użytkownika, z którym chcesz rozpocząć prywatną rozmowę.',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'UID użytkownika',
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: 'Wklej UID drugiej osoby',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.fingerprint_rounded, color: yellow),
              filled: true,
              fillColor: navy,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: yellow, width: 1.4),
              ),
            ),
            onSubmitted: (_) {
              final uid = _controller.text.trim();
              if (uid.isNotEmpty) {
                Navigator.pop(context, uid);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj', style: TextStyle(color: Colors.white60)),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context, _controller.text.trim());
          },
          style: FilledButton.styleFrom(
            backgroundColor: yellow,
            foregroundColor: navy,
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text(
            'Rozpocznij',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

// DIALOG TWORZENIA GRUPY

class _GroupChatDialog extends StatefulWidget {
  const _GroupChatDialog();

  @override
  State<_GroupChatDialog> createState() => _GroupChatDialogState();
}

class _GroupChatDialogState extends State<_GroupChatDialog> {
  final TextEditingController _nameController = TextEditingController();

  final ChatService _service = ChatService();
  final UserProfileService _profiles = UserProfileService();

  final Set<String> _selectedUids = <String>{};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFFD54F);
    const navy = Color(0xFF101827);
    const card = Color(0xFF1C2738);

    return AlertDialog(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: yellow.withValues(alpha: 0.25)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      title: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: yellow.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.groups_rounded, color: yellow, size: 25),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Text(
              'Utwórz grupę',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'Nazwa grupy',
                labelStyle: const TextStyle(color: Colors.white60),
                hintText: 'Np. Ekipa treningowa',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.edit_outlined, color: yellow),
                counterStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: navy,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: yellow, width: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'WYBIERZ ZNAJOMYCH',
                    style: TextStyle(
                      color: yellow,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: yellow.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedUids.length} wybranych',
                    style: const TextStyle(
                      color: yellow,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _service.watchFriends(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Nie udało się pobrać znajomych:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: yellow),
                    );
                  }

                  final friends = snapshot.data?.docs ?? [];

                  if (friends.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, color: yellow, size: 34),
                            SizedBox(height: 10),
                            Text(
                              'Nie masz jeszcze znajomych.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: friends.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 65,
                      color: Colors.white10,
                    ),
                    itemBuilder: (context, index) {
                      final data = friends[index].data();
                      final uid = data['uid'] as String? ?? '';

                      if (uid.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return FutureBuilder<UserProfile>(
                        future: _profiles.getProfile(uid),
                        builder: (context, profileSnapshot) {
                          final profile = profileSnapshot.data;
                          final selected = _selectedUids.contains(uid);

                          return CheckboxListTile(
                            value: selected,
                            activeColor: yellow,
                            checkColor: navy,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            title: Text(
                              profile?.displayName ?? 'Użytkownik',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: profile == null
                                ? null
                                : Text(
                                    uid,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                            secondary: UserAvatar(
                              photoUrl: profile?.photoUrl ?? '',
                            ),
                            controlAffinity: ListTileControlAffinity.trailing,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedUids.add(uid);
                                } else {
                                  _selectedUids.remove(uid);
                                }
                              });
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj', style: TextStyle(color: Colors.white60)),
        ),
        FilledButton.icon(
          onPressed: () {
            final name = _nameController.text.trim();

            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Podaj nazwę grupy.')),
              );
              return;
            }

            if (_selectedUids.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Wybierz przynajmniej jednego znajomego.'),
                ),
              );
              return;
            }

            Navigator.pop(context, {
              'name': name,
              'members': _selectedUids.toList(),
            });
          },
          style: FilledButton.styleFrom(
            backgroundColor: yellow,
            foregroundColor: navy,
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          icon: const Icon(Icons.group_add_rounded, size: 19),
          label: const Text(
            'Utwórz grupę',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

// EKRAN ROZMOWY

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.chatId,
    required this.service,
  });

  final String chatId;
  final ChatService service;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final UserProfileService _profiles = UserProfileService();

  bool _sending = false;

  static const yellow = Color(0xFFFFD54F);
  static const navy = Color(0xFF101827);
  static const card = Color(0xFF1C2738);

  // Strumienie tworzymy raz, żeby nie subskrybować ich od nowa przy każdej
  // przebudowie ekranu.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream =
      widget.service.watchMessages(widget.chatId);

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _eventsStream =
      widget.service.watchGroupEvents(widget.chatId);

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _send() async {
    if (_sending) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    try {
      await widget.service.sendMessage(chatId: widget.chatId, text: text);

      if (!mounted) return;
      _messageController.clear();
    } catch (e) {
      _showMessage('Nie wysłano wiadomości: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _openGroupManagement() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupManagementSheet(
        chatId: widget.chatId,
        service: widget.service,
        profiles: _profiles,
      ),
    );
  }

  Widget _buildConversation({required bool isGroup, required String? me}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, messageSnapshot) {
        if (messageSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Błąd wiadomości:\n${messageSnapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        if (messageSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: yellow));
        }

        final messages = messageSnapshot.data?.docs ?? [];

        if (!isGroup) {
          return _buildTimeline(messages: messages, events: const [], me: me);
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _eventsStream,
          builder: (context, eventSnapshot) {
            // Błąd historii zdarzeń nie powinien blokować wiadomości.
            final events = eventSnapshot.data?.docs ?? [];
            return _buildTimeline(messages: messages, events: events, me: me);
          },
        );
      },
    );
  }

  DateTime _timeOf(Object? value) {
    // Wiadomość, którą właśnie wysłano, nie ma jeszcze czasu z serwera.
    if (value is Timestamp) return value.toDate();
    return DateTime.now();
  }

  Widget _buildTimeline({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
    required String? me,
  }) {
    if (messages.isEmpty && events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: yellow.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: yellow,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Zacznij rozmowę!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Wyślij pierwszą wiadomość i rozpocznij rozmowę.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    final items = <_TimelineItem>[
      for (final doc in messages)
        _TimelineItem(
          id: 'm-${doc.id}',
          time: _timeOf(doc.data()['createdAt']),
          message: doc.data(),
        ),
      for (final doc in events)
        _TimelineItem(
          id: 'e-${doc.id}',
          time: _timeOf(doc.data()['createdAt']),
          event: doc.data(),
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final event = item.event;

        if (event != null) {
          return _GroupEventNotice(
            key: ValueKey(item.id),
            type: event['type'] as String? ?? '',
            actorUid: event['actorUid'] as String? ?? '',
            targetUid: event['targetUid'] as String?,
            time: item.time,
            profiles: _profiles,
          );
        }

        final data = item.message!;
        final senderId = data['senderId'] as String? ?? '';

        return _MessageWithProfile(
          key: ValueKey(item.id),
          senderId: senderId,
          isMine: senderId == me,
          text: data['text'] as String? ?? '',
          createdAt: data['createdAt'] as Timestamp?,
          profiles: _profiles,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .snapshots(),
      builder: (context, chatSnapshot) {
        final chatData = chatSnapshot.data?.data();
        final isGroup = chatData?['type'] == 'group';
        final title = isGroup
            ? (chatData?['title'] as String? ?? 'Grupa')
            : 'Rozmowa';

        return Scaffold(
          backgroundColor: navy,
          appBar: AppBar(
            backgroundColor: navy,
            elevation: 0,
            iconTheme: const IconThemeData(color: yellow),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                if (isGroup && chatData != null)
                  Text(
                    '${(chatData['participants'] as List? ?? []).length} członków',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
              ],
            ),
            actions: [
              if (isGroup)
                IconButton(
                  tooltip: 'Zarządzaj grupą',
                  onPressed: _openGroupManagement,
                  icon: const Icon(Icons.groups_rounded, color: yellow),
                ),
              const SizedBox(width: 6),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _buildConversation(isGroup: isGroup, me: me)),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: card,
                    border: Border(
                      top: BorderSide(color: yellow.withValues(alpha: 0.18)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 4000,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _send(),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Napisz wiadomość...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            counterText: '',
                            filled: true,
                            fillColor: navy,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: const BorderSide(
                                color: Colors.white12,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: const BorderSide(
                                color: yellow,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 50,
                        width: 50,
                        child: IconButton(
                          onPressed: _sending ? null : _send,
                          tooltip: 'Wyślij',
                          style: IconButton.styleFrom(
                            backgroundColor: yellow,
                            foregroundColor: navy,
                            disabledBackgroundColor: yellow.withValues(
                              alpha: 0.35,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                          icon: _sending
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: navy,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
//panel zarządzania grupą
class _GroupManagementSheet extends StatefulWidget {
  const _GroupManagementSheet({
    required this.chatId,
    required this.service,
    required this.profiles,
  });

  final String chatId;
  final ChatService service;
  final UserProfileService profiles;

  @override
  State<_GroupManagementSheet> createState() => _GroupManagementSheetState();
}

class _GroupManagementSheetState extends State<_GroupManagementSheet> {
  static const yellow = Color(0xFFFFD54F);
  static const navy = Color(0xFF101827);
  static const card = Color(0xFF1C2738);

  bool _working = false;

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    String? successMessage,
    bool closeAfter = false,
  }) async {
    if (_working) return;

    setState(() => _working = true);

    try {
      await action();

      if (!mounted) return;

      if (successMessage != null) {
        _message(successMessage);
      }

      if (closeAfter) {
        Navigator.pop(context);
      }
    } catch (e) {
      _message('Nie udało się wykonać operacji: $e');
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _addMember(List<String> participants) async {
    final selectedUid = await showDialog<String>(
      context: context,
      builder: (_) => _AddGroupMemberDialog(
        service: widget.service,
        profiles: widget.profiles,
        existingMembers: participants,
      ),
    );

    if (!mounted || selectedUid == null) return;

    await _runAction(
      () => widget.service.addGroupMember(
        chatId: widget.chatId,
        friendUid: selectedUid,
      ),
      successMessage: 'Dodano znajomego do grupy.',
    );
  }

  Future<void> _confirmRemove(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: card,
        title: const Text(
          'Usunąć członka?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Czy na pewno chcesz usunąć użytkownika $name z grupy?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Anuluj',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _runAction(
      () => widget.service.removeGroupMember(
        chatId: widget.chatId,
        memberUid: uid,
      ),
      successMessage: 'Usunięto członka grupy.',
    );
  }

  Future<void> _changeAdmin(String uid, bool makeAdmin) async {
    await _runAction(
      () => widget.service.setGroupAdmin(
        chatId: widget.chatId,
        memberUid: uid,
        makeAdmin: makeAdmin,
      ),
      successMessage: makeAdmin
          ? 'Nadano uprawnienia administratora.'
          : 'Odebrano uprawnienia administratora.',
    );
  }

  Future<void> _openGroupHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GroupEventsScreen(
          chatId: widget.chatId,
          service: widget.service,
          profiles: widget.profiles,
        ),
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: card,
        title: const Text(
          'Opuścić grupę?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Po opuszczeniu grupy nie będziesz już otrzymywać jej wiadomości.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Anuluj',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Opuść grupę'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _working = true);

    try {
      await widget.service.leaveGroup(widget.chatId);

      if (!mounted) return;

      Navigator.pop(context); // zamknij panel
      Navigator.pop(context); // wróć do listy rozmów
    } catch (e) {
      _message('Nie udało się opuścić grupy: $e');
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _sheetContainer(
            context,
            child: const Text(
              'Nie udało się pobrać danych grupy.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        if (!snapshot.hasData) {
          return _sheetContainer(
            context,
            child: const Center(
              child: CircularProgressIndicator(color: yellow),
            ),
          );
        }

        final data = snapshot.data!.data();

        if (data == null) {
          return _sheetContainer(
            context,
            child: const Text(
              'Ta grupa już nie istnieje.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final participants = List<String>.from(data['participants'] ?? []);
        final admins = List<String>.from(data['admins'] ?? []);
        final me = _myUid;
        final isAdmin = me != null && admins.contains(me);
        final isLastAdmin = isAdmin && admins.length <= 1;

        return _sheetContainer(
          context,
          bottomInset: bottomInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: yellow.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: yellow,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] as String? ?? 'Grupa',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${participants.length} członków • ${admins.length} administratorów',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _working ? null : () => _addMember(participants),
                  style: FilledButton.styleFrom(
                    backgroundColor: yellow,
                    foregroundColor: navy,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text(
                    'Dodaj znajomego do grupy',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _working ? null : _openGroupHistory,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: yellow,
                    side: BorderSide(color: yellow.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text(
                    'Historia grupy',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CZŁONKOWIE GRUPY',
                  style: TextStyle(
                    color: yellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: participants.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final uid = participants[index];
                    final memberIsAdmin = admins.contains(uid);
                    final isMe = uid == me;

                    return FutureBuilder<UserProfile>(
                      future: widget.profiles.getProfile(uid),
                      builder: (context, profileSnapshot) {
                        final profile = profileSnapshot.data;
                        final name = profile?.displayName ?? 'Użytkownik';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 3,
                          ),
                          leading: UserAvatar(
                            photoUrl: profile?.photoUrl ?? '',
                          ),
                          title: Text(
                            isMe ? '$name (Ty)' : name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: memberIsAdmin
                              ? const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.shield_rounded,
                                        color: yellow,
                                        size: 13,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'Administrator',
                                        style: TextStyle(
                                          color: yellow,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const Text(
                                  'Członek grupy',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                          trailing: isAdmin && !isMe
                              ? PopupMenuButton<String>(
                                  color: card,
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.white70,
                                  ),
                                  onSelected: (value) {
                                    if (value == 'promote') {
                                      _changeAdmin(uid, true);
                                    } else if (value == 'demote') {
                                      _changeAdmin(uid, false);
                                    } else if (value == 'remove') {
                                      _confirmRemove(uid, name);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    if (!memberIsAdmin)
                                      const PopupMenuItem(
                                        value: 'promote',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.shield_outlined,
                                              color: yellow,
                                              size: 19,
                                            ),
                                            SizedBox(width: 9),
                                            Text(
                                              'Ustaw administratora',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (memberIsAdmin && admins.length > 1)
                                      const PopupMenuItem(
                                        value: 'demote',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.shield_outlined,
                                              color: Colors.orangeAccent,
                                              size: 19,
                                            ),
                                            SizedBox(width: 9),
                                            Text(
                                              'Odbierz admina',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person_remove_outlined,
                                            color: Colors.redAccent,
                                            size: 19,
                                          ),
                                          SizedBox(width: 9),
                                          Text(
                                            'Usuń z grupy',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (isLastAdmin)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Jesteś ostatnim administratorem. Aby opuścić grupę, najpierw nadaj komuś uprawnienia administratora.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _working || isLastAdmin ? null : _leaveGroup,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Opuść grupę',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (_working) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(
                  color: yellow,
                  backgroundColor: Colors.white12,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sheetContainer(
    BuildContext context, {
    required Widget child,
    double bottomInset = 0,
  }) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        decoration: const BoxDecoration(
          color: card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: child,
      ),
    );
  }
}

// DIALOG DODAWANIA ZNAJOMEGO DO GRUPY

class _AddGroupMemberDialog extends StatefulWidget {
  const _AddGroupMemberDialog({
    required this.service,
    required this.profiles,
    required this.existingMembers,
  });

  final ChatService service;
  final UserProfileService profiles;
  final List<String> existingMembers;

  @override
  State<_AddGroupMemberDialog> createState() => _AddGroupMemberDialogState();
}

class _AddGroupMemberDialogState extends State<_AddGroupMemberDialog> {
  static const yellow = Color(0xFFFFD54F);
  static const navy = Color(0xFF101827);
  static const card = Color(0xFF1C2738);

  String _search = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: yellow.withValues(alpha: 0.25)),
      ),
      title: const Text(
        'Dodaj znajomego',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 390,
        child: Column(
          children: [
            TextField(
              onChanged: (value) {
                setState(() => _search = value.trim().toLowerCase());
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Szukaj znajomego...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search_rounded, color: yellow),
                filled: true,
                fillColor: navy,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.service.watchFriends(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Nie udało się pobrać znajomych.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: yellow),
                    );
                  }

                  final friends = (snapshot.data?.docs ?? []).where((doc) {
                    final uid = doc.data()['uid'] as String? ?? '';
                    return uid.isNotEmpty &&
                        !widget.existingMembers.contains(uid);
                  }).toList();

                  if (friends.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nie masz znajomych, których można dodać.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final uid = friends[index].data()['uid'] as String;

                      return FutureBuilder<UserProfile>(
                        future: widget.profiles.getProfile(uid),
                        builder: (context, profileSnapshot) {
                          final profile = profileSnapshot.data;
                          final name = profile?.displayName ?? 'Użytkownik';

                          if (_search.isNotEmpty &&
                              !name.toLowerCase().contains(_search)) {
                            return const SizedBox.shrink();
                          }

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: UserAvatar(
                              photoUrl: profile?.photoUrl ?? '',
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: yellow,
                            ),
                            onTap: () => Navigator.pop(context, uid),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj', style: TextStyle(color: Colors.white60)),
        ),
      ],
    );
  }
}

// WIADOMOŚĆ Z NAZWĄ, AVATAREM I GODZINĄ

class _MessageWithProfile extends StatelessWidget {
    const _MessageWithProfile({
    super.key,
    required this.senderId,
    required this.isMine,
    required this.text,
    required this.createdAt,
    required this.profiles,
  });

  final String senderId;
  final bool isMine;
  final String text;
  final Timestamp? createdAt;
  final UserProfileService profiles;

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFFD54F);
    const navy = Color(0xFF101827);
    const card = Color(0xFF1C2738);

    return FutureBuilder<UserProfile>(
      future: profiles.getProfile(senderId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final timestamp = createdAt?.toDate();

        final time = timestamp == null
            ? null
            : '${timestamp.hour.toString().padLeft(2, '0')}:'
                  '${timestamp.minute.toString().padLeft(2, '0')}';

        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            margin: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(left: 5, bottom: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UserAvatar(
                          photoUrl: profile?.photoUrl ?? '',
                          radius: 13,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          profile?.displayName ?? 'Użytkownik',
                          style: const TextStyle(
                            color: yellow,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isMine ? yellow : card,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(19),
                      topRight: const Radius.circular(19),
                      bottomLeft: Radius.circular(isMine ? 19 : 5),
                      bottomRight: Radius.circular(isMine ? 5 : 19),
                    ),
                    border: isMine ? null : Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isMine ? navy : Colors.white,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (time != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, right: 6, top: 5),
                    child: Text(
                      time,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
// EKRAN HISTORII ZDARZEŃ GRUPY

class _GroupEventsScreen extends StatelessWidget {
  const _GroupEventsScreen({
    required this.chatId,
    required this.service,
    required this.profiles,
  });

  final String chatId;
  final ChatService service;
  final UserProfileService profiles;

  static const yellow = Color(0xFFFFD54F);
  static const navy = Color(0xFF101827);
  static const card = Color(0xFF1C2738);

  String _eventTitle(String type) {
    switch (type) {
      case 'group_created':
        return 'Utworzono grupę';
      case 'member_added':
        return 'Dodano członka';
      case 'member_removed':
        return 'Usunięto członka';
      case 'admin_promoted':
        return 'Nadano administratora';
      case 'admin_demoted':
        return 'Odebrano uprawnienia administratora';
      case 'member_left':
        return 'Członek opuścił grupę';
      default:
        return 'Zdarzenie grupy';
    }
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'group_created':
        return Icons.group_add_rounded;
      case 'member_added':
        return Icons.person_add_alt_1_rounded;
      case 'member_removed':
        return Icons.person_remove_alt_1_rounded;
      case 'admin_promoted':
        return Icons.shield_rounded;
      case 'admin_demoted':
        return Icons.shield_outlined;
      case 'member_left':
        return Icons.logout_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  String _dateLabel(Timestamp? timestamp) {
    if (timestamp == null) return 'Przed chwilą';

    final date = timestamp.toDate().toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);

    final time =
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

    if (eventDay == today) {
      return 'Dzisiaj, $time';
    }

    if (eventDay == today.subtract(const Duration(days: 1))) {
      return 'Wczoraj, $time';
    }

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} • $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Historia grupy',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.watchGroupEvents(chatId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nie udało się pobrać historii:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: yellow),
            );
          }

          final events = snapshot.data?.docs ?? [];

          if (events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: yellow,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Brak zdarzeń',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Zmiany w grupie będą pojawiać się tutaj.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: yellow.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: yellow, size: 28),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AKTYWNOŚĆ GRUPY',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${events.length} ${events.length == 1 ? 'zdarzenie' : 'zdarzeń'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              ...events.map((event) {
                final data = event.data();
                final type = data['type'] as String? ?? '';
                final actorUid = data['actorUid'] as String? ?? '';
                final targetUid = data['targetUid'] as String?;
                final timestamp = data['createdAt'] as Timestamp?;

                return FutureBuilder<UserProfile>(
                  future: actorUid.isEmpty
                      ? null
                      : profiles.getProfile(actorUid),
                  builder: (context, actorSnapshot) {
                    final actorName =
                        actorSnapshot.data?.displayName ?? 'Użytkownik';

                    return FutureBuilder<UserProfile>(
                      future: targetUid == null
                          ? null
                          : profiles.getProfile(targetUid),
                      builder: (context, targetSnapshot) {
                        final targetName =
                            targetSnapshot.data?.displayName ?? 'Użytkownik';

                        String description;

                        switch (type) {
                          case 'group_created':
                            description = '$actorName utworzył grupę.';
                            break;
                          case 'member_added':
                            description = '$actorName dodał: $targetName.';
                            break;
                          case 'member_removed':
                            description = '$actorName usunął: $targetName.';
                            break;
                          case 'admin_promoted':
                            description =
                                '$actorName nadał uprawnienia administratora użytkownikowi $targetName.';
                            break;
                          case 'admin_demoted':
                            description =
                                '$actorName odebrał uprawnienia administratora użytkownikowi $targetName.';
                            break;
                          case 'member_left':
                            description = '$actorName opuścił grupę.';
                            break;
                          default:
                            description = 'W grupie nastąpiła zmiana.';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 43,
                                height: 43,
                                decoration: BoxDecoration(
                                  color: yellow.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  _eventIcon(type),
                                  color: yellow,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _eventTitle(type),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      description,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _dateLabel(timestamp),
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
class _TimelineItem {
  const _TimelineItem({
    required this.id,
    required this.time,
    this.message,
    this.event,
  });

  final String id;
  final DateTime time;
  final Map<String, dynamic>? message;
  final Map<String, dynamic>? event;
}

class _GroupEventNotice extends StatefulWidget {
  const _GroupEventNotice({
    super.key,
    required this.type,
    required this.actorUid,
    required this.targetUid,
    required this.time,
    required this.profiles,
  });

  final String type;
  final String actorUid;
  final String? targetUid;
  final DateTime time;
  final UserProfileService profiles;

  @override
  State<_GroupEventNotice> createState() => _GroupEventNoticeState();
}

class _GroupEventNoticeState extends State<_GroupEventNotice> {
  late final Future<UserProfile>? _actor;
  late final Future<UserProfile>? _target;

  @override
  void initState() {
    super.initState();

    _actor = widget.actorUid.isEmpty
        ? null
        : widget.profiles.getProfile(widget.actorUid);

    final targetUid = widget.targetUid;
    _target = targetUid == null ? null : widget.profiles.getProfile(targetUid);
  }

  String _nameOf(AsyncSnapshot<UserProfile> snapshot) {
    final name = snapshot.data?.displayName;
    return (name == null || name.trim().isEmpty) ? 'Użytkownik' : name.trim();
  }

  String? _describe(String actor, String target) {
    switch (widget.type) {
      case 'group_created':
        return '$actor utworzył(a) grupę';
      case 'member_added':
        return '$actor dodał(a) użytkownika $target';
      case 'member_removed':
        return '$actor usunął(a) użytkownika $target';
      case 'admin_promoted':
        return '$actor nadał(a) uprawnienia administratora: $target';
      case 'admin_demoted':
        return '$actor odebrał(a) uprawnienia administratora: $target';
      case 'member_left':
        return '$actor opuścił(a) grupę';
      default:
        return null;
    }
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: _actor,
      builder: (context, actorSnapshot) {
        return FutureBuilder<UserProfile>(
          future: _target,
          builder: (context, targetSnapshot) {
            final text = _describe(
              _nameOf(actorSnapshot),
              _nameOf(targetSnapshot),
            );

            if (text == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '$text · ${_hm(widget.time)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}