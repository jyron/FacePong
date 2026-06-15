// SchemaDecoder.swift — a decoder for the FacePong @colyseus/schema (v3) room
// state. Hand-verified byte-for-byte against live server captures.
//
// Wire format (little-endian "notepack" primitives):
//   • The decode stream is a flat sequence of operations against a "current ref".
//   • 255 (SWITCH_TO_STRUCTURE) + a refId switches the current ref.
//   • For a Schema ref: [opByte] where op = (b>>6)<<6 and fieldIndex = b % (op||255),
//     followed by the field value (primitive) — or a refId for the players map.
//   • For the players MapSchema ref: [opByte][index][key string (on ADD)][playerRefId].
// We model only PongState + Player (their field orders are fixed below).
import CoreGraphics

struct NetPlayer {
    var sessionId = ""
    var slot = "p1"
    var x: CGFloat = 195
    var score = 0
    var name = ""
    var hasFace = false
    var faceData = ""
}

struct NetState {
    var phase = "waiting"
    var code = ""
    var ballX: CGFloat = 195
    var ballY: CGFloat = 422
    var rally = 0
    var round = 1
    var servingSlot = "p1"
    var scorerSlot = ""
    var winnerSlot = ""
    var topRally = 0
    var countdown = 0
    var players: [String: NetPlayer] = [:]   // keyed by sessionId
}

final class SchemaDecoder {
    private(set) var state = NetState()

    // reference tracking
    private var mapRefId = -1
    private var playerKeyByRefId: [Int: String] = [:]
    private var mapIndexToKey: [Int: String] = [:]

    private enum Cursor { case root, map, player(String), unknown }

    /// Apply a ROOM_STATE (full) or ROOM_STATE_PATCH (delta) payload.
    func apply(_ b: [UInt8], full: Bool) {
        if full {
            state = NetState()
            mapRefId = -1
            playerKeyByRefId.removeAll()
            mapIndexToKey.removeAll()
        }
        var i = 0
        let n = b.count
        var cursor: Cursor = .root
        while i < n {
            if b[i] == 255 { // SWITCH_TO_STRUCTURE
                i += 1
                let rid = Int(readNumber(b, &i))
                if rid == 0 { cursor = .root }
                else if rid == mapRefId { cursor = .map }
                else if let key = playerKeyByRefId[rid] { cursor = .player(key) }
                else { cursor = .unknown }
                continue
            }
            switch cursor {
            case .root: decodeRootField(b, &i)
            case .map: decodeMapEntry(b, &i)
            case .player(let key): decodePlayerField(key, b, &i)
            case .unknown: return // unknown ref → stop to avoid desync
            }
        }
    }

    private func decodeRootField(_ b: [UInt8], _ i: inout Int) {
        let first = Int(b[i]); i += 1
        let op = (first >> 6) << 6
        let index = first % (op == 0 ? 255 : op)
        switch index {
        case 0: state.phase = readString(b, &i)
        case 1: state.code = readString(b, &i)
        case 2: state.ballX = CGFloat(readNumber(b, &i))
        case 3: state.ballY = CGFloat(readNumber(b, &i))
        case 4: state.rally = Int(readNumber(b, &i))
        case 5: state.round = Int(readNumber(b, &i))
        case 6: state.servingSlot = readString(b, &i)
        case 7: state.scorerSlot = readString(b, &i)
        case 8: state.winnerSlot = readString(b, &i)
        case 9: state.topRally = Int(readNumber(b, &i))
        case 10: state.countdown = Int(readNumber(b, &i))
        case 11: // players map
            if (op & 64) != 0 && (op & 128) == 0 {
                state.players.removeAll(); mapIndexToKey.removeAll()
            } else {
                mapRefId = Int(readNumber(b, &i))
            }
        default: break
        }
    }

