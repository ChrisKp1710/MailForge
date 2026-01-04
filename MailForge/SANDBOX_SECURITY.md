# 🔒 Sicurezza e Sandbox - Email Rendering

## ⚠️ Warning Sandbox

Se vedi warning sulla sandbox tipo:
```
Sandbox: deny(1) network-outbound
Sandbox: deny(1) file-read-data
```

**Non preoccuparti!** Questi sono **normali** e **corretti** per una app sandboxed.

---

## 🛡️ Content Security Policy (CSP)

La WebView ora usa una CSP **molto restrittiva**:

```
default-src 'none';           ← Blocca tutto di default
style-src 'unsafe-inline';    ← Permette CSS inline (necessario per email)
img-src * data: blob: https: http:;  ← Permette immagini da qualsiasi fonte
font-src 'self' data:;        ← Permette font embedded
media-src * data: blob:;      ← Permette video/audio
script-src 'unsafe-inline';   ← Permette SOLO JavaScript inline (NO script esterni!)
```

### Cosa Significa:

✅ **Permesso:**
- CSS inline nell'email (colori, font, layout)
- Immagini da server esterni (HTTP/HTTPS)
- Immagini embedded (data: URLs)
- Font incorporati
- Video/audio embedded

❌ **Bloccato:**
- Script JavaScript esterni (`.js` files)
- Connessioni WebSocket
- Fetch/XHR verso server esterni
- Plugins (Flash, ecc.)
- Frames/iframes da altri siti

---

## 🔐 Sandbox di macOS

### Entitlements Richiesti

L'app ha bisogno di questi entitlements (nel file `.entitlements`):

```xml
<!-- Network per IMAP/SMTP -->
<key>com.apple.security.network.client</key>
<true/>

<!-- NO server (non ospitiamo servizi) -->
<key>com.apple.security.network.server</key>
<false/>

<!-- File access limitato (solo Application Support e Downloads) -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<!-- NO accesso a tutta la Home -->
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

### Warning Normali da Ignorare

Questi warning sono **OK** e indicano che la sandbox funziona:

```
❌ Sandbox: deny(1) network-outbound
   → Bloccato tentativo di connessione non autorizzata (BENE!)

❌ Sandbox: deny(1) file-read-data /path/to/file
   → Bloccato accesso a file fuori dalla sandbox (BENE!)

❌ Sandbox: deny(1) mach-lookup com.apple.xxx
   → Bloccato accesso a servizio di sistema (BENE!)
```

### Warning Preoccupanti (da Risolvere)

Questi invece indicano un problema:

```
⚠️ App Sandbox violation: network-outbound attempted without entitlement
   → Manca entitlement per rete (AGGIUNGI!)

⚠️ Critical sandbox violation
   → Tentativo di accesso non autorizzato (CONTROLLA!)
```

---

## 🌐 WebView e Sandbox

### Cosa Può Fare la WebView

✅ **Permesso dalla sandbox:**
- Caricare HTML/CSS inline (da stringa)
- Renderizzare immagini con `data:` URLs
- Eseguire JavaScript inline (limitato dalla CSP)
- Mostrare contenuti incorporati

❌ **Bloccato dalla sandbox:**
- Scaricare script `.js` esterni
- Fare fetch/XHR a server
- Accedere al filesystem locale
- Aprire connessioni WebSocket

### Come Gestiamo le Immagini Remote

Le email spesso contengono immagini remote tipo:
```html
<img src="https://example.com/image.png">
```

**Problema:** La sandbox blocca network-outbound per la WebView!

**Soluzioni:**

#### Opzione 1: Proxy Locale (Raccomandato)
1. Scarica le immagini con URLSession (che ha entitlement network)
2. Converti in `data:` URLs
3. Sostituisci gli `<img src="">` nell'HTML prima di mostrarlo

#### Opzione 2: Allow Network per WebView
Aggiungi entitlement:
```xml
<key>com.apple.security.network.client</key>
<true/>
```

⚠️ **Attenzione:** Questo permette alla WebView di fare richieste, potenziale tracking!

#### Opzione 3: Blocca Immagini Remote
Non fare nulla. Le immagini remote saranno bloccate (icona ❌).

**Raccomandazione:** Usa Opzione 1 o 3 (più sicuro).

---

## 🔍 Debug Sandbox Issues

### Come Vedere i Sandbox Violations

1. Apri la **Console.app** (Applicazioni → Utility → Console)
2. Filtra per: `Sandbox` o il nome della tua app
3. Cerca righe tipo `deny(1)` o `violation`

### Interpretiamo i Log

```
Sandbox: deny(1) network-outbound 10.0.0.1:443 target:/usr/libexec/nsurlsessiond
```

**Significa:**
- `deny(1)` = Bloccato (corretto!)
- `network-outbound` = Tentativo di connessione in uscita
- `10.0.0.1:443` = Server di destinazione
- `nsurlsessiond` = URLSession (per IMAP/SMTP)

**Azione:** Verifica che l'app abbia l'entitlement `com.apple.security.network.client`

---

```
Sandbox: deny(1) file-read-data /Users/xxx/.ssh/known_hosts
```

**Significa:**
- Tentativo di leggere file `.ssh` (bloccato correttamente!)

**Azione:** Nessuna, questo è **desiderato**!

---

```
Sandbox: deny(1) mach-lookup com.apple.WebKit.WebContent
```

**Significa:**
- WebView prova ad accedere a un servizio di sistema

**Azione:** Questo può essere normale per WebKit. Se l'app funziona, ignora.

---

## 🛠️ Fixing Sandbox Violations

### Se vedi "network-outbound" per IMAP/SMTP

**Soluzione:** Aggiungi al file `.entitlements`:
```xml
<key>com.apple.security.network.client</key>
<true/>
```

### Se vedi "file-read-data" per email salvate

**Soluzione:** Assicurati di salvare i file in:
- `~/Library/Application Support/[App Bundle ID]/`
- O usa User Selected Files con file picker

### Se vedi "mach-lookup" per WebKit

**Soluzione:** Aggiungi:
```xml
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>com.apple.WebKit.WebContent</string>
    <string>com.apple.WebKit.Networking</string>
