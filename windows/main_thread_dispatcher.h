// Marshals callbacks from worker threads onto the platform (UI) thread.
// 将工作线程上的回调调度回平台（UI）线程执行。
#ifndef XUE_HUA_AUDIO_WINDOWS_MAIN_THREAD_DISPATCHER_H_
#define XUE_HUA_AUDIO_WINDOWS_MAIN_THREAD_DISPATCHER_H_

#include <windows.h>

#include <functional>
#include <memory>

namespace xue_hua_audio_windows {

// A hidden message-only window whose WndProc runs posted std::functions on
// the thread that created the dispatcher (the Flutter platform thread).
//
// 一个隐藏的 message-only 窗口：投递进来的 std::function 会在创建本调度器
// 的线程（Flutter 平台线程）上执行。
class MainThreadDispatcher {
 public:
  // Must be constructed on the platform thread. / 必须在平台线程上构造。
  MainThreadDispatcher() {
    WNDCLASSW window_class = {};
    window_class.lpfnWndProc = WndProc;
    window_class.hInstance = GetModuleHandleW(nullptr);
    window_class.lpszClassName = kClassName;
    RegisterClassW(&window_class);  // Idempotent; failure is fine. / 幂等，失败无碍。
    hwnd_ = CreateWindowExW(0, kClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                            nullptr, window_class.hInstance, nullptr);
  }

  ~MainThreadDispatcher() {
    if (hwnd_) {
      DestroyWindow(hwnd_);
    }
  }

  // Runs `task` asynchronously on the platform thread. Safe to call from
  // any thread. / 在平台线程上异步执行 `task`；可从任意线程调用。
  void Post(std::function<void()> task) const {
    if (!hwnd_) {
      return;
    }
    auto* heap_task = new std::function<void()>(std::move(task));
    if (!PostMessageW(hwnd_, kRunTaskMessage, 0,
                      reinterpret_cast<LPARAM>(heap_task))) {
      delete heap_task;
    }
  }

 private:
  static constexpr UINT kRunTaskMessage = WM_APP + 0x5841;
  static constexpr const wchar_t* kClassName = L"XueHuaAudioDispatcherWindow";

  static LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wparam,
                                  LPARAM lparam) {
    if (message == kRunTaskMessage) {
      auto* task = reinterpret_cast<std::function<void()>*>(lparam);
      (*task)();
      delete task;
      return 0;
    }
    return DefWindowProcW(hwnd, message, wparam, lparam);
  }

  HWND hwnd_ = nullptr;
};

}  // namespace xue_hua_audio_windows

#endif  // XUE_HUA_AUDIO_WINDOWS_MAIN_THREAD_DISPATCHER_H_
