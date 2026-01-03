import 'dart:async';

import 'package:li_clash/common/common.dart';
import 'package:li_clash/enum/enum.dart';
import 'package:li_clash/models/models.dart';
import 'package:li_clash/providers/providers.dart';
import 'package:li_clash/state.dart';
import 'package:li_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton> {
  Timer? _timer;
  String? _statusText;
  int _seconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 0;

    if (system.isAndroid) return;

    // Set first status immediately
    _statusText = appLocalizations.waitMoment;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _seconds++;

      String? newText;
      // Faster transitions to ensure visibility even on relatively quick startups
      if (_seconds < 2) {
        newText = appLocalizations.waitMoment;
      } else if (_seconds < 4) {
        newText = appLocalizations.checkingService;
      } else if (_seconds < 6) {
        newText = appLocalizations.asyncLoading;
      } else if (_seconds < 8) {
        newText = appLocalizations.quickConfig;
      } else {
        newText = appLocalizations.safeStartup;
      }

      if (newText != _statusText) {
        setState(() {
          _statusText = newText;
        });
      }
    });
  }

  void _handleStart() {
    final isStart = ref.read(runTimeProvider) != null;
    final newState = !isStart;

    if (newState) {
      setState(() {
        _startTimer();
      });
    } else {
      _timer?.cancel();
      if (_statusText != null) {
        setState(() {
          _statusText = null;
        });
      }
    }

    debouncer.call(
      FunctionTag.updateStatus,
      () {
        globalState.appController.updateStatus(newState);
      },
      duration: commonDuration,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(runTimeProvider, (previous, next) {
      if (next != null) {
        if (_timer != null || _statusText != null) {
          _timer?.cancel();
          _timer = null;
          setState(() {
            _statusText = null;
          });
        }
      }
    });

    final state = ref.watch(startButtonSelectorStateProvider);
    final runTime = ref.watch(runTimeProvider);
    final isStart = runTime != null;

    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: Info(
          label: isStart
              ? appLocalizations.runTime
              : (_statusText ?? appLocalizations.powerSwitch),
          iconData: Icons.power_settings_new,
        ),
        onPressed: state.isInit && state.hasProfile ? _handleStart : null,
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(
            top: 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: globalState.measure.bodyMediumHeight + 2,
                child: FadeThroughBox(
                  child: _buildContent(context, ref, state, isStart, runTime),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    StartButtonSelectorState state,
    bool isStart,
    int? runTime,
  ) {
    if (!state.isInit) {
      return Container(
        padding: EdgeInsets.all(2),
        child: AspectRatio(
          aspectRatio: 1,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (!state.hasProfile) {
      return Text(
        appLocalizations.checkOrAddProfile,
        style: context.textTheme.bodyMedium?.toLight.adjustSize(1),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (!isStart) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(
            Icons.play_arrow,
            size: 16,
            color: context.colorScheme.primary,
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              appLocalizations.serviceReady,
              style: context.textTheme.bodyMedium?.toLight.adjustSize(1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    // Started state: show pause icon + run time
    final timeText = _formatRunTime(runTime);
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          Icons.pause,
          size: 16,
          color: context.colorScheme.primary,
        ),
        SizedBox(width: 4),
        Text('  ', style: context.textTheme.bodyMedium?.toLight.adjustSize(1)),
        Expanded(
          child: Text(
            timeText,
            style: context.textTheme.bodyMedium?.toLight.adjustSize(1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatRunTime(int? timeStamp) {
    if (timeStamp == null) return '00:00:00';

    final diff = timeStamp / 1000;
    int inHours = (diff / 3600).floor();
    int inMinutes = (diff / 60 % 60).floor();
    int inSeconds = (diff % 60).floor();

    // Limit maximum display to 999:59:59
    if (inHours > 999) {
      inHours = 999;
      inMinutes = 59;
      inSeconds = 59;
    }

    // If less than 100 hours, show 2 digits; otherwise 3
    final hourStr = inHours < 100
        ? inHours.toString().padLeft(2, '0')
        : inHours.toString().padLeft(3, '0');

    return '$hourStr:${inMinutes.toString().padLeft(2, '0')}:${inSeconds.toString().padLeft(2, '0')}';
  }
}
