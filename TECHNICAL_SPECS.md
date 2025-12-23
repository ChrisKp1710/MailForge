# MailForge - Specifiche Tecniche Complete

**Versione:** 1.0
**Data:** 23 Dicembre 2024
**Status:** In Pianificazione

---

## 🎯 Obiettivo del Progetto

Sviluppare un **client email nativo per macOS** di nuova generazione, ottimizzato per Apple Silicon (M1/M2/M3/M4), con focus su:
- **Performance eccezionali**
- **Privacy totale** (on-device, zero telemetria)
- **Interfaccia moderna e intuitiva**
- **Supporto PEC italiana** + email tradizionali
- **Hub di produttività integrato** (email + calendario + note + task)

---

## 🏗️ Architettura Tecnica

### Stack Tecnologico - 100% Apple Native

```
┌─────────────────────────────────────────────┐
│          UI Layer                           │
│  - SwiftUI (dichiarativo, reattivo)         │
│  - Combine / async-await per reactive       │
├─────────────────────────────────────────────┤
│          Business Logic Layer               │
│  - Swift Actors (thread-safe concurrency)   │
│  - MVVM Architecture                        │
│  - Dependency Injection                     │
├─────────────────────────────────────────────┤
│          Email Engine                       │
│  - SwiftNIO (async networking)              │
│  - Custom IMAP/SMTP client (Swift puro)     │
│  - Email parsing & rendering                │
├─────────────────────────────────────────────┤
│          Data Layer                         │
│  - SwiftData (storage & cache)              │
│  - File System (email bodies .eml)          │
│  - Keychain (credenziali sicure)            │
├─────────────────────────────────────────────┤
│          Sync & Cloud (Opzionale)           │
│  - CloudKit (settings sync tra dispositivi) │
├─────────────────────────────────────────────┤
│          AI & ML Layer                      │
│  - CoreML (on-device inference)             │
│  - NaturalLanguage Framework                │
│  - Neural Engine optimization               │
└─────────────────────────────────────────────┘
```

### Principi Architetturali

1. **Privacy by Design**
   - Tutto on-device quando possibile
   - Zero telemetria
   - Credenziali solo in Keychain
   - AI processing locale con CoreML

2. **Performance First**
   - Compilazione nativa ARM64 per Apple Silicon
   - Utilizzo Neural Engine per ML
   - Memory management ottimizzato per unified memory
   - Lazy loading e caching intelligente

3. **Modular & Testable**
   - Separation of Concerns (UI / Logic / Data)
   - Dependency Injection per testabilità
   - Protocol-oriented design
   - Unit tests per business logic critica

---

## 📦 Componenti Principali

### 1. Email Engine (Core)

**Responsabilità:**
- Connessione IMAP/SMTP ai server email
- Fetch, invio, sincronizzazione email
- Parsing email (headers, body, allegati)
- Gestione multi-account

**Tecnologie:**
- **SwiftNIO**: Framework async networking di Apple
- **Swift Concurrency**: async/await, actors per thread safety
- **Custom IMAP Client**: Implementazione Swift pura del protocollo IMAP4rev1
- **Custom SMTP Client**: Implementazione Swift pura per invio email

**Protocolli Supportati:**
- IMAP4rev1 (fetch email)
- SMTP (invio email)
- TLS/SSL per connessioni sicure
- OAuth2 per Gmail/Outlook (opzionale fase 2)

**Dettagli Implementazione IMAP:**
```swift
// Architettura proposta
actor IMAPClient {
    private let channel: NIOAsyncChannel
    private var state: IMAPState

    func connect(host: String, port: Int, useTLS: Bool) async throws
    func login(username: String, password: String) async throws
    func selectFolder(_ folder: String) async throws -> FolderInfo
    func fetchMessages(range: MessageRange) async throws -> [EmailMessage]
    func search(criteria: SearchCriteria) async throws -> [MessageID]
    func setFlags(messageIDs: [MessageID], flags: [Flag]) async throws
    func disconnect() async
}
```

**Gestione PEC:**
- Le PEC sono email IMAP/SMTP standard
- Parser speciale per allegati PEC (daticert.xml, postacert.eml)
- UI dedicata per visualizzare certificazioni e ricevute

---

### 2. Data Layer (SwiftData)

**Responsabilità:**
- Persistenza metadata email (mittente, oggetto, date, flags)
- Cache locale per offline access
- Indici per ricerca full-text
- Sincronizzazione stato (letto/non letto, starred, etc.)

