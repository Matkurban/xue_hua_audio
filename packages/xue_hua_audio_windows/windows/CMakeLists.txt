# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "xue_hua_audio_windows")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "xue_hua_audio_windows_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "event_stream.h"
  "main_thread_dispatcher.h"
  "messages.g.cpp"
  "messages.g.h"
  "windows_player.cpp"
  "windows_player.h"
  "windows_recorder.cpp"
  "windows_recorder.h"
  "xue_hua_audio_windows_plugin.cpp"
  "xue_hua_audio_windows_plugin.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/xue_hua_audio_windows/xue_hua_audio_windows_plugin_c_api.h"
  "xue_hua_audio_windows_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Sources contain UTF-8 comments; tell MSVC not to guess the ANSI code page.
# 源码含 UTF-8 中文注释，需显式告知 MSVC 不要按系统 ANSI 代码页解析。
if(MSVC)
  target_compile_options(${PLUGIN_NAME} PRIVATE "/utf-8")
endif()

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
# Media Foundation (playback + AAC encoding) and WASAPI/COM helpers.
# Media Foundation（播放 + AAC 编码）与 WASAPI/COM 所需系统库。
target_link_libraries(${PLUGIN_NAME} PRIVATE
  mfplat mfreadwrite mfuuid ole32 propsys runtimeobject)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(xue_hua_audio_windows_bundled_libraries
  ""
  PARENT_SCOPE
)

