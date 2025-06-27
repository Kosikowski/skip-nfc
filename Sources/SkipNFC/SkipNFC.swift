// Copyright 2023–2025 Skip
// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception
#if !SKIP_BRIDGE
import Foundation
#if SKIP
import skip.ui.UIApplication
import android.app.Activity
import android.nfc.__
import android.nfc.tech.__
#elseif canImport(CoreNFC)
import CoreNFC
#endif

/// An NFCAdapter that wraps `CoreNFC.NFCNDEFReaderSession` on iOS and `android.nfc.NfcAdapter` on Android.
public final class NFCAdapter: NSObject {
    private var messageHandler: ((NDEFMessage) -> ())?
    #if SKIP
    private var nfcAdapter: NfcAdapter?
    #elseif canImport(CoreNFC)
    private var nfcSession: NFCNDEFReaderSession?
    #endif

    public override init() {
        #if SKIP
        self.nfcAdapter = NfcAdapter.getDefaultAdapter(self.activity)
        #elseif canImport(CoreNFC)
        super.init()
        self.nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        #endif
    }

    public var isAvailable: Bool {
        #if SKIP
        return self.nfcAdapter != nil
        #elseif canImport(CoreNFC)
        return NFCNDEFReaderSession.readingAvailable
        #else
        return false
        #endif
    }

    /// For iOS, set the alert message for the user when initiating the NFC scanning. E.g., “Hold your device near the NFC tag”
    public var alertMessage: String? {
        get {
            #if canImport(CoreNFC)
            return self.nfcSession?.alertMessage
            #else
            return nil
            #endif
        }

        set {
            #if canImport(CoreNFC)
            self.nfcSession?.alertMessage = newValue ?? ""
            #else
            // no-op
            #endif
        }
    }

    public func startScanning(messageHandler: @escaping (NDEFMessage) -> ()) {
        self.messageHandler = messageHandler
        #if SKIP
        var flags = 0
        // example of setting flags on the reader scan
        // https://developer.android.com/reference/android/nfc/NfcAdapter#FLAG_READER_NFC_A
        //flags = NfcAdapter.FLAG_READER_NFC_A
        // https://developer.android.com/reference/android/nfc/NfcAdapter#FLAG_READER_SKIP_NDEF_CHECK
        //flags = flags | NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK
        self.nfcAdapter?.enableReaderMode(activity, self, flags, nil)
        #elseif canImport(CoreNFC)
        self.nfcSession?.begin()
        #endif
    }

    public func stopScanning() {
        #if SKIP
        self.nfcAdapter?.disableReaderMode(activity)
        #elseif canImport(CoreNFC)
        self.nfcSession?.invalidate()
        #endif
        self.messageHandler = nil
    }

    func handleMessage(_ message: NDEFMessage) {
        self.messageHandler?(message)
        return
    }

    #if SKIP
    fileprivate var activity: android.app.Activity? {
        UIApplication.shared.androidActivity
    }
    #endif
}

#if SKIP
extension NFCAdapter: NfcAdapter.ReaderCallback {
    // SKIP @nobridge
    override func onTagDiscovered(tag: Tag) {
        // https://developer.android.com/reference/android/nfc/tech/Ndef
        let ndef: Ndef = Ndef.get(tag)
        ndef.connect()
        if let message: NdefMessage = ndef.getNdefMessage() {
            handleMessage(NDEFMessage(platformValue: message))
        }
    }
}
#elseif canImport(CoreNFC)
extension NFCAdapter: NFCNDEFReaderSessionDelegate {
    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: any Error) {
        // TODO: error handling
    }
    
    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        for message in messages {
            handleMessage(NDEFMessage(platformValue: message))
        }
    }
}
#endif

/// https://developer.android.com/reference/android/nfc/NdefMessage
/// https://developer.apple.com/documentation/corenfc/nfcndefmessage
public final class NDEFMessage {
    #if SKIP
    typealias PlatformValue = NdefMessage
    #elseif canImport(CoreNFC)
    typealias PlatformValue = NFCNDEFMessage
    #else
    typealias PlatformValue = Void
    #endif

    let platformValue: PlatformValue

    init(platformValue: PlatformValue) {
        self.platformValue = platformValue
    }

    public var records: [NDEFRecord] {
        var records: [NDEFRecord] = []
        #if SKIP
        for record in self.platformValue.getRecords() {
            records.append(NDEFRecord(platformValue: record))
        }
        #elseif canImport(CoreNFC)
        for record in self.platformValue.records {
            records.append(NDEFRecord(platformValue: record))
        }
        #endif
        return records
    }
}

/// https://developer.android.com/reference/android/nfc/NdefRecord
/// https://developer.apple.com/documentation/corenfc/nfcndefpayload
public final class NDEFRecord {
    #if SKIP
    typealias PlatformValue = NdefRecord
    #elseif canImport(CoreNFC)
    typealias PlatformValue = NFCNDEFPayload
    #else
    typealias PlatformValue = Void
    #endif

    let platformValue: PlatformValue

    init(platformValue: PlatformValue) {
        self.platformValue = platformValue
    }

    /// The identifier of the payload, as defined by the NDEF specification.
    public var identifier: Data {
        #if SKIP
        return Data(platformValue: platformValue.getId())
        #elseif canImport(CoreNFC)
        return platformValue.identifier
        #else
        return Data()
        #endif
    }

    /// The type of the payload, as defined by the NDEF specification.
    public var type: Data {
        #if SKIP
        return Data(platformValue: platformValue.getType())
        #elseif canImport(CoreNFC)
        return platformValue.type
        #else
        return Data()
        #endif
    }

    /// The payload, as defined by the NDEF specification.
    public var payload: Data {
        #if SKIP
        return Data(platformValue: platformValue.getPayload())
        #elseif canImport(CoreNFC)
        return platformValue.payload
        #else
        return Data()
        #endif
    }

    public var typeName: TypeName {
        #if SKIP
        switch platformValue.getTnf() {
        case NdefRecord.TNF_ABSOLUTE_URI: return .absoluteURI
        case NdefRecord.TNF_EMPTY: return .empty
        case NdefRecord.TNF_EXTERNAL_TYPE: return .nfcExternal
        case NdefRecord.TNF_UNCHANGED: return .unchanged
        case NdefRecord.TNF_UNKNOWN: return .unknown
        case NdefRecord.TNF_WELL_KNOWN: return .nfcWellKnown
        //case NdefRecord.TNF_MIME_MEDIA:
        default: return .unknown
        }
        #elseif canImport(CoreNFC)
        switch platformValue.typeNameFormat {
        case .empty: return .empty
        case .nfcWellKnown: return .nfcWellKnown
        case .media: return .media
        case .absoluteURI: return .absoluteURI
        case .nfcExternal: return .nfcExternal
        case .unknown: return .unknown
        case .unchanged: return .unchanged
        @unknown default: return .unknown
        }
        #else
        return .unknown
        #endif
    }

    public enum TypeName {
        case empty
        case nfcWellKnown
        case media
        case absoluteURI
        case nfcExternal
        case unknown
        case unchanged
    }
}


#endif