**Schema Dati (SwiftData Models):**

```swift
@Model
class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String
    var type: AccountType // IMAP, PEC, Gmail, Outlook
    var imapHost: String
    var imapPort: Int
    var smtpHost: String
    var smtpPort: Int
    var useTLS: Bool

    @Relationship(deleteRule: .cascade) var folders: [Folder]
}

@Model
class Folder {
    @Attribute(.unique) var id: UUID
    var name: String
    var path: String // IMAP path
    var unreadCount: Int

    @Relationship var account: Account
    @Relationship(deleteRule: .cascade) var messages: [Message]
}

@Model
class Message {
    @Attribute(.unique) var id: UUID
    var messageID: String // IMAP message ID
    var subject: String
    var from: String
    var to: [String]
    var cc: [String]?
    var date: Date
    var isRead: Bool
    var isStarred: Bool
    var hasAttachments: Bool
    var bodyPath: String? // Path a file .eml su disco

    @Relationship var folder: Folder
    @Relationship(deleteRule: .cascade) var attachments: [Attachment]
}

@Model
class Attachment {
    @Attribute(.unique) var id: UUID
    var filename: String
    var mimeType: String
    var size: Int
    var path: String // Path su disco

    @Relationship var message: Message
}
```

**Storage Strategy:**
- **Metadata** → SwiftData (SQLite ottimizzato da Apple)
- **Email bodies** → File system come `.eml` files (~/Library/Application Support/MailForge/emails/)
- **Attachments** → File system (~/Library/Application Support/MailForge/attachments/)
- **Indici ricerca** → SwiftData full-text search indexes

**Cache Management:**
- Keep locale: 30 giorni di email (configurabile)
- Auto-cleanup di email più vecchie
- Download on-demand per email archiviate

---

### 3. UI Layer (SwiftUI)

**Responsabilità:**
- Interfaccia utente moderna e reattiva
- Rendering email (HTML, plain text, PEC)
- Composer per scrivere email
- Navigation e keyboard shortcuts

**Struttura UI:**

```
┌─────────────────────────────────────────────┐
│  Sidebar         │  List      │  Detail     │
│                  │            │             │
│  📬 Inbox (42)   │  Email 1   │  [Preview]  │
│  📤 Sent         │  Email 2   │             │
│  ⭐ Starred      │  Email 3   │  Subject    │
│  📁 Folders      │  Email 4   │  From/To    │
│    └ Work        │  Email 5   │  Body       │
│    └ Personal    │  ...       │  Attachs    │
│                  │            │             │
│  ➕ Accounts     │            │             │
│    └ Account 1   │            │             │
│    └ Account 2   │            │             │
└─────────────────────────────────────────────┘
```

**Componenti SwiftUI:**
- `SidebarView`: Navigazione account, folders, smart folders
- `MessageListView`: Lista email con virtualized scroll (LazyVStack)
- `MessageDetailView`: Preview email con rendering HTML sicuro
- `ComposerView`: Editor per scrivere nuove email
- `SettingsView`: Configurazione app e account

**Design System:**
- **Typography**: SF Pro (system font Apple)
- **Colors**: Dynamic colors con supporto Dark/Light mode
- **Spacing**: Sistema 4pt grid (4, 8, 12, 16, 24, 32, 48)
- **Icons**: SF Symbols 5
- **Animations**: SwiftUI native (withAnimation, transitions)

**Keyboard Shortcuts:**
```
CMD+N     Nuova email
CMD+R     Rispondi
CMD+F     Forward
CMD+K     Command Palette
CMD+1,2,3 Switch account
E         Archivia
U         Marca come non letto
S         Starred
/         Focus ricerca
J/K       Email successiva/precedente (vim-style)
ESC       Chiudi detail/composer
```

---

### 4. Productivity Hub (Fase 2)

**Calendario:**
- Integrazione CalDAV (Google Calendar, iCloud, Exchange)
- Parsing date/orari da email per creare eventi
- Vista giornaliera/settimanale/mensile
- Sincronizzazione bidirezionale

**Note:**
- Editor Markdown nativo (SwiftUI TextEditor + syntax highlighting)
- Link bidirezionali a email specifiche
- Organizzazione in folders/tags
- Ricerca full-text

**Task Management:**
- Conversione email → task
- Todo list con priorità, scadenze, tag
- Vista Kanban / Lista
- Integrazione con calendario

---

### 5. AI Layer (Fase 3)

