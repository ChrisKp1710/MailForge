# 📧 Fix per la Renderizzazione delle Email HTML

## Problema Originale

L'app client email mostrava il contenuto raw delle email invece di renderizzare correttamente l'HTML. A volte l'utente vedeva solo il codice HTML grezzo invece della versione formattata.

## Cause Identificate

### 1. **Coordinator senza stato** (MessageDetailView.swift)
- **Problema**: La classe `Coordinator` nella `HTMLEmailView` non aveva la proprietà `lastLoadedHTML`
- **Sintomo**: La WebView veniva ricaricata continuamente o non si aggiornava correttamente
- **Fix**: Aggiunta proprietà `var lastLoadedHTML: String?` al Coordinator

### 2. **Auto-rilevamento Base64 aggressivo** (AccountManager.swift)
- **Problema**: La regex per rilevare contenuto base64 classificava erroneamente l'HTML come base64
- **Sintomo**: Il contenuto HTML veniva passato al decoder base64 e corrotto
- **Fix**: Rimossa l'auto-rilevazione, ora si fida solo dell'header `Content-Transfer-Encoding`

### 3. **Parsing del boundary non robusto** (AccountManager.swift)
- **Problema**: Il boundary nelle email multipart non veniva estratto correttamente se aveva quote, apici o caratteri speciali
- **Sintomo**: Le email multipart non venivano separate correttamente, l'HTML non veniva estratto
- **Fix**: Migliorata la logica di estrazione del boundary con gestione di quote, apici e caratteri speciali

### 4. **Decodifica quoted-printable sempre attiva** (AccountManager.swift)
- **Problema**: Ogni contenuto veniva processato per quoted-printable anche quando non necessario
- **Sintomo**: Potenziale corruzione di contenuto già decodificato
- **Fix**: Aggiunto controllo per verificare se la decodifica è necessaria prima di applicarla

### 5. **Conversione RFC822 migliorata** (IMAPClient.swift)
- **Problema**: La conversione delle parti del messaggio in RFC822 non gestiva correttamente i vari encoding
- **Sintomo**: Contenuto corrotto o mancante
- **Fix**: Aggiunto fallback per diversi encoding (UTF-8 → ISO-Latin-1 → ASCII) e logging migliorato

## Modifiche Effettuate

### File: MessageDetailView.swift

1. **Aggiunta proprietà al Coordinator**
```swift
class Coordinator: NSObject, WKNavigationDelegate {
    var lastLoadedHTML: String?  // ← NUOVO
    // ...
}
```

2. **Migliorato logging per debug**
```swift
let _ = Logger.debug("🌐 Full HTML starts with: \(htmlBody.prefix(500))", category: .email)
```

### File: AccountManager.swift

1. **Fix auto-rilevamento base64**
```swift
// PRIMA:
let isBase64 = encoding?.lowercased().contains("base64") ?? false ||
              content.range(of: "^[A-Za-z0-9+/=\\s]+$", options: .regularExpression) != nil

// DOPO:
let isBase64 = encoding?.lowercased().contains("base64") ?? false
```

2. **Fix parsing boundary**
```swift
// Gestisce correttamente:
// boundary="something"
// boundary='something'  
// boundary=something; other-params
var boundaryValue = parts[1].trimmingCharacters(in: .whitespaces)

if boundaryValue.hasPrefix("\"") && boundaryValue.contains("\"", range: 1) {
    // Estrae fino alla quote di chiusura
    let endQuoteIndex = boundaryValue.firstIndex(of: "\"", startingFrom: 1) ?? boundaryValue.endIndex
    boundaryValue = String(boundaryValue[boundaryValue.index(after: boundaryValue.startIndex)..<endQuoteIndex])
}
// ... gestione apici e punto-e-virgola
```

3. **Fix decodifica quoted-printable**
```swift
// Controlla se serve la decodifica prima di applicarla
let needsQuotedPrintableDecode = encoding?.lowercased().contains("quoted-printable") ?? false ||
                                 decoded.contains("=3D") ||
                                 decoded.contains("=20") ||
                                 decoded.range(of: "=[0-9A-Fa-f]{2}", options: .regularExpression) != nil

if !needsQuotedPrintableDecode {
    return decoded  // Ritorna senza processare
}
```

4. **Aggiunte estensioni String helper**
```swift
extension String {
    func firstIndex(of character: Character, startingFrom index: Int) -> String.Index?
    func contains(_ substring: String, range: Int) -> Bool
}
```

### File: IMAPClient.swift

1. **Migliorata conversione RFC822**
```swift
// Prova diversi encoding in ordine
if let text = String(data: data, encoding: .utf8) {
    rfc822String += text
} else if let text = String(data: data, encoding: .isoLatin1) {
    rfc822String += text
} else if let text = String(data: data, encoding: .ascii) {
    rfc822String += text
}
```

2. **Aggiunto logging dettagliato**
```swift
Logger.debug("🔄 Converting SwiftMail message to RFC822 format", category: logCategory)
Logger.debug("   Message has \(message.parts.count) parts", category: logCategory)
// ... logging per ogni parte
```

