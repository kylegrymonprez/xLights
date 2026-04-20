import SwiftUI

/// Per-preview appearance / camera-mode state shared between the pane and
/// its controls overlay. Kept here (rather than inside the bridge) so the
/// SwiftUI overlay can render toggle state without round-tripping through
/// ObjC each frame; PreviewPaneView syncs the relevant bits into the
/// bridge in updateUIView.
@Observable @MainActor
final class PreviewSettings {
    var is3D: Bool
    var showViewObjects: Bool

    init(is3DDefault: Bool, showViewObjectsDefault: Bool) {
        self.is3D = is3DDefault
        self.showViewObjects = showViewObjectsDefault
    }
}

/// House Preview — shows every model plus view objects.
struct HousePreviewView: View {
    @State private var controlsVisible: Bool = false
    @State private var settings = PreviewSettings(is3DDefault: true,
                                                  showViewObjectsDefault: true)

    var body: some View {
        PreviewContainer(title: "House",
                         previewName: "HousePreview",
                         previewModelName: nil,
                         controlsVisible: $controlsVisible,
                         settings: settings)
    }
}

/// Model Preview — always 2D on desktop; no 2D/3D toggle exposed.
struct ModelPreviewView: View {
    @Environment(SequencerViewModel.self) var viewModel
    @State private var controlsVisible: Bool = false
    // is3D is wired off and the toggle is hidden via supportsIs3D below.
    @State private var settings = PreviewSettings(is3DDefault: false,
                                                  showViewObjectsDefault: false)

    var body: some View {
        PreviewContainer(title: "Model",
                         previewName: "ModelPreview",
                         previewModelName: viewModel.previewModelName,
                         controlsVisible: $controlsVisible,
                         settings: settings)
    }
}

/// Shared container that hosts a PreviewPaneView and overlays the controls
/// toggle and — when visible — camera shortcut buttons.
private struct PreviewContainer: View {
    let title: String
    let previewName: String
    let previewModelName: String?
    @Binding var controlsVisible: Bool
    let settings: PreviewSettings

    /// Model Preview ignores view objects entirely in XLMetalBridge, so the
    /// "Show View Objects" toggle is a no-op there — suppress it. Desktop
    /// Model Preview is 2D-only, so suppress the 2D/3D toggle there too.
    private var supportsViewObjects: Bool { previewName == "HousePreview" }
    private var supportsIs3D: Bool { previewName == "HousePreview" }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PreviewPaneView(previewName: previewName,
                            previewModelName: previewModelName,
                            controlsVisible: $controlsVisible,
                            settings: settings)

            VStack(alignment: .trailing, spacing: 4) {
                Button {
                    controlsVisible.toggle()
                } label: {
                    Image(systemName: controlsVisible
                          ? "slider.horizontal.3"
                          : "slider.horizontal.below.rectangle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if controlsVisible {
                    PreviewControlsOverlay(previewName: previewName,
                                           settings: settings,
                                           supportsViewObjects: supportsViewObjects,
                                           supportsIs3D: supportsIs3D)
                }
            }
            .padding(6)

            // Small title label in the upper-left for orientation.
            VStack {
                HStack {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 4))
                    Spacer()
                }
                Spacer()
            }
            .padding(6)
            .allowsHitTesting(false)
        }
        .background(Color.black)
        .clipped()
    }
}

/// Camera shortcut buttons plus per-preview appearance toggles (2D/3D for
/// House only, view-object visibility). Zoom / reset actions are still
/// routed through NotificationCenter so each pane's Coordinator picks up
/// only its own — the mode/appearance state lives on the shared
/// `PreviewSettings` and is synced to the bridge in updateUIView.
private struct PreviewControlsOverlay: View {
    let previewName: String
    @Bindable var settings: PreviewSettings
    let supportsViewObjects: Bool
    let supportsIs3D: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                Button { post(.zoomOut) } label: { Image(systemName: "minus.magnifyingglass") }
                Button { post(.zoomReset) } label: { Text("1×").font(.caption.monospacedDigit()) }
                Button { post(.zoomIn) } label: { Image(systemName: "plus.magnifyingglass") }
                Button { post(.reset) } label: { Image(systemName: "arrow.counterclockwise") }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            // 2D / 3D — House Preview only. Desktop Model Preview is 2D-only,
            // so no toggle there. Persisting at the scene level is Phase F.
            if supportsIs3D {
                Picker("", selection: $settings.is3D) {
                    Text("2D").tag(false)
                    Text("3D").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 96)
            }

            if supportsViewObjects {
                Toggle(isOn: $settings.showViewObjects) {
                    Text("View Objs").font(.caption2)
                }
                .toggleStyle(.button)
                .controlSize(.small)
            }

            // Share / save the current preview contents. Presents the
            // standard iOS share sheet (Photos, Files, Mail, AirDrop,
            // Copy, Print). No separate "Copy" button — the share sheet
            // already includes a copy action on all iPadOS versions.
            Button {
                NotificationCenter.default.post(name: .previewSaveImage,
                                                object: previewName)
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private enum Action {
        case zoomIn, zoomOut, zoomReset, reset
    }

    private func post(_ action: Action) {
        let name: Notification.Name
        switch action {
        case .zoomIn: name = .previewZoomIn
        case .zoomOut: name = .previewZoomOut
        case .zoomReset: name = .previewZoomReset
        case .reset: name = .previewResetCamera
        }
        NotificationCenter.default.post(name: name, object: previewName)
    }
}

extension Notification.Name {
    static let previewZoomIn = Notification.Name("PreviewZoomIn")
    static let previewZoomOut = Notification.Name("PreviewZoomOut")
    static let previewZoomReset = Notification.Name("PreviewZoomReset")
    static let previewResetCamera = Notification.Name("PreviewResetCamera")
    static let previewSaveImage = Notification.Name("PreviewSaveImage")
}