</array>
```

⚠️ Questo è un'eccezione temporanea. Usa solo se necessario!

---

## ✅ Checklist Sicurezza

Verifica che la tua app abbia:

- [ ] **CSP restrittiva** nel HTML della WebView
- [ ] **No JavaScript esterni** (solo inline limitato)
- [ ] **Entitlement network.client** per IMAP/SMTP
- [ ] **File access limitato** (solo Application Support)
- [ ] **No entitlement pericolosi** (come `allow-dyld-environment-variables`)
- [ ] **Immagini remote** proxy tramite URLSession (opzionale)
- [ ] **Link esterni** aperti in browser (✅ già implementato!)

---

## 🎯 Configurazione Raccomandata

### 1. File Entitlements

Crea/modifica `YourApp.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Enable App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Network Client (for IMAP/SMTP) -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- File Access (user selected files only) -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <!-- Keychain Access -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>$(TeamIdentifierPrefix)com.yourcompany.yourapp</string>
    </array>
</dict>
</plist>
```

### 2. Build Settings

In Xcode:
1. Target → Signing & Capabilities
2. Verifica "App Sandbox" sia **ON**
3. Abilita:
   - ✅ Outgoing Connections (Network Client)
   - ✅ User Selected Files (Read/Write)
   - ❌ Incoming Connections (NO!)
   - ❌ Camera/Microphone (NO!)

---

## 📊 Test della Sicurezza

### Test 1: CSP Funziona?
1. Apri una email con `<script src="https://evil.com/script.js">`
2. Guarda la Console JavaScript della WebView
3. Dovresti vedere: `Refused to load script due to Content Security Policy`

✅ **Passa:** Script bloccato  
❌ **Fallisce:** Script viene eseguito

### Test 2: Link Esterni Si Aprono nel Browser?
1. Apri una email con un link
2. Clicca sul link
3. Dovrebbe aprirsi Safari/Chrome, non nella WebView

✅ **Passa:** Si apre browser esterno  
❌ **Fallisce:** Si apre nella WebView

### Test 3: File System Protetto?
1. Prova ad aprire Console.app
2. Cerca sandbox violations per la tua app
3. Verifica che non ci siano `deny(1)` per percorsi sensibili tipo `/etc/`, `/private/`, ecc.

✅ **Passa:** Nessun accesso a file sensibili  
❌ **Fallisce:** L'app legge file al di fuori della sandbox

---

## 🚨 Red Flags (Segnali di Pericolo)

Se vedi questi nel codice, **RIMUOVILI**:

❌ `disable-library-validation` entitlement  
❌ `allow-dyld-environment-variables` entitlement  
❌ `allow-unsigned-executable-memory` entitlement  
❌ `loadFileURL()` in WKWebView (senza sicurezza)  
❌ JavaScript con `eval()`  
❌ CSP con `default-src *` (troppo permissiva)  

---

## 📝 Best Practices

### 1. Principle of Least Privilege
Abilita **solo** gli entitlements necessari:
- ✅ Network client (per IMAP/SMTP)
- ✅ User selected files (per allegati)
- ❌ Network server (non serve)
- ❌ Full disk access (non serve)

### 2. Defense in Depth
Molteplici livelli di sicurezza:
1. **Sandbox di macOS** - Limita l'app
2. **CSP** - Limita la WebView
3. **Navigation Policy** - Blocca navigazione non autorizzata
4. **URL Validation** - Verifica URL prima di aprirli

### 3. Validate, Don't Trust
- Non fidarti dell'HTML nelle email
- Sanifica sempre l'input
- Usa CSP restrittiva
- Blocca script esterni

---

## 🎓 Riferimenti

- [Apple Sandbox Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/)
- [WKWebView Security](https://developer.apple.com/documentation/webkit/wkwebview)
- [Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
- [macOS Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)

---

## ✅ Conclusione

La tua app ora è **sicura**:
- ✅ Sandbox attiva
- ✅ CSP restrittiva
- ✅ No script esterni
- ✅ Link aperti nel browser
- ✅ JavaScript limitato

I warning sandbox che vedi sono **normali** e indicano che la protezione funziona!

Se hai dubbi specifici su un warning, copia il log e ti dico se è normale o preoccupante.
