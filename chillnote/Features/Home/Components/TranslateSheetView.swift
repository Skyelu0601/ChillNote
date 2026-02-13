import SwiftUI

struct TranslateSheetView: View {
    let translateLanguages: [TranslateLanguage]
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.system(size: 48))
                                .foregroundStyle(LinearGradient(colors: [.accentPrimary, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .padding(.bottom, 8)

                            Text("Select Language")
                                .font(.title2.bold())
                                .foregroundColor(.textMain)

                            Text("Choose a language to translate your note")
                                .font(.subheadline)
                                .foregroundColor(.textSub)
                        }
                        .padding(.top, 24)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(translateLanguages) { language in
                                Button {
                                    onSelect(language.name)
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(language.flag)
                                            .font(.system(size: 32))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(language.displayName)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.textMain)

                                            Text(language.name)
                                                .font(.system(size: 12))
                                                .foregroundColor(.textSub)
                                        }
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.black.opacity(0.03), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.textMain)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}
