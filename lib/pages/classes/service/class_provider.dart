import 'package:acs_upb_mobile/generated/l10n.dart';
import 'package:acs_upb_mobile/pages/classes/model/class.dart';
import 'package:acs_upb_mobile/pages/classes/model/person.dart';
import 'package:acs_upb_mobile/pages/filter/model/filter.dart';
import 'package:acs_upb_mobile/widgets/toast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

extension PersonExtension on Person {
  static Person fromSnap(DocumentSnapshot snap) {
    return Person(
      name: snap.data['name'],
      email: snap.data['email'],
      phone: snap.data['phone'],
      office: snap.data['office'],
      position: snap.data['position'],
      photo: snap.data['photo'],
    );
  }
}

extension ShortcutTypeExtension on ShortcutType {
  static ShortcutType fromString(String string) {
    switch (string) {
      case 'main':
        return ShortcutType.main;
      case 'classbook':
        return ShortcutType.classbook;
      case 'resource':
        return ShortcutType.resource;
      case 'other':
        return ShortcutType.other;
    }
  }
}

extension ShortcutExtension on Shortcut {
  Map<String, dynamic> toData() {
    return {
      'type': type.toString().split('.').last,
      'name': name,
      'link': link,
      'addedBy': ownerUid
    };
  }
}

extension ClassExtension on Class {
  static Future<Class> fromSnap(
      {DocumentSnapshot classSnap, DocumentSnapshot subclassSnap}) async {
    if (subclassSnap == null) {
      return Class(
        id: classSnap.documentID,
        name: classSnap.data['class'],
        acronym: classSnap.data['acronym'],
        credits: int.parse(classSnap.data['credits']),
        degree: classSnap.data['degree'],
        domain: classSnap.data['domain'],
        year: classSnap.data['year'],
        semester: classSnap.data['semester'],
      );
    } else {
      List<Shortcut> shortcuts = [];
      for (var s in List<Map<String, dynamic>>.from(
          subclassSnap.data['shortcuts'] ?? [])) {
        shortcuts.add(Shortcut(
          type: ShortcutTypeExtension.fromString(s['type']),
          name: s['name'],
          link: s['link'],
          ownerUid: s['addedBy'],
        ));
      }

      var lecturerSnap = await Firestore.instance
          .collection('people')
          .document(subclassSnap.data['lecturer'])
          .get();
      Person lecturer;
      if (lecturerSnap?.data != null) {
        lecturer = PersonExtension.fromSnap(lecturerSnap);
      }

      Map<String, double> grading = Map<String, double>.from(
          subclassSnap['grading'].map((String name, dynamic value) =>
              MapEntry(name, value.toDouble())));

      return Class(
        id: classSnap.documentID + '/' + subclassSnap.documentID,
        name: classSnap.data['class'],
        acronym: classSnap.data['acronym'],
        credits: int.parse(classSnap.data['credits']),
        degree: classSnap.data['degree'],
        domain: classSnap.data['domain'],
        year: classSnap.data['year'],
        semester: classSnap.data['semester'],
        series: subclassSnap.data['series'],
        shortcuts: shortcuts,
        lecturer: lecturer,
        grading: grading,
      );
    }
  }
}

class ClassProvider with ChangeNotifier {
  final Firestore _db = Firestore.instance;
  List<Class> classesCache;
  List<Class> userClassesCache;

  Future<List<String>> fetchUserClassIds(
      {String uid, BuildContext context}) async {
    try {
      DocumentSnapshot snap =
          await Firestore.instance.collection('users').document(uid).get();
      return List<String>.from(snap.data['classes'] ?? []);
    } catch (e) {
      if (context != null) {
        AppToast.show(S.of(context).errorSomethingWentWrong);
      }
      return null;
    }
  }

  Future<bool> setUserClassIds(
      {List<String> classIds, String uid, BuildContext context}) async {
    try {
      DocumentReference ref =
          Firestore.instance.collection('users').document(uid);
      await ref.updateData({'classes': classIds});
      userClassesCache = null;
      notifyListeners();
      return true;
    } catch (e) {
      if (context != null) {
        AppToast.show(S.of(context).errorSomethingWentWrong);
      }
      return false;
    }
  }

