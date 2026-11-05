// windows.h before the imaging and shell headers, for the same reason as
// everywhere else in this project: they do not pull their own prerequisites in.
#include <windows.h>

#include <shellapi.h>
#include <shlwapi.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <string>
#include <vector>

#include "dynamicbar/core/logging.h"
#include "dynamicbar/shelf/shelf_channel.h"

namespace dynamicbar {
namespace {

using Microsoft::WRL::ComPtr;

constexpr const char kTag[] = "Shelf";
constexpr const char kMethodChannelName[] = "dynamicbar/shelf";
constexpr const char kEventChannelName[] = "dynamicbar/shelf/events";

ComPtr<IWICImagingFactory> CreateFactory() {
  ComPtr<IWICImagingFactory> factory;
  const HRESULT hr =
      ::CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER,
                         IID_PPV_ARGS(&factory));
  if (FAILED(hr)) {
    DB_LOG_WARN(kTag, "WIC is unavailable; images cannot be shelved.");
    return nullptr;
  }
  return factory;
}

/// Writes a WIC bitmap source out as a PNG.
bool WritePng(IWICImagingFactory* factory, IWICBitmapSource* source,
              const std::wstring& path, UINT width, UINT height) {
  ComPtr<IWICStream> stream;
  if (FAILED(factory->CreateStream(&stream)) ||
      FAILED(stream->InitializeFromFilename(path.c_str(), GENERIC_WRITE))) {
    return false;
  }
  ComPtr<IWICBitmapEncoder> encoder;
  if (FAILED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr,
                                    &encoder)) ||
      FAILED(encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache))) {
    return false;
  }
  ComPtr<IWICBitmapFrameEncode> frame;
  ComPtr<IPropertyBag2> properties;
  return SUCCEEDED(encoder->CreateNewFrame(&frame, &properties)) &&
         SUCCEEDED(frame->Initialize(properties.Get())) &&
         SUCCEEDED(frame->SetSize(width, height)) &&
         SUCCEEDED(frame->WriteSource(source, nullptr)) &&
         SUCCEEDED(frame->Commit()) && SUCCEEDED(encoder->Commit());
}

/// Encodes a GDI bitmap to a PNG file.
///
/// Alpha is ignored rather than assumed: a bitmap that came from a screenshot
/// or a browser usually has a zeroed alpha channel, and treating that as
/// transparency would store a completely invisible image.
bool EncodeToPng(HBITMAP bitmap, const std::wstring& path, int* width,
                 int* height) {
  ComPtr<IWICImagingFactory> factory = CreateFactory();
  if (factory == nullptr) {
    return false;
  }
  ComPtr<IWICBitmap> source;
  if (FAILED(factory->CreateBitmapFromHBITMAP(bitmap, nullptr,
                                              WICBitmapIgnoreAlpha, &source))) {
    return false;
  }
  UINT w = 0;
  UINT h = 0;
  source->GetSize(&w, &h);
  if (w == 0 || h == 0 || !WritePng(factory.Get(), source.Get(), path, w, h)) {
    return false;
  }
  *width = static_cast<int>(w);
  *height = static_cast<int>(h);
  return true;
}

/// Re-encodes any image WIC can read into a PNG at [destination].
///
/// The shelf stores one format, so a dropped JPEG, BMP, GIF or WebP becomes a
/// PNG on the way in rather than the page having to cope with four decoders and
/// four file extensions.
bool ConvertToPng(const std::wstring& source, const std::wstring& destination,
                  int* width, int* height) {
  ComPtr<IWICImagingFactory> factory = CreateFactory();
  if (factory == nullptr) {
    return false;
  }
  ComPtr<IWICBitmapDecoder> decoder;
  if (FAILED(factory->CreateDecoderFromFilename(
          source.c_str(), nullptr, GENERIC_READ,
          WICDecodeMetadataCacheOnDemand, &decoder))) {
    return false;
  }
  ComPtr<IWICBitmapFrameDecode> frame;
  if (FAILED(decoder->GetFrame(0, &frame))) {
    return false;
  }
  ComPtr<IWICFormatConverter> converter;
  if (FAILED(factory->CreateFormatConverter(&converter)) ||
      FAILED(converter->Initialize(frame.Get(), GUID_WICPixelFormat32bppBGRA,
                                   WICBitmapDitherTypeNone, nullptr, 0.0,
                                   WICBitmapPaletteTypeCustom))) {
    return false;
  }
  UINT w = 0;
  UINT h = 0;
  converter->GetSize(&w, &h);
  if (w == 0 || h == 0 ||
      !WritePng(factory.Get(), converter.Get(), destination, w, h)) {
    return false;
  }
  *width = static_cast<int>(w);
  *height = static_cast<int>(h);
  return true;
}

