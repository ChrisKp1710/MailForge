# MailForge - Roadmap di Sviluppo

**Versione:** 1.0
**Ultima Modifica:** 23 Dicembre 2024 - 18:59
**Status Progetto:** 🟡 In Progress

---

## 📊 Overview Progetto

### Timeline Stimata
- **Fase 0**: Setup & Fondamenta → 2-3 settimane
- **Fase 1**: Email Core MVP → 6-8 settimane
- **Fase 2**: Produttività Avanzata → 4-6 settimane
- **Fase 3**: AI & Automazione → 4-6 settimane
- **Fase 4**: Polish & Launch → 2-3 settimane

**Totale stimato: 4-6 mesi per versione 1.0 completa**

### Approach
- ✅ **Qualità > Velocità**: Codice fatto bene da subito
- ✅ **100% Swift Nativo**: Zero compromessi su performance
- ✅ **Privacy First**: On-device, zero telemetria
- ✅ **Apple Silicon Optimized**: Sfruttare al massimo M-series

---

## 🎯 Milestone Overview

| Fase | Obiettivo | Features | Status | Completamento |
|------|-----------|----------|--------|---------------|
| **Fase 0** | Setup & Fondamenta | Progetto Xcode, Design System, Architettura | 🟡 In Progress | 25% |
| **Fase 1** | Email Core MVP | IMAP/SMTP, Lettura/Invio, UI Base | 🔴 Not Started | 0% |
| **Fase 2** | Produttività | Calendario, Note, Task | 🔴 Not Started | 0% |
| **Fase 3** | AI & Automazione | ML on-device, Smart features | 🔴 Not Started | 0% |
| **Fase 4** | Polish & Launch | Testing, Beta, App Store | 🔴 Not Started | 0% |

**Progress Totale: 5%**

---

## 📅 Fase 0: Setup & Fondamenta (2-3 settimane)

**Obiettivo:** Creare le fondamenta solide del progetto - architettura, design system, struttura base.

**Status:** 🟡 In Progress
**Completamento:** 25%

### Tasks

#### 1. Setup Progetto Xcode ✅ COMPLETATO
- [x] Creare nuovo progetto Swift Package
  - App macOS
  - SwiftUI lifecycle
  - Target: macOS 14+
  - Swift 6
- [x] Configurare Git repository
  - .gitignore per Xcode/Swift
  - Branch main creato
  - Initial commit fatto
- [x] Setup folder structure
  ```
  MailForge/
  ├── Sources/MailForge/
  │   ├── App/
  │   ├── Core/
  │   ├── Features/
  │   ├── UI/
  │   └── Utils/
  ├── Package.swift
  └── ...
  ```
- [x] Configurare Swift Package Manager
  - SwiftNIO dependency (v2.92.0)
  - NIOSSL dependency (v2.36.0)
  - Build verificato: ZERO errori, ZERO warning

**Stima:** 1-2 giorni
**Completato:** 23 Dicembre 2024

---

#### 2. Design System Foundation
- [ ] Definire palette colori
  - Light mode colors
  - Dark mode colors
  - Semantic colors (primary, secondary, accent, etc.)
- [ ] Typography system
  - Font sizes (SF Pro)
  - Font weights
  - Line heights
- [ ] Spacing system
  - 4pt grid (4, 8, 12, 16, 24, 32, 48, 64)
- [ ] Creare componenti SwiftUI base
  - `DSButton` (Design System Button)
  - `DSTextField`
  - `DSCard`
  - `DSList`
  - `DSSidebar`
- [ ] Icon system
  - SF Symbols mapping
  - Custom icons se necessario

**Stima:** 3-4 giorni

---

#### 3. Architettura & Boilerplate
- [ ] Setup MVVM architecture
  - Base `ViewModel` protocol
  - Base `View` structure
- [ ] Dependency Injection setup
  - Service container / Registry
  - Protocol per services
- [ ] SwiftData schema iniziale
  - `Account` model
  - `Folder` model
  - `Message` model
  - `Attachment` model
- [ ] File system structure
  - Application Support directory setup
  - Emails folder
  - Attachments folder
  - Cache management base

**Stima:** 3-4 giorni

---

#### 4. Core Utilities
- [ ] Keychain wrapper
  - Save credentials
  - Load credentials
  - Delete credentials
- [ ] Logging system
  - Swift OSLog wrapper
  - Log levels (debug, info, warning, error)
- [ ] Configuration management
  - User defaults wrapper
  - Settings persistence
- [ ] Error handling
  - Custom error types
  - User-friendly error messages

