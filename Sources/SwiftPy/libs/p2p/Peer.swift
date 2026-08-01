//
//  Peer.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-02-20.
//

import MultipeerConnectivity

// TODO: test
/// An object represents a peer in a multipeer session.
@Scriptable
@MainActor
public class Peer: NSObject {
    /// Callback handler. Set a Callable[[bytes], None] function.
    var onMessage: PyObject?

    private let id: MCPeerID
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private let session: MCSession
    private var onMessageHandler: ((Data) -> Void)?
    private var peerToConnect: String?
    
    /// Initializes a peer with a display name.
    public init(name: String) {
        id = MCPeerID(displayName: name)
        // TODO(tech-debt): peer-encryption — `.none` because `.required` fails the
        // TLS handshake on OS 27. See the `peer-connectivity` skill.
        session = MCSession(peer: id, securityIdentity: nil, encryptionPreference: .none)
        advertiser = MCNearbyServiceAdvertiser(peer: id, discoveryInfo: nil, serviceType: "pocketpy")
        browser = MCNearbyServiceBrowser(peer: id, serviceType: "pocketpy")

        super.init()

        advertiser.delegate = self
        browser.delegate = self
        session.delegate = self
    }

    @MainActor deinit {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    /// Makes the peer discoverable.
    public func advertise() {
        print("[Peer] advertise as '\(id.displayName)' service: 'pocketpy'")
        advertiser.startAdvertisingPeer()
    }

    /// Starts browsing and connects to the peer with the given name.
    public func autoconnect(name: String) {
        print("[Peer] autoconnect: browsing for '\(name)' as '\(id.displayName)'")
        browser.startBrowsingForPeers()
        peerToConnect = name
    }

    /// Sends data to all connected peers.
    public func send(data: Data) throws {
        let peers = session.connectedPeers
        guard !peers.isEmpty else {
            print("[Peer] send skipped: no connected peers (\(data.count) bytes)")
            return
        }
        print("[Peer] send \(data.count) bytes to \(peers.count) peer(s)")
        try session.send(data, toPeers: peers, with: .reliable)
    }
}

extension Peer {
    public func messageReceived(handler: @escaping (Data) -> Void) {
        onMessageHandler = handler
    }
}

extension Peer: MCNearbyServiceAdvertiserDelegate {
    nonisolated public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        print("[Peer] received invitation from '\(peerID.displayName)', accepting")
        // Allways accepts invitations.
        invitationHandler(true, session)
    }

    nonisolated public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: any Error
    ) {
        print("[Peer] failed to start advertising: \(error.localizedDescription)")
    }
}

extension Peer: MCNearbyServiceBrowserDelegate {
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // If the name from autoconnect('name') matches connect to that peer.
        Task { @MainActor in
            if peerID.displayName == peerToConnect {
                print("[Peer] found '\(peerID.displayName)' (target match), inviting")
                browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
            } else {
                print("[Peer] found '\(peerID.displayName)' (ignored, target is '\(peerToConnect ?? "nil")')")
            }
        }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("[Peer] lost peer '\(peerID.displayName)'")
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
        print("[Peer] failed to start browsing: \(error.localizedDescription)")
    }
}

extension MCSession: @retroactive @unchecked Sendable {}
extension MCPeerID: @retroactive @unchecked Sendable {}
extension MCNearbyServiceBrowser: @retroactive @unchecked Sendable {}

extension Peer: MCSessionDelegate {
    nonisolated public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let description = switch state {
        case .notConnected: "notConnected"
        case .connecting: "connecting"
        case .connected: "connected"
        @unknown default: "unknown(\(state.rawValue))"
        }
        print("[Peer] session state '\(peerID.displayName)': \(description)")
    }

    nonisolated public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("[Peer] received \(data.count) bytes from '\(peerID.displayName)'")
        Task { @MainActor [self] in
            _ = try? onMessage?(data)
            onMessageHandler?(data)
        }
    }
    
    nonisolated public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    nonisolated public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    nonisolated public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}
}
