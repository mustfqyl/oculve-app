#include "xray_config.h"
#include <iostream>
#include <stdexcept>

using namespace flutter_vless::xray_config;
void Check(bool ok, const char* message) {
  if (!ok) throw std::runtime_error(message);
}
int main() {
  const std::string original = R"({
    "outbounds":[{"protocol":"socks","settings":{"servers":[{"address":"127.0.0.1","port":18582}]},"tag":"proxy"},{"tag":"direct","protocol":"freedom"}],
    "inbounds":[{"port":18580,"settings":{"nested":{"port":18582}},"protocol":"socks","tag":"socks-in"}],
    "routing":{"domainStrategy":"AsIs","rules":[{"domain":["domain:ru","domain:io"],"outboundTag":"direct"}]},
    "dns":{"queryStrategy":"UseIPv4"},
    "policy":{"levels":{"8":{"bufferSize":3}}},
    "remarks":"Escaped braces { } and a quote: \""
  })";
  Check(SocksPort(original) == 18580, "inbound order must not select outbound port");
  std::string prepared = original;
  int allocations = 0;
  Check(PrepareProxy(prepared, [](uint16_t p) { return p != 18582; },
      [&]() { ++allocations; return uint16_t{19000}; }), "proxy preparation");
  Check(allocations == 0, "occupied remote and nested ports must not be probed");
  auto before = Parse(original); auto after = Parse(prepared);
  Check(after["outbounds"] == before["outbounds"], "outbound preservation");
  Check(after["routing"] == before["routing"], "routing preservation");
  Check(after["policy"]["levels"] == before["policy"]["levels"], "policy preservation");
  Check(after["api"]["listen"] == "127.0.0.1:10085", "API without log section");
  Check(PrepareProxy(prepared, [](uint16_t p) { return p != 18580; },
      []() { return uint16_t{19000}; }), "inbound conflict preparation");
  Check(SocksPort(prepared) == 19000, "occupied inbound remapped");
  Check(Parse(prepared)["outbounds"] == before["outbounds"], "server untouched after remap");
  auto vpn = PrepareVpn(original);
  Check(vpn.has_value(), "VPN preparation");
  after = Parse(*vpn);
  Check(after["routing"] == before["routing"], "VPN domain rules preserved");
  Check(after["dns"] == before["dns"], "VPN DNS preserved");
  Check(after["outbounds"] == before["outbounds"], "VPN outbounds preserved");
  Check(after["api"]["listen"] == "127.0.0.1:10086", "VPN API listener");
  Check(PrepareVpn(*vpn) == vpn, "VPN preparation is idempotent");
  std::string bound = *vpn;
  Check(BindDirectOutbounds(bound, "Ethernet"), "bind direct transport");
  after = Parse(bound);
  Check(after["outbounds"][1]["streamSettings"]["sockopt"]["interface"] == "Ethernet", "direct uses underlay");
  Check(after["outbounds"][0] == before["outbounds"][0], "proxy transport preserved");
  Check(after["routing"] == before["routing"], "binding preserves domain rules");
  Check(BindDirectOutbounds(bound, "Wi-Fi"), "preserve explicit interface");
  Check(Parse(bound)["outbounds"][1]["streamSettings"]["sockopt"]["interface"] == "Ethernet", "explicit binding respected");
  Check(!BindDirectOutbounds(bound, ""), "missing underlay rejected");
  Check(!SocksPort(R"({"outbounds":[{"protocol":"socks","port":443}]})"), "missing inbound");
  Check(!PrepareVpn("{bad json}"), "invalid JSON rejected");
  Check(!PrepareVpn(R"({"inbounds":[{"protocol":"socks","port":65536}]})"), "invalid port rejected");

  const std::string dpi = R"({
    "log":{"loglevel":"warning","access":"none","error":"none","dnsLog":false},
    "inbounds":[{"tag":"socks","listen":"127.0.0.1","port":10808,"protocol":"socks","settings":{"auth":"noauth","udp":true},"sniffing":{"enabled":true,"routeOnly":true}}],
    "outbounds":[
      {"tag":"byedpi","protocol":"socks","settings":{"servers":[{"address":"127.0.0.1","port":65535}]},"targetStrategy":"UseIP"},
      {"tag":"direct","protocol":"freedom"},
      {"tag":"block","protocol":"blackhole"}
    ],
    "dns":{"servers":["tcp://1.1.1.1"],"queryStrategy":"UseIPv4","disableFallback":true},
    "routing":{"domainStrategy":"AsIs","rules":[]}
  })";
  Check(IsDpiBypassConfig(dpi) && HasDpiBypassTag(dpi), "client-owned DPI config not recognized");
  auto remote_dpi = Parse(dpi); remote_dpi["outbounds"].push_back({{"tag","vpn"},{"protocol","vless"}});
  Check(HasDpiBypassTag(remote_dpi.dump()) && !IsDpiBypassConfig(remote_dpi.dump()), "remote tunnel accepted in DPI mode");
  auto protected_dpi = PrepareProtectedVpn(dpi, "session-user", "session-password", "Ethernet",
      [](const std::string&) { return std::string(); });
  Check(protected_dpi.has_value(), "built-in DPI config did not pass protected preparation");
  auto dynamic_dpi = SetDpiProxyPort(*protected_dpi, 43219);
  Check(dynamic_dpi.has_value(), "runtime DPI endpoint was not applied");
  auto dpi_config = Parse(*dynamic_dpi);
  auto dpi_outbound = std::find_if(dpi_config["outbounds"].begin(), dpi_config["outbounds"].end(),
      [](const Json& outbound) { return outbound.value("tag", "") == "byedpi"; });
  Check(dpi_outbound != dpi_config["outbounds"].end(), "ByeDPI outbound missing after DNS preparation");
  Check((*dpi_outbound)["settings"]["servers"][0]["port"] == 43219, "dynamic local proxy port not applied");
  Check(dpi_config["inbounds"][0]["settings"]["auth"] == "password", "DPI TUN listener is not session authenticated");
  Check(dpi_config["outbounds"][1]["streamSettings"]["sockopt"]["interface"] == "Ethernet", "DPI direct path is not bound to underlay");
  Check(!SetDpiProxyPort(dpi, 0), "invalid runtime DPI port accepted");
  std::cout << "Windows Xray configuration regression tests passed\n";
}
