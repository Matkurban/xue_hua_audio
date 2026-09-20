# AudioSource

Sealed, immutable description of where audio data comes from. Prefer the
three factories on `AudioSource`. The concrete classes `FileSource`,
`UrlSource`, and `AssetSource` are also exported.

Source: `xue_hua_audio_platform_interface` → `lib/src/types/audio_source.dart`,
re-exported by `package:xue_hua_audio`.

```dart
@immutable
sealed class AudioSource {
  const AudioSource();
}
```

---

## Factories

### `const factory AudioSource.file(String path) = FileSource`

Local-file source.

| Parameter | Type | Meaning |
| --- | --- | --- |
| `path` | `String` | Absolute path of the audio file on the local file system. |

### `const factory AudioSource.url(String url, {Map<String, String>? headers}) = UrlSource`

Remote HTTP(S) source. Network audio is streamed natively.

| Parameter | Type | Meaning |
| --- | --- | --- |
| `url` | `String` | Remote audio URL. |
| `headers` | `Map<String, String>?` | Optional HTTP request headers sent when fetching the audio. **Ignored on Web** (the browser controls the request). |

### `const factory AudioSource.asset(String key, {String? package}) = AssetSource`

Flutter asset source.

| Parameter | Type | Meaning |
| --- | --- | --- |
| `key` | `String` | Asset key as declared in `pubspec.yaml`, e.g. `assets/audio/ring.wav`. |
| `package` | `String?` | Owning package name when the asset belongs to another package. |

Declare the asset in the app (or package) `pubspec.yaml` `flutter: assets:` list.

---

## FileSource

`final class FileSource extends AudioSource`

### `const FileSource(this.path)`

Equivalent to `AudioSource.file(path)`.

### `final String path`

Absolute path of the audio file.

### `bool operator ==(Object other)`

Equal when `other` is a `FileSource` with the same `path`.

### `int get hashCode`

`Object.hash(runtimeType, path)`.

### `String toString()`

`'AudioSource.file($path)'`.

---

## UrlSource

`final class UrlSource extends AudioSource`

### `const UrlSource(this.url, {this.headers})`

Equivalent to `AudioSource.url(url, headers: headers)`.

### `final String url`

Remote audio URL.

### `final Map<String, String>? headers`

Optional HTTP request headers. Ignored on Web.

### `bool operator ==(Object other)`

Equal when `other` is a `UrlSource` with the same `url` and
`mapEquals` headers.

### `int get hashCode`

`Object.hash(runtimeType, url, headers)`.

### `String toString()`

`'AudioSource.url($url)'` (headers are not included in the string).

---

## AssetSource

`final class AssetSource extends AudioSource`

### `const AssetSource(this.key, {this.package})`

Equivalent to `AudioSource.asset(key, package: package)`.

### `final String key`

Asset key declared in `pubspec.yaml`.

### `final String? package`

Owning package name when the asset comes from another package.

### `String get resolvedKey`

Fully-resolved key used by the Flutter engine:

* `package == null` → `key`
* otherwise → `'packages/$package/$key'`

### `bool operator ==(Object other)`

Equal when `other` is an `AssetSource` with the same `key` and `package`.

### `int get hashCode`

`Object.hash(runtimeType, key, package)`.

### `String toString()`

`'AudioSource.asset($key, package: $package)'`.
