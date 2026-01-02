# Analisi Completa: Spark Mail
## Studio per Competitor MailForge

**Data**: 1 Gennaio 2026
**Obiettivo**: Analizzare Spark Mail per creare un competitor con MailForge
**Focus Iniziale**: Features senza AI (AI in futuro)

---

## 📊 Overview di Spark Mail

### Numeri Chiave
- **19,5 milioni** di download
- **Rating**: 4.6/5 su iOS App Store
- **Premio**: "Scelta della Redazione" Apple
- **Piattaforme**: iPhone, iPad, Mac, Windows, Android, Apple Watch
- **Compatibilità**: IMAP, iCloud, Exchange, Outlook, Yahoo, Google

---

## 🎯 FEATURES PRINCIPALI DA IMPLEMENTARE

### 1. SMART INBOX (Priorità Alta)

#### Tre Tipi di Inbox:

**A. Smart Inbox 2.0 (Focused List)** - CONSIGLIATO
- Lista focalizzata con priorità
- Categorie automatiche:
  - **Priority** (email importanti in cima)
  - **Pins** (messaggi fissati)
  - **Notifications** (notifiche)
  - **Newsletters** (newsletter)
  - **Invitations** (inviti calendario)
  - **Assigned to me** (assegnate a me - team)

**B. Smart Inbox (Unread Cards)**
- Raggruppa email non lette in card
- Categorie:
  - People (persone)
  - Notifications (notifiche)
  - Newsletters (newsletter)
  - Pins (fissate)
  - Seen (viste)

**C. Classic Inbox**
- Lista semplice tradizionale
- Per utenti che preferiscono approccio classico

**Implementazione per MailForge:**
```
Fase 1: Classic Inbox (già fatto ✓)
Fase 2: Categorie automatiche (People, Notifications, Newsletters)
Fase 3: Smart Inbox 2.0 con prioritizzazione
Fase 4: Card view opzionale
```

---

### 2. GESTIONE EMAIL (Priorità Alta)

#### Actions Principali

**Completata (Done)**
- Marca email come "completata"
- Sposta fuori dalla inbox (archivio)
- Shortcut: ⌘E o swipe

**Metti da Parte (Set Aside)**
- Sposta temporaneamente email
- Riappare quando necessario
- Simile a "Snooze" ma più contestuale

**Posticipa (Snooze)**
- Posticipa email a data/ora specifica
- Opzioni quick: "Più tardi oggi", "Domani", "Questo weekend", "Prossima settimana"
- Opzione custom: scegli data/ora

**Pin**
- Fissa email importanti in cima
- Sempre visibili indipendentemente da filtri
- Shortcut: ⌘⇧P

**Implementazione per MailForge:**
```swift
enum EmailAction {
    case done           // Archivia
    case setAside       // Metti da parte (cartella temporanea)
    case snooze(Date)   // Posticipa
    case pin            // Fissa
    case delete         // Elimina
    case spam           // Segna come spam
}
```

---

### 3. SWIPE GESTURES (Priorità Alta)

#### 4 Direzioni Personalizzabili
- **Short swipe left**: es. Archive
- **Long swipe left**: es. Delete
- **Short swipe right**: es. Mark as read
- **Long swipe right**: es. Pin

**Azioni Disponibili:**
- Mark as read/unread
- Pin/Unpin
- Archive
- Delete
- Snooze
- Move to folder
- Mark as spam

**Implementazione per MailForge:**
```swift
struct SwipeConfig {
    var shortLeft: EmailAction = .archive
    var longLeft: EmailAction = .delete
    var shortRight: EmailAction = .markRead
    var longRight: EmailAction = .pin
}
```

---

### 4. SIDEBAR PERSONALIZZABILE (Priorità Media)