/// Reads a PNG back and puts it on the clipboard as a bottom-up CF_DIB.
///
/// Bottom-up rather than a negative height: a top-down DIB is legal and some
/// applications still refuse it, and this exists so the image can be pasted
/// somewhere else.
bool PngToClipboard(const std::wstring& path) {
  ComPtr<IWICImagingFactory> factory = CreateFactory();
  if (factory == nullptr) {
    return false;
  }
  ComPtr<IWICBitmapDecoder> decoder;
  if (FAILED(factory->CreateDecoderFromFilename(
          path.c_str(), nullptr, GENERIC_READ, WICDecodeMetadataCacheOnDemand,
          &decoder))) {
    return false;
  }
  ComPtr<IWICBitmapFrameDecode> frame;
  if (FAILED(decoder->GetFrame(0, &frame))) {
    return false;
  }
  ComPtr<IWICFormatConverter> converter;
  if (FAILED(factory->CreateFormatConverter(&converter)) ||
      FAILED(converter->Initialize(frame.Get(), GUID_WICPixelFormat32bppBGRA,
                                   WICBitmapDitherTypeNone, nullptr, 0.0,
                                   WICBitmapPaletteTypeCustom))) {
    return false;
  }

  UINT w = 0;
  UINT h = 0;
  converter->GetSize(&w, &h);
  if (w == 0 || h == 0) {
    return false;
  }

  const UINT stride = w * 4;
  const size_t pixels = static_cast<size_t>(stride) * h;
  std::vector<BYTE> buffer(pixels);
  if (FAILED(converter->CopyPixels(nullptr, stride,
                                   static_cast<UINT>(buffer.size()),
                                   buffer.data()))) {
    return false;
  }

  const size_t total = sizeof(BITMAPINFOHEADER) + pixels;
  HGLOBAL handle = ::GlobalAlloc(GMEM_MOVEABLE, total);
  if (handle == nullptr) {
    return false;
  }
  auto* header = static_cast<BITMAPINFOHEADER*>(::GlobalLock(handle));
  if (header == nullptr) {
    ::GlobalFree(handle);
    return false;
  }
  *header = {};
  header->biSize = sizeof(BITMAPINFOHEADER);
  header->biWidth = static_cast<LONG>(w);
  header->biHeight = static_cast<LONG>(h);
  header->biPlanes = 1;
  header->biBitCount = 32;
  header->biCompression = BI_RGB;
  header->biSizeImage = static_cast<DWORD>(pixels);

  auto* destination = reinterpret_cast<BYTE*>(header + 1);
  for (UINT row = 0; row < h; ++row) {
    ::memcpy(destination + static_cast<size_t>(row) * stride,
             buffer.data() + static_cast<size_t>(h - 1 - row) * stride, stride);
  }
  ::GlobalUnlock(handle);

  if (!::OpenClipboard(nullptr)) {
    ::GlobalFree(handle);
    return false;
  }
  ::EmptyClipboard();
  const bool ok = ::SetClipboardData(CF_DIB, handle) != nullptr;
  ::CloseClipboard();
  if (!ok) {
    // Ownership only transfers on success.
    ::GlobalFree(handle);
  }
  return ok;
}

/// A scratch file for an image that arrived as raw pixels rather than as a
/// file. Dart moves it onto the shelf and deletes it.
std::wstring TemporaryPngPath() {
  wchar_t folder[MAX_PATH] = {};
  if (::GetTempPathW(MAX_PATH, folder) == 0) {
    return std::wstring();
  }
  wchar_t name[MAX_PATH] = {};
  ::wsprintfW(name, L"%sdynamicbar-drop-%u.png", folder, ::GetTickCount());
  return std::wstring(name);
}

bool LooksLikeImage(const std::wstring& path) {
  const wchar_t* extension = ::PathFindExtensionW(path.c_str());
  if (extension == nullptr || *extension == 0) {
    return false;
  }
  std::wstring lower(extension);
  std::transform(lower.begin(), lower.end(), lower.begin(),
                 [](wchar_t c) { return static_cast<wchar_t>(::towlower(c)); });
  return lower == L".png" || lower == L".jpg" || lower == L".jpeg" ||
         lower == L".bmp" || lower == L".gif" || lower == L".webp" ||
         lower == L".tif" || lower == L".tiff";
}

