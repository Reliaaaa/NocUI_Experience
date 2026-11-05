#include "dynamicbar/core/logging.h"

#include <windows.h>

#include <cstdio>
#include <fstream>
#include <mutex>
#include <sstream>

namespace dynamicbar {
namespace {

constexpr long long kMaxLogBytes = 1024 * 1024;  // 1 MiB before rotation.

std::mutex g_mutex;
std::ofstream g_stream;
std::wstring g_path;
long long g_written = 0;
#ifdef _DEBUG
LogLevel g_min_level = LogLevel::kDebug;
#else
LogLevel g_min_level = LogLevel::kInfo;
#endif

std::wstring LocalAppDataDirectory() {
  wchar_t buffer[MAX_PATH] = {};
  DWORD length = ::GetEnvironmentVariableW(L"LOCALAPPDATA", buffer, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) {
    return std::wstring();
  }
  return std::wstring(buffer, length);
}

const char* LevelName(LogLevel level) {
  switch (level) {
    case LogLevel::kTrace:
      return "TRACE";
    case LogLevel::kDebug:
      return "DEBUG";
    case LogLevel::kInfo:
      return "INFO ";
    case LogLevel::kWarn:
      return "WARN ";
    case LogLevel::kError:
      return "ERROR";
  }
  return "?????";
}

std::string Timestamp() {
  SYSTEMTIME time = {};
  ::GetLocalTime(&time);
  char buffer[32] = {};
  ::sprintf_s(buffer, sizeof(buffer), "%02d:%02d:%02d.%03d", time.wHour,
              time.wMinute, time.wSecond, time.wMilliseconds);
  return std::string(buffer);
}

// Requires g_mutex.
void RotateIfNeeded() {
  if (g_written < kMaxLogBytes || g_path.empty()) {
    return;
  }
  g_stream.close();
  std::wstring previous = g_path + L".1";
  ::DeleteFileW(previous.c_str());
  ::MoveFileW(g_path.c_str(), previous.c_str());
  g_stream.open(g_path.c_str(), std::ios::out | std::ios::trunc);
  g_written = 0;
}

}  // namespace

void InitLogging() {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_stream.is_open()) {
    return;
  }
  std::wstring root = LocalAppDataDirectory();
  if (root.empty()) {
    return;
  }
  std::wstring directory = root + L"\\NocUIExperience";
  ::CreateDirectoryW(directory.c_str(), nullptr);
  directory += L"\\logs";
  ::CreateDirectoryW(directory.c_str(), nullptr);
  g_path = directory + L"\\dynamicbar.log";

  WIN32_FILE_ATTRIBUTE_DATA attributes = {};
  if (::GetFileAttributesExW(g_path.c_str(), GetFileExInfoStandard,
                             &attributes)) {
    LARGE_INTEGER size = {};
    size.LowPart = attributes.nFileSizeLow;
    size.HighPart = static_cast<LONG>(attributes.nFileSizeHigh);
    g_written = size.QuadPart;
  }
  g_stream.open(g_path.c_str(), std::ios::out | std::ios::app);
  RotateIfNeeded();
}

void ShutdownLogging() {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_stream.is_open()) {
    g_stream.flush();
    g_stream.close();
  }
}

void SetMinimumLogLevel(LogLevel level) {
  std::lock_guard<std::mutex> lock(g_mutex);
  g_min_level = level;
}

void LogMessage(LogLevel level, const char* tag, const std::string& message) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (static_cast<int>(level) < static_cast<int>(g_min_level)) {
    return;
  }
  std::ostringstream line;
  line << Timestamp() << " [" << LevelName(level) << "] " << (tag ? tag : "-")
       << ": " << message << "\n";
  const std::string text = line.str();

  ::OutputDebugStringA(text.c_str());
  if (g_stream.is_open()) {
    g_stream << text;
    g_stream.flush();
    g_written += static_cast<long long>(text.size());
    RotateIfNeeded();
  }
}

std::string FormatHResult(long hr) {
  char buffer[32] = {};
  ::sprintf_s(buffer, sizeof(buffer), "0x%08lX", static_cast<unsigned long>(hr));
  return std::string(buffer);
}

std::wstring LogFilePath() {
  std::lock_guard<std::mutex> lock(g_mutex);
  return g_path;
}

}  // namespace dynamicbar
