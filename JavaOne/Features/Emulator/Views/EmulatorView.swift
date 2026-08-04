import SwiftUI

/// Owns the visual LCD surface that displays FreeJ2ME frames.
///
/// On appear, starts observing `runtimeEvents` and launches `game` through the
/// bridge. On disappear, stops the session. Renders via `CGImage` (no Metal).
struct EmulatorView: View {

    // MARK: - Dependencies

    @ObservedObject private var viewModel: EmulatorViewModel
    private let game: InstalledGame

    // MARK: - Init

    init(viewModel: EmulatorViewModel, game: InstalledGame) {
        self.viewModel = viewModel
        self.game = game
    }

    // MARK: - Body

    var body: some View {
        lcdSurface
            .navigationTitle(game.title)
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "Launch Failed",
                isPresented: launchErrorBinding
            ) {
                Button("OK", role: .cancel) {
                    viewModel.dismissLaunchError()
                }
            } message: {
                Text(viewModel.launchErrorMessage ?? "")
            }
            .task(id: game.id) {
                await viewModel.startSession(for: game)
            }
            .onDisappear {
                viewModel.endSession()
            }
    }

    // MARK: - Surface

    /// LCD plane showing the latest frame, or a waiting placeholder.
    private var lcdSurface: some View {
        GeometryReader { geometry in
            let size = fittedLCDSize(in: geometry.size)
            ZStack {
                Color.black
                lcdContent
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }

    @ViewBuilder
    private var lcdContent: some View {
        if let cgImage = viewModel.lcdImage {
            Image(decorative: cgImage, scale: 1.0, orientation: .up)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(white: 0.12))
                .overlay {
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
        }
    }

    private var statusMessage: String {
        if viewModel.activeSession != nil {
            return "Waiting for frame…"
        }
        if viewModel.launchErrorMessage != nil {
            return "Launch failed"
        }
        return "Starting…"
    }

    // MARK: - Layout

    private func fittedLCDSize(in container: CGSize) -> CGSize {
        let aspect: CGFloat
        if let metadata = viewModel.surfaceMetadata, metadata.height > 0 {
            aspect = CGFloat(metadata.width) / CGFloat(metadata.height)
        } else {
            aspect = 240.0 / 320.0
        }

        let maxWidth = container.width
        let maxHeight = container.height
        let widthLimitedHeight = maxWidth / aspect
        if widthLimitedHeight <= maxHeight {
            return CGSize(width: maxWidth, height: widthLimitedHeight)
        }
        return CGSize(width: maxHeight * aspect, height: maxHeight)
    }

    private var accessibilityLabel: String {
        if let metadata = viewModel.surfaceMetadata {
            return "Emulator LCD, \(metadata.width) by \(metadata.height), \(viewModel.receivedFrameCount) frames"
        }
        return "Emulator LCD surface, waiting for frame"
    }

    // MARK: - Bindings

    private var launchErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.launchErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissLaunchError()
                }
            }
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        EmulatorView(
            viewModel: EmulatorViewModel(bridge: PreviewEmulatorBridge()),
            game: InstalledGame(
                id: UUID(),
                title: "Demo",
                jarURL: URL(fileURLWithPath: "/tmp/demo.jar"),
                importedAt: Date(),
                contentHash: "abc"
            )
        )
    }
}

@MainActor
private final class PreviewEmulatorBridge: EmulatorBridgeProtocol {
    private let pipe = RuntimeEventPipe()

    var runtimeEvents: AsyncStream<RuntimeEvent> {
        pipe.events
    }

    func launch(_ configuration: LaunchConfiguration) throws -> EmulatorSession {
        EmulatorSession(configuration: configuration, state: .running)
    }

    func pause(_ session: EmulatorSession) throws {
        session.transition(to: .paused)
    }

    func resume(_ session: EmulatorSession) throws {
        session.transition(to: .running)
    }

    func stop(_ session: EmulatorSession) throws {
        session.transition(to: .stopped)
    }
}
#endif
