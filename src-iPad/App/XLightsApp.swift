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

    var body: some View {
        NavigationStack {
            List(viewModel.sequenceFiles, id: \.self) { file in
                Button(file) {
                    let path = (viewModel.showFolderPath ?? "") + "/" + file
                    viewModel.openSequence(path: path)
                }
            }
            .navigationTitle("Sequences")
            .toolbar {
                Button {
                    showFolderConfig = true
                } label: {
                    Image(systemName: "folder.badge.gearshape")
                }
            }
        }
    }
}
