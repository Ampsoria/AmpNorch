import Foundation
import Network
import Combine

final class WebSocketBridgeService: ObservableObject {
    static let shared = WebSocketBridgeService()
    @Published private(set) var isExtensionConnected = false
    @Published private(set) var status = "Starting browser bridge…"
    let pairingToken: String
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private var authenticated = Set<UUID>()
    private var routes: [String: (connection: UUID, remote: String, updated: Date)] = [:]
    private var pending: [String: (connection: UUID, completion: (String?) -> Void)] = [:]
    private var expiryTimer: Timer?

    init() {
        if let token = UserDefaults.standard.string(forKey: "browserPairingToken") { pairingToken = token }
        else {
            pairingToken = UUID().uuidString + UUID().uuidString
            UserDefaults.standard.set(pairingToken, forKey: "browserPairingToken")
        }
        startServer()
        expiryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            for (source, route) in self.routes where Date().timeIntervalSince(route.updated) > 12 {
                self.routes.removeValue(forKey: source)
                MusicPlayerService.shared.removeBrowserSource(source)
            }
        }
    }
    func startServer(port: UInt16 = 9876) {
        guard listener == nil else { return }
        do {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
            let webSocket = NWProtocolWebSocket.Options()
            webSocket.autoReplyPing = true
            parameters.defaultProtocolStack.applicationProtocols.insert(webSocket, at: 0)
            let listener = try NWListener(using: parameters)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready: self?.status = "Waiting for browser extension"
                case .failed(let error): self?.status = "Browser bridge: \(error.localizedDescription)"
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] in self?.accept($0) }
            listener.start(queue: .main)
        } catch { status = "Browser bridge: \(error.localizedDescription)" }
    }
    private func accept(_ connection: NWConnection) {
        guard connections.count < 8 else { connection.cancel(); return }
        let id = UUID(); connections[id] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready: self?.receive(id)
            case .failed, .cancelled: self?.removeConnection(id)
            default: break
            }
        }
        connection.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, !self.authenticated.contains(id) else { return }
            self.connections[id]?.cancel()
        }
    }
    private func removeConnection(_ id: UUID) {
        connections.removeValue(forKey: id); authenticated.remove(id)
        for (source, route) in routes where route.connection == id {
            routes.removeValue(forKey: source); MusicPlayerService.shared.removeBrowserSource(source)
        }
        for (request, callback) in pending where callback.connection == id {
            pending.removeValue(forKey: request)?.completion("Browser disconnected.")
        }
        isExtensionConnected = !authenticated.isEmpty
        status = isExtensionConnected ? "Browser connected" : "Waiting for browser extension"
    }
    private func receive(_ id: UUID) {
        connections[id]?.receiveMessage { [weak self] data, context, _, error in
            guard let self, let connection = self.connections[id] else { return }
            if let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata,
               metadata.opcode == .close { connection.cancel(); return }
            if let data, data.count <= 65536, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                self.process(json, connection: id)
            } else if data != nil { connection.cancel(); return }
            if error == nil { self.receive(id) } else { connection.cancel() }
        }
    }
    private func process(_ json: [String: Any], connection id: UUID) {
        guard authenticated.contains(id) else {
            guard json["type"] as? String == "hello", json["token"] as? String == pairingToken else {
                connections[id]?.cancel(); return
            }
            authenticated.insert(id); isExtensionConnected = true; status = "Browser connected"
            send(["type": "authenticated"], to: id); return
        }
        if json["type"] as? String == "ack", let request = json["requestID"] as? String,
           let callback = pending[request], callback.connection == id {
            pending.removeValue(forKey: request)
            callback.completion(json["ok"] as? Bool == true ? nil : (json["error"] as? String ?? "Browser command failed."))
            return
        }
        guard let remote = json["sourceID"] as? String, remote.count < 128 else { return }
        let source = "browser:\(id):\(remote)"
        if json["type"] as? String == "remove" {
            routes.removeValue(forKey: source); MusicPlayerService.shared.removeBrowserSource(source); return
        }
        guard json["type"] as? String == "track_update", let title = json["title"] as? String,
              let playing = json["isPlaying"] as? Bool,
              let position = json["position"] as? Double, position.isFinite,
              let duration = json["duration"] as? Double, duration.isFinite else { return }
        routes[source] = (id, remote, Date())
        let track = TrackInfo(title: String(title.prefix(500)), artist: String((json["artist"] as? String ?? "Browser").prefix(300)),
            album: json["source"] as? String ?? "Browser", duration: duration, position: position, isPlaying: playing,
            playerType: .browser, artworkUrl: json["thumbnail"] as? String, sourceID: source,
            mediaID: json["mediaID"] as? String, canSeek: json["canSeek"] as? Bool ?? false,
            canSkip: json["canSkip"] as? Bool ?? false)
        MusicPlayerService.shared.receiveBrowserTrack(track)
    }
    func sendCommand(sourceID: String, action: String, value: Double? = nil, completion: @escaping (String?) -> Void) {
        guard let route = routes[sourceID], authenticated.contains(route.connection) else { completion("Browser tab is unavailable."); return }
        let request = UUID().uuidString
        pending[request] = (route.connection, completion)
        var payload: [String: Any] = ["type": "command", "action": action, "sourceID": route.remote, "requestID": request]
        if let value { payload["time"] = value }
        send(payload, to: route.connection)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.pending.removeValue(forKey: request)?.completion("Browser did not acknowledge the command. Check the extension.")
        }
    }
    private func send(_ payload: [String: Any], to id: UUID) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        connections[id]?.send(content: data, contentContext: .init(identifier: "message", metadata: [metadata]),
                             isComplete: true, completion: .idempotent)
    }
}
