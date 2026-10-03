import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class TtlockException implements Exception {
  TtlockException(this.message, [this.body]);
  final String message;
  final Object? body;
  @override
  String toString() => message;
}

class TtlockApi {
  TtlockApi({required this.baseUrl, required this.clientId});

  final String baseUrl;
  final String clientId;

  String get _root => baseUrl.replaceAll(RegExp(r'/+$'), '');

  static String md5Password(String password) =>
      md5.convert(utf8.encode(password)).toString();

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  static String recordTypeLabel(int? type) {
    const map = {
      1: 'App unlock',
      2: 'Parking touch',
      3: 'Gateway unlock',
      4: 'Passcode unlock',
      5: 'Parking raise',
      6: 'Parking lower',
      7: 'IC card unlock',
      8: 'Fingerprint unlock',
      9: 'Wristband unlock',
      10: 'Mechanical key',
      11: 'Bluetooth lock',
      12: 'Gateway unlock',
      29: 'Unexpected unlock',
      30: 'Door magnet close',
      31: 'Door magnet open',
      32: 'Open from inside',
      33: 'Lock by fingerprint',
      34: 'Lock by passcode',
      35: 'Lock by IC card',
      36: 'Lock by mechanical key',
      37: 'Remote control',
      44: 'Tamper alert',
      45: 'Auto lock',
      46: 'Unlock key',
      47: 'Lock key',
      48: 'Invalid passcode attempts',
    };
    if (type == null) return 'Άγνωστο';
    return map[type] ?? 'Type $type';
  }

  static String openStateLabel(int? state) {
    switch (state) {
      case 0:
        return 'Κλειδωμένη';
      case 1:
        return 'Ξεκλείδωτη';
      case 2:
        return 'Άγνωστη';
      default:
        return '—';
    }
  }

  static String friendlyError(Object data) {
    if (data is Map && data['errcode'] != null) {
      final code = data['errcode'];
      final msg = data['errmsg']?.toString() ?? '';
      if (code == -4043) {
        return 'Remote unlock απενεργοποιημένο στη ρύθμιση της κλειδαριάς';
      }
      return 'Σφάλμα $code${msg.isEmpty ? '' : ': $msg'}';
    }
    return data.toString();
  }

  Future<Map<String, dynamic>> getToken({
    required String clientSecret,
    required String username,
    required String password,
  }) async {
    final resp = await http.post(
      Uri.parse('$_root/oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'username': username,
        'password': md5Password(password),
      },
    );
    final data = _decode(resp);
    if (data['access_token'] == null) {
      throw TtlockException('Αποτυχία token', data);
    }
    return data;
  }

  Future<Map<String, dynamic>> listLocks({
    required String accessToken,
    int pageNo = 1,
    int pageSize = 100,
    String? lockAlias,
  }) async {
    final params = <String, String>{
      'clientId': clientId,
      'accessToken': accessToken,
      'pageNo': '$pageNo',
      'pageSize': '$pageSize',
      'date': '${nowMs()}',
    };
    if (lockAlias != null && lockAlias.trim().isNotEmpty) {
      params['lockAlias'] = lockAlias.trim();
    }
    final uri = Uri.parse('$_root/v3/lock/list').replace(queryParameters: params);
    return _decode(await http.get(uri));
  }

  Future<Map<String, dynamic>> lockDetail({
    required String accessToken,
    required int lockId,
  }) async {
    final uri = Uri.parse('$_root/v3/lock/detail').replace(
      queryParameters: {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'date': '${nowMs()}',
      },
    );
    return _decode(await http.get(uri));
  }

  Future<Map<String, dynamic>> listGateways({
    required String accessToken,
    int pageNo = 1,
    int pageSize = 100,
    int orderBy = 0,
  }) async {
    final uri = Uri.parse('$_root/v3/gateway/list').replace(
      queryParameters: {
        'clientId': clientId,
        'accessToken': accessToken,
        'pageNo': '$pageNo',
        'pageSize': '$pageSize',
        'orderBy': '$orderBy',
        'date': '${nowMs()}',
      },
    );
    return _decode(await http.get(uri));
  }