#### Elementi Sidebar
- **Smart Folders** (cartelle intelligenti)
- **All Mail** (tutte le email)
- **Unread** (non lette)
- **Starred** (con stella)
- **Attachments** (con allegati)
- **From Clients** (da clienti specifici)
- **Invoices** (fatture)
- **Custom Smart Folders** (create dall'utente)

**Smart Folders** - Cerca e Salva:
1. Cerca email per mittente, oggetto, keyword
2. Salva ricerca come Smart Folder
3. Accesso rapido dalla sidebar

**Implementazione per MailForge:**
```swift
struct SmartFolder {
    let name: String
    let icon: String
    let query: SearchQuery
    let color: Color?

    struct SearchQuery {
        var sender: String?
        var subject: String?
        var keywords: [String]
        var hasAttachments: Bool?
        var dateRange: DateRange?
        var flags: [MessageFlag]
    }
}
```

---

### 5. QUICK ACTIONS & SHORTCUTS (Priorità Alta)

#### Command Center
- Lista di tutte le azioni disponibili
- Ricerca rapida di comandi
- Simile a Command Palette in VSCode
- Shortcut: ⌘K

**Preset Shortcuts Disponibili:**
- Spark Desktop
- Mail.app (Apple)
- Gmail
- Superhuman
- Custom (personalizzato)

**Azioni Comuni:**
- Compose new email: ⌘N
- Reply: ⌘R
- Reply All: ⌘⇧R
- Forward: ⌘⇧F
- Archive: E
- Delete: ⌫
- Mark as read: ⌘⇧U
- Search: ⌘F
- Next email: ↓
- Previous email: ↑

**Implementazione per MailForge:**
```swift
struct CommandCenter {
    let commands: [Command]

    struct Command {
        let name: String
        let description: String
        let shortcut: KeyboardShortcut
        let action: () -> Void
        let icon: String
        let category: CommandCategory
    }

    enum CommandCategory {
        case compose, navigate, manage, search, settings
    }
}
```

---

### 6. CALENDAR INTEGRATION (Priorità Media)

#### Features
- Calendario integrato nell'app
- Supporta: Google, Exchange, Microsoft 365, Outlook, iCloud
- Widget calendario in inbox
- Aggiungi eventi senza uscire da email
- Visualizza eventi mentre leggi email

**Implementazione per MailForge:**
```swift
// Usare EventKit framework
import EventKit

struct CalendarIntegration {
    let eventStore: EKEventStore

    func requestAccess()
    func fetchEvents(for date: Date)
    func createEvent(from email: Message)
    func showCalendarWidget()
}
```

---

### 7. WIDGETS (Priorità Bassa)

#### Widget Disponibili (max 3)
- **Recently Seen** (visti di recente)
- **Attachments** (allegati recenti)
- **Calendar** (calendario)
- **Unread** (non letti)
- **Important** (importanti)

Accessibili rapidamente dall'inbox.

---

### 8. GATEKEEPER (Priorità Media)

#### Blocco Mittenti Sconosciuti
- Blocca automaticamente mittenti sconosciuti
- Solo mittenti approvati arrivano in inbox
- Lista whitelist/blacklist
- Riduce spam e distrazioni

**Implementazione per MailForge:**
```swift
struct GateKeeper {
    var enabled: Bool
    var whitelist: Set<String>  // Email approvate
    var blacklist: Set<String>  // Email bloccate
    var unknownAction: GateKeeperAction

    enum GateKeeperAction {
        case block          // Blocca completamente
        case quarantine     // Metti in cartella separata
        case askApproval    // Chiedi conferma
    }
}
```

---

### 9. SEND LATER (Priorità Media)

#### Pianifica Invio Email
- Scegli data/ora per inviare email
- Email salvata in "Scheduled"
- Inviata automaticamente al momento giusto
- Annulla/modifica prima dell'invio

**Implementazione per MailForge:**
```swift
struct ScheduledEmail {
    let message: Message
    let scheduledDate: Date
    var status: ScheduleStatus

    enum ScheduleStatus {
        case pending
        case sending
        case sent
        case cancelled
        case failed(Error)
    }
}
```

---

### 10. REMINDERS & FOLLOW-UP (Priorità Bassa)

#### Auto-Reminders
- Promemoria automatici per email senza risposta
- "Ricordami se non rispondo in X giorni"
- "Ricordami se non ricevo risposta in X giorni"

---

## 🎨 UI/UX DESIGN PRINCIPLES

### Layout Generale

#### 3-Column Layout (Desktop)
1. **Sidebar** (150-250px)
   - Accounts
   - Smart Folders
   - Folders
   - Labels/Tags

2. **Email List** (300-500px)
   - Subject + Preview
   - Sender + Date
   - Flags/Icons
   - Avatar

3. **Email Detail** (Resto dello spazio)
   - Full email content
   - Actions toolbar
   - Attachments
   - Related emails

### Design Principi
- **Clean & Minimal**: Interfaccia pulita, pochi elementi
- **Focus on Content**: Contenuto email è protagonista
- **Smart Categorization**: Categorie intelligenti e automatiche
- **Quick Actions**: Tutto accessibile in 1-2 click/swipe
- **Customizable**: Tutto personalizzabile dall'utente

---

## 🚀 ROADMAP IMPLEMENTAZIONE PER MAILFORGE

### FASE 1: FONDAMENTALI (4-6 settimane)
**Priorità: CRITICA**

- [x] 3-column layout
- [x] Email list view
- [x] Email detail view
- [x] Multiple accounts
- [x] IMAP sync
- [ ] **FIX: Email body rendering** ⚠️
- [ ] Swipe gestures (4 direzioni)
- [ ] Quick actions toolbar
- [ ] Archive/Delete/Pin
- [ ] Mark as read/unread

### FASE 2: SMART FEATURES (6-8 settimane)
**Priorità: ALTA**

- [ ] Smart Inbox categorization
  - [ ] Detect People vs Notifications vs Newsletters
  - [ ] Auto-categorize using email headers
  - [ ] Priority detection
- [ ] Snooze functionality
  - [ ] Quick snooze options
  - [ ] Custom date/time picker
  - [ ] Snooze storage and notifications
- [ ] Pin messages
- [ ] Done/Set Aside actions
- [ ] Search functionality
- [ ] Command Center (⌘K)

### FASE 3: PERSONALIZZAZIONE (4-6 settimane)
**Priorità: MEDIA**

- [ ] Customizable swipes
- [ ] Smart Folders
  - [ ] Save search as folder
  - [ ] Custom queries
  - [ ] Sidebar management
- [ ] Keyboard shortcuts
  - [ ] Preset configurations
  - [ ] Custom shortcuts
- [ ] Themes (Dark/Light)
- [ ] Density settings (Compact/Normal/Spacious)

### FASE 4: PRODUTTIVITÀ (6-8 settimane)
**Priorità: MEDIA**

- [ ] Send Later
- [ ] Templates
- [ ] Signatures
- [ ] Calendar integration
- [ ] Widgets
- [ ] GateKeeper
- [ ] Reminders/Follow-up

### FASE 5: COLLABORAZIONE (8-10 settimane)
**Priorità: BASSA (per ora)**

- [ ] Shared Inboxes
- [ ] Team Comments
- [ ] Email Assignment
- [ ] Shared Drafts
- [ ] Shared Templates

### FASE 6: AI FEATURES (Futuro)
**Priorità: FUTURA**

- [ ] Smart Reply suggestions
- [ ] Email summarization
- [ ] Translation
- [ ] Smart compose
- [ ] AI assistant

---

## 🔧 PROBLEMI ATTUALI DA RISOLVERE

### 1. Email Body Rendering (CRITICO)
**Problema**: `fetchBodyPeek()` non funziona con parser IMAP attuale

**Soluzioni Possibili**:
1. **Refactor IMAP Parser** per gestire risposte multi-linea
2. **Usare libreria esistente** (es. MailCore2, swift-nio-imap)
3. **Fetch HTML diretto** via API Gmail/Outlook quando disponibile
4. **Implementare parser MIME** robusto per RFC822

**Raccomandazione**: Usare libreria esistente per parsing IMAP/MIME invece di reimplementare da zero.

### 2. Performance con Molte Email
**Considerazioni**:
- Lazy loading email list
- Virtual scrolling
- Cache locale
- Background sync
- Incremental fetch

---

## 📚 FONTI E RIFERIMENTI

### Documentazione Spark
- [Spark Features](https://sparkmailapp.com/features)
- [Smart Inbox](https://sparkmailapp.com/features/smart_inbox)
- [Personalization](https://sparkmailapp.com/features/personalization)
- [Teams](https://sparkmailapp.com/teams)

### App Store & Review
- [Spark Mail - App Store](https://apps.apple.com/us/app/spark-mail-ai-email-inbox/id6445813049?mt=12)
- [Spark Email Review 2025](https://alternativeto.getmailbird.com/softwares/spark/)

### Help & Knowledge Base
- [Customize Smart Inbox](https://support.readdle.com/spark/personalization/customize-your-smart-inbox)
- [Swipe Gestures](https://support.readdle.com/spark/personalization/manage-emails-with-swipes)
- [Keyboard Shortcuts](https://sparkmailapp.com/help/tips-tricks/use-keyboard-shortcuts)
- [Calendar Integration](https://support.readdle.com/spark/using-calendar-in-spark/enable-and-view-calendars-in-spark)

### Competitor Analysis
- [Spark vs Superhuman](https://blog.superhuman.com/spark-ai/)
- [Spark vs Missive](https://missiveapp.com/compare/spark-mail-vs-missive)
- [8 Spark Features - Zapier](https://zapier.com/blog/spark-email/)

---

## 💡 DIFFERENZIATORI PER MAILFORGE

### Cosa MailForge Può Fare Meglio

1. **Focus su macOS Native**
   - Spark è cross-platform, MailForge può essere 100% macOS ottimizzato
   - SwiftUI nativo invece di framework cross-platform
   - Integrazione profonda con macOS (Shortcuts, Widgets, Handoff)

2. **Privacy-First**
   - Nessun cloud di terze parti
   - Tutti i dati solo locali o sul server IMAP dell'utente
   - Nessun tracking, analytics opt-in only

3. **Open Source / Transparent**
   - Codice open source
   - Community-driven features
   - Nessun vendor lock-in

4. **Lightweight & Fast**
   - App nativa, non Electron
   - Ottimizzata per performance
   - Basso utilizzo memoria

5. **PEC Support**
   - Feature unica per mercato italiano
   - Spark non supporta PEC nativamente
   - Certificati digitali, daticert.xml, etc.

6. **Gratis per Uso Personale**
   - Spark ha piano premium
   - MailForge può essere gratis per singoli utenti
   - Premium solo per teams/business

---

## 🎯 OBIETTIVI SMART PER MAILFORGE

### 3 Mesi
- [ ] Fix rendering email body
- [ ] Implement swipe gestures
- [ ] Smart Inbox v1 (categorization base)
- [ ] Snooze functionality
- [ ] Command Center

### 6 Mesi
- [ ] Smart Folders
- [ ] Send Later
- [ ] Calendar integration
- [ ] Templates
- [ ] Beta pubblica

### 12 Mesi
- [ ] Team features (inbox condivise)
- [ ] AI features (summary, compose)
- [ ] iOS/iPadOS companion app
- [ ] 1,000+ utenti attivi

---

## 🏁 CONCLUSIONI

Spark Mail è un competitor formidabile con:
- UI/UX eccellente
- Features smart ben pensate
- Ottima integrazione cross-platform
- Team collaboration avanzata

**MailForge può competere puntando su**:
1. Native macOS experience
2. Privacy e trasparenza
3. PEC support (mercato italiano)
4. Open source
5. Performance superiore

**Prossimi passi immediati**:
1. ✅ Completare questa analisi
2. ⚠️ Fixare rendering email body
3. 🎯 Implementare swipe gestures
4. 🎯 Implementare Smart Inbox categorization
5. 🎯 Implementare Command Center (⌘K)

---

**Fine Documento**