**Stima:** 2-3 giorni

---

### Deliverable Fase 0
✅ Progetto Xcode configurato e funzionante
✅ Design system base implementato
✅ Architettura MVVM + SwiftData pronta
✅ Utilities core funzionanti
✅ Pronto per iniziare sviluppo Email Engine

---

## 📧 Fase 1: Email Core MVP (6-8 settimane)

**Obiettivo:** Client email funzionante - lettura, invio, gestione base. Focus su PEC + IMAP generico.

**Status:** 🔴 Not Started
**Completamento:** 0%

### Tasks

#### 1. SwiftNIO IMAP Client (Custom Implementation)
- [ ] Setup SwiftNIO base
  - Channel pipeline configuration
  - TLS/SSL handler
- [ ] IMAP protocol implementation
  - [ ] Connection & Login
    - CAPABILITY command
    - LOGIN command
    - TLS negotiation (STARTTLS)
  - [ ] Folder operations
    - LIST command (fetch folders)
    - SELECT command (select folder)
    - EXAMINE command (read-only select)
  - [ ] Message fetching
    - FETCH command (headers, body, flags)
    - UID FETCH (persistent IDs)
    - BODY.PEEK (non-marking as read)
  - [ ] Search
    - SEARCH command
    - Search criteria (FROM, TO, SUBJECT, DATE, etc.)
  - [ ] Flags & State
    - STORE command (set flags)
    - FLAGS (\Seen, \Flagged, \Deleted, etc.)
  - [ ] IDLE support (push notifications)
- [ ] IMAP State Machine
  - Not Authenticated
  - Authenticated
  - Selected
  - Logout
- [ ] Error handling robusto
  - Network errors
  - Authentication failures
  - Protocol errors
- [ ] Unit tests per IMAP client
  - Mock server per testing
  - Test coverage > 80%

**Stima:** 2-3 settimane

---

#### 2. SMTP Client (Invio Email)
- [ ] SwiftNIO SMTP implementation
  - EHLO/HELO command
  - AUTH LOGIN (authentication)
  - MAIL FROM / RCPT TO / DATA
  - TLS support (STARTTLS)
- [ ] Email composition
  - MIME message builder
  - Headers (From, To, Cc, Bcc, Subject, Date)
  - Plain text body
  - HTML body
  - Multipart/alternative
- [ ] Attachments
  - MIME multipart/mixed
  - Base64 encoding
  - Content-Type detection
- [ ] Send queue
  - Retry logic per fallimenti
  - Offline queue (invia quando torna rete)

**Stima:** 1-2 settimane

---

#### 3. Email Parsing & Storage
- [ ] Email parser
  - Headers parsing (RFC 5322)
  - Body extraction (text/html)
  - Attachment extraction
  - MIME decoding
- [ ] SwiftData integration
  - Save messages to SwiftData
  - Save attachments to file system
  - Indexing per ricerca full-text
- [ ] PEC handling speciale
  - Riconoscere email PEC (headers specifici)
  - Parse allegati PEC (daticert.xml, postacert.eml)
  - UI speciale per visualizzare certificazioni

**Stima:** 1-2 settimane

---

#### 4. Account Management
- [ ] Account setup flow
  - UI per aggiungere account
  - Form: email, password, IMAP/SMTP hosts, ports
  - Preset per PEC IONOS
  - Test connessione
  - Save credenziali in Keychain
- [ ] Multi-account support
  - Switch tra account
  - Unified inbox
  - Per-account inbox
- [ ] Account settings
  - Edit account
  - Remove account
  - Sync settings (frequency, etc.)

**Stima:** 1 settimana

---

#### 5. UI - Inbox & Message List
- [ ] Sidebar
  - Account list
  - Folders tree
  - Smart folders (Inbox, Sent, Starred, etc.)
- [ ] Message List View
  - LazyVStack per performance
  - Message row (from, subject, date, preview)
  - Unread indicator
  - Star icon
  - Selection state
- [ ] Pull-to-refresh
- [ ] Loading states
- [ ] Empty states

**Stima:** 1 settimana

---

#### 6. UI - Message Detail View
- [ ] Email preview
  - Headers (From, To, Cc, Date)
  - Subject
  - Body rendering
    - Plain text
    - HTML (sanitized con WebKit)
  - Attachments list
- [ ] Actions
  - Reply
  - Reply All
  - Forward
  - Archive
  - Delete
  - Star/Unstar
  - Mark as read/unread