**Funzionalità:**
- Riassunti automatici email lunghe
- Suggerimenti risposta smart
- Categorizzazione automatica (fatture, newsletter, etc.)
- Correzione grammaticale e tone adjustment
- Traduzione automatica

**Implementazione:**
- **CoreML** per inference on-device
- **NaturalLanguage Framework** per NLP tasks
- Modelli custom addestrati (o fine-tuned) per:
  - Summarization
  - Reply suggestions
  - Email classification
- **Neural Engine** optimization per M-series

**Privacy:**
- TUTTO on-device, zero chiamate a server esterni
- Nessun dato inviato a cloud per AI processing

---

## 🔐 Sicurezza e Privacy

### Gestione Credenziali

- **Keychain macOS**: Storage sicuro per username/password
- **OAuth2** (opzionale): Token per Gmail/Outlook
- **TLS/SSL**: Tutte le connessioni IMAP/SMTP criptate
- **Zero plaintext passwords**: Mai salvate in chiaro

### Privacy

- **Zero telemetria**: Nessun analytics, crash reporting disabilitato di default
- **On-device AI**: Tutto il processing ML locale
- **No third-party SDKs**: Solo framework Apple
- **GDPR compliant**: Nessun dato personale lascia il dispositivo

### Sandboxing

- **App Sandbox**: Abilitato per Mac App Store
- **Hardened Runtime**: Protezione contro code injection
- **Entitlements minimi**: Solo ciò che serve (network, keychain)

---

## 🧪 Testing Strategy

### Unit Tests
- Business logic (IMAP client, parsing, models)
- Data layer (SwiftData operations)
- Utilities e helpers

### Integration Tests
- IMAP/SMTP flow completo con server di test
- SwiftData persistenza e queries

### UI Tests
- User flows critici (login, lettura email, invio)
- Keyboard shortcuts
- Accessibility

### Performance Tests
- Startup time < 1 secondo
- Email list scroll a 60fps
- Search full-text < 100ms per 10K email
- Memory footprint < 200MB per uso normale

---

## 📊 Performance Targets

### Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| App Launch | < 1s | Cold start su M1 base |
| Email Fetch | < 2s | 100 email headers via IMAP |
| Search | < 100ms | Full-text su 10K email |
| UI Responsiveness | 60fps | Scroll email list |
| Memory | < 200MB | Uso normale (1-2 account) |
| Battery Impact | Low | Background sync minimo |

### Optimization

- **Lazy Loading**: Fetch email on-demand
- **Virtualized Lists**: Solo rendering email visibili
- **Image Caching**: Disk + memory cache per allegati
- **Background Processing**: Low-priority queues per sync
- **Compression**: Email bodies compresse su disco

---

## 🔄 Sync & Offline

### Sync Strategy

- **IMAP IDLE**: Push notifications per nuove email (opzionale)
- **Periodic Sync**: Ogni 5 minuti quando app è aperta
- **Background Sync**: Ogni 30 minuti quando app è in background (configurabile)
- **Manual Sync**: Pull-to-refresh

### Offline Mode

- **Cache locale**: 30 giorni di email (configurabile)
- **Read offline**: Email già fetched disponibili offline
- **Compose offline**: Draft salvati localmente, invio quando torna connessione
- **Conflict resolution**: Last-write-wins per flag/folders

---

## 🌐 Multi-Account

### Gestione

- **Unified Inbox**: Vista consolidata di tutti gli account
- **Per-Account Inbox**: Vista separata per ogni account
- **Smart Folders**: Folder virtuali che aggregano da tutti gli account
  - Urgenti
  - Starred
  - Unread
  - Da te
  - CC me

### Account Types

1. **IMAP/SMTP Generico**
   - Server custom (host, port, TLS)
   - Username/password authentication

2. **PEC IONOS** (preset)
   - Host preconfigurati (imap.ionos.it, smtp.ionos.it)
   - Port 993/587, TLS obbligatorio

3. **Gmail** (Fase 2)
   - OAuth2 authentication
   - Label handling speciale

4. **Outlook/Exchange** (Fase 2)
   - OAuth2 o username/password
   - Exchange protocol support

---

## 🎨 Design Principles

### Visual

- **Minimale**: Focus sul contenuto, zero clutter
- **Consistente**: Design system coerente
- **Adattivo**: Dark/Light mode, window resizing
- **Accessibile**: VoiceOver, keyboard navigation, high contrast

### UX

