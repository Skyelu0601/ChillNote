import AVFoundation
import Photos
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct TeleprompterFloatingPanel: View {
    let scriptText: String
    @Binding var scrollSpeed: Double
    let fontSize: Double
    let textColor: Color
    let panelSize: CGSize
    let isScrolling: Bool
    let resetToken: UUID
    let onEdit: () -> Void
    let onSettings: () -> Void

    @State private var scrollOffset: CGFloat = 0
    @State private var storedScrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 1
    @State private var visibleTextHeight: CGFloat = 1
    @State private var isUserDraggingText = false

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 42, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 14)

                GeometryReader { textAreaProxy in
                    ZStack(alignment: .topLeading) {
                        Text(scriptText)
                            .font(.system(size: fontSize, weight: .bold))
                            .lineSpacing(fontSize * 0.35)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .offset(y: -scrollOffset)
                            .background(
                                GeometryReader { textProxy in
                                    Color.clear
                                        .onAppear { contentHeight = textProxy.size.height }
                                        .onChange(of: textProxy.size.height) { _, height in
                                            contentHeight = height
                                        }
                                }
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .onAppear { visibleTextHeight = textAreaProxy.size.height }
                    .onChange(of: textAreaProxy.size.height) { _, value in
                        visibleTextHeight = value
                    }
                }
                .padding(.horizontal, 22)
                .clipped()
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            if !isUserDraggingText {
                                isUserDraggingText = true
                                storedScrollOffset = scrollOffset
                            }
                            let proposed = storedScrollOffset - value.translation.height
                            scrollOffset = clampOffset(proposed)
                        }
                        .onEnded { value in
                            updateSpeedAfterManualDrag(value)
                            storedScrollOffset = scrollOffset
                            isUserDraggingText = false
                        }
                )

                HStack(spacing: 44) {
                    Button(action: onEdit) {
                        Label(L10n.text("teleprompter.action.edit_script"), systemImage: "square.and.pencil")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel(L10n.text("teleprompter.action.edit_script"))

                    Button(action: onSettings) {
                        Label(L10n.text("teleprompter.action.prompt_settings"), systemImage: "gearshape")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel(L10n.text("teleprompter.action.prompt_settings"))
                }
                .padding(.vertical, 16)
            }
            .frame(width: panelSize.width, height: panelSize.height)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.62))
            )
            .position(x: proxy.size.width / 2, y: proxy.size.height * 0.3)
            .onChange(of: scriptText) { _, _ in
                scrollOffset = 0
                storedScrollOffset = 0
            }
            .onChange(of: resetToken) { _, _ in
                scrollOffset = 0
                storedScrollOffset = 0
            }
            .modifier(
                TeleprompterAutoScrollModifier(
                    isScrolling: isScrolling,
                    isUserDragging: isUserDraggingText,
                    scrollSpeed: scrollSpeed,
                    contentHeight: contentHeight,
                    visibleHeight: visibleTextHeight,
                    scrollOffset: $scrollOffset,
                    storedScrollOffset: $storedScrollOffset
                )
            )
        }
        .ignoresSafeArea()
    }

    private func clampOffset(_ value: CGFloat) -> CGFloat {
        let maxOffset = max(contentHeight - visibleTextHeight + 40, 0)
        return min(max(value, 0), maxOffset)
    }

    private func updateSpeedAfterManualDrag(_ value: DragGesture.Value) {
        let predictedExtraDistance = value.predictedEndTranslation.height - value.translation.height
        guard predictedExtraDistance < -24 else { return }
        let speedBoost = min(Double(abs(predictedExtraDistance)) / 12, 10)
        scrollSpeed = min(scrollSpeed + speedBoost, 50)
    }
}

private struct TeleprompterAutoScrollModifier: ViewModifier {
    let isScrolling: Bool
    let isUserDragging: Bool
    let scrollSpeed: Double
    let contentHeight: CGFloat
    let visibleHeight: CGFloat
    @Binding var scrollOffset: CGFloat
    @Binding var storedScrollOffset: CGFloat

