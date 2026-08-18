// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recording.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$XueHuaRecordingEvent {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XueHuaRecordingEvent&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'XueHuaRecordingEvent(field0: $field0)';
}


}

/// @nodoc
class $XueHuaRecordingEventCopyWith<$Res>  {
$XueHuaRecordingEventCopyWith(XueHuaRecordingEvent _, $Res Function(XueHuaRecordingEvent) __);
}


/// Adds pattern-matching-related methods to [XueHuaRecordingEvent].
extension XueHuaRecordingEventPatterns on XueHuaRecordingEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( XueHuaRecordingEvent_Progress value)?  progress,TResult Function( XueHuaRecordingEvent_Completed value)?  completed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case XueHuaRecordingEvent_Progress() when progress != null:
return progress(_that);case XueHuaRecordingEvent_Completed() when completed != null:
return completed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( XueHuaRecordingEvent_Progress value)  progress,required TResult Function( XueHuaRecordingEvent_Completed value)  completed,}){
final _that = this;
switch (_that) {
case XueHuaRecordingEvent_Progress():
return progress(_that);case XueHuaRecordingEvent_Completed():
return completed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( XueHuaRecordingEvent_Progress value)?  progress,TResult? Function( XueHuaRecordingEvent_Completed value)?  completed,}){
final _that = this;
switch (_that) {
case XueHuaRecordingEvent_Progress() when progress != null:
return progress(_that);case XueHuaRecordingEvent_Completed() when completed != null:
return completed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( XueHuaRecordingProgress field0)?  progress,TResult Function( XueHuaRecordingCompleted field0)?  completed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case XueHuaRecordingEvent_Progress() when progress != null:
return progress(_that.field0);case XueHuaRecordingEvent_Completed() when completed != null:
return completed(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( XueHuaRecordingProgress field0)  progress,required TResult Function( XueHuaRecordingCompleted field0)  completed,}) {final _that = this;
switch (_that) {
case XueHuaRecordingEvent_Progress():
return progress(_that.field0);case XueHuaRecordingEvent_Completed():
return completed(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( XueHuaRecordingProgress field0)?  progress,TResult? Function( XueHuaRecordingCompleted field0)?  completed,}) {final _that = this;
switch (_that) {
case XueHuaRecordingEvent_Progress() when progress != null:
return progress(_that.field0);case XueHuaRecordingEvent_Completed() when completed != null:
return completed(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class XueHuaRecordingEvent_Progress extends XueHuaRecordingEvent {
  const XueHuaRecordingEvent_Progress(this.field0): super._();
  

@override final  XueHuaRecordingProgress field0;

/// Create a copy of XueHuaRecordingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XueHuaRecordingEvent_ProgressCopyWith<XueHuaRecordingEvent_Progress> get copyWith => _$XueHuaRecordingEvent_ProgressCopyWithImpl<XueHuaRecordingEvent_Progress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XueHuaRecordingEvent_Progress&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'XueHuaRecordingEvent.progress(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $XueHuaRecordingEvent_ProgressCopyWith<$Res> implements $XueHuaRecordingEventCopyWith<$Res> {
  factory $XueHuaRecordingEvent_ProgressCopyWith(XueHuaRecordingEvent_Progress value, $Res Function(XueHuaRecordingEvent_Progress) _then) = _$XueHuaRecordingEvent_ProgressCopyWithImpl;
@useResult
$Res call({
 XueHuaRecordingProgress field0
});




}
/// @nodoc
class _$XueHuaRecordingEvent_ProgressCopyWithImpl<$Res>
    implements $XueHuaRecordingEvent_ProgressCopyWith<$Res> {
  _$XueHuaRecordingEvent_ProgressCopyWithImpl(this._self, this._then);

  final XueHuaRecordingEvent_Progress _self;
  final $Res Function(XueHuaRecordingEvent_Progress) _then;

/// Create a copy of XueHuaRecordingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(XueHuaRecordingEvent_Progress(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as XueHuaRecordingProgress,
  ));
}


}

/// @nodoc


class XueHuaRecordingEvent_Completed extends XueHuaRecordingEvent {
  const XueHuaRecordingEvent_Completed(this.field0): super._();
  

@override final  XueHuaRecordingCompleted field0;

/// Create a copy of XueHuaRecordingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XueHuaRecordingEvent_CompletedCopyWith<XueHuaRecordingEvent_Completed> get copyWith => _$XueHuaRecordingEvent_CompletedCopyWithImpl<XueHuaRecordingEvent_Completed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XueHuaRecordingEvent_Completed&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'XueHuaRecordingEvent.completed(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $XueHuaRecordingEvent_CompletedCopyWith<$Res> implements $XueHuaRecordingEventCopyWith<$Res> {
  factory $XueHuaRecordingEvent_CompletedCopyWith(XueHuaRecordingEvent_Completed value, $Res Function(XueHuaRecordingEvent_Completed) _then) = _$XueHuaRecordingEvent_CompletedCopyWithImpl;
@useResult
$Res call({
 XueHuaRecordingCompleted field0
});




}
/// @nodoc
class _$XueHuaRecordingEvent_CompletedCopyWithImpl<$Res>
    implements $XueHuaRecordingEvent_CompletedCopyWith<$Res> {
  _$XueHuaRecordingEvent_CompletedCopyWithImpl(this._self, this._then);

  final XueHuaRecordingEvent_Completed _self;
  final $Res Function(XueHuaRecordingEvent_Completed) _then;

/// Create a copy of XueHuaRecordingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(XueHuaRecordingEvent_Completed(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as XueHuaRecordingCompleted,
  ));
}


}

// dart format on
