// ColyseusClient.swift — a minimal native Colyseus 0.16 client: HTTP seat-
// reservation matchmaking + a WebSocket room that speaks the protocol opcodes
// (verified against the live server). State arrives via SchemaDecoder; outgoing
// `input`/`face` go as plain msgpack (which the server's msgpackr decodes).
//
// Protocol opcodes: 10 JOIN_ROOM, 11 ERROR, 12 LEAVE_ROOM, 13 ROOM_DATA,
// 14 ROOM_STATE (full), 15 ROOM_STATE_PATCH (delta).
import Foundation
import CoreGraphics

enum ColyseusError: Error { case matchmake(String), badResponse, noConnection }

struct SeatReservation {
    let processId: String
    let roomId: String
    let sessionId: String
}

final class ColyseusClient {
    let endpoint: String // e.g. wss://host  or  ws://localhost:2567

    init(endpoint: String) { self.endpoint = endpoint }

    private var httpBase: String {
        if endpoint.hasPrefix("wss://") { return "https://" + endpoint.dropFirst(6) }
        if endpoint.hasPrefix("ws://") { return "http://" + endpoint.dropFirst(5) }
        return endpoint
    }

    func joinOrCreate(_ room: String, options: [String: Any]) async throws -> ColyseusRoom {
        try await matchmakeAndJoin("joinOrCreate", room, options)
    }
    func create(_ room: String, options: [String: Any]) async throws -> ColyseusRoom {
        try await matchmakeAndJoin("create", room, options)
    }
    func join(_ room: String, options: [String: Any]) async throws -> ColyseusRoom {
        try await matchmakeAndJoin("join", room, options)
    }

    private func matchmakeAndJoin(_ method: String, _ room: String, _ options: [String: Any]) async throws -> ColyseusRoom {
        let res = try await matchmake(method, room, options)
        return ColyseusRoom(endpoint: endpoint, reservation: res)
    }

    private func matchmake(_ method: String, _ room: String, _ options: [String: Any]) async throws -> SeatReservation {
        guard let url = URL(string: "\(httpBase)/matchmake/\(method)/\(room)") else { throw ColyseusError.badResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: options)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ColyseusError.badResponse
        }
        if let err = json["error"] as? String { throw ColyseusError.matchmake(err) }
        guard let roomObj = json["room"] as? [String: Any],
              let roomId = roomObj["roomId"] as? String,
              let sessionId = json["sessionId"] as? String else {
            throw ColyseusError.matchmake((json["error"] as? String) ?? "no seat")
        }
        let processId = (roomObj["processId"] as? String) ?? ""
        return SeatReservation(processId: processId, roomId: roomId, sessionId: sessionId)
    }
}

final class ColyseusRoom: NSObject, URLSessionWebSocketDelegate {
    let sessionId: String
    private let url: URL
    private var task: URLSessionWebSocketTask?
    private let decoder = SchemaDecoder()
    private var joined = false
    private var didLeave = false

    // callbacks (fire on a background queue — hop to main in the integration layer)
    var onState: ((NetState) -> Void)?
    var onError: ((String) -> Void)?
    var onLeave: (() -> Void)?

    init(endpoint: String, reservation: SeatReservation) {
        self.sessionId = reservation.sessionId
        let path = reservation.processId.isEmpty ? "/\(reservation.roomId)" : "/\(reservation.processId)/\(reservation.roomId)"
        let q = "sessionId=\(reservation.sessionId)&reconnectionToken="
        self.url = URL(string: "\(endpoint)\(path)?\(q)")!
        super.init()
    }

    func connect() {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let t = session.webSocketTask(with: url)
        t.maximumMessageSize = 4 * 1024 * 1024 // full-state syncs carry both players' face cutouts
        task = t
        t.resume()
        receive()
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let e):
                if !self.didLeave { self.onError?(e.localizedDescription) }
            case .success(let msg):
                if case .data(let d) = msg { self.handle([UInt8](d)) }
                self.receive()
            }
        }
    }

    private func handle(_ b: [UInt8]) {
        guard let op = b.first else { return }
        switch op {
        case 10: // JOIN_ROOM → reply with a single-byte ack, then state streams
            joined = true
            task?.send(.data(Data([10]))) { _ in }
        case 14: decoder.apply(Array(b.dropFirst()), full: true); onState?(decoder.state)
        case 15: decoder.apply(Array(b.dropFirst()), full: false); onState?(decoder.state)
        case 12: didLeave = true; onLeave?()
        case 11: onError?("server error")
        default: break // 13 ROOM_DATA — everything we need is in state
        }
    }

    // MARK: outgoing

    func sendInput(_ x: CGFloat) {
        send("input", payload: msgMap1("x", msgDouble(Double(x))))
    }
    func sendFace(_ dataURI: String) {
        send("face", payload: msgMap1("data", msgString(dataURI)))
    }

    private func send(_ type: String, payload: [UInt8]) {
        guard let task, joined else { return }
        var frame: [UInt8] = [13]
        frame += msgString(type)
        frame += payload
        task.send(.data(Data(frame))) { _ in }
    }

    func leave() {
        didLeave = true
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }

    // MARK: standard msgpack encoders (big-endian — decoded by server msgpackr)

    private func msgString(_ s: String) -> [UInt8] {
        let u = Array(s.utf8); let len = u.count
        var out: [UInt8] = []
        if len < 32 { out.append(0xa0 | UInt8(len)) }
        else if len < 256 { out.append(0xd9); out.append(UInt8(len)) }
        else if len < 65536 { out.append(0xda); out.append(UInt8(len >> 8)); out.append(UInt8(len & 0xff)) }
        else { out.append(0xdb); for k in stride(from: 24, through: 0, by: -8) { out.append(UInt8((len >> k) & 0xff)) } }
        out += u
        return out
    }
    private func msgDouble(_ d: Double) -> [UInt8] {
        var out: [UInt8] = [0xcb]
        let bits = d.bitPattern
        for k in stride(from: 56, through: 0, by: -8) { out.append(UInt8((bits >> UInt64(k)) & 0xff)) }
        return out
    }
    private func msgMap1(_ key: String, _ value: [UInt8]) -> [UInt8] {
        var out: [UInt8] = [0x81]
        out += msgString(key)
        out += value
        return out
    }
}
