// DynamicBar - structured native logging.
//
// Writes to %LOCALAPPDATA%\DynamicBar\logs\dynamicbar.log with size based
// rotation, and mirrors everything to the debugger output. Logging never
// throws and never blocks the platform thread for more than a file append.
#ifndef DYNAMICBAR_CORE_LOGGING_H_
#define DYNAMICBAR_CORE_LOGGING_H_

#include <string>

namespace dynamicbar {

enum class LogLevel {
  kTrace = 0,
  kDebug = 1,
  kInfo = 2,
  kWarn = 3,
  kError = 4,
};

// Opens the log file. Safe to call more than once.
void InitLogging();

// Flushes and closes the log file.
void ShutdownLogging();

// Minimum level that is persisted. Defaults to kInfo in release builds and
// kDebug otherwise.
void SetMinimumLogLevel(LogLevel level);

void LogMessage(LogLevel level, const char* tag, const std::string& message);

// Formats `hr` as "0x8007000E (message)" for diagnostics.
std::string FormatHResult(long hr);

// Absolute path of the active log file, or an empty string before InitLogging.
std::wstring LogFilePath();

}  // namespace dynamicbar

#define DB_LOG_TRACE(tag, msg) \
  ::dynamicbar::LogMessage(::dynamicbar::LogLevel::kTrace, tag, msg)
#define DB_LOG_DEBUG(tag, msg) \
  ::dynamicbar::LogMessage(::dynamicbar::LogLevel::kDebug, tag, msg)
#define DB_LOG_INFO(tag, msg) \
  ::dynamicbar::LogMessage(::dynamicbar::LogLevel::kInfo, tag, msg)
#define DB_LOG_WARN(tag, msg) \
  ::dynamicbar::LogMessage(::dynamicbar::LogLevel::kWarn, tag, msg)
#define DB_LOG_ERROR(tag, msg) \
  ::dynamicbar::LogMessage(::dynamicbar::LogLevel::kError, tag, msg)

#endif  // DYNAMICBAR_CORE_LOGGING_H_
