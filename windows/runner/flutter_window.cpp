#include "flutter_window.h"
#include "passkey_capability.h"

#include <optional>
#include <array>
#include <cstdio>
#include <cstring>
#include <vector>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {
// Read the same SMBIOS Type 1 UUID exposed by Win32_ComputerSystemProduct.
std::string ReadDeviceUuid() {
  constexpr DWORD provider = 0x52534D42;  // RSMB
  const UINT size = GetSystemFirmwareTable(provider, 0, nullptr, 0);
  if (size < 8 || size > 1024 * 1024) return {};
  std::vector<BYTE> data(size);
  if (GetSystemFirmwareTable(provider, 0, data.data(), size) != size) return {};
  DWORD table_length = 0;
  memcpy(&table_length, data.data() + 4, sizeof(table_length));
  if (table_length > size - 8) return {};
  const size_t end = 8 + table_length;
  size_t offset = 8;
  while (offset + 4 <= end) {
    const BYTE type = data[offset];
    const size_t length = data[offset + 1];
    if (length < 4 || length > end - offset) return {};
    if (type == 1 && length >= 0x19) {
      const BYTE* uuid = data.data() + offset + 8;
      bool all_zero = true, all_ff = true;
      for (size_t i = 0; i < 16; ++i) {
        all_zero = all_zero && uuid[i] == 0;
        all_ff = all_ff && uuid[i] == 0xff;
      }
      if (all_zero || all_ff) return {};
      std::array<int, 16> order{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15};
      if (data[1] > 2 || (data[1] == 2 && data[2] >= 6)) {
        order = {3, 2, 1, 0, 5, 4, 7, 6, 8, 9, 10, 11, 12, 13, 14, 15};
      }
      std::string value;
      for (size_t i = 0; i < order.size(); ++i) {
        if (i == 4 || i == 6 || i == 8 || i == 10) value += '-';
        char hex[3];
        std::snprintf(hex, sizeof(hex), "%02X", static_cast<unsigned int>(uuid[order[i]]));
        value += hex;
      }
      return value;
    }
    if (type == 127) break;
    offset += length;
    // Skip the structure's double-null-terminated string section.
    while (offset + 1 < end && !(data[offset] == 0 && data[offset + 1] == 0)) ++offset;
    if (offset + 1 >= end) return {};
    offset += 2;
  }
  return {};
}
std::string ReadDeviceModel() {
  constexpr DWORD provider = 0x52534D42;
  const UINT size = GetSystemFirmwareTable(provider, 0, nullptr, 0);
  if (size < 8 || size > 1024 * 1024) return {};
  std::vector<BYTE> data(size);
  if (GetSystemFirmwareTable(provider, 0, data.data(), size) != size) return {};
  DWORD table_length = 0;
  memcpy(&table_length, data.data() + 4, sizeof(table_length));
  if (table_length > size - 8) return {};
  const size_t end = 8 + table_length;
  size_t offset = 8;
  while (offset + 4 <= end) {
    const BYTE type = data[offset];
    const size_t length = data[offset + 1];
    if (length < 4 || length > end - offset) return {};
    if (type == 1 && length >= 6) {
      const BYTE product_index = data[offset + 5];
      if (product_index == 0) return {};
      size_t cursor = offset + length;
      for (unsigned int index = 1; cursor < end && data[cursor] != 0; ++index) {
        const size_t start = cursor;
        while (cursor < end && data[cursor] != 0) ++cursor;
        if (cursor >= end) return {};
        if (index == product_index) {
          return std::string(reinterpret_cast<const char*>(data.data() + start), cursor - start);
        }
        ++cursor;
      }
      return {};
    }
    if (type == 127) break;
    offset += length;
    while (offset + 1 < end && !(data[offset] == 0 && data[offset + 1] == 0)) ++offset;
    if (offset + 1 >= end) return {};
    offset += 2;
  }
  return {};
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  flutter::MethodChannel<flutter::EncodableValue> passkey_capability(
      flutter_controller_->engine()->messenger(), "oculve/passkey_capability",
      &flutter::StandardMethodCodec::GetInstance());
  passkey_capability.SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "hasEnrolledBiometrics") {
          result->Success(flutter::EncodableValue(HasEnrolledBiometrics()));
        } else {
          result->NotImplemented();
        }
      });
  flutter::MethodChannel<flutter::EncodableValue> identity_channel(
      flutter_controller_->engine()->messenger(), "com.oculve/device_identity",
      &flutter::StandardMethodCodec::GetInstance());
  identity_channel.SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getDeviceModel") {
          result->Success(flutter::EncodableValue(ReadDeviceModel()));
          return;
        }
        if (call.method_name() != "getHwid") {
          result->NotImplemented();
          return;
        }
        const auto uuid = ReadDeviceUuid();
        if (uuid.empty()) {
          result->Error("HWID_UNAVAILABLE", "Device identity unavailable.");
          return;
        }
        result->Success(flutter::EncodableValue(uuid));
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // This is a tray app. Dart creates the tray icon before showing the window,
  // so the first Flutter frame must not open a regular taskbar window.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
