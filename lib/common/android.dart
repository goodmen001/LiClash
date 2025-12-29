import 'package:li_clash/plugins/app.dart';
import 'package:li_clash/state.dart';

import 'system.dart';

class Android {
  Future<void> init() async {
    app?.onExit = () async {
      await globalState.appController.savePreferences();
    };
  }
}

final android = system.isAndroid ? Android() : null;
