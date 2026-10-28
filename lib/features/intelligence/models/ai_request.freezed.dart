// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AiMessage {

 AiRole get role; String get text;
/// Create a copy of AiMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiMessageCopyWith<AiMessage> get copyWith => _$AiMessageCopyWithImpl<AiMessage>(this as AiMessage, _$identity);

  /// Serializes this AiMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiMessage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiMessage&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.text, _this.text) || other.text == _this.text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiMessage;
  return Object.hash(runtimeType,_this.role,_this.text);
}

@override
String toString() {
  final _this = this as AiMessage;
  return 'AiMessage(role: ${_this.role}, text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $AiMessageCopyWith<$Res>  {
  factory $AiMessageCopyWith(AiMessage value, $Res Function(AiMessage) _then) = _$AiMessageCopyWithImpl;
@useResult
$Res call({
 AiRole role, String text
});




}
/// @nodoc
class _$AiMessageCopyWithImpl<$Res>
    implements $AiMessageCopyWith<$Res> {
  _$AiMessageCopyWithImpl(this._self, this._then);

  final AiMessage _self;
  final $Res Function(AiMessage) _then;

/// Create a copy of AiMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,Object? text = null,}) {
  return _then(AiMessage(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as AiRole,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AiMessage].
extension AiMessagePatterns on AiMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiMessage value)  $default,){
final _that = this;
switch (_that) {
case _AiMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiMessage value)?  $default,){
final _that = this;
switch (_that) {
case _AiMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AiRole role,  String text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiMessage() when $default != null:
return $default(_that.role,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AiRole role,  String text)  $default,) {final _that = this;
switch (_that) {
case _AiMessage():
return $default(_that.role,_that.text);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AiRole role,  String text)?  $default,) {final _that = this;
switch (_that) {
case _AiMessage() when $default != null:
return $default(_that.role,_that.text);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiMessage implements AiMessage {
  const _AiMessage({required this.role, required this.text});
  factory _AiMessage.fromJson(Map<String, dynamic> json) => _$AiMessageFromJson(json);

@override final  AiRole role;
@override final  String text;

/// Create a copy of AiMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiMessageCopyWith<_AiMessage> get copyWith => __$AiMessageCopyWithImpl<_AiMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiMessageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiMessage&&(identical(other.role, role) || other.role == role)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,role,text);
}

@override
String toString() {
    return 'AiMessage(role: $role, text: $text)';
}


}

/// @nodoc
abstract mixin class _$AiMessageCopyWith<$Res> implements $AiMessageCopyWith<$Res> {
  factory _$AiMessageCopyWith(_AiMessage value, $Res Function(_AiMessage) _then) = __$AiMessageCopyWithImpl;
@override @useResult
$Res call({
 AiRole role, String text
});




}
/// @nodoc
class __$AiMessageCopyWithImpl<$Res>
    implements _$AiMessageCopyWith<$Res> {
  __$AiMessageCopyWithImpl(this._self, this._then);

  final _AiMessage _self;
  final $Res Function(_AiMessage) _then;

/// Create a copy of AiMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = null,Object? text = null,}) {
  return _then(_AiMessage(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as AiRole,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AiGenerationOptions {

 double get temperature; double get topP; int get topK; int get seed; int? get maxOutputTokens;
/// Create a copy of AiGenerationOptions
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiGenerationOptionsCopyWith<AiGenerationOptions> get copyWith => _$AiGenerationOptionsCopyWithImpl<AiGenerationOptions>(this as AiGenerationOptions, _$identity);

  /// Serializes this AiGenerationOptions to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiGenerationOptions;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiGenerationOptions&&(identical(other.temperature, _this.temperature) || other.temperature == _this.temperature)&&(identical(other.topP, _this.topP) || other.topP == _this.topP)&&(identical(other.topK, _this.topK) || other.topK == _this.topK)&&(identical(other.seed, _this.seed) || other.seed == _this.seed)&&(identical(other.maxOutputTokens, _this.maxOutputTokens) || other.maxOutputTokens == _this.maxOutputTokens));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiGenerationOptions;
  return Object.hash(runtimeType,_this.temperature,_this.topP,_this.topK,_this.seed,_this.maxOutputTokens);
}

@override
String toString() {
  final _this = this as AiGenerationOptions;
  return 'AiGenerationOptions(temperature: ${_this.temperature}, topP: ${_this.topP}, topK: ${_this.topK}, seed: ${_this.seed}, maxOutputTokens: ${_this.maxOutputTokens})';
}


}

/// @nodoc
abstract mixin class $AiGenerationOptionsCopyWith<$Res>  {
  factory $AiGenerationOptionsCopyWith(AiGenerationOptions value, $Res Function(AiGenerationOptions) _then) = _$AiGenerationOptionsCopyWithImpl;
@useResult
$Res call({
 double temperature, double topP, int topK, int seed, int? maxOutputTokens
});




}
/// @nodoc
class _$AiGenerationOptionsCopyWithImpl<$Res>
    implements $AiGenerationOptionsCopyWith<$Res> {
  _$AiGenerationOptionsCopyWithImpl(this._self, this._then);

  final AiGenerationOptions _self;
  final $Res Function(AiGenerationOptions) _then;

/// Create a copy of AiGenerationOptions
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? temperature = null,Object? topP = null,Object? topK = null,Object? seed = null,Object? maxOutputTokens = freezed,}) {
  return _then(AiGenerationOptions(
temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,topP: null == topP ? _self.topP : topP // ignore: cast_nullable_to_non_nullable
as double,topK: null == topK ? _self.topK : topK // ignore: cast_nullable_to_non_nullable
as int,seed: null == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int,maxOutputTokens: freezed == maxOutputTokens ? _self.maxOutputTokens : maxOutputTokens // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [AiGenerationOptions].
extension AiGenerationOptionsPatterns on AiGenerationOptions {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiGenerationOptions value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiGenerationOptions() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiGenerationOptions value)  $default,){
final _that = this;
switch (_that) {
case _AiGenerationOptions():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiGenerationOptions value)?  $default,){
final _that = this;
switch (_that) {
case _AiGenerationOptions() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double temperature,  double topP,  int topK,  int seed,  int? maxOutputTokens)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiGenerationOptions() when $default != null:
return $default(_that.temperature,_that.topP,_that.topK,_that.seed,_that.maxOutputTokens);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double temperature,  double topP,  int topK,  int seed,  int? maxOutputTokens)  $default,) {final _that = this;
switch (_that) {
case _AiGenerationOptions():
return $default(_that.temperature,_that.topP,_that.topK,_that.seed,_that.maxOutputTokens);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double temperature,  double topP,  int topK,  int seed,  int? maxOutputTokens)?  $default,) {final _that = this;
switch (_that) {
case _AiGenerationOptions() when $default != null:
return $default(_that.temperature,_that.topP,_that.topK,_that.seed,_that.maxOutputTokens);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiGenerationOptions implements AiGenerationOptions {
  const _AiGenerationOptions({this.temperature = 1.0, this.topP = 0.95, this.topK = 40, this.seed = 0, this.maxOutputTokens});
  factory _AiGenerationOptions.fromJson(Map<String, dynamic> json) => _$AiGenerationOptionsFromJson(json);

@override@JsonKey() final  double temperature;
@override@JsonKey() final  double topP;
@override@JsonKey() final  int topK;
@override@JsonKey() final  int seed;
@override final  int? maxOutputTokens;

/// Create a copy of AiGenerationOptions
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiGenerationOptionsCopyWith<_AiGenerationOptions> get copyWith => __$AiGenerationOptionsCopyWithImpl<_AiGenerationOptions>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiGenerationOptionsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiGenerationOptions&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.topP, topP) || other.topP == topP)&&(identical(other.topK, topK) || other.topK == topK)&&(identical(other.seed, seed) || other.seed == seed)&&(identical(other.maxOutputTokens, maxOutputTokens) || other.maxOutputTokens == maxOutputTokens));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,temperature,topP,topK,seed,maxOutputTokens);
}

@override
String toString() {
    return 'AiGenerationOptions(temperature: $temperature, topP: $topP, topK: $topK, seed: $seed, maxOutputTokens: $maxOutputTokens)';
}


}

/// @nodoc
abstract mixin class _$AiGenerationOptionsCopyWith<$Res> implements $AiGenerationOptionsCopyWith<$Res> {
  factory _$AiGenerationOptionsCopyWith(_AiGenerationOptions value, $Res Function(_AiGenerationOptions) _then) = __$AiGenerationOptionsCopyWithImpl;
@override @useResult
$Res call({
 double temperature, double topP, int topK, int seed, int? maxOutputTokens
});




}
/// @nodoc
class __$AiGenerationOptionsCopyWithImpl<$Res>
    implements _$AiGenerationOptionsCopyWith<$Res> {
  __$AiGenerationOptionsCopyWithImpl(this._self, this._then);

  final _AiGenerationOptions _self;
  final $Res Function(_AiGenerationOptions) _then;

/// Create a copy of AiGenerationOptions
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? temperature = null,Object? topP = null,Object? topK = null,Object? seed = null,Object? maxOutputTokens = freezed,}) {
  return _then(_AiGenerationOptions(
temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,topP: null == topP ? _self.topP : topP // ignore: cast_nullable_to_non_nullable
as double,topK: null == topK ? _self.topK : topK // ignore: cast_nullable_to_non_nullable
as int,seed: null == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int,maxOutputTokens: freezed == maxOutputTokens ? _self.maxOutputTokens : maxOutputTokens // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$AiRequest {

 List<AiMessage> get messages; AiGenerationOptions get options; Map<String, dynamic>? get responseSchema; String? get modelId; Map<String, String> get metadata;
/// Create a copy of AiRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiRequestCopyWith<AiRequest> get copyWith => _$AiRequestCopyWithImpl<AiRequest>(this as AiRequest, _$identity);

  /// Serializes this AiRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiRequest&&const DeepCollectionEquality().equals(other.messages, _this.messages)&&(identical(other.options, _this.options) || other.options == _this.options)&&const DeepCollectionEquality().equals(other.responseSchema, _this.responseSchema)&&(identical(other.modelId, _this.modelId) || other.modelId == _this.modelId)&&const DeepCollectionEquality().equals(other.metadata, _this.metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiRequest;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.messages),_this.options,const DeepCollectionEquality().hash(_this.responseSchema),_this.modelId,const DeepCollectionEquality().hash(_this.metadata));
}

@override
String toString() {
  final _this = this as AiRequest;
  return 'AiRequest(messages: ${_this.messages}, options: ${_this.options}, responseSchema: ${_this.responseSchema}, modelId: ${_this.modelId}, metadata: ${_this.metadata})';
}


}

/// @nodoc
abstract mixin class $AiRequestCopyWith<$Res>  {
  factory $AiRequestCopyWith(AiRequest value, $Res Function(AiRequest) _then) = _$AiRequestCopyWithImpl;
@useResult
$Res call({
 List<AiMessage> messages, AiGenerationOptions options, Map<String, dynamic>? responseSchema, String? modelId, Map<String, String> metadata
});


$AiGenerationOptionsCopyWith<$Res> get options;

}
/// @nodoc
class _$AiRequestCopyWithImpl<$Res>
    implements $AiRequestCopyWith<$Res> {
  _$AiRequestCopyWithImpl(this._self, this._then);

  final AiRequest _self;
  final $Res Function(AiRequest) _then;

/// Create a copy of AiRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messages = null,Object? options = null,Object? responseSchema = freezed,Object? modelId = freezed,Object? metadata = null,}) {
  return _then(AiRequest(
messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<AiMessage>,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as AiGenerationOptions,responseSchema: freezed == responseSchema ? _self.responseSchema : responseSchema // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}
/// Create a copy of AiRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiGenerationOptionsCopyWith<$Res> get options {
  
  return $AiGenerationOptionsCopyWith<$Res>(_self.options, (value) {
    return _then(_self.copyWith(options: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiRequest].
extension AiRequestPatterns on AiRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiRequest value)  $default,){
final _that = this;
switch (_that) {
case _AiRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiRequest value)?  $default,){
final _that = this;
switch (_that) {
case _AiRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AiMessage> messages,  AiGenerationOptions options,  Map<String, dynamic>? responseSchema,  String? modelId,  Map<String, String> metadata)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiRequest() when $default != null:
return $default(_that.messages,_that.options,_that.responseSchema,_that.modelId,_that.metadata);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AiMessage> messages,  AiGenerationOptions options,  Map<String, dynamic>? responseSchema,  String? modelId,  Map<String, String> metadata)  $default,) {final _that = this;
switch (_that) {
case _AiRequest():
return $default(_that.messages,_that.options,_that.responseSchema,_that.modelId,_that.metadata);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AiMessage> messages,  AiGenerationOptions options,  Map<String, dynamic>? responseSchema,  String? modelId,  Map<String, String> metadata)?  $default,) {final _that = this;
switch (_that) {
case _AiRequest() when $default != null:
return $default(_that.messages,_that.options,_that.responseSchema,_that.modelId,_that.metadata);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiRequest extends AiRequest {
  const _AiRequest({required  List<AiMessage> messages, this.options = const AiGenerationOptions(),  Map<String, dynamic>? responseSchema, this.modelId,  Map<String, String> metadata = const <String, String>{}}): _messages = messages,_responseSchema = responseSchema,_metadata = metadata,super._();
  factory _AiRequest.fromJson(Map<String, dynamic> json) => _$AiRequestFromJson(json);

 final  List<AiMessage> _messages;
@override List<AiMessage> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

@override@JsonKey() final  AiGenerationOptions options;
 final  Map<String, dynamic>? _responseSchema;
@override Map<String, dynamic>? get responseSchema {
  final value = _responseSchema;
  if (value == null) return null;
  if (_responseSchema is EqualUnmodifiableMapView) return _responseSchema;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  String? modelId;
 final  Map<String, String> _metadata;
@override@JsonKey() Map<String, String> get metadata {
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_metadata);
}


/// Create a copy of AiRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiRequestCopyWith<_AiRequest> get copyWith => __$AiRequestCopyWithImpl<_AiRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiRequest&&const DeepCollectionEquality().equals(other.messages, _messages)&&(identical(other.options, options) || other.options == options)&&const DeepCollectionEquality().equals(other.responseSchema, _responseSchema)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&const DeepCollectionEquality().equals(other.metadata, _metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_messages),options,const DeepCollectionEquality().hash(_responseSchema),modelId,const DeepCollectionEquality().hash(_metadata));
}

@override
String toString() {
    return 'AiRequest(messages: $messages, options: $options, responseSchema: $responseSchema, modelId: $modelId, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class _$AiRequestCopyWith<$Res> implements $AiRequestCopyWith<$Res> {
  factory _$AiRequestCopyWith(_AiRequest value, $Res Function(_AiRequest) _then) = __$AiRequestCopyWithImpl;
@override @useResult
$Res call({
 List<AiMessage> messages, AiGenerationOptions options, Map<String, dynamic>? responseSchema, String? modelId, Map<String, String> metadata
});


@override $AiGenerationOptionsCopyWith<$Res> get options;

}
/// @nodoc
class __$AiRequestCopyWithImpl<$Res>
    implements _$AiRequestCopyWith<$Res> {
  __$AiRequestCopyWithImpl(this._self, this._then);

  final _AiRequest _self;
  final $Res Function(_AiRequest) _then;

/// Create a copy of AiRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messages = null,Object? options = null,Object? responseSchema = freezed,Object? modelId = freezed,Object? metadata = null,}) {
  return _then(_AiRequest(
messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<AiMessage>,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as AiGenerationOptions,responseSchema: freezed == responseSchema ? _self._responseSchema : responseSchema // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,metadata: null == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

/// Create a copy of AiRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiGenerationOptionsCopyWith<$Res> get options {
  
  return $AiGenerationOptionsCopyWith<$Res>(_self.options, (value) {
    return _then(_self.copyWith(options: value));
  });
}
}

// dart format on