- [ ] Keyboard navigation
  - J/K per navigare email
  - E per archiviare
  - R per reply
  - etc.

**Stima:** 1 settimana

---

#### 7. UI - Composer (Scrivere Email)
- [ ] Composer window/sheet
  - To/Cc/Bcc fields
  - Subject field
  - Body editor (TextEditor)
  - Rich text formatting base (grassetto, corsivo, liste)
- [ ] Attachments
  - Drag & drop files
  - File picker
  - Preview allegati
  - Remove attachment
- [ ] Send functionality
  - Validation (recipient, subject)
  - Sending state
  - Error handling
- [ ] Draft auto-save
  - Save draft ogni 30s
  - Restore draft al reopen

**Stima:** 1 settimana

---

#### 8. Search & Filters
- [ ] Search bar
  - Full-text search (SwiftData query)
  - Search in subject, from, to, body
- [ ] Filters
  - Unread only
  - Starred only
  - Has attachments
  - Date range
- [ ] Search results view
  - Highlight matching terms

**Stima:** 3-4 giorni

---

#### 9. Settings & Preferences
- [ ] Settings window
  - General settings
  - Accounts management
  - Appearance (Light/Dark mode toggle)
  - Notifications settings
  - Keyboard shortcuts reference
- [ ] Preferences persistence
  - UserDefaults wrapper

**Stima:** 2-3 giorni

---

#### 10. Background Sync
- [ ] Periodic sync
  - Fetch new messages every N minutes
  - Background fetch con low priority
- [ ] IMAP IDLE (push notifications)
  - Opzionale, solo se server supporta
- [ ] Notification Center integration
  - Local notifications per nuove email importanti

**Stima:** 3-4 giorni

---

### Testing & Bug Fixing
- [ ] Test con account PEC IONOS reale
- [ ] Test con Gmail (IMAP)
- [ ] Test con Outlook/Exchange
- [ ] Performance testing
  - Load 1000+ email
  - Search performance
  - Memory usage
- [ ] Bug fixing & polish

**Stima:** 1 settimana

---

### Deliverable Fase 1
✅ Client email funzionante
✅ IMAP/SMTP client custom in Swift
✅ Multi-account support (PEC + IMAP generico)
✅ UI moderna per inbox, lettura, composizione
✅ Ricerca full-text
✅ Sync in background
✅ **MVP pronto per uso quotidiano (dogfooding)**

---

## 📅 Fase 2: Produttività Avanzata (4-6 settimane)

**Obiettivo:** Aggiungere calendario, note, task management - trasformare MailForge in productivity hub.

**Status:** 🔴 Not Started
**Completamento:** 0%

### Tasks

#### 1. Calendario Integrato
- [ ] CalDAV client (per Google Calendar, iCloud)
  - Fetch eventi
  - Create evento
  - Update evento
  - Delete evento
- [ ] Calendario UI
  - Vista giornaliera
  - Vista settimanale
  - Vista mensile
  - Event detail view
- [ ] Integrazione con email
  - Parse date/orari da email
  - Suggerimento "Crea evento da questa email"
  - Link evento ↔ email
- [ ] Sincronizzazione
  - Periodic sync con calendari remoti
  - Conflict resolution

**Stima:** 2-3 settimane

---

#### 2. Note (Markdown Editor)
- [ ] Note model (SwiftData)
  - Title, body, tags, date
  - Link a email/eventi
- [ ] Markdown editor
  - Syntax highlighting
  - Preview mode
  - Shortcuts (CMD+B per bold, etc.)
- [ ] Note organization
  - Folders
  - Tags
  - Search full-text
- [ ] Link bidirezionali
  - Note → Email
  - Email → Note

**Stima:** 1-2 settimane

---

#### 3. Task Management
- [ ] Task model (SwiftData)
  - Title, description, priority, due date, status
  - Tags, project
- [ ] Task UI
  - Lista task
  - Vista Kanban (opzionale)
  - Filter by status/priority/tag
- [ ] Email → Task conversion
  - Un click per creare task da email
- [ ] Integrazione calendario
  - Task con scadenza appare in calendario

**Stima:** 1-2 settimane

---

#### 4. Smart Folders & Organization
- [ ] Smart folders automatici
  - Urgenti (heuristic: oggi + unread)
  - Da seguire (non risposto in 3 giorni)
  - Newsletter (pattern recognition)
- [ ] Tags & labels custom
  - Assegna tag a email
  - Filter by tag
- [ ] Snooze email
  - Nascondi email fino a data/ora specifica
  - Riappare automaticamente