  Future<List<Class>> fetchClasses(
      {String uid, Filter filter, BuildContext context}) async {
    try {
      if (uid == null) {
        if (classesCache != null) {
          return classesCache;
        }

        // Get all classes
        QuerySnapshot qSnapshot =
            await _db.collection('classes').getDocuments();
        List<DocumentSnapshot> documents = qSnapshot.documents;

        // Get query results as a list of lists (including subclasses)
        var results = Future.wait(documents.map((doc) async {
          CollectionReference subclasses =
              doc.reference.collection('subclasses');
          if (subclasses != null) {
            var subdocs = (await subclasses.getDocuments()).documents;
            if (subdocs.length > 0) {
              List<Class> classes = [];
              for (var subdoc in subdocs) {
                classes.add(await ClassExtension.fromSnap(
                    classSnap: doc, subclassSnap: subdoc));
              }
              return classes;
            }
          }
          return [await ClassExtension.fromSnap(classSnap: doc)];
        }).toList());

        // Flatten
        classesCache = (await results).expand((i) => i).toList();
        return classesCache;
      } else {
        if (userClassesCache != null) {
          return userClassesCache;
        }
        List<Class> classes = [];

        // Get only the user's classes
        List<String> classIds =
            await fetchUserClassIds(uid: uid, context: context);

        CollectionReference col = _db.collection('classes');
        for (var classId in classIds) {
          var idTokens = classId.split('/');
          if (idTokens.length > 1) {
            // it's a subclass
            var parent = await col.document(idTokens[0]).get();
            var child = await col
                .document(idTokens[0])
                .collection('subclasses')
                .document(idTokens[1])
                .get();
            classes.add(await ClassExtension.fromSnap(
                classSnap: parent, subclassSnap: child));
          } else {
            // it's a parent class
            classes.add(await ClassExtension.fromSnap(
                classSnap: await col.document(classId).get()));
          }
        }

        userClassesCache = classes;
        return userClassesCache;
      }
    } catch (e) {
      print(e);
      if (context != null) {
        AppToast.show(S.of(context).errorSomethingWentWrong);
      }
      return null;
    }
  }

  DocumentReference _getClassDocument(String classId) {
    CollectionReference col = _db.collection('classes');
    DocumentReference doc;
    var idTokens = classId.split('/');
    if (idTokens.length > 1) {
      // it's a subclass
      return col
          .document(idTokens[0])
          .collection('subclasses')
          .document(idTokens[1]);
    } else {
      // it's a parent class
      return col.document(idTokens[0]);
    }
  }

  Future<bool> addShortcut(
      {String classId, Shortcut shortcut, BuildContext context}) async {
    try {
      DocumentReference doc = _getClassDocument(classId);

      var shortcuts = List<Map<String, dynamic>>.from(
          (await doc.get()).data['shortcuts'] ?? []);
      shortcuts.add(shortcut.toData());

      await doc.updateData({'shortcuts': shortcuts});
      userClassesCache = null;
      notifyListeners();
      return true;
    } catch (e) {
      print(e);
      if (context != null) {
        AppToast.show(S.of(context).errorSomethingWentWrong);
      }
      return false;
    }
  }

  Future<bool> deleteShortcut(
      {String classId, int shortcutIndex, BuildContext context}) async {
    try {
      DocumentReference doc = _getClassDocument(classId);

      var shortcuts = List<Map<String, dynamic>>.from(
          (await doc.get()).data['shortcuts'] ?? []);
      shortcuts.removeAt(shortcutIndex);

      await doc.updateData({'shortcuts': shortcuts});
      userClassesCache = null;
      notifyListeners();
      return true;
    } catch (e) {
      print(e);
      if (context != null) {
        AppToast.show(S.of(context).errorSomethingWentWrong);
      }
      return false;
    }
  }
}
