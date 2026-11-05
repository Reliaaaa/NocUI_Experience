#include <flutter/dart_project.h>
#include <windows.h>

#include "dynamicbar/app/native_app.h"
#include "resource.h"
#include "utils.h"

// A single running instance owns the island; a second one would fight over the
// same screen real estate and the same notification icon.
namespace {
constexpr const wchar_t kSingleInstanceMutex[] =
    L"Local\\DynamicBar.SingleInstance";
constexpr const wchar_t kActivationMessage[] = L"DynamicBar.ActivateExisting";
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t* command_line, _In_ int show_command) {
  HANDLE single_instance = ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
  if (single_instance != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    // Ask the running instance to reveal itself, then step aside.
    UINT activation = ::RegisterWindowMessageW(kActivationMessage);
    if (activation != 0) {
      ::PostMessageW(HWND_BROADCAST, activation, 0, 0);
    }
    ::CloseHandle(single_instance);
    return EXIT_SUCCESS;
  }

  // Attach to a console when launched from one (flutter run), or create one
  // under a debugger. Release launches from Explorer get neither.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(GetCommandLineArguments());

  int exit_code = EXIT_FAILURE;
  {
    dynamicbar::NativeApp app;
    exit_code = app.Run(project, IDI_APP_ICON);
  }

  ::CoUninitialize();
  if (single_instance != nullptr) {
    ::ReleaseMutex(single_instance);
    ::CloseHandle(single_instance);
  }
  return exit_code;
}