**Stima:** 1 settimana

---

### Testing & Polish
- [ ] Integration testing (calendario + email + note + task)
- [ ] Performance testing
- [ ] Bug fixing

**Stima:** 3-5 giorni

---

### Deliverable Fase 2
✅ Calendario integrato con sync CalDAV
✅ Note editor Markdown
✅ Task management funzionante
✅ Smart folders e organizzazione avanzata
✅ **MailForge diventa productivity hub completo**

---

## 🤖 Fase 3: AI & Automazione (4-6 settimane)

**Obiettivo:** Aggiungere intelligenza artificiale on-device per automazione e produttività.

**Status:** 🔴 Not Started
**Completamento:** 0%

### Tasks

#### 1. Riassunti Email (Summarization)
- [ ] CoreML model per summarization
  - Training o fine-tuning di modello
  - Ottimizzazione per Neural Engine
- [ ] UI per riassunto
  - "TL;DR" button
  - Preview riassunto sopra email
- [ ] Performance optimization
  - Caching riassunti generati
  - Background processing

**Stima:** 1-2 settimane

---

#### 2. Suggerimenti Risposta (Reply Suggestions)
- [ ] NaturalLanguage framework
  - Sentiment analysis
  - Key phrase extraction
- [ ] Smart reply generation
  - 3 suggerimenti di risposta breve
  - Contextual (basato su email ricevuta)
- [ ] UI integration
  - Quick reply buttons in composer

**Stima:** 1-2 settimane

---

#### 3. Categorizzazione Automatica
- [ ] Email classifier (CoreML)
  - Categorie: Fattura, Ordine, Newsletter, Personale, Lavoro, etc.
  - Training su dataset etichettato
- [ ] Auto-tagging
  - Assegna tag automaticamente
- [ ] Smart folder population
  - Popola smart folders basati su categoria

**Stima:** 1-2 settimane

---

#### 4. Correzione & Tone Adjustment
- [ ] Grammar correction (NaturalLanguage)
  - Suggerimenti grammaticali in composer
- [ ] Tone detection & adjustment
  - Rileva tone (formale, casual, amichevole)
  - Suggerisci riscrittura per tone diverso
- [ ] Translation (opzionale)
  - Traduci email in diverse lingue
  - CoreML translation model

**Stima:** 1 settimana

---

#### 5. Automazioni Intelligenti
- [ ] Rule engine
  - "Se email da X, allora tag Y"
  - "Se newsletter, archivia dopo 3 giorni se non letta"
- [ ] Follow-up reminders
  - "Non hai ricevuto risposta da 3 giorni, vuoi follow-up?"
- [ ] Smart notifications
  - "Questa email sembra importante" (priority inbox)

**Stima:** 1 settimana

---

### Testing & Optimization
- [ ] AI performance testing
  - Latency < 200ms per inference
  - Battery impact acceptable
- [ ] Model optimization
  - Quantization per ridurre size
  - Neural Engine profiling
- [ ] Bug fixing

**Stima:** 3-5 giorni

---

### Deliverable Fase 3
✅ AI riassunti email on-device
✅ Suggerimenti risposta intelligenti
✅ Categorizzazione automatica
✅ Correzione grammaticale e tone adjustment
✅ Automazioni smart
✅ **MailForge con intelligenza artificiale integrata**

---

## 🚀 Fase 4: Polish & Launch (2-3 settimane)

**Obiettivo:** Preparare l'app per il lancio pubblico - testing, polish UI, App Store submission.

**Status:** 🔴 Not Started
**Completamento:** 0%

### Tasks

#### 1. UI/UX Polish
- [ ] Design refinement
  - Animazioni fluide
  - Transizioni coerenti
  - Micro-interactions
- [ ] Accessibility
  - VoiceOver support
  - Keyboard navigation completo
  - High contrast mode
  - Dynamic type support
- [ ] Dark/Light mode polish
  - Tutti gli edge cases coperti
  - Smooth transition

**Stima:** 1 settimana

---

#### 2. Performance Optimization
- [ ] Profiling con Instruments
  - Memory leaks
  - CPU hotspots
  - Disk I/O optimization
- [ ] Startup time optimization
  - Target: < 1 secondo cold start
- [ ] Battery optimization
  - Background activity minimizzata

**Stima:** 3-4 giorni

---

#### 3. Testing Completo
- [ ] Unit tests coverage > 80%
- [ ] Integration tests per flow critici
- [ ] UI tests
- [ ] Manual QA
  - Test su diversi Mac (M1, M2, M3)
  - Test con account reali (PEC, Gmail, Outlook)
  - Test edge cases

