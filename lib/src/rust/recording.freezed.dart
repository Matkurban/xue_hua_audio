// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recording.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$XueHuaRecordingEvent {
  Object get field0 => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(XueHuaRecordingProgress field0) progress,
    required TResult Function(XueHuaRecordingCompleted field0) completed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(XueHuaRecordingProgress field0)? progress,
    TResult? Function(XueHuaRecordingCompleted field0)? completed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(XueHuaRecordingProgress field0)? progress,
    TResult Function(XueHuaRecordingCompleted field0)? completed,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(XueHuaRecordingEvent_Progress value) progress,
    required TResult Function(XueHuaRecordingEvent_Completed value) completed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(XueHuaRecordingEvent_Progress value)? progress,
    TResult? Function(XueHuaRecordingEvent_Completed value)? completed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(XueHuaRecordingEvent_Progress value)? progress,
    TResult Function(XueHuaRecordingEvent_Completed value)? completed,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $XueHuaRecordingEventCopyWith<$Res> {
  factory $XueHuaRecordingEventCopyWith(
    XueHuaRecordingEvent value,
    $Res Function(XueHuaRecordingEvent) then,
  ) = _$XueHuaRecordingEventCopyWithImpl<$Res, XueHuaRecordingEvent>;
}

/// @nodoc
class _$XueHuaRecordingEventCopyWithImpl<
  $Res,
  $Val extends XueHuaRecordingEvent
>
    implements $XueHuaRecordingEventCopyWith<$Res> {
  _$XueHuaRecordingEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of XueHuaRecordingEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$XueHuaRecordingEvent_ProgressImplCopyWith<$Res> {
  factory _$$XueHuaRecordingEvent_ProgressImplCopyWith(
    _$XueHuaRecordingEvent_ProgressImpl value,
    $Res Function(_$XueHuaRecordingEvent_ProgressImpl) then,
  ) = __$$XueHuaRecordingEvent_ProgressImplCopyWithImpl<$Res>;
  @useResult
  $Res call({XueHuaRecordingProgress field0});
}

/// @nodoc
class __$$XueHuaRecordingEvent_ProgressImplCopyWithImpl<$Res>
    extends
        _$XueHuaRecordingEventCopyWithImpl<
          $Res,
          _$XueHuaRecordingEvent_ProgressImpl
        >
    implements _$$XueHuaRecordingEvent_ProgressImplCopyWith<$Res> {
  __$$XueHuaRecordingEvent_ProgressImplCopyWithImpl(
    _$XueHuaRecordingEvent_ProgressImpl _value,
    $Res Function(_$XueHuaRecordingEvent_ProgressImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of XueHuaRecordingEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$XueHuaRecordingEvent_ProgressImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as XueHuaRecordingProgress,
      ),
    );
  }
}

/// @nodoc

class _$XueHuaRecordingEvent_ProgressImpl
    extends XueHuaRecordingEvent_Progress {
  const _$XueHuaRecordingEvent_ProgressImpl(this.field0) : super._();

  @override
  final XueHuaRecordingProgress field0;

  @override
  String toString() {
    return 'XueHuaRecordingEvent.progress(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$XueHuaRecordingEvent_ProgressImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of XueHuaRecordingEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$XueHuaRecordingEvent_ProgressImplCopyWith<
    _$XueHuaRecordingEvent_ProgressImpl
  >
  get copyWith =>
      __$$XueHuaRecordingEvent_ProgressImplCopyWithImpl<
        _$XueHuaRecordingEvent_ProgressImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(XueHuaRecordingProgress field0) progress,
    required TResult Function(XueHuaRecordingCompleted field0) completed,
  }) {
    return progress(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(XueHuaRecordingProgress field0)? progress,
    TResult? Function(XueHuaRecordingCompleted field0)? completed,
  }) {
    return progress?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(XueHuaRecordingProgress field0)? progress,
    TResult Function(XueHuaRecordingCompleted field0)? completed,
    required TResult orElse(),
  }) {
    if (progress != null) {
      return progress(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(XueHuaRecordingEvent_Progress value) progress,
    required TResult Function(XueHuaRecordingEvent_Completed value) completed,
  }) {
    return progress(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(XueHuaRecordingEvent_Progress value)? progress,
    TResult? Function(XueHuaRecordingEvent_Completed value)? completed,
  }) {
    return progress?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(XueHuaRecordingEvent_Progress value)? progress,
    TResult Function(XueHuaRecordingEvent_Completed value)? completed,
    required TResult orElse(),
  }) {
    if (progress != null) {
      return progress(this);
    }
    return orElse();
  }
}