    private func decodeMapEntry(_ b: [UInt8], _ i: inout Int) {
        let op = Int(b[i]); i += 1
        if op == 10 { state.players.removeAll(); mapIndexToKey.removeAll(); return } // CLEAR
        let index = Int(readNumber(b, &i))
        if (op & 64) != 0 { // DELETE or DELETE_AND_ADD
            if let key = mapIndexToKey[index] {
                state.players[key] = nil
                for (rid, k) in playerKeyByRefId where k == key { playerKeyByRefId[rid] = nil }
            }
            if op == 64 { return } // pure delete — no value follows
        }
        if (op & 128) != 0 { // ADD or DELETE_AND_ADD → key + child refId
            let key = readString(b, &i)
            mapIndexToKey[index] = key
            let prid = Int(readNumber(b, &i))
            if i < b.count && b[i] == 213 { i += 1; _ = readNumber(b, &i) } // TYPE_ID
            playerKeyByRefId[prid] = key
            if state.players[key] == nil {
                var np = NetPlayer(); np.sessionId = key; state.players[key] = np
            }
        } else { // REPLACE: existing index, new child refId
            let key = mapIndexToKey[index] ?? ""
            let prid = Int(readNumber(b, &i))
            playerKeyByRefId[prid] = key
        }
    }

    private func decodePlayerField(_ key: String, _ b: [UInt8], _ i: inout Int) {
        var p = state.players[key] ?? NetPlayer()
        let first = Int(b[i]); i += 1
        let op = (first >> 6) << 6
        let index = first % (op == 0 ? 255 : op)
        if (op & 64) != 0 && op != 192 { return } // delete (no value) — players' primitives don't delete
        switch index {
        case 0: p.sessionId = readString(b, &i)
        case 1: p.slot = readString(b, &i)
        case 2: p.x = CGFloat(readNumber(b, &i))
        case 3: p.score = Int(readNumber(b, &i))
        case 4: p.name = readString(b, &i)
        case 5: p.hasFace = readBoolean(b, &i)
        case 6: p.faceData = readString(b, &i)
        default: break
        }
        state.players[key] = p
    }

    // MARK: little-endian primitive readers (match @colyseus/schema decode.ts)

    private func readNumber(_ b: [UInt8], _ i: inout Int) -> Double {
        let p = b[i]; i += 1
        switch p {
        case 0x00...0x7f: return Double(p)
        case 0xca: return Double(Float(bitPattern: UInt32(readLE(b, &i, 4)))) // float32
        case 0xcb: return Double(bitPattern: readLE(b, &i, 8))        // float64
        case 0xcc: let v = b[i]; i += 1; return Double(v)
        case 0xcd: return Double(readLE(b, &i, 2))
        case 0xce: return Double(readLE(b, &i, 4))
        case 0xcf: return Double(readLE(b, &i, 8))
        case 0xd0: let v = Int8(bitPattern: b[i]); i += 1; return Double(v)
        case 0xd1: return Double(Int16(bitPattern: UInt16(readLE(b, &i, 2))))
        case 0xd2: return Double(Int32(bitPattern: UInt32(readLE(b, &i, 4))))
        case 0xd3: return Double(Int64(bitPattern: readLE(b, &i, 8)))
        case 0xe0...0xff: return Double(Int(p) - 256)
        default: return 0
        }
    }

    private func readLE(_ b: [UInt8], _ i: inout Int, _ count: Int) -> UInt64 {
        var v: UInt64 = 0
        for k in 0..<count { v |= UInt64(b[i + k]) << (8 * k) }
        i += count
        return v
    }

    private func readString(_ b: [UInt8], _ i: inout Int) -> String {
        let p = b[i]; i += 1
        var len = 0
        if p < 0xc0 { len = Int(p & 0x1f) }
        else if p == 0xd9 { len = Int(b[i]); i += 1 }
        else if p == 0xda { len = Int(readLE(b, &i, 2)) }
        else if p == 0xdb { len = Int(readLE(b, &i, 4)) }
        guard len > 0, i + len <= b.count else { return "" }
        let s = String(bytes: b[i..<i + len], encoding: .utf8) ?? ""
        i += len
        return s
    }

    private func readBoolean(_ b: [UInt8], _ i: inout Int) -> Bool {
        let v = b[i] > 0; i += 1; return v
    }
}