    func body(content: Content) -> some View {
        content.task(id: TeleprompterAutoScrollState(isScrolling: isScrolling, scrollSpeed: scrollSpeed)) {
            guard isScrolling else { return }
            var last = Date()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 16_666_666)
                } catch {
                    return
                }
                if Task.isCancelled { return }
                let now = Date()
                let delta = now.timeIntervalSince(last)
                last = now
                if isUserDragging { continue }
                let maxOffset = max(contentHeight - visibleHeight + 40, 0)
                let next = min(scrollOffset + CGFloat(scrollSpeed * delta), maxOffset)
                scrollOffset = next
                storedScrollOffset = next
            }
        }
    }
}

private struct TeleprompterAutoScrollState: Equatable {
    let isScrolling: Bool
    let scrollSpeed: Double
}


struct TeleprompterScriptEditorView: View {
    @Binding var scriptText: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $scriptText)
                .font(.system(size: 17))
                .padding(14)
                .navigationTitle(L10n.text("teleprompter.editor.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.text("common.done")) {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct TeleprompterExportPreviewView: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var saveMessage: String?
    @State private var videoAspectRatio: CGFloat = 9.0 / 16.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VideoPlayerPreview(url: videoURL)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(videoAspectRatio, contentMode: .fit)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if let saveMessage {
                    Text(saveMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSub)
                }

                Button {
                    saveToPhotoLibrary()
                } label: {
                    Label(L10n.text("teleprompter.preview.save_to_photos"), systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .safeAreaPadding(.top, 12)
            .navigationTitle(L10n.text("teleprompter.preview.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.textSub)
                    }
                    .accessibilityLabel(L10n.text("teleprompter.accessibility.close"))
                }
            }
            .task(id: videoURL) {
                if let ratio = await Self.detectAspectRatio(for: videoURL) {
                    videoAspectRatio = ratio
                }
            }
        }
    }

    private static func detectAspectRatio(for url: URL) async -> CGFloat? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }
        guard let naturalSize = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform) else {
            return nil
        }
        let applied = naturalSize.applying(transform)
        let width = abs(applied.width)
        let height = abs(applied.height)
        guard width > 0, height > 0 else { return nil }
        return width / height
    }

    private func saveToPhotoLibrary() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    saveMessage = L10n.text("teleprompter.preview.save_permission_denied")
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    saveMessage = success
                        ? L10n.text("teleprompter.preview.save_success")
                        : L10n.text("teleprompter.preview.save_failed")
                }
            }
        }
    }
}

private struct VideoPlayerPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewControllerBox {
        AVPlayerViewControllerBox(url: url)
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewControllerBox, context: Context) {
        uiViewController.update(url: url)
    }
}

private final class AVPlayerViewControllerBox: UIViewController {
    private let playerLayer = AVPlayerLayer()
    private var player: AVPlayer?

    init(url: URL) {
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        update(url: url)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer.frame = view.bounds
    }

    func update(url: URL) {
        player = AVPlayer(url: url)
        playerLayer.player = player
        player?.play()
    }
}

struct TeleprompterClipThumbnailView: View {
    let clip: TeleprompterClip
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                Group {
                    if let thumbnail = clip.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.black.opacity(0.5)
                            .overlay(Image(systemName: "video.fill").foregroundColor(.white))
                    }
                }
                .frame(width: 54, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    Text(durationText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .padding(4),
                    alignment: .bottom
                )
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.white))
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .offset(x: 7, y: -7)
            .accessibilityLabel(L10n.text("teleprompter.clip.delete"))
        }
    }

    private var durationText: String {
        let seconds = Int(clip.duration.rounded())
        return "\(seconds)s"
    }
}

struct TeleprompterClipDropDelegate: DropDelegate {
    let item: TeleprompterClip
    @Binding var clips: [TeleprompterClip]
    @Binding var draggedClip: TeleprompterClip?

    func dropEntered(info: DropInfo) {
        guard let draggedClip,
              draggedClip.id != item.id,
              let from = clips.firstIndex(where: { $0.id == draggedClip.id }),
              let to = clips.firstIndex(where: { $0.id == item.id })
        else {
            return
        }
        withAnimation {
            clips.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedClip = nil
        return true
    }
}

enum TeleprompterDragType {
    static let clip = UTType(exportedAs: "com.chillnote.teleprompter.clip")
}


struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