abstract class XueHuaRecordingEvent_Progress extends XueHuaRecordingEvent {
  const factory XueHuaRecordingEvent_Progress(
    final XueHuaRecordingProgress field0,
  ) = _$XueHuaRecordingEvent_ProgressImpl;
  const XueHuaRecordingEvent_Progress._() : super._();

  @override
  XueHuaRecordingProgress get field0;

  /// Create a copy of XueHuaRecordingEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$XueHuaRecordingEvent_ProgressImplCopyWith<
    _$XueHuaRecordingEvent_ProgressImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$XueHuaRecordingEvent_CompletedImplCopyWith<$Res> {
  factory _$$XueHuaRecordingEvent_CompletedImplCopyWith(
    _$XueHuaRecordingEvent_CompletedImpl value,
    $Res Function(_$XueHuaRecordingEvent_CompletedImpl) then,
  ) = __$$XueHuaRecordingEvent_CompletedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({XueHuaRecordingCompleted field0});
}

/// @nodoc
class __$$XueHuaRecordingEvent_CompletedImplCopyWithImpl<$Res>
    extends
        _$XueHuaRecordingEventCopyWithImpl<
          $Res,
          _$XueHuaRecordingEvent_CompletedImpl
        >
    implements _$$XueHuaRecordingEvent_CompletedImplCopyWith<$Res> {
  __$$XueHuaRecordingEvent_CompletedImplCopyWithImpl(
    _$XueHuaRecordingEvent_CompletedImpl _value,
    $Res Function(_$XueHuaRecordingEvent_CompletedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of XueHuaRecordingEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$XueHuaRecordingEvent_CompletedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as XueHuaRecordingCompleted,
      ),
    );
  }
}

/// @nodoc

class _$XueHuaRecordingEvent_CompletedImpl
    extends XueHuaRecordingEvent_Completed {
  const _$XueHuaRecordingEvent_CompletedImpl(this.field0) : super._();

  @override
  final XueHuaRecordingCompleted field0;

  @override
  String toString() {
    return 'XueHuaRecordingEvent.completed(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$XueHuaRecordingEvent_CompletedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of XueHuaRecordingEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$XueHuaRecordingEvent_CompletedImplCopyWith<
    _$XueHuaRecordingEvent_CompletedImpl
  >
  get copyWith =>
      __$$XueHuaRecordingEvent_CompletedImplCopyWithImpl<
        _$XueHuaRecordingEvent_CompletedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(XueHuaRecordingProgress field0) progress,
    required TResult Function(XueHuaRecordingCompleted field0) completed,
  }) {
    return completed(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(XueHuaRecordingProgress field0)? progress,
    TResult? Function(XueHuaRecordingCompleted field0)? completed,
  }) {
    return completed?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(XueHuaRecordingProgress field0)? progress,
    TResult Function(XueHuaRecordingCompleted field0)? completed,
    required TResult orElse(),
  }) {
    if (completed != null) {
      return completed(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(XueHuaRecordingEvent_Progress value) progress,
    required TResult Function(XueHuaRecordingEvent_Completed value) completed,
  }) {
    return completed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(XueHuaRecordingEvent_Progress value)? progress,
    TResult? Function(XueHuaRecordingEvent_Completed value)? completed,
  }) {
    return completed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(XueHuaRecordingEvent_Progress value)? progress,
    TResult Function(XueHuaRecordingEvent_Completed value)? completed,
    required TResult orElse(),
  }) {
    if (completed != null) {
      return completed(this);
    }
    return orElse();
  }
}

abstract class XueHuaRecordingEvent_Completed extends XueHuaRecordingEvent {
  const factory XueHuaRecordingEvent_Completed(
    final XueHuaRecordingCompleted field0,
  ) = _$XueHuaRecordingEvent_CompletedImpl;
  const XueHuaRecordingEvent_Completed._() : super._();

  @override
  XueHuaRecordingCompleted get field0;

  /// Create a copy of XueHuaRecordingEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$XueHuaRecordingEvent_CompletedImplCopyWith<
    _$XueHuaRecordingEvent_CompletedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}
