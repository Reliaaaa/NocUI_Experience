// DynamicBar - marshals work from worker threads onto the platform thread.
//
// Every Flutter channel call must happen on the thread that owns the engine.
// Native watchers (registry, directory, WinRT completion handlers, audio
// callbacks) all signal from arbitrary threads, so they queue a closure here
// and a message-only window drains the queue on the platform thread.
#ifndef DYNAMICBAR_CORE_DISPATCHER_H_
#define DYNAMICBAR_CORE_DISPATCHER_H_

#include <windows.h>

#include <functional>
#include <mutex>
#include <vector>

namespace dynamicbar {

class MainThreadDispatcher {
 public:
  static MainThreadDispatcher& Instance();

  // Must be called once, from the platform thread, before any Post().
  bool Initialize();
  void Shutdown();

  // Runs the task on the platform thread. Safe from any thread. Tasks posted
  // after Shutdown() are dropped.
  void Post(std::function<void()> task);

  bool initialized() const { return window_ != nullptr; }

 private:
  MainThreadDispatcher() = default;
  ~MainThreadDispatcher();
  MainThreadDispatcher(const MainThreadDispatcher&) = delete;
  MainThreadDispatcher& operator=(const MainThreadDispatcher&) = delete;

  static LRESULT CALLBACK WndProc(HWND window, UINT message, WPARAM wparam,
                                  LPARAM lparam) noexcept;
  void Drain();

  HWND window_ = nullptr;
  std::mutex mutex_;
  std::vector<std::function<void()>> queue_;
  bool shutting_down_ = false;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_CORE_DISPATCHER_H_
