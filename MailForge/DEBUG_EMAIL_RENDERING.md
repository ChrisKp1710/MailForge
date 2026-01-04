# 🐛 Debug Email Rendering - Guida Passo-Passo

## ✅ Modifiche Applicate

### 1. **Fix Base64 Intelligente** (AccountManager.swift)
Il sistema ora rileva il base64 in modo più intelligente:
- ✅ Si fida dell'header `Content-Transfer-Encoding: base64`
- ✅ Auto-rileva SOLO se:
  - Non ci sono tag HTML (`<` o `>`)
  - Il contenuto è lungo (>100 caratteri)
  - Corrisponde al pattern base64: `[A-Za-z0-9+/=\r\n\s]`

### 2. **WebView Migliorata** (MessageDetailView.swift)
- ✅ Logging più dettagliato ad ogni fase
- ✅ Frame minimo aumentato a 300px
- ✅ Bordo blu per vedere i limiti della WebView
- ✅ JavaScript per verificare il caricamento
- ✅ Pulsante "Show Raw / Hide Raw" per vedere l'HTML grezzo

### 3. **CSS Migliorato**
- ✅ Viewport ottimizzato
- ✅ Overflow gestito correttamente
- ✅ Tabelle con larghezza automatica
- ✅ Wrapper `.email-content` per forzare il fit

---

## 🔍 Come Debuggare

### Passo 1: Compila ed Esegui
```bash
# Compila l'app
cmd + B

# Esegui
cmd + R
```

### Passo 2: Apri la Console
1. In Xcode: `View` → `Debug Area` → `Show Debug Area` (o `cmd + shift + Y`)
2. Clicca sulla tab "Console" in basso
3. (Opzionale) Filtra per vedere solo i log delle email: cerca `🌐` o `📧` o `✅`

### Passo 3: Apri una Email
1. Nell'app, clicca su una email che non si vede bene
2. **Guarda la Console** e cerca questi log in sequenza:

---

## 📊 Log da Cercare

### A. Caricamento del Corpo Email

```
🔍 CERCA QUESTI LOG:

✅ Fetching body for message UID 123 in folder 'INBOX'
✅ Step 1: Fetching message info for UID 123
✅ Step 2: Fetching complete message with all parts
✅ Step 3: Converting message to RFC822 format
✅ RFC822 conversion complete: XXXX bytes
```

**❌ Se vedi errori qui:**
- `❌ fetchMessageInfo returned nil` → Il messaggio non esiste sul server
- `❌ Failed to fetch body` → Problema di connessione IMAP

**💡 Soluzione:** Ri-sincronizza la cartella

---

### B. Parsing dell'Email

```
🔍 CERCA QUESTI LOG:

📧 Parsing email body (XXXX chars)
   Found boundary: 'boundary-string-here'    ← Importante per email multipart
📄 Content classified as HTML               ← O "text" se è plain text
💾 Saved to message: bodyHTML=XXXX chars    ← Conferma che l'HTML è stato estratto
```

**❌ Problemi Comuni:**

1. **Boundary non trovato ma è multipart:**
   ```
   📄 Non-multipart email, processing entire body
   ```
   Se l'email DOVREBBE essere multipart ma il boundary non viene trovato:
   - **Soluzione:** L'header `Content-Type` potrebbe essere malformato
   - Clicca "Show Raw" nell'app per vedere l'email raw
   - Cerca `Content-Type:` e `boundary=` nell'email raw

2. **Contenuto classificato come text invece che HTML:**
   ```
   📄 Content classified as text
   ```
   Ma tu sai che è HTML:
   - **Soluzione:** L'HTML potrebbe non iniziare con `<html>` o `<!DOCTYPE>`
   - Clicca "Show Raw" per vedere il contenuto
   - Se vedi tag HTML, il parsing non funziona

3. **bodyHTML è nil o vuoto:**
   ```
   💾 Saved to message: bodyHTML=nil, bodyText=nil
   ⚠️ No HTML or text extracted, using raw body as text
   ```
   - **Soluzione:** Il parsing è completamente fallito
   - Copia l'intero contenuto raw dai log
   - Cerca pattern insoliti (encoding strani, formato non-standard)

---

### C. Decodifica del Contenuto

```
🔍 CERCA QUESTI LOG:

🔄 decodeEmailContent called: encoding=quoted-printable
🔤 Decoding quoted-printable...
✅ Quoted-printable decoded successfully: XX sequences → XXXX chars
```

O per base64:

