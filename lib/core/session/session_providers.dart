import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import 'session_api.dart';

final sessionApiProvider = Provider((ref) => SessionApi(ref.watch(dioProvider)));
