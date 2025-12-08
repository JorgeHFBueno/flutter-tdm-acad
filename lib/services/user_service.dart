import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "../models/user.dart";

class UserService {
  final CollectionReference _users =
  FirebaseFirestore.instance.collection('users');

  Future<UserModel?> getUser() async {
    final _currentUser = FirebaseAuth.instance.currentUser!;
    DocumentSnapshot userDoc = await _users.doc(_currentUser.uid).get();
    return UserModel.fromSnap(userDoc);
  }
}
