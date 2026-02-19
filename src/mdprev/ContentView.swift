import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            MarkdownWebView(
                html: model.renderedHTML,
                selectAllRequestID: model.selectAllRequestID,
                onFileDrop: { fileURL in
                    model.openFile(fileURL)
                },
                isDropTargeted: $isDropTargeted
            )
                .padding(1)
                .background(Color(nsColor: .textBackgroundColor))
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 8]))
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }

            Divider()
            statusBar
        }
        .background(
            WindowAccessor { window in
                model.attachWindow(window)
            }
        )
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button("Open Markdown...") {
                model.requestFileOpen()
            }

            Button("Reload") {
                model.reload()
            }
            .disabled(model.selectedFileURL == nil)

            Toggle("Auto Reload", isOn: $model.autoReloadEnabled)
                .toggleStyle(.switch)
                .frame(width: 140)

            Spacer()
        }
        .padding(12)
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text(model.statusMessage)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if let fileURL = model.selectedFileURL {
                Text(fileURL.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }

            if let lastReloadDate = model.lastReloadDate {
                Text(lastReloadDate.formatted(date: .omitted, time: .standard))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(12)
    }
}
