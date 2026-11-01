
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.photoUrl,
  });

  final String displayName;
  final String photoUrl;

  factory UserProfile.fromMap(
    Map<String, dynamic>? data, {
    String fallbackName = 'Użytkownik',
  }) {
    final name = data?['displayName'];
    final photo = data?['photoUrl'];

    return UserProfile(
      displayName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : fallbackName,
      photoUrl: photo is String ? photo.trim() : '',
    );
  }
}

class UserProfileService {
  UserProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Future<void> ensureCurrentUser({
    required String uid,
    required String displayName,
    required String photoUrl,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final snapshot = await ref.get();

    final currentName = displayName.trim().isNotEmpty
        ? displayName.trim()
        : (_auth.currentUser?.email?.split('@').first ?? 'Użytkownik');

    if (!snapshot.exists) {
      await ref.set({
        'displayName': currentName,
        'photoUrl': photoUrl.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // Uzupełnij brakującą nazwę, ale nie nadpisuj istniejącej.
    final data = snapshot.data()!;
    final savedName = data['displayName'];

    if (savedName is! String || savedName.trim().isEmpty) {
      await ref.update({
        'displayName': currentName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<UserProfile> getProfile(String uid) async {
    final cleanUid = uid.trim();

    if (cleanUid.isEmpty) {
      return const UserProfile(
        displayName: 'Użytkownik',
        photoUrl: '',
      );
    }

    final snapshot = await _db.collection('users').doc(cleanUid).get();

    debugPrint(
      'PROFILE DEBUG: uid=$cleanUid, exists=${snapshot.exists}, '
      'data=${snapshot.data()}',
    );

    return UserProfile.fromMap(
      snapshot.data(),
      fallbackName: 'Użytkownik',
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.photoUrl,
    this.radius = 22,
  });

  final String photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl.trim();

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: url.startsWith('https://')
          ? ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person),
              ),
            )
          : const Icon(Icons.person),
    );
  }
}
