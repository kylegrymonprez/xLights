import SwiftUI

@main
struct XLightsApp: App {
    @State private var viewModel: SequencerViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Must initialize xLights core (sets FileUtils::GetResourcesDir) BEFORE
        // creating the view model, since SequencerViewModel constructs an
        // iPadRenderContext whose EffectManager needs the resources directory
        // to load effectmetadata JSON files.
        XLiPadInit.initialize()
        let vm = SequencerViewModel()
        vm.startMemoryMonitoring()
        // Attempt to restore the previously-selected show folder + media
        // folders via their persistent security-scoped bookmarks.
        vm.restorePersistedShowFolder()
        _viewModel = State(initialValue: vm)
    }

    var body: some Scene {
        WindowGroup("xLights", id: "sequencer") {
            ContentView()
                .environment(viewModel)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .inactive:
                // Temporary suspension (app switcher, incoming call,
                // Control Center). Pause playback + scrub so the
                // frame timers and audio stop burning energy;
                // keep render state so returning to .active is
                // instant. `.background` follows if the app really
                // goes away — that's handled below.
                viewModel.quiesceForInactive()
            case .background:
                // May precede termination; iOS can kill the process
                // without further notice. Pause playback, stop scrub,
                // then abort the render and block briefly so worker
                // threads exit cleanly before the teardown race —
                // otherwise they crash mid-frame on freed
                // SequenceElements / SequenceData.
                viewModel.shutdownForBackground()
            case .active:
                break
            @unknown default:
                break
            }
        }
    }
}

struct ContentView: View {
    @Environment(SequencerViewModel.self) var viewModel
    @State private var showFolderConfig = false

    @State private var showMediaManager = false

    /// Session-scoped dismissals for the migration banner. Keyed by
    /// "<file version> → <app version>" so opening a different
    /// older sequence shows its own banner even after dismissal.
    /// Re-appears on app relaunch — stored in memory only, matching
    /// desktop's banner behaviour.
    @State private var dismissedMigrationKeys: Set<String> = []

    /// Autosave recovery state. When a sequence opens with a
    /// newer `.xbkp` alongside its `.xsq`, we sheet the user:
    /// Recover (promote .xbkp → .xsq + reopen) or Discard
    /// (delete .xbkp). Checked once per open; the
    /// `lastCheckedSequencePath` guard prevents re-offering on
    /// every re-render of the shell.
    @State private var autosaveRecoveryDate: Date? = nil
    @State private var lastCheckedSequencePath: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.memoryWarning {
                MemoryWarningBanner()
            }
            if viewModel.isSequenceLoaded && viewModel.brokenMediaCount > 0 {
                MissingMediaBanner(
                    count: viewModel.brokenMediaCount,
                    onReview: { showMediaManager = true })
            }
            if viewModel.isSequenceLoaded,
               let migration = migrationInfo(),
               !dismissedMigrationKeys.contains(migration.key) {
                MigrationBanner(
                    fileVersion: migration.file,
                    appVersion: migration.app,
                    onDismiss: {
                        dismissedMigrationKeys.insert(migration.key)
                    })
            }
            Group {
                if !viewModel.isShowFolderLoaded {
                    ShowFolderSetupView(showFolderConfig: $showFolderConfig)
                } else if !viewModel.isSequenceLoaded {
                    SequencePickerView(showFolderConfig: $showFolderConfig)
                } else {
                    SequencerView()
                }
            }
        }
        .sheet(isPresented: $showMediaManager) {
            MediaManagerSheet()
                .environment(viewModel)
        }
        .sheet(isPresented: $showFolderConfig) {
            FolderConfigView()
                .environment(viewModel)
        }
        .onAppear {
            // Auto-open the dialog on first launch when nothing is configured.
            if !viewModel.isShowFolderLoaded && FolderConfig.showFolder == nil {
                showFolderConfig = true
            }
        }
        .onChange(of: viewModel.isSequenceLoaded) { _, loaded in
            if loaded {
                checkAutosaveRecovery()
            } else {
                autosaveRecoveryDate = nil
                lastCheckedSequencePath = ""
            }
        }
        .alert("Recover Autosave Backup?",
               isPresented: Binding(
                get: { autosaveRecoveryDate != nil },
                set: { if !$0 { autosaveRecoveryDate = nil } }
               )) {
            Button("Recover") {
                _ = viewModel.applyAutosaveBackup()
                autosaveRecoveryDate = nil
            }
            Button("Discard Backup", role: .destructive) {
                viewModel.suppressAutosaveBackup()
                autosaveRecoveryDate = nil
            }
            Button("Keep for Later", role: .cancel) {
                autosaveRecoveryDate = nil
            }
        } message: {
            if let date = autosaveRecoveryDate {
                Text("An autosave backup newer than the sequence file was found (saved \(date.formatted(date: .abbreviated, time: .shortened))). Recover changes from the backup, or discard it?")
            } else {
                Text("")
            }
        }
    }

    /// Run once per open: compare `.xbkp` mtime vs. `.xsq` and
    /// surface the recovery alert when the backup is newer.
    private func checkAutosaveRecovery() {
        let path = viewModel.document.currentSequencePath() ?? ""
        guard !path.isEmpty, path != lastCheckedSequencePath else { return }
        lastCheckedSequencePath = path
        let (has, when) = viewModel.hasRecoverableBackup()
        if has { autosaveRecoveryDate = when }
    }

    /// Returns the file / app version pair when they disagree.
    /// An empty file version means the sequence hasn't been opened
    /// yet or was loaded before the field existed — suppress the
    /// banner either way.
    private func migrationInfo() -> (file: String, app: String, key: String)? {
        let file = viewModel.document.sequenceFileVersion() ?? ""
        let app = viewModel.document.currentAppVersion() ?? ""
        if file.isEmpty || app.isEmpty { return nil }
        if file == app { return nil }
        return (file, app, "\(file)→\(app)")
    }
}

