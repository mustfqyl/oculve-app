#include "dpi_connectivity_probe.h"
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <winhttp.h>
#include <algorithm>
#include <atomic>
#include <chrono>
#include <string>
#include <thread>

namespace flutter_vless {
namespace {
bool SendAll(SOCKET socket, const char* data, size_t length) {
  size_t offset = 0;
  while (offset < length) {
    const int sent = send(socket, data + offset, static_cast<int>(length - offset), 0);
    if (sent <= 0) return false;
    offset += static_cast<size_t>(sent);
  }
  return true;
}
bool ReceiveAll(SOCKET socket, unsigned char* data, size_t length) {
  size_t offset = 0;
  while (offset < length) {
    const int received = recv(socket, reinterpret_cast<char*>(data + offset), static_cast<int>(length - offset), 0);
    if (received <= 0) return false;
    offset += static_cast<size_t>(received);
  }
  return true;
}
void SocketTimeouts(SOCKET socket) {
  DWORD timeout = 3500;
  setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, reinterpret_cast<const char*>(&timeout), sizeof(timeout));
  setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, reinterpret_cast<const char*>(&timeout), sizeof(timeout));
}
bool AllowedHost(const std::string& host) {
  return host == "www.gstatic.com" || host == "cp.cloudflare.com";
}
bool ConnectSocks(SOCKET& socket, uint16_t port, const std::string& user,
                  const std::string& password, const std::string& host) {
  socket = ::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (socket == INVALID_SOCKET) return false;
  SocketTimeouts(socket);
  sockaddr_in local{}; local.sin_family = AF_INET; local.sin_port = htons(port);
  InetPtonA(AF_INET, "127.0.0.1", &local.sin_addr);
  if (connect(socket, reinterpret_cast<sockaddr*>(&local), sizeof(local)) != 0
      || user.empty() || user.size() > 255 || password.size() > 255 || host.size() > 255) return false;

  const unsigned char greeting[] = {5, 1, 2};
  unsigned char reply[4]{};
  if (!SendAll(socket, reinterpret_cast<const char*>(greeting), sizeof(greeting))
      || !ReceiveAll(socket, reply, 2) || reply[0] != 5 || reply[1] != 2) return false;
  std::string auth{static_cast<char>(1), static_cast<char>(user.size())}; auth += user;
  auth += static_cast<char>(password.size()); auth += password;
  if (!SendAll(socket, auth.data(), auth.size()) || !ReceiveAll(socket, reply, 2)
      || reply[0] != 1 || reply[1] != 0) return false;
  std::string request{static_cast<char>(5), static_cast<char>(1), static_cast<char>(0), static_cast<char>(3),
      static_cast<char>(host.size())};
  request += host; request.push_back(static_cast<char>(1)); request.push_back(static_cast<char>(187)); // port 443
  if (!SendAll(socket, request.data(), request.size()) || !ReceiveAll(socket, reply, 4)
      || reply[0] != 5 || reply[1] != 0 || reply[2] != 0) return false;
  size_t remaining = 0;
  if (reply[3] == 1) remaining = 4;
  else if (reply[3] == 4) remaining = 16;
  else if (reply[3] == 3) {
    unsigned char size = 0;
    if (!ReceiveAll(socket, &size, 1)) return false;
    remaining = size;
  } else return false;
  unsigned char tail[18]{};
  return remaining + 2 <= sizeof(tail) && ReceiveAll(socket, tail, remaining + 2);
}

