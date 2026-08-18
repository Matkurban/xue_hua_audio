#include "include/xue_hua_audio_windows/xue_hua_audio_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "xue_hua_audio_windows_plugin.h"

void XueHuaAudioWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  xue_hua_audio_windows::XueHuaAudioWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