/// Pulls the image file paths out of a dropped data object, and failing that
/// its raw bitmap, which is what a browser hands over when an image is dragged
/// straight out of a web page.
EncodableList ExtractImages(IDataObject* data) {
  EncodableList paths;
  if (data == nullptr) {
    return paths;
  }

  FORMATETC files = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  STGMEDIUM medium = {};
  if (SUCCEEDED(data->GetData(&files, &medium))) {
    auto drop = static_cast<HDROP>(::GlobalLock(medium.hGlobal));
    if (drop != nullptr) {
      const UINT count = ::DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
      for (UINT i = 0; i < count; ++i) {
        wchar_t buffer[MAX_PATH] = {};
        if (::DragQueryFileW(drop, i, buffer, MAX_PATH) > 0 &&
            LooksLikeImage(buffer)) {
          paths.push_back(EncodableValue(Utf8FromUtf16(buffer)));
        }
      }
      ::GlobalUnlock(medium.hGlobal);
    }
    ::ReleaseStgMedium(&medium);
    if (!paths.empty()) {
      return paths;
    }
  }

  FORMATETC bitmap = {CF_DIB, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  STGMEDIUM pixels = {};
  if (SUCCEEDED(data->GetData(&bitmap, &pixels))) {
    auto* header = static_cast<BITMAPINFOHEADER*>(::GlobalLock(pixels.hGlobal));
    if (header != nullptr) {
      const HDC screen = ::GetDC(nullptr);
      // Any colour table sits between the header and the pixels.
      const DWORD colours =
          header->biClrUsed != 0
              ? header->biClrUsed
              : (header->biBitCount <= 8
                     ? (1u << static_cast<unsigned>(header->biBitCount))
                     : 0u);
      const BYTE* bits = reinterpret_cast<const BYTE*>(header) +
                         header->biSize + colours * sizeof(RGBQUAD);
      const HBITMAP handle = ::CreateDIBitmap(
          screen, header, CBM_INIT, bits,
          reinterpret_cast<const BITMAPINFO*>(header), DIB_RGB_COLORS);
      ::ReleaseDC(nullptr, screen);

      if (handle != nullptr) {
        const std::wstring path = TemporaryPngPath();
        int width = 0;
        int height = 0;
        if (!path.empty() && EncodeToPng(handle, path, &width, &height)) {
          paths.push_back(EncodableValue(Utf8FromUtf16(path)));
        }
        ::DeleteObject(handle);
      }
      ::GlobalUnlock(pixels.hGlobal);
    }
    ::ReleaseStgMedium(&pixels);
  }
  return paths;
}

/// The stage window's drop target.
///
/// Hand rolled rather than built on a framework helper: it is five methods, it
/// must not throw, and this library is compiled with exceptions disabled.
class ShelfDropTarget : public IDropTarget {
 public:
  explicit ShelfDropTarget(ShelfChannel* owner) : owner_(owner) {}

  // IUnknown ------------------------------------------------------------
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** object) override {
    if (object == nullptr) {
      return E_POINTER;
    }
    if (riid == IID_IUnknown || riid == IID_IDropTarget) {
      *object = static_cast<IDropTarget*>(this);
      AddRef();
      return S_OK;
    }
    *object = nullptr;
    return E_NOINTERFACE;
  }

  ULONG STDMETHODCALLTYPE AddRef() override {
    return static_cast<ULONG>(::InterlockedIncrement(&references_));
  }

  ULONG STDMETHODCALLTYPE Release() override {
    const LONG count = ::InterlockedDecrement(&references_);
    if (count == 0) {
      delete this;
    }
    return static_cast<ULONG>(count);
  }

  // IDropTarget ---------------------------------------------------------
  HRESULT STDMETHODCALLTYPE DragEnter(IDataObject* data, DWORD, POINTL,
                                      DWORD* effect) override {
    carrying_ = HasImage(data);
    if (effect != nullptr) {
      *effect = carrying_ ? DROPEFFECT_COPY : DROPEFFECT_NONE;
    }
    if (carrying_ && owner_ != nullptr) {
      owner_->ReportHover(true);
    }
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE DragOver(DWORD, POINTL, DWORD* effect) override {
    if (effect != nullptr) {
      *effect = carrying_ ? DROPEFFECT_COPY : DROPEFFECT_NONE;
    }
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE DragLeave() override {
    if (carrying_ && owner_ != nullptr) {
      owner_->ReportHover(false);
    }
    carrying_ = false;
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE Drop(IDataObject* data, DWORD, POINTL,
                                 DWORD* effect) override {
    if (effect != nullptr) {
      *effect = DROPEFFECT_COPY;
    }
    carrying_ = false;
    if (owner_ != nullptr) {
      owner_->ReportHover(false);
      owner_->ReportDrop(ExtractImages(data));
    }
    return S_OK;
  }

  void Detach() { owner_ = nullptr; }

 private:
  /// Cheap enough to run on every DragEnter: it asks the data object whether a
  /// format is available without transferring anything.
  static bool HasImage(IDataObject* data) {
    if (data == nullptr) {
      return false;
    }
    FORMATETC files = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
    FORMATETC bitmap = {CF_DIB, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
    return data->QueryGetData(&files) == S_OK ||
           data->QueryGetData(&bitmap) == S_OK;
  }

  ShelfChannel* owner_;
  LONG references_ = 1;
  bool carrying_ = false;
};

}  // namespace

ShelfChannel::ShelfChannel(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
  events_ = std::make_unique<EventEmitter>(messenger, kEventChannelName);
}

ShelfChannel::~ShelfChannel() {
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
  if (drop_target_ != nullptr) {
    if (drop_window_ != nullptr) {
      ::RevokeDragDrop(drop_window_);
    }
    static_cast<ShelfDropTarget*>(drop_target_)->Detach();
    drop_target_->Release();
    drop_target_ = nullptr;
  }
}

void ShelfChannel::AttachDropTarget(HWND window) {
  if (window == nullptr || drop_target_ != nullptr) {
    return;
  }
  // OLE, not plain COM: RegisterDragDrop needs the OLE layer on top. The runner
  // has already put this thread into a single threaded apartment, so this
  // returns S_FALSE and initialises OLE over it.
  if (FAILED(::OleInitialize(nullptr))) {
    DB_LOG_WARN(kTag, "OLE refused to initialise; drag and drop is off.");
    return;
  }

  auto* target = new ShelfDropTarget(this);
  if (FAILED(::RegisterDragDrop(window, target))) {
    DB_LOG_WARN(kTag, "RegisterDragDrop failed; drag and drop is off.");
    target->Detach();
    target->Release();
    return;
  }
  drop_window_ = window;
  drop_target_ = target;
  DB_LOG_INFO(kTag, "Drag and drop attached to the island.");
}

void ShelfChannel::ReportDrop(EncodableList paths) {
  if (events_ == nullptr) {
    return;
  }
  DB_LOG_INFO(kTag, "Dropped " + std::to_string(paths.size()) + " image(s).");
  events_->Emit("drop", EncodableMap{
                            {EncodableValue("paths"), EncodableValue(paths)},
                        });
}

void ShelfChannel::ReportHover(bool inside) {
  if (events_ == nullptr) {
    return;
  }
  events_->Emit(
      "dragging",
      EncodableMap{{EncodableValue("inside"), EncodableValue(inside)}});
}

void ShelfChannel::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const EncodableMap* arguments = AsMap(call.arguments());
  const EncodableMap empty;
  const EncodableMap& args = arguments != nullptr ? *arguments : empty;

  if (method == "hasImage") {
    result->Success(
        EncodableValue(::IsClipboardFormatAvailable(CF_BITMAP) != FALSE));
    return;
  }

  if (method == "captureImage") {
    const std::wstring path = Utf16FromUtf8(GetString(args, "path"));
    if (path.empty()) {
      result->Error("argument", "A destination path is required.");
      return;
    }
    if (!::IsClipboardFormatAvailable(CF_BITMAP) || !::OpenClipboard(nullptr)) {
      result->Success(EncodableValue(
          EncodableMap{{EncodableValue("ok"), EncodableValue(false)}}));
      return;
    }
    auto bitmap = static_cast<HBITMAP>(::GetClipboardData(CF_BITMAP));
    int width = 0;
    int height = 0;
    const bool ok =
        bitmap != nullptr && EncodeToPng(bitmap, path, &width, &height);
    ::CloseClipboard();

    result->Success(EncodableValue(EncodableMap{
        {EncodableValue("ok"), EncodableValue(ok)},
        {EncodableValue("width"), EncodableValue(width)},
        {EncodableValue("height"), EncodableValue(height)},
    }));
    return;
  }

  if (method == "importImage") {
    const std::wstring source = Utf16FromUtf8(GetString(args, "source"));
    const std::wstring path = Utf16FromUtf8(GetString(args, "path"));
    int width = 0;
    int height = 0;
    const bool ok = !source.empty() && !path.empty() &&
                    ConvertToPng(source, path, &width, &height);
    result->Success(EncodableValue(EncodableMap{
        {EncodableValue("ok"), EncodableValue(ok)},
        {EncodableValue("width"), EncodableValue(width)},
        {EncodableValue("height"), EncodableValue(height)},
    }));
    return;
  }

  if (method == "copyImage") {
    const std::wstring path = Utf16FromUtf8(GetString(args, "path"));
    result->Success(EncodableValue(!path.empty() && PngToClipboard(path)));
    return;
  }

  result->NotImplemented();
}

}  // namespace dynamicbar
