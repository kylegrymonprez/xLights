import SwiftUI
import UIKit

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
        .commands {
            XLSequencerCommands(viewModel: viewModel)
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

        // F-1 — detachable House Preview. Opened via
        // `openWindow(id: "house-preview")` from the embedded
        // preview's controls overlay or the View menu. The scene
        // root flips `viewModel.housePreviewDetached` via its
        // onAppear / onDisappear so the embedded version in
        // SequencerView swaps for a dock placeholder while the
        // detached window is alive. Stage Manager on iPadOS 26
        // lets users drag this to an external display without us
        // routing screens directly.
        //
        // `WindowGroup` (not `Window`) because `Window` is macOS-
        // only. The Detach button on the embedded overlay is
        // suppressed when the placeholder is showing, which keeps
        // the WindowGroup from spawning a second instance.
        // iPadOS doesn't expose `.defaultLaunchBehavior(.suppressed)`
        // / `.restorationBehavior(.disabled)` (those are macOS-only),
        // so the "don't auto-restore detached scenes" behaviour is
        // implemented in the scene roots via a token check on
        // `onAppear`: an explicit user detach sets a token, the
        // detached scene's onAppear consumes it and proceeds;
        // absence of a token means the scene was system-restored
        // on launch and the root dismisses itself immediately. That
        // fixes the "relaunch restores the last-closed scene as
        // the main window's geometry" bug without losing genuine
        // user-opened scenes.

        WindowGroup("House Preview", id: "house-preview") {
            DetachedHousePreviewRoot()
                .environment(viewModel)
        }
        .defaultSize(width: 560, height: 360)
        .windowResizability(.contentSize)

        // F-1 — detachable Model Preview. Same pattern as House.
        WindowGroup("Model Preview", id: "model-preview") {
            DetachedModelPreviewRoot()
                .environment(viewModel)
        }
        .defaultSize(width: 420, height: 320)
        .windowResizability(.contentSize)

        // F-1c — detachable inspector tabs. Keyed by `InspectorTab`
        // so each of the four tabs (Effect / Colors / Blending /
        // Buffer) opens as its own scene window. Opening the same
        // tab twice focuses the existing window in Stage Manager.
        // The scene root flips an entry in
        // `viewModel.detachedInspectorTabs` so the embedded sidebar
        // swaps to a dock placeholder.
        WindowGroup(id: "inspector-tab", for: InspectorTab.self) { $tab in
            DetachedInspectorRoot(tab: tab ?? .effect)
                .environment(viewModel)
        }
        .defaultSize(width: 380, height: 620)
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @Environment(SequencerViewModel.self) var viewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var showFolderConfig = false

    @State private var showMediaManager = false

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
        // F-1 runtime coupling — when the main window is about to
        // close, dismiss the detached preview / inspector scenes
        // and wipe their persisted sessions BEFORE main commits
        // its own close, so iPadOS doesn't carry a detached's
        // geometry forward as "the app state".
        //
        // We hook `.active → .inactive` (first step of the close
        // sequence), not `.background` — by the time `.background`
        // fires, main is already gone and iPadOS has persisted
        // whatever it was going to persist.
        //
        // Differentiating close-this-window from app-wide
        // background / Control Center: when the user taps the
        // pill X on main, main alone transitions; the detached
        // scenes stay `.foregroundActive`. In app-wide
        // backgrounding, all scenes go `.inactive` simultaneously
        // so no sibling stays `.foregroundActive`. Using "another
        // scene is foregroundActive" as the predicate narrows to
        // the window-close case.
        //
        // Dirty handling: Stage Manager's pill close is not
        // interceptable — any confirmation alert we'd present is
        // torn down with the scene. Follow the iPad-native pattern
        // (Notes / Pages / Numbers) and silently save-on-close so
        // no work is lost. Users who want explicit save/discard
        // can still use the toolbar X, which prompts via
        // `showingUnsavedPrompt` as before.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .inactive else { return }
            let siblingsActive = UIApplication.shared.connectedScenes.contains { scene in
                scene.activationState == .foregroundActive
            }
            guard siblingsActive else { return }

            if viewModel.isDirty {
                _ = viewModel.saveSequence()
            }
            dismissWindow(id: "house-preview")
            dismissWindow(id: "model-preview")
            for tab in InspectorTab.allCases {
                dismissWindow(id: "inspector-tab", value: tab)
            }
            // Destroy the foreground-active scene sessions (the
            // detached panes). Running synchronously here, during
            // main's `.inactive` window, gets them torn down
            // before main commits its close — iPadOS then sees
            // main as the last-used scene and persists its
            // geometry, not a detached pane's.
            for scene in UIApplication.shared.connectedScenes
                where scene.activationState == .foregroundActive {
                UIApplication.shared.requestSceneSessionDestruction(
                    scene.session, options: nil, errorHandler: nil)
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
