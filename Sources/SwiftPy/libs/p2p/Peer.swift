//
//  Peer.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-02-20.
//

import MultipeerConnectivity
import pocketpy

/// An object represents a peer in a multipeer session.
@Scriptable
@MainActor
public class Peer: NSObject {
    /// Callback handler. Set a Callable[[bytes], None] function.
    var onMessage: object? {
        get { self[.onMessage] }
        set { self[.onMessage] = newValue }
    }

    private let id: MCPeerID
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private let session: MCSession
    private var onMessageHandler: ((Data) -> Void)?
    private var peerToConnect: String?
    
    /// Initializes a peer with a display name.
    public init(name: String) {
        id = MCPeerID(displayName: name)
        session = MCSession(peer: id)
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
        advertiser.startAdvertisingPeer()
    }

    /// Starts browsing and connects to the peer with the given name.
    public func autoconnect(name: String) {
        browser.startBrowsingForPeers()
        peerToConnect = name
    }

    /// Sends data to all connected peers.
    public func send(data: Data) throws {
        try session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension Peer: HasSlots {
    public enum Slot: Int32, CaseIterable {
        case onMessage
    }

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
        // Allways accepts invitations.
        invitationHandler(true, session)
        Task { @MainActor in
            Interpreter.output.stdout("Connected to \(peerID.displayName)")
        }
    }
}

extension Peer: MCNearbyServiceBrowserDelegate {
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // If the name from autoconnect('name') matches connect to that peer.
        Task { @MainActor in
            if peerID.displayName == peerToConnect {
                browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
            }
        }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

extension MCSession: @retroactive @unchecked Sendable {}
extension MCPeerID: @retroactive @unchecked Sendable {}
extension MCNearbyServiceBrowser: @retroactive @unchecked Sendable {}

extension Peer: MCSessionDelegate {
    nonisolated public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {}
    
    nonisolated public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor [self] in
            let bytes = data.retained
            _ = try? self[.onMessage]?.call([bytes.reference])
            onMessageHandler?(data)
        }
    }
    
    nonisolated public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    nonisolated public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    nonisolated public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}
}