  Future<Map<String, dynamic>> listGatewaysByLock({
    required String accessToken,
    required int lockId,
  }) async {
    final uri = Uri.parse('$_root/v3/gateway/listByLock').replace(
      queryParameters: {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'date': '${nowMs()}',
      },
    );
    return _decode(await http.get(uri));
  }

  Future<Map<String, dynamic>> unlock({
    required String accessToken,
    required int lockId,
  }) async {
    return _postForm(
      '/v3/lock/unlock',
      {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'date': '${nowMs()}',
      },
      failLabel: 'Unlock',
    );
  }

  Future<Map<String, dynamic>> lock({
    required String accessToken,
    required int lockId,
  }) async {
    return _postForm(
      '/v3/lock/lock',
      {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'date': '${nowMs()}',
      },
      failLabel: 'Lock',
    );
  }

  Future<Map<String, dynamic>> queryOpenState({
    required String accessToken,
    required int lockId,
  }) async {
    final uri = Uri.parse('$_root/v3/lock/queryOpenState').replace(
      queryParameters: {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'date': '${nowMs()}',
      },
    );
    return _decode(await http.get(uri));
  }

  Future<Map<String, dynamic>> queryElectricQuantity({
    required String accessToken,
    required int lockId,
  }) async {
    final uri = Uri.parse('$_root/v3/lock/queryElectricQuantity').replace(
      queryParameters: {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'date': '${nowMs()}',
      },
    );
    return _decode(await http.get(uri));
  }

  Future<Map<String, dynamic>> renameLock({
    required String accessToken,
    required int lockId,
    required String lockAlias,
  }) async {
    return _postForm(
      '/v3/lock/rename',
      {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'lockAlias': lockAlias,
        'date': '${nowMs()}',
      },
      failLabel: 'Rename',
    );
  }

  Future<Map<String, dynamic>> freezeLock({
    required String accessToken,
    required int lockId,
  }) async {
    return _postForm(
      '/v3/lock/freeze',
      {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'date': '${nowMs()}',
      },
      failLabel: 'Freeze',
    );
  }

  Future<Map<String, dynamic>> unfreezeLock({
    required String accessToken,
    required int lockId,
  }) async {
    return _postForm(
      '/v3/lock/unfreeze',
      {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'date': '${nowMs()}',
      },
      failLabel: 'Unfreeze',
    );
  }

  Future<Map<String, dynamic>> listPasscodes({
    required String accessToken,
    required int lockId,
    int pageNo = 1,
    int pageSize = 100,
  }) async {
    final uri = Uri.parse('$_root/v3/lock/listKeyboardPwd').replace(
      queryParameters: {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'pageNo': '$pageNo',
        'pageSize': '$pageSize',
        'date': '${nowMs()}',
      },
    );
    return _decode(await http.get(uri));
  }

