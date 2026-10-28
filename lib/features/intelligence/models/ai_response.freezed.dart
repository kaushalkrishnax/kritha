// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AiResponse {

 String get text; String get modelId;@JsonKey(name: 'latencyMs', fromJson: _latencyFromJson, toJson: _latencyToJson) Duration get latency; Map<String, String> get metadata;
/// Create a copy of AiResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiResponseCopyWith<AiResponse> get copyWith => _$AiResponseCopyWithImpl<AiResponse>(this as AiResponse, _$identity);

  /// Serializes this AiResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiResponse&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.modelId, _this.modelId) || other.modelId == _this.modelId)&&(identical(other.latency, _this.latency) || other.latency == _this.latency)&&const DeepCollectionEquality().equals(other.metadata, _this.metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiResponse;
  return Object.hash(runtimeType,_this.text,_this.modelId,_this.latency,const DeepCollectionEquality().hash(_this.metadata));
}

@override
String toString() {
  final _this = this as AiResponse;
  return 'AiResponse(text: ${_this.text}, modelId: ${_this.modelId}, latency: ${_this.latency}, metadata: ${_this.metadata})';
}


}

/// @nodoc
abstract mixin class $AiResponseCopyWith<$Res>  {
  factory $AiResponseCopyWith(AiResponse value, $Res Function(AiResponse) _then) = _$AiResponseCopyWithImpl;
@useResult
$Res call({
 String text, String modelId,@JsonKey(name: 'latencyMs', fromJson: _latencyFromJson, toJson: _latencyToJson) Duration latency, Map<String, String> metadata
});




}
/// @nodoc
class _$AiResponseCopyWithImpl<$Res>
    implements $AiResponseCopyWith<$Res> {
  _$AiResponseCopyWithImpl(this._self, this._then);

  final AiResponse _self;
  final $Res Function(AiResponse) _then;

/// Create a copy of AiResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? modelId = null,Object? latency = null,Object? metadata = null,}) {
  return _then(AiResponse(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,latency: null == latency ? _self.latency : latency // ignore: cast_nullable_to_non_nullable
as Duration,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [AiResponse].
extension AiResponsePatterns on AiResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiResponse value)  $default,){
final _that = this;
switch (_that) {
case _AiResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiResponse value)?  $default,){
final _that = this;
switch (_that) {
case _AiResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  String modelId, @JsonKey(name: 'latencyMs', fromJson: _latencyFromJson, toJson: _latencyToJson)  Duration latency,  Map<String, String> metadata)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiResponse() when $default != null:
return $default(_that.text,_that.modelId,_that.latency,_that.metadata);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  String modelId, @JsonKey(name: 'latencyMs', fromJson: _latencyFromJson, toJson: _latencyToJson)  Duration latency,  Map<String, String> metadata)  $default,) {final _that = this;
switch (_that) {
case _AiResponse():
return $default(_that.text,_that.modelId,_that.latency,_that.metadata);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  String modelId, @JsonKey(name: 'latencyMs', fromJson: _latencyFromJson, toJson: _latencyToJson)  Duration latency,  Map<String, String> metadata)?  $default,) {final _that = this;
switch (_that) {
case _AiResponse() when $default != null:
return $default(_that.text,_that.modelId,_that.latency,_that.metadata);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiResponse implements AiResponse {
  const _AiResponse({required this.text, required this.modelId, @JsonKey(name: 'latencyMs', fromJson: _latencyFromJson, toJson: _latencyToJson) required this.latency,  Map<String, String> metadata = const <String, String>{}}): _metadata = metadata;
  factory _AiResponse.fromJson(Map<String, dynamic> json) => _$AiResponseFromJson(json);

@override final  String text;
@override final  String modelId;
@override@JsonKey(name: 'latencyMs', fromJson: _latencyFromJson, toJson: _latencyToJson) final  Duration latency;
 final  Map<String, String> _metadata;
@override@JsonKey() Map<String, String> get metadata {
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_metadata);
}


/// Create a copy of AiResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiResponseCopyWith<_AiResponse> get copyWith => __$AiResponseCopyWithImpl<_AiResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiResponse&&(identical(other.text, text) || other.text == text)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.latency, latency) || other.latency == latency)&&const DeepCollectionEquality().equals(other.metadata, _metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,text,modelId,latency,const DeepCollectionEquality().hash(_metadata));
}

@override
String toString() {
    return 'AiResponse(text: $text, modelId: $modelId, latency: $latency, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class _$AiResponseCopyWith<$Res> implements $AiResponseCopyWith<$Res> {
  factory _$AiResponseCopyWith(_AiResponse value, $Res Function(_AiResponse) _then) = __$AiResponseCopyWithImpl;
@override @useResult
$Res call({
 String text, String modelId,@JsonKey(name: 'latencyMs', fromJson: _latencyFromJson, toJson: _latencyToJson) Duration latency, Map<String, String> metadata
});




}
/// @nodoc
class __$AiResponseCopyWithImpl<$Res>
    implements _$AiResponseCopyWith<$Res> {
  __$AiResponseCopyWithImpl(this._self, this._then);

  final _AiResponse _self;
  final $Res Function(_AiResponse) _then;

/// Create a copy of AiResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? modelId = null,Object? latency = null,Object? metadata = null,}) {
  return _then(_AiResponse(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,latency: null == latency ? _self.latency : latency // ignore: cast_nullable_to_non_nullable
as Duration,metadata: null == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

// dart format on
