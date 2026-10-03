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
  }) async {
    final uri = Uri.parse('$_root/v3/lock/list').replace(
      queryParameters: {
        'clientId': clientId,
        'accessToken': accessToken,
        'pageNo': '$pageNo',
        'pageSize': '$pageSize',
        'date': '${nowMs()}',
      },
    );
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

  Future<Map<String, dynamic>> unlock({
    required String accessToken,
    required int lockId,
  }) async {
    final resp = await http.post(
      Uri.parse('$_root/v3/lock/unlock'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'clientId': clientId,
        'accessToken': accessToken,
        'lockId': '$lockId',
        'date': '${nowMs()}',
      },
    );
    final data = _decode(resp);
    final err = data['errcode'];
    if (err != null && err != 0) {
      throw TtlockException(
        'Unlock απέτυχε: ${data['errmsg'] ?? data}',
        data,
      );
    }
    return data;
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

  Future<Map<String, dynamic>> createPeriodPasscode({
    required String accessToken,
    required int lockId,
    required int startDateMs,
    required int endDateMs,
    String? keyboardPwdName,
    int keyboardPwdVersion = 4,
  }) async {
    final body = <String, String>{
      'clientId': clientId,
      'accessToken': accessToken,
      'lockId': '$lockId',
      'keyboardPwdVersion': '$keyboardPwdVersion',
      'keyboardPwdType': '3',
      'startDate': '$startDateMs',
      'endDate': '$endDateMs',
      'date': '${nowMs()}',
    };
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
        'Αποτυχία κωδικού: ${data['errmsg'] ?? data}',
        data,
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> addCustomPasscode({
    required String accessToken,
    required int lockId,
    required String keyboardPwd,
    required int startDateMs,
    required int endDateMs,
    String? keyboardPwdName,
    int addType = 2,
  }) async {
    final body = <String, String>{
      'clientId': clientId,
      'accessToken': accessToken,
      'lockId': '$lockId',
      'keyboardPwd': keyboardPwd,
      'keyboardPwdType': '3',
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
        'Custom κωδικός απέτυχε: ${data['errmsg'] ?? data}',
        data,
      );
    }
    if (data['keyboardPwdId'] == null) {
      throw TtlockException('Custom κωδικός απέτυχε', data);
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
