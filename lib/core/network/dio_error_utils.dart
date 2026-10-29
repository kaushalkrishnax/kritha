import 'dart:io';

import 'package:dio/dio.dart';

bool isNetworkUnavailable(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    error.type == DioExceptionType.receiveTimeout ||
    error.type == DioExceptionType.sendTimeout ||
    error.error is SocketException;