  Future<Map<String, dynamic>> createPasscode({
    required String accessToken,
    required int lockId,
    required int keyboardPwdType,
    int? startDateMs,
    int? endDateMs,
    String? keyboardPwdName,
    int keyboardPwdVersion = 4,
  }) async {
    final body = <String, String>{
      'clientId': clientId,
      'accessToken': accessToken,
      'lockId': '$lockId',
      'keyboardPwdVersion': '$keyboardPwdVersion',
      'keyboardPwdType': '$keyboardPwdType',
      'date': '${nowMs()}',
    };
    if (startDateMs != null) body['startDate'] = '$startDateMs';
    if (endDateMs != null) body['endDate'] = '$endDateMs';
    if (keyboardPwdName != null && keyboardPwdName.trim().isNotEmpty) {
      body['keyboardPwdName'] = keyboardPwdName.trim();
    }
    final resp = await http.post(
      Uri.parse('$_root/v3/keyboardPwd/get'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    final data = _decode(resp);
    if (data['keyboardPwd'] == null) {
      throw TtlockException(
        'Αποτυχία κωδικού: ${data['errmsg'] ?? friendlyError(data)}',
        data,
      );
    }
    return data;
  }

  /// Back-compat wrapper for period passcodes.
  Future<Map<String, dynamic>> createPeriodPasscode({
    required String accessToken,
    required int lockId,
    required int startDateMs,
    required int endDateMs,
    String? keyboardPwdName,
    int keyboardPwdVersion = 4,
  }) {
    return createPasscode(
      accessToken: accessToken,
      lockId: lockId,
      keyboardPwdType: 3,
      startDateMs: startDateMs,
      endDateMs: endDateMs,
      keyboardPwdName: keyboardPwdName,
      keyboardPwdVersion: keyboardPwdVersion,
    );
  }

  Future<Map<String, dynamic>> addCustomPasscode({
    required String accessToken,
    required int lockId,
    required String keyboardPwd,
    required int startDateMs,
    required int endDateMs,
    String? keyboardPwdName,
    int keyboardPwdType = 3,
    int addType = 2,
  }) async {
    final body = <String, String>{
      'clientId': clientId,
      'accessToken': accessToken,
      'lockId': '$lockId',
      'keyboardPwd': keyboardPwd,
      'keyboardPwdType': '$keyboardPwdType',
      'startDate': '$startDateMs',
      'endDate': '$endDateMs',
      'addType': '$addType',
      'date': '${nowMs()}',
    };
    if (keyboardPwdName != null && keyboardPwdName.trim().isNotEmpty) {
      body['keyboardPwdName'] = keyboardPwdName.trim();
    }
    final resp = await http.post(
      Uri.parse('$_root/v3/keyboardPwd/add'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    final data = _decode(resp);
    final err = data['errcode'];
    if (err != null && err != 0) {
      throw TtlockException(
        'Custom κωδικός απέτυχε: ${data['errmsg'] ?? friendlyError(data)}',
        data,
      );
    }
    if (data['keyboardPwdId'] == null) {
      throw TtlockException('Custom κωδικός απέτυχε', data);
    }
    return data;
  }

  Future<Map<String, dynamic>> deletePasscode({
    required String accessToken,
    required int lockId,
    required int keyboardPwdId,
    int deleteType = 2,
  }) async {
    return _postForm(
      '/v3/keyboardPwd/delete',
      {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'keyboardPwdId': '$keyboardPwdId',
        'deleteType': '$deleteType',
        'date': '${nowMs()}',
      },
      failLabel: 'Διαγραφή κωδικού',
    );
  }

  Future<Map<String, dynamic>> changePasscode({
    required String accessToken,
    required int lockId,
    required int keyboardPwdId,
    String? keyboardPwdName,
    String? newKeyboardPwd,
    int? startDateMs,
    int? endDateMs,
    int changeType = 2,
  }) async {
    final body = <String, String>{
      'clientId': clientId,
      'accessToken': accessToken,
      'lockId': '$lockId',
      'keyboardPwdId': '$keyboardPwdId',
      'changeType': '$changeType',
      'date': '${nowMs()}',
    };
    if (keyboardPwdName != null && keyboardPwdName.trim().isNotEmpty) {
      body['keyboardPwdName'] = keyboardPwdName.trim();
    }
    if (newKeyboardPwd != null && newKeyboardPwd.trim().isNotEmpty) {
      body['newKeyboardPwd'] = newKeyboardPwd.trim();
    }
    if (startDateMs != null) body['startDate'] = '$startDateMs';
    if (endDateMs != null) body['endDate'] = '$endDateMs';
    return _postForm('/v3/keyboardPwd/change', body, failLabel: 'Αλλαγή κωδικού');
  }

  Future<Map<String, dynamic>> listRecords({
    required String accessToken,
    required int lockId,
    int? startDateMs,
    int? endDateMs,
    int pageNo = 1,
    int pageSize = 50,
  }) async {
    final params = <String, String>{
      'clientId': clientId,
      'accessToken': accessToken,
      'lockId': '$lockId',
      'pageNo': '$pageNo',
      'pageSize': '$pageSize',
      'date': '${nowMs()}',
    };
    if (startDateMs != null) params['startDate'] = '$startDateMs';
    if (endDateMs != null) params['endDate'] = '$endDateMs';
    final uri =
        Uri.parse('$_root/v3/lockRecord/list').replace(queryParameters: params);
    return _decode(await http.get(uri));
  }

  Future<Map<String, dynamic>> listKeys({
    required String accessToken,
    required int lockId,
    int pageNo = 1,
    int pageSize = 100,
  }) async {
    final uri = Uri.parse('$_root/v3/lock/listKey').replace(
      queryParameters: {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'pageNo': '$pageNo',
        'pageSize': '$pageSize',
        'date': '${nowMs()}',
      },
    );
    return _decode(await http.get(uri));
  }

  Future<Map<String, dynamic>> sendKey({
    required String accessToken,
    required int lockId,
    required String receiverUsername,
    required String keyName,
    required int startDateMs,
    required int endDateMs,
    String? remarks,
    int remoteEnable = 1,
  }) async {
    final body = <String, String>{
      'clientId': clientId,
      'accessToken': accessToken,
      'lockId': '$lockId',
      'receiverUsername': receiverUsername,
      'keyName': keyName,
      'startDate': '$startDateMs',
      'endDate': '$endDateMs',
      'remoteEnable': '$remoteEnable',
      'date': '${nowMs()}',
    };
    if (remarks != null && remarks.trim().isNotEmpty) {
      body['remarks'] = remarks.trim();
    }
    return _postForm('/v3/key/send', body, failLabel: 'Αποστολή ekey');
  }

  Future<Map<String, dynamic>> deleteKey({
    required String accessToken,
    required int keyId,
  }) async {
    return _postForm(
      '/v3/key/delete',
      {
        'clientId': clientId,
        'accessToken': accessToken,
        'keyId': '$keyId',
        'date': '${nowMs()}',
      },
      failLabel: 'Διαγραφή ekey',
    );
  }

  Future<Map<String, dynamic>> listIdentityCards({
    required String accessToken,
    required int lockId,
    int pageNo = 1,
    int pageSize = 100,
  }) async {
    final uri = Uri.parse('$_root/v3/identityCard/list').replace(
      queryParameters: {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'pageNo': '$pageNo',
        'pageSize': '$pageSize',
        'date': '${nowMs()}',
      },
    );
    return _decode(await http.get(uri));
  }

  Future<Map<String, dynamic>> deleteIdentityCard({
    required String accessToken,
    required int lockId,
    required int cardId,
    int deleteType = 2,
  }) async {
    return _postForm(
      '/v3/identityCard/delete',
      {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'cardId': '$cardId',
        'deleteType': '$deleteType',
        'date': '${nowMs()}',
      },
      failLabel: 'Διαγραφή IC card',
    );
  }

  Future<Map<String, dynamic>> listFingerprints({
    required String accessToken,
    required int lockId,
    int pageNo = 1,
    int pageSize = 100,
  }) async {
    final uri = Uri.parse('$_root/v3/fingerprint/list').replace(
      queryParameters: {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'pageNo': '$pageNo',
        'pageSize': '$pageSize',
        'date': '${nowMs()}',
      },
    );
    return _decode(await http.get(uri));
  }

  Future<Map<String, dynamic>> _postForm(
    String path,
    Map<String, String> body, {
    required String failLabel,
  }) async {
    final resp = await http.post(
      Uri.parse('$_root$path'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    final data = _decode(resp);
    final err = data['errcode'];
    if (err != null && err != 0) {
      throw TtlockException(
        '$failLabel απέτυχε: ${data['errmsg'] ?? friendlyError(data)}',
        data,
      );
    }
    return data;
  }

  Map<String, dynamic> _decode(http.Response resp) {
    Object? decoded;
    try {
      decoded = jsonDecode(resp.body);
    } catch (_) {
      throw TtlockException(
        'Μη έγκυρο JSON (HTTP ${resp.statusCode})',
        resp.body,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw TtlockException('Απρόσμενη απάντηση', decoded);
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TtlockException('HTTP ${resp.statusCode}', decoded);
    }
    return decoded;
  }
}
