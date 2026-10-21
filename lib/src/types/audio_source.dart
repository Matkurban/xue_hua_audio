import 'package:flutter/foundation.dart';

/// A type-safe description of where audio data comes from.
///
/// Use one of the three factory constructors:
/// [AudioSource.file], [AudioSource.url] or [AudioSource.asset].
///
/// 描述音频数据来源的类型安全模型。
///
/// 请使用三个工厂构造函数之一：
/// [AudioSource.file]（本地文件）、[AudioSource.url]（网络地址）、
/// [AudioSource.asset]（Flutter Asset 资源）。
@immutable
sealed class AudioSource {
  const AudioSource();

  /// Creates a source backed by a local file.
  ///
  /// [path]: absolute path of the audio file on the local file system.
  ///
  /// 创建一个基于本地文件的音频源。
  ///
  /// [path]：本地文件系统上音频文件的绝对路径。
  const factory AudioSource.file(String path) = FileSource;

  /// Creates a source backed by a remote HTTP(S) URL.
  ///
  /// [url]: the remote audio URL.
  /// [headers]: optional HTTP request headers sent when fetching the audio
  /// (ignored on Web, where the browser controls the request).
  ///
  /// 创建一个基于远程 HTTP(S) 地址的音频源。
  ///
  /// [url]：远程音频地址。
  /// [headers]：请求音频时附带的可选 HTTP 请求头（Web 端由浏览器控制请求，
  /// 该参数会被忽略）。
  const factory AudioSource.url(String url, {Map<String, String>? headers}) =
      UrlSource;

  /// Creates a source backed by a Flutter asset.
  ///
  /// [key]: the asset key as declared in `pubspec.yaml`,
  /// e.g. `assets/audio/ring.wav`.
  /// [package]: when the asset belongs to another package, its package name.
  ///
  /// 创建一个基于 Flutter Asset 资源的音频源。
  ///
  /// [key]：在 `pubspec.yaml` 中声明的资源键，例如 `assets/audio/ring.wav`。
  /// [package]：当资源属于其他 package 时，填写其包名。
  const factory AudioSource.asset(String key, {String? package}) = AssetSource;
}

/// An [AudioSource] backed by a local file. / 基于本地文件的音频源。
final class FileSource extends AudioSource {
  /// Creates a local-file source with the given [path].
  /// 使用给定的 [path] 创建本地文件音频源。
  const FileSource(this.path);

  /// Absolute path of the audio file. / 音频文件的绝对路径。
  final String path;

  @override
  bool operator ==(Object other) => other is FileSource && other.path == path;

  @override
  int get hashCode => Object.hash(runtimeType, path);

  @override
  String toString() => 'AudioSource.file($path)';
}

/// An [AudioSource] backed by a remote URL. / 基于远程地址的音频源。
final class UrlSource extends AudioSource {
  /// Creates a URL source with the given [url] and optional [headers].
  /// 使用给定的 [url] 与可选的 [headers] 创建网络音频源。
  const UrlSource(this.url, {this.headers});

  /// The remote audio URL. / 远程音频地址。
  final String url;

  /// Optional HTTP request headers. / 可选的 HTTP 请求头。
  final Map<String, String>? headers;

  @override
  bool operator ==(Object other) =>
      other is UrlSource &&
      other.url == url &&
      mapEquals(other.headers, headers);

  @override
  int get hashCode => Object.hash(runtimeType, url, headers);

  @override
  String toString() => 'AudioSource.url($url)';
}

/// An [AudioSource] backed by a Flutter asset. / 基于 Flutter Asset 资源的音频源。
final class AssetSource extends AudioSource {
  /// Creates an asset source with the given [key] and optional [package].
  /// 使用给定的 [key] 与可选的 [package] 创建 Asset 音频源。
  const AssetSource(this.key, {this.package});

  /// The asset key declared in `pubspec.yaml`. / 在 `pubspec.yaml` 中声明的资源键。
  final String key;

  /// The owning package name, when the asset comes from another package.
  /// 当资源来自其他 package 时的包名。
  final String? package;

  /// The fully-resolved asset key used by the Flutter engine, including the
  /// `packages/<package>/` prefix when [package] is set.
  ///
  /// 返回 Flutter 引擎实际使用的完整资源键；当设置了 [package] 时会带上
  /// `packages/<package>/` 前缀。
  String get resolvedKey => package == null ? key : 'packages/$package/$key';

  @override
  bool operator ==(Object other) =>
      other is AssetSource && other.key == key && other.package == package;

  @override
  int get hashCode => Object.hash(runtimeType, key, package);

  @override
  String toString() => 'AudioSource.asset($key, package: $package)';
}
