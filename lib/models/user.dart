import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String photoURL;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoURL,
  });

  // Factory para criar um objeto User a partir de um documento do Firestore
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    return UserModel(
      uid: doc['uid'],
      displayName: doc['displayName'],
      email: doc['email'],
      photoURL: doc['photoURL'],
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'photoURL': photoURL,
      };

  static UserModel? fromSnap(DocumentSnapshot snap) {
    return UserModel(
      uid: snap['uid'],
      displayName: snap['displayName'],
      email: snap['email'],
      photoURL: snap['photoURL'],
    );
  }
}
