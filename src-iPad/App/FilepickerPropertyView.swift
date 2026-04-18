import SwiftUI
import UniformTypeIdentifiers

// File-picker row for JSON properties with `controlType: "filepicker"`
// (Glediator_Filename, VUMeter_Filename). Mirrors the desktop wxFilePicker:
// a button that opens a document picker, a label showing the current file's
// last-path component, and a Clear button. The stored value is the absolute
// path — callers must invoke `ObtainAccessToPath` so the picked file stays
// reachable after app restart via the persisted security-scoped bookmark.
struct FilepickerPropertyView: View {
    let property: PropertyMetadata
    let currentPath: String
    let onChoose: (String) -> Void
    let onClear: () -> Void

    @State private var presentingPicker = false

    private var filename: String {
        if currentPath.isEmpty { return "(none)" }
        return (currentPath as NSString).lastPathComponent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(property.label)
                .font(.caption)
            HStack(spacing: 6) {
                Text(filename)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Select…") { presentingPicker = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                if !currentPath.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 2)
        .fileImporter(isPresented: $presentingPicker,
                      allowedContentTypes: allowedTypes()) { result in
            handleResult(result)
        }
    }

    /// JSON's `fileFilter` follows wx's pipe-delimited format (e.g.
    /// `"Glediator Files (*.gled)|*.gled|CSV files (*.csv)|*.csv"`). iOS
    /// wants UTTypes — extract the *.ext globs and map to UTTypes by
    /// filename extension. Unknown extensions fall back to `.data` so the
    /// picker at least opens (the file still stores its real extension).
    private func allowedTypes() -> [UTType] {
        guard let filter = property.fileFilter, !filter.isEmpty else {
            return [.data]
        }
        var types: [UTType] = []
        // Walk the pipe groups; every other segment is a pattern list.
        let parts = filter.split(separator: "|").map(String.init)
        for (i, part) in parts.enumerated() where i % 2 == 1 {
            for pattern in part.split(separator: ";") {
                let glob = String(pattern).trimmingCharacters(in: .whitespaces)
                if let dotIdx = glob.lastIndex(of: ".") {
                    let ext = String(glob[glob.index(after: dotIdx)...])
                    if ext == "*" { continue }
                    if let t = UTType(filenameExtension: ext) {
                        types.append(t)
                    }
                }
            }
        }
        return types.isEmpty ? [.data] : types
    }

    private func handleResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // Security-scoped bookmark so subsequent reads (including after
            // relaunch) can reach the file. Matches the pattern used in
            // FolderConfig for show folders.
            _ = url.startAccessingSecurityScopedResource()
            _ = XLSequenceDocument.obtainAccess(toPath: url.path,
                                                  enforceWritable: false)
            onChoose(url.path)
        case .failure:
            break
        }
    }
}