class ConnectBridge {
 public:
  ConnectBridge(uint16_t socks_port, const std::string& user, const std::string& password)
      : socks_port_(socks_port), user_(user), password_(password) {}
  ~ConnectBridge() { Stop(); }
  bool Start() {
    listener_ = ::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (listener_ == INVALID_SOCKET) return false;
    BOOL exclusive = TRUE;
    setsockopt(listener_, SOL_SOCKET, SO_EXCLUSIVEADDRUSE, reinterpret_cast<const char*>(&exclusive), sizeof(exclusive));
    sockaddr_in local{}; local.sin_family = AF_INET;
    InetPtonA(AF_INET, "127.0.0.1", &local.sin_addr);
    if (bind(listener_, reinterpret_cast<sockaddr*>(&local), sizeof(local)) || listen(listener_, 1)) return false;
    int size = sizeof(local);
    if (getsockname(listener_, reinterpret_cast<sockaddr*>(&local), &size)) return false;
    port_ = ntohs(local.sin_port);
    running_.store(true);
    worker_ = std::thread(&ConnectBridge::Serve, this);
    return true;
  }
  uint16_t Port() const { return port_; }
  void Stop() {
    running_.store(false);
    if (listener_ != INVALID_SOCKET) shutdown(listener_, SD_BOTH);
    if (worker_.joinable()) worker_.join();
    if (listener_ != INVALID_SOCKET) { closesocket(listener_); listener_ = INVALID_SOCKET; }
  }
 private:
  bool ReadConnect(SOCKET client, std::string& host) {
    std::string request;
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(4);
    while (running_.load() && std::chrono::steady_clock::now() < deadline && request.size() < 8192) {
      fd_set readable; FD_ZERO(&readable); FD_SET(client, &readable);
      timeval wait{0, 100000};
      if (select(0, &readable, nullptr, nullptr, &wait) <= 0) continue;
      char buffer[1024]; const int count = recv(client, buffer, sizeof(buffer), 0);
      if (count <= 0) return false;
      request.append(buffer, count);
      const auto end = request.find("\r\n\r\n");
      if (end == std::string::npos) continue;
      const auto first_end = request.find("\r\n");
      if (first_end == std::string::npos) return false;
      const auto first = request.substr(0, first_end);
      const auto prefix = std::string("CONNECT ");
      const auto suffix = std::string(" HTTP/1.");
      if (first.rfind(prefix, 0) != 0) return false;
      const auto host_end = first.find(':', prefix.size());
      if (host_end == std::string::npos || first.compare(host_end, 4, ":443") != 0
          || host_end + 5 >= first.size() || first[host_end + 4] != ' ') return false;
      const auto protocol = first.substr(host_end + 5);
      if (protocol != "HTTP/1.1" && protocol != "HTTP/1.0") return false;
      host = first.substr(prefix.size(), host_end - prefix.size());
      return AllowedHost(host);
    }
    return false;
  }
  void Serve() {
    while (running_.load()) {
      fd_set readable; FD_ZERO(&readable); FD_SET(listener_, &readable);
      timeval wait{0, 100000};
      if (select(0, &readable, nullptr, nullptr, &wait) <= 0) continue;
      SOCKET client = accept(listener_, nullptr, nullptr);
      if (client == INVALID_SOCKET) continue;
      SocketTimeouts(client);
      std::string host;
      SOCKET upstream = INVALID_SOCKET;
      bool ok = ReadConnect(client, host) && ConnectSocks(upstream, socks_port_, user_, password_, host);
      if (ok) ok = SendAll(client, "HTTP/1.1 200 Connection established\r\n\r\n", 39);
      if (ok) Relay(client, upstream);
      if (upstream != INVALID_SOCKET) closesocket(upstream);
      closesocket(client);
      return; // one request only; the listener is never a general local proxy
    }
  }
  void Relay(SOCKET client, SOCKET upstream) {
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(12);
    size_t transferred = 0;
    while (running_.load() && std::chrono::steady_clock::now() < deadline && transferred < 1024 * 1024) {
      fd_set readable; FD_ZERO(&readable); FD_SET(client, &readable); FD_SET(upstream, &readable);
      timeval wait{0, 250000};
      const int selected = select(0, &readable, nullptr, nullptr, &wait);
      if (selected <= 0) continue;
      for (SOCKET source : {client, upstream}) {
        if (!FD_ISSET(source, &readable)) continue;
        char buffer[8192]; const int count = recv(source, buffer, sizeof(buffer), 0);
        if (count <= 0) return;
        const SOCKET destination = source == client ? upstream : client;
        if (!SendAll(destination, buffer, static_cast<size_t>(count))) return;
        transferred += static_cast<size_t>(count);
        if (transferred >= 1024 * 1024) return;
      }
    }
  }
  uint16_t socks_port_ = 0, port_ = 0;
  std::string user_, password_;
  SOCKET listener_ = INVALID_SOCKET;
  std::atomic<bool> running_{false};
  std::thread worker_;
};

bool Probe(const wchar_t* host, const wchar_t* path, uint16_t socks_port,
           const std::string& username, const std::string& password) {
  ConnectBridge bridge(socks_port, username, password);
  if (!bridge.Start()) return false;
  const std::wstring proxy = L"127.0.0.1:" + std::to_wstring(bridge.Port());
  HINTERNET session = WinHttpOpen(L"Oculve Connectivity Check", WINHTTP_ACCESS_TYPE_NAMED_PROXY,
      proxy.c_str(), WINHTTP_NO_PROXY_BYPASS, 0);
  if (!session) return false;
  WinHttpSetTimeouts(session, 3000, 3000, 3000, 4000);
  HINTERNET connection = WinHttpConnect(session, host, INTERNET_DEFAULT_HTTPS_PORT, 0);
  HINTERNET request = connection ? WinHttpOpenRequest(connection, L"GET", path, nullptr,
      WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, WINHTTP_FLAG_SECURE | WINHTTP_FLAG_REFRESH) : nullptr;
  DWORD redirect = WINHTTP_OPTION_REDIRECT_POLICY_NEVER;
  if (request) WinHttpSetOption(request, WINHTTP_OPTION_REDIRECT_POLICY, &redirect, sizeof(redirect));
  bool ok = request && WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
      WINHTTP_NO_REQUEST_DATA, 0, 0, 0) && WinHttpReceiveResponse(request, nullptr);
  DWORD status = 0, status_size = sizeof(status);
  ok = ok && WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
      WINHTTP_HEADER_NAME_BY_INDEX, &status, &status_size, WINHTTP_NO_HEADER_INDEX) && status == 204;
  if (request) WinHttpCloseHandle(request);
  if (connection) WinHttpCloseHandle(connection);
  WinHttpCloseHandle(session);
  return ok;
}
}  // namespace

bool DpiConnectivityReady(uint16_t socks_port, const std::string& username,
                          const std::string& password) {
  WSADATA data{};
  if (WSAStartup(MAKEWORD(2, 2), &data)) return false;
  const bool ready = Probe(L"www.gstatic.com", L"/generate_204", socks_port, username, password)
      || Probe(L"cp.cloudflare.com", L"/generate_204", socks_port, username, password);
  WSACleanup();
  return ready;
}
}  // namespace flutter_vless
