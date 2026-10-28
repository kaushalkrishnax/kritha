// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_descriptor.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ModelDescriptor {

 String get id; String get displayName; String get runtimeId; ModelCapabilities get capabilities; String? get modelPath;
/// Create a copy of ModelDescriptor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelDescriptorCopyWith<ModelDescriptor> get copyWith => _$ModelDescriptorCopyWithImpl<ModelDescriptor>(this as ModelDescriptor, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ModelDescriptor;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelDescriptor&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.runtimeId, _this.runtimeId) || other.runtimeId == _this.runtimeId)&&(identical(other.capabilities, _this.capabilities) || other.capabilities == _this.capabilities)&&(identical(other.modelPath, _this.modelPath) || other.modelPath == _this.modelPath));
}


@override
int get hashCode {
  final _this = this as ModelDescriptor;
  return Object.hash(runtimeType,_this.id,_this.displayName,_this.runtimeId,_this.capabilities,_this.modelPath);
}

@override
String toString() {
  final _this = this as ModelDescriptor;
  return 'ModelDescriptor(id: ${_this.id}, displayName: ${_this.displayName}, runtimeId: ${_this.runtimeId}, capabilities: ${_this.capabilities}, modelPath: ${_this.modelPath})';
}


}

/// @nodoc
abstract mixin class $ModelDescriptorCopyWith<$Res>  {
  factory $ModelDescriptorCopyWith(ModelDescriptor value, $Res Function(ModelDescriptor) _then) = _$ModelDescriptorCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, String runtimeId, ModelCapabilities capabilities, String? modelPath
});


$ModelCapabilitiesCopyWith<$Res> get capabilities;

}
/// @nodoc
class _$ModelDescriptorCopyWithImpl<$Res>
    implements $ModelDescriptorCopyWith<$Res> {
  _$ModelDescriptorCopyWithImpl(this._self, this._then);

  final ModelDescriptor _self;
  final $Res Function(ModelDescriptor) _then;

/// Create a copy of ModelDescriptor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? runtimeId = null,Object? capabilities = null,Object? modelPath = freezed,}) {
  return _then(ModelDescriptor(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,runtimeId: null == runtimeId ? _self.runtimeId : runtimeId // ignore: cast_nullable_to_non_nullable
as String,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as ModelCapabilities,modelPath: freezed == modelPath ? _self.modelPath : modelPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ModelDescriptor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelCapabilitiesCopyWith<$Res> get capabilities {
  
  return $ModelCapabilitiesCopyWith<$Res>(_self.capabilities, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}
}


/// Adds pattern-matching-related methods to [ModelDescriptor].
extension ModelDescriptorPatterns on ModelDescriptor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelDescriptor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelDescriptor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelDescriptor value)  $default,){
final _that = this;
switch (_that) {
case _ModelDescriptor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelDescriptor value)?  $default,){
final _that = this;
switch (_that) {
case _ModelDescriptor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  String runtimeId,  ModelCapabilities capabilities,  String? modelPath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelDescriptor() when $default != null:
return $default(_that.id,_that.displayName,_that.runtimeId,_that.capabilities,_that.modelPath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  String runtimeId,  ModelCapabilities capabilities,  String? modelPath)  $default,) {final _that = this;
switch (_that) {
case _ModelDescriptor():
return $default(_that.id,_that.displayName,_that.runtimeId,_that.capabilities,_that.modelPath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  String runtimeId,  ModelCapabilities capabilities,  String? modelPath)?  $default,) {final _that = this;
switch (_that) {
case _ModelDescriptor() when $default != null:
return $default(_that.id,_that.displayName,_that.runtimeId,_that.capabilities,_that.modelPath);case _:
  return null;

}
}

}

/// @nodoc


class _ModelDescriptor implements ModelDescriptor {
  const _ModelDescriptor({required this.id, required this.displayName, required this.runtimeId, required this.capabilities, this.modelPath});
  

@override final  String id;
@override final  String displayName;
@override final  String runtimeId;
@override final  ModelCapabilities capabilities;
@override final  String? modelPath;

/// Create a copy of ModelDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelDescriptorCopyWith<_ModelDescriptor> get copyWith => __$ModelDescriptorCopyWithImpl<_ModelDescriptor>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelDescriptor&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.runtimeId, runtimeId) || other.runtimeId == runtimeId)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities)&&(identical(other.modelPath, modelPath) || other.modelPath == modelPath));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,displayName,runtimeId,capabilities,modelPath);
}

@override
String toString() {
    return 'ModelDescriptor(id: $id, displayName: $displayName, runtimeId: $runtimeId, capabilities: $capabilities, modelPath: $modelPath)';
}


}

/// @nodoc
abstract mixin class _$ModelDescriptorCopyWith<$Res> implements $ModelDescriptorCopyWith<$Res> {
  factory _$ModelDescriptorCopyWith(_ModelDescriptor value, $Res Function(_ModelDescriptor) _then) = __$ModelDescriptorCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, String runtimeId, ModelCapabilities capabilities, String? modelPath
});


@override $ModelCapabilitiesCopyWith<$Res> get capabilities;

}
/// @nodoc
class __$ModelDescriptorCopyWithImpl<$Res>
    implements _$ModelDescriptorCopyWith<$Res> {
  __$ModelDescriptorCopyWithImpl(this._self, this._then);

  final _ModelDescriptor _self;
  final $Res Function(_ModelDescriptor) _then;

/// Create a copy of ModelDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? runtimeId = null,Object? capabilities = null,Object? modelPath = freezed,}) {
  return _then(_ModelDescriptor(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,runtimeId: null == runtimeId ? _self.runtimeId : runtimeId // ignore: cast_nullable_to_non_nullable
as String,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as ModelCapabilities,modelPath: freezed == modelPath ? _self.modelPath : modelPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ModelDescriptor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelCapabilitiesCopyWith<$Res> get capabilities {
  
  return $ModelCapabilitiesCopyWith<$Res>(_self.capabilities, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}
}

// dart format on
