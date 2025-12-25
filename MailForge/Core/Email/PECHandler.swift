import Foundation

// MARK: - PEC Handler

/// Handles Italian PEC (Posta Elettronica Certificata) specific features
/// PEC emails have special headers and attachments (daticert.xml, postacert.eml)
final class PECHandler {

    // MARK: - Properties

    /// Logger category
    private let logCategory: Logger.Category = .pec

    /// Email parser
    private let emailParser = EmailParser()

    // MARK: - Detection

    /// Check if email is a PEC message
    /// - Parameter email: Parsed email
    /// - Returns: True if this is a PEC message
    func isPECMessage(_ email: ParsedEmail) -> Bool {
        // Check for PEC-specific headers
        let headers = email.headers

        // Common PEC headers
        let pecHeaders = [
            "X-Ricevuta",
            "X-Tipo-Ricevuta",
            "X-TipoRicevuta",
            "X-VerificaSicurezza",
            "X-Trasporto"
        ]

        for header in pecHeaders {
            if headers[header] != nil {
                Logger.debug("PEC message detected (header: \(header))", category: logCategory)
                return true
            }
        }

        // Check for daticert.xml attachment
        let attachments = emailParser.extractAttachments(from: email)
        if attachments.contains(where: { $0.filename.lowercased() == "daticert.xml" }) {
            Logger.debug("PEC message detected (daticert.xml found)", category: logCategory)
            return true
        }

        return false
    }

    // MARK: - Parse PEC Data

    /// Parse PEC-specific data from email
    /// - Parameter email: Parsed email
    /// - Returns: PECData or nil if not a PEC message
    func parsePECData(from email: ParsedEmail) -> PECData? {
        guard isPECMessage(email) else {
            return nil
        }

        Logger.info("Parsing PEC data...", category: logCategory)

        let headers = email.headers
        let attachments = emailParser.extractAttachments(from: email)

        // Extract PEC type
        let pecType = extractPECType(from: headers)

        // Find daticert.xml
        let daticert = attachments.first(where: { $0.filename.lowercased() == "daticert.xml" })
        let daticertData = daticert.flatMap { parseDaticert($0) }

        // Find postacert.eml (original message)
        let postacert = attachments.first(where: { $0.filename.lowercased() == "postacert.eml" })

        // Extract receipt info
        let receiptType = headers["X-Tipo-Ricevuta"] ?? headers["X-TipoRicevuta"]
        let receiptDate = parsePECDate(headers["X-Data-Ricevuta"])

        let pecData = PECData(
            type: pecType,
            receiptType: receiptType,
            receiptDate: receiptDate,
            daticertData: daticertData,
            hasPostacert: postacert != nil,
            transport: headers["X-Trasporto"],
            verification: headers["X-VerificaSicurezza"]
        )

        Logger.info("PEC data parsed: \(pecType)", category: logCategory)

        return pecData
    }

    // MARK: - Extract PEC Type

    /// Determine PEC message type
    /// - Parameter headers: Email headers
    /// - Returns: PEC type
    private func extractPECType(from headers: [String: String]) -> PECType {
        // Check X-Ricevuta header
        if let ricevuta = headers["X-Ricevuta"]?.lowercased() {
            if ricevuta.contains("accettazione") {
                return .receipt
            } else if ricevuta.contains("consegna") {
                return .delivery
            } else if ricevuta.contains("errore") || ricevuta.contains("mancata-consegna") {
                return .error
            }
        }

        // Check X-Tipo-Ricevuta
        if let tipoRicevuta = headers["X-Tipo-Ricevuta"]?.lowercased() {
            if tipoRicevuta.contains("accettazione") {
                return .receipt
            } else if tipoRicevuta.contains("consegna") {
                return .delivery
            } else if tipoRicevuta.contains("errore-consegna") {
                return .error
            } else if tipoRicevuta.contains("presa-in-carico") {
                return .receipt
            } else if tipoRicevuta.contains("virus") {
                return .anomaly
            }
        }

        // Check subject for keywords
        let subject = headers["Subject"]?.lowercased() ?? ""
        if subject.contains("accettazione") {
            return .receipt
        } else if subject.contains("consegna") {
            return .delivery
        } else if subject.contains("errore") || subject.contains("mancata consegna") {
            return .error
        }

        // Default: normal PEC message
        return .standard
    }

    // MARK: - Parse Daticert.xml

    /// Parse daticert.xml attachment
    /// - Parameter attachment: daticert.xml attachment
    /// - Returns: Parsed daticert data
    private func parseDaticert(_ attachment: EmailAttachment) -> DaticertData? {
        guard let xmlString = String(data: attachment.data, encoding: .utf8) else {
            Logger.warning("Failed to decode daticert.xml", category: logCategory)
            return nil
        }

        Logger.debug("Parsing daticert.xml (\(xmlString.count) bytes)", category: logCategory)

        // Simple XML parsing (extract key fields)
        // In production, use XMLParser for robust parsing

        let mittente = extractXMLValue(from: xmlString, tag: "mittente")
        let destinatario = extractXMLValue(from: xmlString, tag: "destinatario")
        let oggetto = extractXMLValue(from: xmlString, tag: "oggetto")
        let dataInvio = extractXMLValue(from: xmlString, tag: "data")
        let messageId = extractXMLValue(from: xmlString, tag: "identificativo")
        let gestore = extractXMLValue(from: xmlString, tag: "gestore-emittente")

        return DaticertData(
            mittente: mittente,
            destinatario: destinatario,
            oggetto: oggetto,
            dataInvio: dataInvio,
            messageId: messageId,
            gestore: gestore
        )
    }

    /// Extract value from XML tag
    /// - Parameters:
    ///   - xml: XML string
    ///   - tag: Tag name
    /// - Returns: Tag content or nil
    private func extractXMLValue(from xml: String, tag: String) -> String? {
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"

        guard let startRange = xml.range(of: openTag),
              let endRange = xml.range(of: closeTag, range: startRange.upperBound..<xml.endIndex) else {
            return nil
        }

        let value = String(xml[startRange.upperBound..<endRange.lowerBound])
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse PEC date format
    /// - Parameter dateString: Date string
    /// - Returns: Parsed date or nil
    private func parsePECDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        // PEC date format: "gg/mm/aaaa hh:mm:ss"
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        formatter.locale = Locale(identifier: "it_IT")

        return formatter.date(from: dateString)
    }
}

// MARK: - PEC Data

/// PEC-specific data extracted from email
struct PECData {
    /// Type of PEC message
    let type: PECType

    /// Receipt type (if this is a receipt)
    let receiptType: String?

    /// Receipt date
    let receiptDate: Date?

    /// Parsed daticert.xml data
    let daticertData: DaticertData?

    /// Has postacert.eml attachment (original message)
    let hasPostacert: Bool

    /// Transport info
    let transport: String?

    /// Security verification info
    let verification: String?
}

// MARK: - Daticert Data

/// Data parsed from daticert.xml
struct DaticertData {
    /// Sender (mittente)
    let mittente: String?

    /// Recipient (destinatario)
    let destinatario: String?

    /// Subject (oggetto)
    let oggetto: String?

    /// Send date
    let dataInvio: String?

    /// Message ID
    let messageId: String?

    /// PEC provider (gestore)
    let gestore: String?
}
