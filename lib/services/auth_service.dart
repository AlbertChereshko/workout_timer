import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'cloud_sync_service.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final bool isSynced;
  final DateTime? lastSyncTime;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.isSynced = false,
    this.lastSyncTime,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl,
    'isSynced': isSynced,
    'lastSyncTime': lastSyncTime?.toIso8601String(),
  };

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) => UserProfile(
    uid: map['uid'] as String,
    displayName: map['displayName'] as String? ?? 'Спортсмен',
    email: map['email'] as String? ?? '',
    photoUrl: map['photoUrl'] as String?,
    isSynced: map['isSynced'] as bool? ?? false,
    lastSyncTime: map['lastSyncTime'] != null
        ? DateTime.tryParse(map['lastSyncTime'] as String)
        : null,
  );
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _lastError;

  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  Future<void> init() async {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final userData = box.get('user_profile');
        if (userData != null && userData is Map) {
          _currentUser = UserProfile.fromMap(userData);
          notifyListeners();
        }
      }

      // Если мобильная платформа (Android/iOS) и Firebase инициализирован
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // Подписываемся на изменения состояния авторизации Firebase
        FirebaseAuth.instance.authStateChanges().listen((fbUser) {
          if (fbUser != null) {
            _currentUser = UserProfile(
              uid: fbUser.uid,
              displayName: fbUser.displayName ?? _currentUser?.displayName ?? 'Спортсмен',
              email: fbUser.email ?? _currentUser?.email ?? '',
              photoUrl: fbUser.photoURL ?? _currentUser?.photoUrl,
              isSynced: true,
              lastSyncTime: _currentUser?.lastSyncTime ?? DateTime.now(),
            );
            if (Hive.isBoxOpen('settings')) {
              Hive.box('settings').put('user_profile', _currentUser!.toMap());
            }
            notifyListeners();
            // Фоновая синхронизация при автоматическом восстановлении сессии
            CloudSyncService().syncAll(fbUser.uid);
          }
        });

        // Также сразу пробуем восстановить сессию через currentUser или silent sign-in
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          _currentUser = UserProfile(
            uid: fbUser.uid,
            displayName: fbUser.displayName ?? _currentUser?.displayName ?? 'Спортсмен',
            email: fbUser.email ?? _currentUser?.email ?? '',
            photoUrl: fbUser.photoURL ?? _currentUser?.photoUrl,
            isSynced: true,
            lastSyncTime: _currentUser?.lastSyncTime ?? DateTime.now(),
          );
          if (Hive.isBoxOpen('settings')) {
            Hive.box('settings').put('user_profile', _currentUser!.toMap());
          }
          notifyListeners();
          CloudSyncService().syncAll(fbUser.uid);
        } else {
          // Если Firebase currentUser еще не инициализирован, но пользователь входил через GoogleSignIn
          try {
            final googleSignIn = GoogleSignIn();
            if (await googleSignIn.isSignedIn()) {
              final googleUser = await googleSignIn.signInSilently();
              if (googleUser != null) {
                final googleAuth = await googleUser.authentication;
                final credential = GoogleAuthProvider.credential(
                  accessToken: googleAuth.accessToken,
                  idToken: googleAuth.idToken,
                );
                final cred = await FirebaseAuth.instance.signInWithCredential(credential);
                if (cred.user != null) {
                  _currentUser = UserProfile(
                    uid: cred.user!.uid,
                    displayName: cred.user!.displayName ?? googleUser.displayName ?? 'Спортсмен',
                    email: cred.user!.email ?? googleUser.email,
                    photoUrl: cred.user!.photoURL ?? googleUser.photoUrl,
                    isSynced: true,
                    lastSyncTime: DateTime.now(),
                  );
                  if (Hive.isBoxOpen('settings')) {
                    Hive.box('settings').put('user_profile', _currentUser!.toMap());
                  }
                  notifyListeners();
                  CloudSyncService().syncAll(cred.user!.uid);
                }
              }
            }
          } catch (e) {
            debugPrint("Silent sign-in error: $e");
          }
        }
      } else if (_currentUser != null) {
        // Для десктоп/симуляции
        CloudSyncService().syncAll(_currentUser!.uid);
      }
    } catch (e) {
      debugPrint("AuthService init error: $e");
    }
  }

  /// Универсальный вход через Google Sign-In
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Для Web используем нативный Firebase Google Popup
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        final userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
        final fbUser = userCredential.user;
        if (fbUser != null) {
          _currentUser = UserProfile(
            uid: fbUser.uid,
            displayName: fbUser.displayName ?? 'Google Атлет',
            email: fbUser.email ?? '',
            photoUrl: fbUser.photoURL,
            isSynced: true,
            lastSyncTime: DateTime.now(),
          );
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        // 2. Для Android/iOS используем нативный GoogleSignIn + FirebaseAuth
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          // Пользователь отменил диалог входа
          _isLoading = false;
          notifyListeners();
          return false;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
        final User? fbUser = userCredential.user;

        if (fbUser != null) {
          _currentUser = UserProfile(
            uid: fbUser.uid,
            displayName: fbUser.displayName ?? googleUser.displayName ?? 'Спортсмен',
            email: fbUser.email ?? googleUser.email,
            photoUrl: fbUser.photoURL ?? googleUser.photoUrl,
            isSynced: true,
            lastSyncTime: DateTime.now(),
          );
        }
      } else {
        // 3. Для Linux Desktop (где Google Play Services отсутствуют нативно)
        // Если уже есть профиль - подтверждаем его, иначе ждем ввод через форму авторизации
        if (_currentUser != null) {
          _isLoading = false;
          notifyListeners();
          return true;
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Сохраняем в локальный кэш Hive для мгновенного офлайн-доступа
      if (_currentUser != null && Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('user_profile', _currentUser!.toMap());
        // Запуск автоматической облачной синхронизации данных (тренировки, история, настройки)
        CloudSyncService().syncAll(_currentUser!.uid);
      }

      _isLoading = false;
      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Авторизация с пользовательскими данными (для Desktop или ручного ввода)
  Future<void> signInWithCustomProfile({
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    _isLoading = true;
    notifyListeners();

    final cleanEmail = email.trim();
    final cleanName = displayName.trim().isNotEmpty ? displayName.trim() : 'Атлет';
    final uid = 'google_user_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

    _currentUser = UserProfile(
      uid: uid,
      displayName: cleanName,
      email: cleanEmail,
      photoUrl: (photoUrl != null && photoUrl.trim().isNotEmpty) ? photoUrl.trim() : null,
      isSynced: true,
      lastSyncTime: DateTime.now(),
    );

    if (Hive.isBoxOpen('settings')) {
      Hive.box('settings').put('user_profile', _currentUser!.toMap());
    }

    _isLoading = false;
    _lastError = null;
    notifyListeners();

    CloudSyncService().syncAll(uid);
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await GoogleSignIn().signOut().catchError((_) => null);
        await FirebaseAuth.instance.signOut().catchError((_) {});
      }
    } catch (_) {}

    _currentUser = null;

    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').delete('user_profile');
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateProfile({
    required String displayName,
    required String email,
    String? photoUrl,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = displayName.trim().isNotEmpty ? displayName.trim() : 'Атлет';
    final cleanPhoto = (photoUrl != null && photoUrl.trim().isNotEmpty) ? photoUrl.trim() : null;

    _currentUser = UserProfile(
      uid: _currentUser?.uid ?? 'google_user_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
      displayName: cleanName,
      email: cleanEmail,
      photoUrl: cleanPhoto ?? _currentUser?.photoUrl,
      isSynced: true,
      lastSyncTime: DateTime.now(),
    );
    if (Hive.isBoxOpen('settings')) {
      Hive.box('settings').put('user_profile', _currentUser!.toMap());
    }
    notifyListeners();
    CloudSyncService().syncAll(_currentUser!.uid);
  }
}

final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  return AuthService();
});