## Come Testare le Modifiche

### 1. Test con Email HTML
1. Apri l'app e vai a una email con contenuto HTML
2. Controlla la Console di Xcode per i log:
   ```
   🌐 MessageDetailView: Rendering HTML body (XXX chars)
   🌐 HTML preview: <!DOCTYPE html>...
   ```
3. Verifica che l'HTML sia renderizzato correttamente nella WebView

### 2. Test con Email Multipart
1. Apri una email con contenuto sia HTML che plain text
2. Controlla i log per vedere se il boundary è stato trovato:
   ```
   Found boundary: 'boundary-string-here'
   ```
3. Verifica che venga mostrata la versione HTML

### 3. Test con Email Encoded
1. Apri una email con encoding quoted-printable o base64
2. Controlla i log:
   ```
   🔄 decodeEmailContent called: encoding=quoted-printable
   ✅ Quoted-printable decoded successfully
   ```
3. Verifica che caratteri speciali (é, è, à, ecc.) siano visualizzati correttamente

### 4. Test con Email Plain Text
1. Apri una email solo testo
2. Verifica che venga mostrata nella `PlainTextEmailView`
3. Controlla il log:
   ```
   📝 MessageDetailView: Rendering plain text body (XXX chars)
   ```

## Debug Avanzato

### Logging Chiave

Per debuggare problemi, cerca questi log nella Console:

**Fetch del corpo dell'email:**
```
Fetching body for message UID X in folder 'INBOX'
Step 1: Fetching message info for UID X
Step 2: Fetching complete message with all parts
Step 3: Converting message to RFC822 format
```

**Parsing dell'email:**
```
📧 Parsing email body (XXX chars)
Found boundary: 'boundary-string'
📄 Content classified as HTML / text
💾 Saved to message: bodyHTML=XXX chars, bodyText=XXX chars
```

**Rendering nella UI:**
```
🌐 MessageDetailView: Rendering HTML body (XXX chars)
🌐 Loading HTML content (XXX chars)
✅ WKWebView finished loading HTML content
```

### Problemi Comuni

**1. WebView mostra pagina bianca**
- Controlla: `🌐 HTML preview:` nei log - verifica che l'HTML sia valido
- Verifica: `✅ WKWebView finished loading` - conferma che il caricamento sia completato
- Soluzione: Potrebbe essere un problema di CSS o JavaScript - controlla la Content Security Policy

**2. Caratteri strani (�, =3D, ecc.)**
- Controlla: `🔄 decodeEmailContent called` - verifica quale encoding viene rilevato
- Verifica: `✅ Quoted-printable decoded successfully` o `✅ Base64 decoded successfully`
- Soluzione: Il contenuto potrebbe avere un encoding non dichiarato - controlla gli header raw

**3. Solo testo grezzo visibile**
- Controlla: `Found boundary:` - se non c'è, il multipart non è stato rilevato
- Verifica: `📄 Content classified as HTML` - conferma che l'HTML sia stato identificato
- Soluzione: Il boundary potrebbe essere malformato - controlla l'header Content-Type

**4. Email non si carica affatto**
- Controlla: `Fetching body for message UID X` - verifica che la fetch inizi
- Verifica: Errori come `❌ fetchMessageInfo returned nil`
- Soluzione: Il messaggio potrebbe essere stato eliminato dal server - ri-sincronizza la cartella

## Prossimi Passi

### Miglioramenti Possibili

1. **Cache del contenuto HTML**: Salvare l'HTML decodificato su disco per evitare re-fetch
2. **Supporto per attachment inline**: Gestire immagini embedded con CID
3. **Miglioramento CSP**: Policy di sicurezza più restrittive per contenuti non fidati
4. **Altezza dinamica WebView**: Calcolare l'altezza reale del contenuto HTML
5. **Dark mode**: Migliorare il supporto per email con/senza dark mode

### Test Aggiuntivi

- [ ] Test con email PEC certificate
- [ ] Test con attachment inline (immagini CID)
- [ ] Test con email in lingue non-latine (Cinese, Arabo, ecc.)
- [ ] Test con email molto grandi (>1MB)
- [ ] Test con email HTML complesse (tabelle, CSS inline)

## Riferimenti

- [RFC 2045](https://tools.ietf.org/html/rfc2045) - MIME Part One: Format of Internet Message Bodies
- [RFC 2046](https://tools.ietf.org/html/rfc2046) - MIME Part Two: Media Types
- [RFC 2047](https://tools.ietf.org/html/rfc2047) - MIME Part Three: Message Header Extensions
- [RFC 2048](https://tools.ietf.org/html/rfc2048) - MIME Part Four: Registration Procedures
- [RFC 2049](https://tools.ietf.org/html/rfc2049) - MIME Part Five: Conformance Criteria

---

**Data**: 4 Gennaio 2026  
**Autore**: Claude AI Assistant  
**Versione**: 1.0