**Stima:** 1 settimana

---

#### 4. Beta Testing
- [ ] TestFlight setup
- [ ] Recruit beta testers (20-50 persone)
- [ ] Collect feedback
- [ ] Iterate su feedback critico
- [ ] Bug fixing

**Stima:** 2 settimane (parallelo ad altre tasks)

---

#### 5. App Store Preparation
- [ ] App Store assets
  - Icon (1024x1024)
  - Screenshots (varie risoluzioni)
  - Preview video (opzionale)
- [ ] App Store copy
  - Descrizione app
  - Keywords
  - Privacy policy
  - Support URL
- [ ] Notarization
  - Apple notarization process
  - Hardened runtime
  - App Sandbox configuration
- [ ] Submission
  - Upload build
  - App Review submission

**Stima:** 2-3 giorni

---

#### 6. Marketing & Launch
- [ ] Landing page
  - Website con info app
  - Download link
  - Pricing info
- [ ] Product Hunt launch
- [ ] Social media announcement
- [ ] Press kit (opzionale)

**Stima:** 3-5 giorni

---

### Deliverable Fase 4
✅ App polished e performante
✅ Beta testing completato
✅ App Store submission approved
✅ **MailForge 1.0 LANCIATO! 🚀**

---

## 📊 Post-Launch (Continuo)

### Maintenance & Iteration
- [ ] Monitor crash reports
- [ ] Fix bug critici ASAP
- [ ] Collect user feedback
- [ ] Plan next features (v1.1, v1.2, etc.)

### Feature Roadmap (Post v1.0)
- [ ] iOS companion app (iPhone/iPad)
- [ ] Plugin system per estensioni third-party
- [ ] Integrazioni (Notion, Todoist, Slack, etc.)
- [ ] Advanced email templates
- [ ] Email scheduling (send later)
- [ ] Read receipts & tracking
- [ ] Team features (shared inboxes, etc.)

---

## 🎯 Success Metrics

### Technical KPIs
- [ ] Startup time < 1s (P95)
- [ ] Crash-free rate > 99.5%
- [ ] App size < 50MB
- [ ] Memory usage < 200MB (average)

### User KPIs
- [ ] 10,000 downloads (6 mesi)
- [ ] 500 paying users (1 anno)
- [ ] 4.5+ stars App Store rating
- [ ] 30-day retention > 40%

### Business KPIs
- [ ] MRR €2,500/mese (12 mesi)
- [ ] Conversion rate free→Pro > 5%
- [ ] Churn rate < 5%/mese

---

## 📝 Note & Decisioni

### Log Decisioni Architetturali

**23 Dicembre 2024:**
- ✅ Deciso: 100% Swift nativo (no Objective-C)
- ✅ Deciso: SwiftData per storage (vs CoreData)
- ✅ Deciso: SwiftNIO per IMAP/SMTP custom (vs MailCore2)
- ✅ Deciso: Approccio qualità > velocità
- ✅ Deciso: Privacy-first, on-device AI

### Rischi & Mitigazioni

| Rischio | Probabilità | Impatto | Mitigazione |
|---------|-------------|---------|-------------|
| IMAP custom troppo complesso | Media | Alto | Start con subset IMAP minimo, aggiungi features incrementalmente |
| Performance AI non accettabile | Bassa | Medio | Profile early, ottimizza modelli CoreML, usa Neural Engine |
| Timeline troppo ottimistica | Media | Medio | Buffer time in ogni fase, MVP minimo ben definito |
| Competizione (Superhuman, Spark) | Alta | Medio | Differenziazione: PEC, privacy, prezzo, native macOS |

---

## ✅ Checklist Pre-Launch

- [ ] Tutte le features MVP funzionanti
- [ ] Zero crash critici
- [ ] Performance targets raggiunti
- [ ] UI/UX polished
- [ ] Accessibility compliant
- [ ] Privacy policy scritta
- [ ] App Store assets pronti
- [ ] Beta testing completato con feedback positivo
- [ ] Notarization approved
- [ ] Landing page live
- [ ] Support email configurato

---

**🚀 MailForge - Building the Future of Email on macOS**

*Questo documento verrà aggiornato regolarmente durante lo sviluppo per tracciare il progresso e adattare la roadmap in base a nuove scoperte e feedback.*

---

**Legend:**
- 🔴 Not Started
- 🟡 In Progress
- 🟢 Completed
- ⏸️ Paused
- ❌ Cancelled