- **Veloce**: Ogni azione < 100ms perceived time
- **Intuitiva**: Zero learning curve per azioni base
- **Power-user friendly**: Keyboard shortcuts per tutto
- **Forgiving**: Undo per azioni critiche (delete, archive)

### Inspirazione

- **Superhuman**: Keyboard-first, velocità, command palette
- **Linear**: Design minimale, animazioni fluide
- **Arc Browser**: Innovazione UX, attenzione ai dettagli
- **Apple Mail**: Familiarità, standard macOS

---

## 📱 Platform Integration

### macOS Features

- **Menu Bar**: Notifiche nuove email con badge
- **Notification Center**: Alert per email importanti
- **Spotlight**: Ricerca email da Spotlight
- **Quick Look**: Preview allegati con SpaceBar
- **Share Extension**: Invia file via email da Finder
- **Handoff**: Continua composizione email da iPhone (Fase futura)

### Apple Silicon Optimization

- **Universal Binary**: ARM64 nativo (no Rosetta)
- **Metal**: Rendering accelerato quando possibile
- **Neural Engine**: AI inference ottimizzato
- **Unified Memory**: Efficienza memory management
- **Low Power Mode**: Riduzione sync in background

---

## 🛠️ Development Tools

### Xcode Setup

- **Xcode 15+**: Richiesto per Swift 6 e SwiftData
- **macOS 14 Sonoma+**: Target deployment
- **Swift 6**: Strict concurrency checking
- **SwiftFormat**: Code formatting automatico
- **SwiftLint**: Linting per best practices

### Dependencies

**Nessuna dipendenza esterna per MVP!** Solo framework Apple:
- SwiftUI
- SwiftData
- SwiftNIO (parte di Swift Server Workgroup, ma considerato "standard")
- Combine
- CryptoKit
- NaturalLanguage
- CoreML

**Opzionali (Fase 2+):**
- Markdown parsing library (se necessario)
- HTML sanitization (o usiamo WebKit)

---

## 📝 Code Style & Conventions

### Swift Style Guide

- **Naming**: camelCase per variabili/funzioni, PascalCase per types
- **Indentation**: 4 spazi (no tabs)
- **Line length**: Max 120 caratteri
- **Access control**: Esplicito (`private`, `internal`, `public`)
- **Documentation**: DocC comments per API pubbliche

### Architecture Patterns

- **MVVM**: Model-View-ViewModel per SwiftUI
- **Protocol-Oriented**: Prefer protocols over inheritance
- **Dependency Injection**: Testabilità e decoupling
- **Actor-based**: Thread safety con Swift actors

### Git Workflow

- **Branch**: `main` (stabile), `develop` (WIP), `feature/*` per nuove feature
- **Commits**: Conventional commits (feat:, fix:, docs:, etc.)
- **PR**: Code review prima di merge in develop

---

## 🚀 Deployment

### Development

- **Local development**: Xcode direct run
- **Debug builds**: Logging verboso, debug UI
- **Test accounts**: PEC/IMAP di test configurati

### Beta Testing

- **TestFlight**: Distribuzione beta a tester
- **Crash reporting**: Opzionale, solo per beta
- **Feedback**: In-app feedback form

### Production

- **Mac App Store**: Distribuzione principale
- **Direct Download**: Opzionale .dmg da sito web
- **Notarization**: Apple notarization obbligatoria
- **Sandboxing**: App sandbox abilitato

---

## 📄 Licensing

- **App License**: Proprietario (closed source per ora)
- **IMAP Client**: Considerare open source in futuro
- **Privacy Policy**: Necessaria per App Store (anche se zero data collection)

---

## 🎯 Success Metrics (Post-Launch)

### User Metrics
- DAU (Daily Active Users)
- Email processate per utente/giorno
- Retention rate 30/60/90 giorni
- Conversion free → Pro

### Performance Metrics
- App startup time P95
- Crash-free rate (target: 99.9%)
- Average memory usage
- Battery drain per hour

### Business Metrics
- Downloads (target: 10K primi 6 mesi)
- Paying users (target: 500 primo anno)
- MRR (Monthly Recurring Revenue)
- Churn rate

---

## 📚 Documentation

### Internal Docs
- Architecture Decision Records (ADR)
- API documentation (DocC)
- Setup guide per sviluppatori
- Testing guide

### User Docs
- Getting started guide
- FAQ
- Keyboard shortcuts reference
- Troubleshooting

---

**Fine Specifiche Tecniche v1.0**

*Questo documento verrà aggiornato durante lo sviluppo quando emergono nuovi requirement o decisioni architetturali.*
