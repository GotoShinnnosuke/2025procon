import 'package:flutter/foundation.dart';

class ProfileNotifier extends ChangeNotifier {
  ProfileNotifier._();
  static final ProfileNotifier instance = ProfileNotifier._();

  void changed() => notifyListeners();
}

