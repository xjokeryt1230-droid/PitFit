import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get currentUid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Musisz być zalogowany, aby korzystać z czatu.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  CollectionReference<Map<String, dynamic>> get _friendCodes =>
      _db.collection('friendCodes');

  CollectionReference<Map<String, dynamic>> get _friendRequests =>
      _db.collection('friendRequests');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> _friendsOf(String uid) =>
      _users.doc(uid).collection('friends');

  // -------------------- CZATY --------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchChats() {
    return _chats
        .where('participants', arrayContains: currentUid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // -------------------- HISTORIA ZDARZEŃ GRUPY --------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchGroupEvents(String chatId) {
    return _chats
        .doc(chatId)
        .collection('events')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _recordGroupEvent({
    required String chatId,
    required String actorUid,
    required String type,
    String? targetUid,
  }) async {
    final eventRef = _chats.doc(chatId).collection('events').doc();

    final eventData = <String, dynamic>{
      'type': type,
      'actorUid': actorUid,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (targetUid != null) {
      eventData['targetUid'] = targetUid;
    }

    await eventRef.set(eventData);
  }

  // -------------------- CZAT PRYWATNY --------------------

  Future<String> createPrivateChat(String otherUid) async {
    final me = currentUid;
    final other = otherUid.trim();

    if (other.isEmpty) {
      throw ArgumentError('Wpisz UID drugiego użytkownika.');
    }

    if (other == me) {
      throw ArgumentError('Nie możesz rozpocząć rozmowy z samym sobą.');
    }

    final participants = [me, other]..sort();
    final chatId = 'private_${participants[0]}_${participants[1]}';
    final ref = _chats.doc(chatId);

    final existing = await ref.get();

    if (existing.exists) {
      final data = existing.data()!;
      final existingParticipants = List<String>.from(
        data['participants'] ?? [],
      );

      if (data['type'] != 'private' ||
          !existingParticipants.contains(me) ||
          !existingParticipants.contains(other)) {
        throw StateError('Nie można otworzyć tej rozmowy.');
      }

      return chatId;
    }

    await ref.set({
      'type': 'private',
      'participants': participants,
      'createdBy': me,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
    });

    return chatId;
  }

  // -------------------- TWORZENIE GRUPY --------------------

  Future<String> createGroup({
    required String name,
    required List<String> memberUids,
  }) async {
    final me = currentUid;
    final groupName = name.trim();

    if (groupName.isEmpty) {
      throw ArgumentError('Podaj nazwę grupy.');
    }

    if (groupName.length > 80) {
      throw ArgumentError('Nazwa grupy może mieć maksymalnie 80 znaków.');
    }

    final participants = <String>{
      me,
      ...memberUids.map((uid) => uid.trim()).where((uid) => uid.isNotEmpty),
    }.toList();

    if (participants.length < 2) {
      throw ArgumentError('Wybierz co najmniej jednego znajomego.');
    }

    if (participants.length > 100) {
      throw ArgumentError('Grupa może mieć maksymalnie 100 uczestników.');
    }

    final ref = _chats.doc();

    await ref.set({
      'type': 'group',
      'title': groupName,
      'participants': participants,
      'createdBy': me,
      'admins': [me],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
    });

    await _recordGroupEvent(
      chatId: ref.id,
      actorUid: me,
      type: 'group_created',
    );

    return ref.id;
  }

  // -------------------- WYSYŁANIE WIADOMOŚCI --------------------

    // -------------------- WYSYŁANIE WIADOMOŚCI --------------------

  Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final me = currentUid;
    final content = text.trim();

    if (content.isEmpty) return;

    if (content.length > 4000) {
      throw ArgumentError('Wiadomość może mieć maksymalnie 4000 znaków.');
    }

    final chatRef = _chats.doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    await _db.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatRef);

      if (!chatSnapshot.exists) {
        throw StateError('Ta rozmowa nie istnieje.');
      }

      final data = chatSnapshot.data()!;
      final participants = List<String>.from(data['participants'] ?? []);

      if (!participants.contains(me)) {
        throw StateError('Nie jesteś uczestnikiem tej rozmowy.');
      }

      transaction.set(messageRef, {
        'senderId': me,
        'text': content,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(chatRef, {
        'lastMessage': content,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    unawaited(_notifyRecipients(chatId, messageRef.id));
  }

  // -------------------- KODY ZNAJOMYCH --------------------

  static const String _friendCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _generateFriendCode() {
    final random = Random.secure();

    final suffix = List.generate(
      6,
      (_) => _friendCodeChars[random.nextInt(_friendCodeChars.length)],
    ).join();

    return 'PF$suffix';
  }

  Future<String> getOrCreateFriendCode() async {
    final me = currentUid;

    final existing = await _friendCodes
        .where('uid', isEqualTo: me)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    for (var attempt = 0; attempt < 10; attempt++) {
      final code = _generateFriendCode();
      final ref = _friendCodes.doc(code);

      final created = await _db.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(ref);

        if (snapshot.exists) return false;

        transaction.set(ref, {
          'uid': me,
          'createdAt': FieldValue.serverTimestamp(),
        });

        return true;
      });

      if (created) return code;

      final ownCode = await _friendCodes
          .where('uid', isEqualTo: me)
          .limit(1)
          .get();

      if (ownCode.docs.isNotEmpty) {
        return ownCode.docs.first.id;
      }
    }

    throw StateError(
      'Nie udało się wygenerować kodu znajomego. Spróbuj ponownie.',
    );
  }

  Future<String> findUserByFriendCode(String input) async {
    final code = input.trim().toUpperCase();

    if (!RegExp(r'^PF[A-HJ-NP-Z2-9]{6}$').hasMatch(code)) {
      throw ArgumentError('Wpisz poprawny kod znajomego.');
    }

    final snapshot = await _friendCodes.doc(code).get();

    if (!snapshot.exists) {
      throw StateError('Nie znaleziono użytkownika z tym kodem.');
    }

    final uid = snapshot.data()?['uid'] as String?;

    if (uid == null || uid.isEmpty) {
      throw StateError('Kod użytkownika jest nieprawidłowy.');
    }

    if (uid == currentUid) {
      throw StateError('Nie możesz dodać siebie do znajomych.');
    }

    return uid;
  }

  // -------------------- ZAPROSZENIA --------------------

  Future<void> sendFriendRequest(String otherUid) async {
    final me = currentUid;
    final other = otherUid.trim();

    if (other.isEmpty || other == me) {
      throw ArgumentError('Nieprawidłowy użytkownik.');
    }

    try {
      debugPrint('1. Sprawdzam profil odbiorcy');

      final target = await _users.doc(other).get();

      if (!target.exists) {
        throw StateError('To konto już nie istnieje.');
      }

      debugPrint('2. Sprawdzam listę znajomych');

      final alreadyFriends = await _friendsOf(me).doc(other).get();

      if (alreadyFriends.exists) {
        throw StateError('Ta osoba jest już na liście znajomych.');
      }

      final requestRef = _friendRequests.doc('${me}_$other');
      final reverseRef = _friendRequests.doc('${other}_$me');

      debugPrint('3. Rozpoczynam transakcję');

      await _db.runTransaction((transaction) async {
        final request = await transaction.get(requestRef);
        debugPrint('4. Odczytano własne zaproszenie');

        final reverse = await transaction.get(reverseRef);
        debugPrint('5. Odczytano odwrotne zaproszenie');

        if (request.exists && request.data()?['status'] == 'pending') {
          throw StateError('Zaproszenie zostało już wysłane.');
        }

        if (reverse.exists && reverse.data()?['status'] == 'pending') {
          throw StateError(
            'Ta osoba już wysłała Ci zaproszenie. '
            'Sprawdź otrzymane zaproszenia.',
          );
        }

        transaction.set(requestRef, {
          'fromUid': me,
          'toUid': other,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      debugPrint('6. Zaproszenie zapisane');
    } catch (e) {
      debugPrint('Błąd sendFriendRequest: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncomingRequests() {
    return _friendRequests
        .where('toUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOutgoingRequests() {
    return _friendRequests
        .where('fromUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> acceptFriendRequest(String requestId) async {
    final me = currentUid;
    final requestRef = _friendRequests.doc(requestId);

    try {
      await _db.runTransaction((transaction) async {
        final request = await transaction.get(requestRef);

        if (!request.exists) {
          throw StateError('Zaproszenie już nie istnieje.');
        }

        final data = request.data()!;
        final fromUid = data['fromUid'] as String?;
        final toUid = data['toUid'] as String?;

        if (toUid != me || data['status'] != 'pending') {
          throw StateError('Nie można zaakceptować tego zaproszenia.');
        }

        if (fromUid == null || fromUid.isEmpty || fromUid == me) {
          throw StateError('Nieprawidłowe zaproszenie.');
        }

        final myFriendRef = _friendsOf(me).doc(fromUid);
        final theirFriendRef = _friendsOf(fromUid).doc(me);

        transaction.set(myFriendRef, {
          'uid': fromUid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(theirFriendRef, {
          'uid': me,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(requestRef, {
          'status': 'accepted',
          'respondedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, stackTrace) {
      debugPrint('BŁĄD AKCEPTACJI ZAPROSZENIA: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  Future<void> rejectFriendRequest(String requestId) async {
    final me = currentUid;
    final requestRef = _friendRequests.doc(requestId);

    await _db.runTransaction((transaction) async {
      final request = await transaction.get(requestRef);

      if (!request.exists) {
        throw StateError('Zaproszenie już nie istnieje.');
      }

      final data = request.data()!;

      if (data['toUid'] != me || data['status'] != 'pending') {
        throw StateError('Nie można odrzucić tego zaproszenia.');
      }

      transaction.update(requestRef, {
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // -------------------- LISTA ZNAJOMYCH --------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFriends() {
    return _friendsOf(currentUid).snapshots();
  }

  Future<void> removeFriend(String friendUid) async {
    final uid = currentUid;
    final batch = _db.batch();

    batch.delete(_friendsOf(uid).doc(friendUid));
    batch.delete(_friendsOf(friendUid).doc(uid));

    try {
      await batch.commit();
    } catch (e, stackTrace) {
      debugPrint('BŁĄD USUWANIA ZNAJOMEGO: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  // -------------------- ZARZĄDZANIE GRUPAMI --------------------

  Future<void> addGroupMember({
    required String chatId,
    required String friendUid,
  }) async {
    final me = currentUid;
    final friend = friendUid.trim();

    if (friend.isEmpty || friend == me) {
      throw ArgumentError('Nieprawidłowy użytkownik.');
    }

    final friendship = await _friendsOf(me).doc(friend).get();

    if (!friendship.exists) {
      throw StateError('Możesz dodawać tylko swoich znajomych.');
    }

    final chatRef = _chats.doc(chatId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(chatRef);

      if (!snapshot.exists) {
        throw StateError('Ta grupa już nie istnieje.');
      }

      final data = snapshot.data()!;

      if (data['type'] != 'group') {
        throw StateError('To nie jest grupa.');
      }

      final participants = List<String>.from(data['participants'] ?? []);

      if (!participants.contains(me)) {
        throw StateError('Nie należysz do tej grupy.');
      }

      if (participants.contains(friend)) {
        throw StateError('Ta osoba już należy do grupy.');
      }

      if (participants.length >= 100) {
        throw StateError('Grupa osiągnęła limit 100 osób.');
      }

      participants.add(friend);

      transaction.update(chatRef, {
        'participants': participants,
        'lastMemberAddedBy': me,
        'lastMemberAddedUid': friend,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _recordGroupEvent(
      chatId: chatId,
      actorUid: me,
      targetUid: friend,
      type: 'member_added',
    );
  }

  Future<void> removeGroupMember({
    required String chatId,
    required String memberUid,
  }) async {
    final me = currentUid;
    final member = memberUid.trim();

    if (member.isEmpty || member == me) {
      throw ArgumentError('Nie możesz usunąć siebie tą operacją.');
    }

    final chatRef = _chats.doc(chatId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(chatRef);

      if (!snapshot.exists) {
        throw StateError('Ta grupa już nie istnieje.');
      }

      final data = snapshot.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      final admins = List<String>.from(data['admins'] ?? []);

      if (data['type'] != 'group' || !participants.contains(me)) {
        throw StateError('Nie należysz do tej grupy.');
      }

      if (!admins.contains(me)) {
        throw StateError('Tylko administrator może usuwać członków.');
      }

      if (!participants.contains(member)) {
        throw StateError('Ta osoba nie należy do grupy.');
      }

      if (admins.contains(member) && admins.length <= 1) {
        throw StateError('Nie można usunąć ostatniego administratora.');
      }

      participants.remove(member);
      admins.remove(member);

      transaction.update(chatRef, {
        'participants': participants,
        'admins': admins,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _recordGroupEvent(
      chatId: chatId,
      actorUid: me,
      targetUid: member,
      type: 'member_removed',
    );
  }

  Future<void> setGroupAdmin({
    required String chatId,
    required String memberUid,
    required bool makeAdmin,
  }) async {
    final me = currentUid;
    final member = memberUid.trim();

    if (member.isEmpty) {
      throw ArgumentError('Nieprawidłowy użytkownik.');
    }

    final chatRef = _chats.doc(chatId);

    // Zdarzenie zapisujemy tylko wtedy, gdy rola rzeczywiście się zmieni.
    var roleChanged = false;

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(chatRef);

      if (!snapshot.exists) {
        throw StateError('Ta grupa już nie istnieje.');
      }

      final data = snapshot.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      final admins = List<String>.from(data['admins'] ?? []);

      if (data['type'] != 'group' || !participants.contains(me)) {
        throw StateError('Nie należysz do tej grupy.');
      }

      if (!admins.contains(me)) {
        throw StateError('Tylko administrator może zarządzać rolami.');
      }

      if (!participants.contains(member)) {
        throw StateError('Ta osoba nie należy do grupy.');
      }

      if (makeAdmin) {
        if (!admins.contains(member)) {
          admins.add(member);
          roleChanged = true;
        }
      } else {
        if (!admins.contains(member)) return;

        if (admins.length <= 1) {
          throw StateError(
            'Grupa musi mieć przynajmniej jednego administratora.',
          );
        }

        admins.remove(member);
        roleChanged = true;
      }

      if (roleChanged) {
        transaction.update(chatRef, {
          'admins': admins,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    if (roleChanged) {
      await _recordGroupEvent(
        chatId: chatId,
        actorUid: me,
        targetUid: member,
        type: makeAdmin ? 'admin_promoted' : 'admin_demoted',
      );
    }
  }

  Future<void> leaveGroup(String chatId) async {
    final me = currentUid;
    final chatRef = _chats.doc(chatId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(chatRef);

      if (!snapshot.exists) {
        throw StateError('Ta grupa już nie istnieje.');
      }

      final data = snapshot.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      final admins = List<String>.from(data['admins'] ?? []);

      if (data['type'] != 'group' || !participants.contains(me)) {
        throw StateError('Nie należysz do tej grupy.');
      }

      if (admins.contains(me) && admins.length <= 1) {
        throw StateError(
          'Przed opuszczeniem grupy wyznacz innego administratora.',
        );
      }

      participants.remove(me);
      admins.remove(me);

      transaction.update(chatRef, {
        'participants': participants,
        'admins': admins,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _recordGroupEvent(
      chatId: chatId,
      actorUid: me,
      targetUid: me,
      type: 'member_left',
    );
  }
    static const String _notifyUrl = 'https://pitfit-notify.pitfit.workers.dev';

  Future<void> _notifyRecipients(String chatId, String messageId) async {
    try {
      final idToken = await _auth.currentUser?.getIdToken();
      if (idToken == null) return;

      final response = await http
          .post(
            Uri.parse(_notifyUrl),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'chatId': chatId, 'messageId': messageId}),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('notify: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('notify błąd: $e');
    }
  }
}
