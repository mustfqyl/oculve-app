import Foundation
import Network

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

/// Registers a TCP-only ping channel whose sockets are pinned to the active
/// physical interface. A normal socket follows a connected VPN's utun route.
func registerPhysicalTcpPingChannel(binaryMessenger: FlutterBinaryMessenger) {
  let channel = FlutterMethodChannel(
    name: "com.oculve/server_latency",
    binaryMessenger: binaryMessenger
  )
  channel.setMethodCallHandler { call, result in
    guard call.method == "tcpConnectLatency" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let host = arguments["host"] as? String,
      !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let port = arguments["port"] as? Int,
      (1...65535).contains(port)
    else {
      result(FlutterError(
        code: "invalid_target",
        message: "A valid TCP host and port are required.",
        details: nil
      ))
      return
    }
    let requestedTimeout = arguments["timeoutMs"] as? Int ?? 3000
    let timeoutMs = min(max(requestedTimeout, 500), 5000)
    DispatchQueue.global(qos: .utility).async {
      let sample = PhysicalTcpPing.measure(
        host: host.trimmingCharacters(in: .whitespacesAndNewlines),
        port: port,
        timeoutMs: timeoutMs
      )
      DispatchQueue.main.async { result(sample) }
    }
  }
}

private enum PhysicalTcpPing {
  static func measure(host: String, port: Int, timeoutMs: Int) -> [String: Any]? {
    guard
      let interface = activePhysicalInterface(timeoutMs: timeoutMs),
      let endpointPort = NWEndpoint.Port(rawValue: UInt16(port))
    else {
      return nil
    }

    let parameters = NWParameters.tcp
    parameters.requiredInterface = interface
    let connection = NWConnection(
      host: NWEndpoint.Host(host),
      port: endpointPort,
      using: parameters
    )
    let queue = DispatchQueue(label: "com.oculve.server-latency")
    let finished = DispatchSemaphore(value: 0)
    let startedAt = DispatchTime.now().uptimeNanoseconds
    let lock = NSLock()
    var response: [String: Any]?
    var didFinish = false

    func finish(_ value: [String: Any]?) {
      lock.lock()
      defer { lock.unlock() }
      guard !didFinish else { return }
      didFinish = true
      response = value
      connection.cancel()
      finished.signal()
    }

    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
        let milliseconds = max(1, Int(elapsed / 1_000_000))
        finish([
          "latencyMs": milliseconds,
          "networkPath": interfaceLabel(interface)
        ])
      case .failed:
        finish(nil)
      case .cancelled:
        finish(nil)
      default:
        break
      }
    }
    connection.start(queue: queue)

    guard finished.wait(timeout: .now() + .milliseconds(timeoutMs)) == .success else {
      connection.cancel()
      return nil
    }
    lock.lock()
    let sample = response
    lock.unlock()
    return sample
  }

  private static func activePhysicalInterface(timeoutMs: Int) -> NWInterface? {
    let monitor = NWPathMonitor()
    let queue = DispatchQueue(label: "com.oculve.server-latency-path")
    let ready = DispatchSemaphore(value: 0)
    let lock = NSLock()
    var selected: NWInterface?
    monitor.pathUpdateHandler = { path in
      let physicalTypes: [NWInterface.InterfaceType] = [.wifi, .wiredEthernet, .cellular]
      // Prefer the physical interface the current route actually uses. The
      // available list may also contain an idle Wi-Fi/cellular interface; pinning
      // to that one can turn a local TCP handshake into a much slower probe.
      let activeType = physicalTypes.first(where: path.usesInterfaceType)
      let candidate = activeType.flatMap { type in
        path.availableInterfaces.first(where: { $0.type == type })
      } ?? physicalTypes.lazy.compactMap { type in
        path.availableInterfaces.first(where: { $0.type == type })
      }.first
      lock.lock()
      selected = candidate
      lock.unlock()
      monitor.cancel()
      ready.signal()
    }
    monitor.start(queue: queue)
    guard ready.wait(timeout: .now() + .milliseconds(min(timeoutMs, 1500))) == .success else {
      monitor.cancel()
      return nil
    }
    lock.lock()
    let interface = selected
    lock.unlock()
    return interface
  }

  private static func interfaceLabel(_ interface: NWInterface) -> String {
    switch interface.type {
    case .wifi: return "Wi-Fi"
    case .wiredEthernet: return "Ethernet"
    case .cellular: return "Cellular"
    default: return "Physical"
    }
  }
}
