#include "dynamicbar/core/encodable.h"

#include <windows.h>

namespace dynamicbar {

std::string Utf8FromUtf16(const std::wstring& utf16) {
  if (utf16.empty()) {
    return std::string();
  }
  int size = ::WideCharToMultiByte(CP_UTF8, 0, utf16.data(),
                                   static_cast<int>(utf16.size()), nullptr, 0,
                                   nullptr, nullptr);
  if (size <= 0) {
    return std::string();
  }
  std::string result(static_cast<size_t>(size), 0);
  ::WideCharToMultiByte(CP_UTF8, 0, utf16.data(),
                        static_cast<int>(utf16.size()), result.data(), size,
                        nullptr, nullptr);
  return result;
}

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  int size = ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                   static_cast<int>(utf8.size()), nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring result(static_cast<size_t>(size), 0);
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                        result.data(), size);
  return result;
}

}  // namespace dynamicbar