struct MemoryWarningBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Low memory — renders paused")
                .font(.caption)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(.white)
        .background(Color.orange)
    }
}

/// Banner shown at the top of the app when the just-opened
/// sequence references media files that don't resolve on this
/// device (missing files, evicted-from-iCloud, revoked bookmarks).
/// Tapping "Review" opens the sequence-wide `MediaManagerSheet` so
/// the user can see which files are missing. Actual relocation UI
/// lands with G30 (rename-with-reference-update) in a later pass.
struct MissingMediaBanner: View {
    let count: Int
    let onReview: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(count == 1
                 ? "1 media file is missing"
                 : "\(count) media files are missing")
                .font(.caption)
            Spacer()
            Button("Review", action: onReview)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(.white)
        .background(Color.red.opacity(0.85))
    }
}

/// Yellow banner shown when the open sequence's saved xLights
/// version differs from the current build. E-4 migration in
/// `SequenceFile::AdjustEffectSettingsForVersion` has already
/// run by the time we reach this banner; the banner just tells
/// the user the sequence has been upgraded in-memory and a save
/// will persist the new form.
struct MigrationBanner: View {
    let fileVersion: String
    let appVersion: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
            Text("Sequence was created in xLights \(fileVersion). Migrated to \(appVersion) — save to update.")
                .font(.caption)
                .lineLimit(2)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(.white)
        .background(Color.yellow.opacity(0.9).overlay(Color.orange.opacity(0.3)))
    }
}

struct ShowFolderSetupView: View {
    @Binding var showFolderConfig: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("xLights")
                .font(.largeTitle)
            Text("Select your show folder to get started")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button("Configure Folders…") {
                showFolderConfig = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct SequencePickerView: View {
    @Environment(SequencerViewModel.self) var viewModel
    @Binding var showFolderConfig: Bool

    @State private var recent: [RecentSequences.Entry] = RecentSequences.load()
    @State private var showingNewWizard: Bool = false

    var body: some View {
        NavigationStack {
            List {
                if !recent.isEmpty {
                    Section("Recent") {
                        ForEach(recent) { entry in
                            Button {
                                viewModel.openSequence(path: entry.path)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.displayName)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(entry.parentFolder)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    RecentSequences.remove(path: entry.path)
                                    recent = RecentSequences.load()
                                } label: {
                                    Label("Remove", systemImage: "xmark.bin")
                                }
                            }
                        }
                    }
                }
                Section(recent.isEmpty ? "Sequences" : "In This Show Folder") {
                    ForEach(viewModel.sequenceFiles, id: \.self) { file in
                        Button(file) {
                            let path = (viewModel.showFolderPath ?? "") + "/" + file
                            viewModel.openSequence(path: path)
                        }
                    }
                }
            }
            .navigationTitle("Sequences")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            showingNewWizard = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        Button {
                            showFolderConfig = true
                        } label: {
                            Image(systemName: "folder.badge.gearshape")
                        }
                    }
                }
                if !recent.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button(role: .destructive) {
                                RecentSequences.clear()
                                recent = []
                            } label: {
                                Label("Clear Recent", systemImage: "clock.badge.xmark")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .onAppear {
                recent = RecentSequences.load()
            }
            .sheet(isPresented: $showingNewWizard) {
                NewSequenceWizardView()
                    .environment(viewModel)
                    .onDisappear {
                        recent = RecentSequences.load()
                    }
            }
        }
    }
}
