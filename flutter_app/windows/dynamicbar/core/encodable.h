// DynamicBar - small helpers for reading EncodableValue argument maps.
#ifndef DYNAMICBAR_CORE_ENCODABLE_H_
#define DYNAMICBAR_CORE_ENCODABLE_H_

#include <flutter/encodable_value.h>

#include <string>
#include <vector>

namespace dynamicbar {

using EncodableMap = flutter::EncodableMap;
using EncodableValue = flutter::EncodableValue;
using EncodableList = flutter::EncodableList;

inline const EncodableValue* FindValue(const EncodableMap& map,
                                       const char* key) {
  auto it = map.find(EncodableValue(std::string(key)));
  return it == map.end() ? nullptr : &it->second;
}

inline const EncodableMap* AsMap(const EncodableValue* value) {
  return value != nullptr ? std::get_if<EncodableMap>(value) : nullptr;
}

inline bool GetBool(const EncodableMap& map, const char* key,
                    bool fallback = false) {
  const EncodableValue* value = FindValue(map, key);
  const bool* result = value != nullptr ? std::get_if<bool>(value) : nullptr;
  return result != nullptr ? *result : fallback;
}

inline int GetInt(const EncodableMap& map, const char* key, int fallback = 0) {
  const EncodableValue* value = FindValue(map, key);
  if (value == nullptr) {
    return fallback;
  }
  if (const int32_t* narrow = std::get_if<int32_t>(value)) {
    return static_cast<int>(*narrow);
  }
  if (const int64_t* wide = std::get_if<int64_t>(value)) {
    return static_cast<int>(*wide);
  }
  if (const double* real = std::get_if<double>(value)) {
    return static_cast<int>(*real);
  }
  return fallback;
}

inline double GetDouble(const EncodableMap& map, const char* key,
                        double fallback = 0.0) {
  const EncodableValue* value = FindValue(map, key);
  if (value == nullptr) {
    return fallback;
  }
  if (const double* real = std::get_if<double>(value)) {
    return *real;
  }
  if (const int32_t* narrow = std::get_if<int32_t>(value)) {
    return static_cast<double>(*narrow);
  }
  if (const int64_t* wide = std::get_if<int64_t>(value)) {
    return static_cast<double>(*wide);
  }
  return fallback;
}

inline std::string GetString(const EncodableMap& map, const char* key,
                             const std::string& fallback = std::string()) {
  const EncodableValue* value = FindValue(map, key);
  const std::string* result =
      value != nullptr ? std::get_if<std::string>(value) : nullptr;
  return result != nullptr ? *result : fallback;
}

inline const EncodableList* GetList(const EncodableMap& map, const char* key) {
  const EncodableValue* value = FindValue(map, key);
  return value != nullptr ? std::get_if<EncodableList>(value) : nullptr;
}

// Conversions between the UTF-16 Win32 world and the UTF-8 standard codec.
std::string Utf8FromUtf16(const std::wstring& utf16);
std::wstring Utf16FromUtf8(const std::string& utf8);

}  // namespace dynamicbar

#endif  // DYNAMICBAR_CORE_ENCODABLE_H_
