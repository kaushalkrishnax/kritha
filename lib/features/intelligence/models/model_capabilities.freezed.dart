// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_capabilities.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ModelCapabilities {

 Set<InferenceCapability> get supported;
/// Create a copy of ModelCapabilities
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelCapabilitiesCopyWith<ModelCapabilities> get copyWith => _$ModelCapabilitiesCopyWithImpl<ModelCapabilities>(this as ModelCapabilities, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ModelCapabilities;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelCapabilities&&const DeepCollectionEquality().equals(other.supported, _this.supported));
}


@override
int get hashCode {
  final _this = this as ModelCapabilities;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.supported));
}

@override
String toString() {
  final _this = this as ModelCapabilities;
  return 'ModelCapabilities(supported: ${_this.supported})';
}


}

/// @nodoc
abstract mixin class $ModelCapabilitiesCopyWith<$Res>  {
  factory $ModelCapabilitiesCopyWith(ModelCapabilities value, $Res Function(ModelCapabilities) _then) = _$ModelCapabilitiesCopyWithImpl;
@useResult
$Res call({
 Set<InferenceCapability> supported
});




}
/// @nodoc
class _$ModelCapabilitiesCopyWithImpl<$Res>
    implements $ModelCapabilitiesCopyWith<$Res> {
  _$ModelCapabilitiesCopyWithImpl(this._self, this._then);

  final ModelCapabilities _self;
  final $Res Function(ModelCapabilities) _then;

/// Create a copy of ModelCapabilities
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? supported = null,}) {
  return _then(ModelCapabilities(
supported: null == supported ? _self.supported : supported // ignore: cast_nullable_to_non_nullable
as Set<InferenceCapability>,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelCapabilities].
extension ModelCapabilitiesPatterns on ModelCapabilities {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelCapabilities value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelCapabilities() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelCapabilities value)  $default,){
final _that = this;
switch (_that) {
case _ModelCapabilities():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelCapabilities value)?  $default,){
final _that = this;
switch (_that) {
case _ModelCapabilities() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Set<InferenceCapability> supported)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelCapabilities() when $default != null:
return $default(_that.supported);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Set<InferenceCapability> supported)  $default,) {final _that = this;
switch (_that) {
case _ModelCapabilities():
return $default(_that.supported);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Set<InferenceCapability> supported)?  $default,) {final _that = this;
switch (_that) {
case _ModelCapabilities() when $default != null:
return $default(_that.supported);case _:
  return null;

}
}

}

/// @nodoc


class _ModelCapabilities extends ModelCapabilities {
  const _ModelCapabilities({ Set<InferenceCapability> supported = const <InferenceCapability>{}}): _supported = supported,super._();
  

 final  Set<InferenceCapability> _supported;
@override@JsonKey() Set<InferenceCapability> get supported {
  if (_supported is EqualUnmodifiableSetView) return _supported;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_supported);
}


/// Create a copy of ModelCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelCapabilitiesCopyWith<_ModelCapabilities> get copyWith => __$ModelCapabilitiesCopyWithImpl<_ModelCapabilities>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelCapabilities&&const DeepCollectionEquality().equals(other.supported, _supported));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_supported));
}

@override
String toString() {
    return 'ModelCapabilities(supported: $supported)';
}


}

/// @nodoc
abstract mixin class _$ModelCapabilitiesCopyWith<$Res> implements $ModelCapabilitiesCopyWith<$Res> {
  factory _$ModelCapabilitiesCopyWith(_ModelCapabilities value, $Res Function(_ModelCapabilities) _then) = __$ModelCapabilitiesCopyWithImpl;
@override @useResult
$Res call({
 Set<InferenceCapability> supported
});




}
/// @nodoc
class __$ModelCapabilitiesCopyWithImpl<$Res>
    implements _$ModelCapabilitiesCopyWith<$Res> {
  __$ModelCapabilitiesCopyWithImpl(this._self, this._then);

  final _ModelCapabilities _self;
  final $Res Function(_ModelCapabilities) _then;

/// Create a copy of ModelCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? supported = null,}) {
  return _then(_ModelCapabilities(
supported: null == supported ? _self._supported : supported // ignore: cast_nullable_to_non_nullable
as Set<InferenceCapability>,
  ));
}


}

// dart format on
