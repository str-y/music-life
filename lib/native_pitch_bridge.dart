library native_pitch_bridge;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'package:music_life/app_constants.dart';
import 'package:music_life/services/permission_service.dart';
import 'package:music_life/pigeon/native_pitch_messages.dart';
import 'package:music_life/utils/app_logger.dart';
import 'package:music_life/utils/ring_buffer.dart';

part 'native_pitch_models.dart';
part 'native_pitch_ffi.dart';
part 'native_pitch_isolate.dart';
part 'native_pitch_manager.dart';
