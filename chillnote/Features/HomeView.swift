import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncManager: SyncManager
    @Environment(\.scenePhase) private var scenePhase

    @Query(filter: #Predicate<Note> { $0.deletedAt == nil }, sort: [SortDescriptor(\Note.createdAt, order: .reverse)])
    private var allNotes: [Note]

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var showingSettings = false
    @State private var inputText = ""
    @State private var isVoiceMode = false

    private var recentNotes: [Note] { Array(allNotes.prefix(50)) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Recent Notes")
                                    .font(.displayMedium)
                                    .foregroundColor(.textMain)
                                Spacer()
                                Button(action: { showingSettings = true }) {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.textMain)
                                        .frame(width: 40, height: 40)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                                .accessibilityLabel("Open settings")
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)

                            if recentNotes.isEmpty {
                                Text("No notes yet. Start typing or recording below.")
                                    .font(.bodyMedium)
                                    .foregroundColor(.textSub)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                LazyVStack(spacing: 16) {
                                    ForEach(recentNotes) { note in
                                        NavigationLink(destination: NoteDetailView(note: note)) {
                                            NoteCard(note: note)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            hideKeyboard()
                        }
                    }
                    .background(Color.bgPrimary)
                    .scrollDismissesKeyboard(.interactively)
                    
                    ChatInputBar(
                        text: $inputText,
                        isVoiceMode: $isVoiceMode,
                        speechRecognizer: speechRecognizer,
                        onSendText: {
                            Task { await handleTextSubmit() }
                        },
                        onCancelVoice: {
                            speechRecognizer.stopRecording(reason: .cancelled)
                        },
                        onConfirmVoice: {
                            speechRecognizer.stopRecording()
                        }
                    )
                }
            }
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingSettings) {
                SettingsView()
            }
            .onChange(of: speechRecognizer.transcript) { _, newValue in
                if !newValue.isEmpty {
                    Task {
                        await handleRecordingSave(text: newValue)
                        speechRecognizer.transcript = "" // Reset after save
                    }
                }
            }
            .onChange(of: authService.isSignedIn) { isSignedIn in
                guard !isSignedIn else { return }
                showingSettings = false
                isVoiceMode = false
            }
            .task {
                await syncManager.syncIfNeeded(context: modelContext)
            }
            .onChange(of: scenePhase) { newPhase in
                guard newPhase == .active else { return }
                Task { await syncManager.syncIfNeeded(context: modelContext) }
            }
        }
    }

    private func handleTextSubmit() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        withAnimation {
            modelContext.insert(Note(content: trimmed))
            inputText = ""
        }
        
        try? modelContext.save()
        Task { await syncManager.syncIfNeeded(context: modelContext) }
    }

    private func handleRecordingSave(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation {
            modelContext.insert(Note(content: trimmed))
        }
        try? modelContext.save()

        Task { await syncManager.syncIfNeeded(context: modelContext) }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    HomeView()
        .modelContainer(DataService.shared.container!)
        .environmentObject(AuthService.shared)
        .environmentObject(SyncManager())
}