```
🔍 Auto-detected base64 (no HTML tags, matches base64 pattern)
Decoding base64 content (XXXX chars)
✅ Base64 decoded successfully: XXXX chars
```

**❌ Problemi Comuni:**

1. **Base64 non rilevato:**
   - Vedi caratteri strani tipo `SGVsbG8gV29ybGQ=`
   - **Verifica:** Il contenuto è lungo >100 caratteri e senza tag HTML?
   - **Soluzione Temporanea:** Aggiungi log per vedere perché non viene rilevato

2. **Quoted-printable parziale:**
   - Vedi caratteri tipo `=3D` o `=20` nel testo finale
   - **Soluzione:** Il regex potrebbe non funzionare, controlla gli header

---

### D. Rendering nella WebView

```
🔍 CERCA QUESTI LOG:

🌐 MessageDetailView: Rendering HTML body (XXXX chars)
🌐 Loading HTML content (XXXX chars)
🌐 WKWebView started loading
🌐 Styled HTML length: XXXX chars
✅ WKWebView finished loading HTML content
✅ HTML body length in DOM: XXXX chars    ← IMPORTANTE: Conferma che il DOM ha contenuto
```

**❌ Problemi Comuni:**

1. **WebView finisce di caricare ma DOM è vuoto:**
   ```
   ✅ WKWebView finished loading HTML content
   ✅ HTML body length in DOM: 0 chars    ← ❌ PROBLEMA!
   ```
   - **Causa:** JavaScript/HTML malformato
   - **Soluzione:** Clicca "Show Raw" e controlla se l'HTML è valido

2. **WebView non finisce mai di caricare:**
   ```
   🌐 WKWebView started loading
   (... niente dopo ...)
   ```
   - **Causa:** Errore di parsing HTML, CSP troppo restrittiva, risorsa esterna bloccata
   - **Soluzione:** Cerca errori nella console JS della WebView

3. **WebView mostra pagina bianca:**
   - Vedi il bordo blu ma niente dentro
   - **Causa:** CSS nasconde il contenuto, o il contenuto è effettivamente vuoto
   - **Soluzione:** Ispeziona il DOM con JavaScript console

---

## 🛠️ Tool di Debug nell'App

### Pulsante "Show Raw"
1. Apri una email con contenuto HTML
2. Clicca il pulsante **"Show Raw"** in alto a destra
3. Vedrai l'HTML grezzo che viene passato alla WebView
4. **Cosa cercare:**
   - È HTML valido? Inizia con `<html>` o `<!DOCTYPE>`?
   - Vedi caratteri strani? (`=3D`, `=20`, stringhe base64, ecc.)
   - Vedi tag completi o sono troncati?

### Bordo Blu della WebView
- La WebView ora ha un **bordo blu** sottile
- Se NON lo vedi → La WebView non viene renderizzata
- Se lo vedi ma è vuoto → Il contenuto non viene caricato nella WebView

---

## 🧪 Test Casi Specifici

### Test 1: Email HTML Semplice
**Email di test:** Qualsiasi email con HTML
**Log attesi:**
```
📧 Parsing email body
📄 Content classified as HTML
💾 bodyHTML=XXXX chars
🌐 Rendering HTML body
✅ WKWebView finished loading
✅ HTML body length in DOM: XXXX chars
```
**Risultato atteso:** Email renderizzata correttamente

---

### Test 2: Email Multipart (HTML + Text)
**Email di test:** Gmail, Outlook (di solito sono multipart)
**Log attesi:**
```
📧 Parsing email body
Found boundary: '----=_Part_...'
📄 Content classified as HTML
💾 bodyHTML=XXXX chars, bodyText=XXXX chars
🌐 Rendering HTML body
```
**Risultato atteso:** Versione HTML mostrata (non text)

---

### Test 3: Email Base64
**Email di test:** Email con `Content-Transfer-Encoding: base64`
**Log attesi:**
```
🔄 decodeEmailContent called: encoding=base64
Decoding base64 content
✅ Base64 decoded successfully
```
**Risultato atteso:** Contenuto decodificato e leggibile

---

### Test 4: Email Quoted-Printable
**Email di test:** Email con caratteri accentati (é, è, à)
**Log attesi:**
```
🔄 decodeEmailContent called: encoding=quoted-printable
🔤 Decoding quoted-printable...
✅ Quoted-printable decoded successfully: XX sequences
```
**Risultato atteso:** Caratteri accentati corretti

---

## 📋 Checklist Debug

