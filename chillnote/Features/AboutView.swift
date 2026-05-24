import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(spacing: 12) {
                        Text(L10n.text("about.brand"))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.textMain)
                        
                        Text(L10n.text("about.subtitle"))
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.textSub)
                        
                        Text(L10n.text("about.tagline"))
                            .font(.body)
                            .italic()
                            .multilineTextAlignment(.center)
                            .foregroundColor(.accentPrimary)
                            .padding(.top, 8)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Introduction
                    Text(L10n.text("about.intro"))
                        .font(.body)
                        .foregroundColor(.textMain)
                        .lineSpacing(4)
                    
                    Divider()
                    
                    CreatorAboutSection(
                        number: "01",
                        title: "about.section.1.title",
                        quote: "about.section.1.quote",
                        content: [
                            "about.section.1.body.1",
                            "about.section.1.body.2",
                            "about.section.1.body.3"
                        ]
                    )
                    
                    CreatorAboutSection(
                        number: "02",
                        title: "about.section.2.title",
                        quote: "about.section.2.quote",
                        content: [
                            "about.section.2.body.1",
                            "about.section.2.body.2",
                            "about.section.2.body.3"
                        ]
                    )
                    
                    CreatorAboutSection(
                        number: "03",
                        title: "about.section.3.title",
                        quote: "about.section.3.quote",
                        content: [
                            "about.section.3.body.1",
                            "about.section.3.body.2",
                            "about.section.3.body.3"
                        ]
                    )
                    
                    CreatorAboutSection(
                        number: "04",
                        title: "about.section.4.title",
                        quote: "about.section.4.quote",
                        content: [
                            "about.section.4.body.1",
                            "about.section.4.body.2",
                            "about.section.4.body.3"
                        ]
                    )
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text(L10n.text("about.workflow.title"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.textMain)
                        
                        Text(L10n.text("about.workflow.subtitle"))
                            .font(.subheadline)
                            .foregroundColor(.textSub)
                        
                        WorkflowPoint(
                            icon: "tray.and.arrow.down.fill",
                            title: "about.workflow.capture.title",
                            bodyText: "about.workflow.capture.body"
                        )
                        
                        WorkflowPoint(
                            icon: "wand.and.stars",
                            title: "about.workflow.ai.title",
                            bodyText: "about.workflow.ai.body"
                        )
                        
                        WorkflowPoint(
                            icon: "arrow.triangle.2.circlepath",
                            title: "about.workflow.reuse.title",
                            bodyText: "about.workflow.reuse.body"
                        )
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // Summary
                    VStack(spacing: 16) {
                        Text(L10n.text("about.vision.title"))
                            .font(.headline)
                            .foregroundColor(.textSub)
                            .textCase(.uppercase)
                        
                        Text(L10n.text("about.vision.body"))
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.textMain)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                    
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationTitle(L10n.text("settings.support.about"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.textSub.opacity(0.5))
                            .font(.system(size: 24))
                    }
                    .accessibilityLabel(L10n.text("common.close"))
                }
            }
        }
    }
}

private struct CreatorAboutSection: View {
    let number: String
    let title: LocalizedStringKey
    let quote: LocalizedStringKey
    let content: [LocalizedStringKey]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(number)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentPrimary.opacity(0.2))
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textMain)
            }
            
            Text(quote)
                .font(.subheadline)
                .italic()
                .foregroundColor(.accentPrimary)
                .padding(.leading, 4)
                .padding(.bottom, 4)
            
            ForEach(Array(content.enumerated()), id: \.offset) { item in
                Text(item.element)
                    .font(.body)
                    .foregroundColor(.textMain.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct WorkflowPoint: View {
    let icon: String
    let title: LocalizedStringKey
    let bodyText: LocalizedStringKey
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.accentPrimary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.textMain)
                
                Text(bodyText)
                    .font(.subheadline)
                    .foregroundColor(.textSub)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    AboutView()
}