Quando un'email non funziona, segui questa checklist:

- [ ] **1. Body caricato dal server?**
  - Cerca: `✅ Message body fetched successfully`
  - Se NO → Problema IMAP

- [ ] **2. Boundary trovato? (solo multipart)**
  - Cerca: `Found boundary:`
  - Se NO → Clicca "Show Raw" e cerca `boundary=` nell'header

- [ ] **3. HTML estratto?**
  - Cerca: `💾 bodyHTML=XXXX chars`
  - Se nil → Problema nel parsing

- [ ] **4. Encoding decodificato?**
  - Cerca: `✅ Base64 decoded` o `✅ Quoted-printable decoded`
  - Se NO ma vedi caratteri strani → Problema nel rilevamento encoding

- [ ] **5. WebView caricata?**
  - Cerca: `✅ WKWebView finished loading`
  - Se NO → Problema nella WebView

- [ ] **6. DOM popolato?**
  - Cerca: `✅ HTML body length in DOM: XXXX chars`
  - Se 0 → HTML malformato o JavaScript non funziona

- [ ] **7. WebView visibile?**
  - Vedi il bordo blu?
  - Se NO → Problema di layout SwiftUI

---

## 🆘 Cosa Fare se Niente Funziona

### Caso A: Log OK ma WebView bianca
```
✅ WKWebView finished loading
✅ HTML body length in DOM: 5000 chars
```
Ma non vedi niente.

**Possibili cause:**
1. CSS nasconde il contenuto (colore bianco su sfondo bianco?)
2. Contenuto fuori dallo schermo (posizionamento assoluto?)
3. Problema di rendering della WebView stessa

**Debugging:**
1. Clicca "Show Raw" e verifica che l'HTML sia sensato
2. Cerca `body { ... color: ...}` nel CSS inline
3. Prova a rimuovere tutti gli stili inline dall'HTML per test

---

### Caso B: Parsing fallito
```
💾 bodyHTML=nil, bodyText=nil
⚠️ No HTML or text extracted, using raw body as text
```

**Cosa fare:**
1. Copia i primi 1000 caratteri dell'email raw dai log
2. Controlla manualmente:
   - Dove sono gli header? Dove inizia il body?
   - C'è `Content-Type: multipart/...`?
   - C'è `boundary=...`?
   - Gli header sono separati dal body da `\r\n\r\n` o `\n\n`?

**Esempio di email raw ben formata:**
```
Content-Type: multipart/alternative; boundary="----=_Part_123"

------=_Part_123
Content-Type: text/plain; charset="UTF-8"

Testo plain

------=_Part_123
Content-Type: text/html; charset="UTF-8"

<html>...</html>
------=_Part_123--
```

---

### Caso C: Caratteri Corrotti
Vedi: `Ã¨` invece di `è`, `â€™` invece di `'`

**Causa:** Problema di encoding (UTF-8 interpretato come ISO-8859-1 o viceversa)

**Soluzione:**
1. Cerca nei log: `Decoded as UTF-8` o `Decoded as ISO-Latin-1`
2. L'header `Content-Type: ... charset="..."` potrebbe essere sbagliato
3. Prova a forzare un encoding diverso in `convertMessageToRFC822`

---

## 📝 Come Condividere Info per Debug

Se hai ancora problemi, prepara queste info:

1. **Screenshot della email** (così vedo cosa aspettarti)
2. **Log completi dalla Console** (copia-incolla)
3. **HTML Raw** (clicca "Show Raw" e copia i primi 500 caratteri)
4. **Tipo di account** (Gmail, Outlook, PEC, altro?)
5. **Descrizione del problema:**
   - WebView bianca?
   - Caratteri strani?
   - Codice HTML visibile?
   - Niente carica?

---

## 🎯 Prossimi Step

Dopo aver testato con i log:

1. **Se il parsing funziona ma la WebView no:**
   → Problema di CSS/rendering → Modifica `HTMLEmailView`

2. **Se il parsing non funziona:**
   → Problema di RFC822 parsing → Modifica `parseEmailBody` in `AccountManager`

3. **Se l'encoding non viene rilevato:**
   → Problema di detection → Modifica `decodeEmailContent` in `AccountManager`

4. **Se il base64 non viene decodificato:**
   → Il nuovo rilevamento intelligente ha un problema → Modifica la logica in `decodeEmailContent`

---

**Ricorda:** I log sono il tuo migliore amico! 🚀 Ogni emoji (🌐📧✅❌) ti indica dove guardare.
