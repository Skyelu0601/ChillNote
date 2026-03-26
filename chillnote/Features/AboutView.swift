import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header Section
                    VStack(spacing: 16) {
                        Image("chillohead_touming")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                        
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
                    .padding(.bottom, 16)
                    
                    // Introduction
                    Text(L10n.text("about.intro"))
                        .font(.body)
                        .foregroundColor(.textMain)
                        .lineSpacing(4)
                    
                    Divider()
                    
                    // Section 1
                    PhilosophySection(
                        number: "01",
                        title: "about.section.1.title",
                        quote: "about.section.1.quote",
                        content: [
                            "about.section.1.body.1",
                            "about.section.1.body.2",
                            "about.section.1.body.3"
                        ]
                    )
                    
                    // Section 2
                    PhilosophySection(
                        number: "02",
                        title: "about.section.2.title",
                        quote: "about.section.2.quote",
                        content: [
                            "about.section.2.body.1",
                            "about.section.2.body.2",
                            "about.section.2.body.3"
                        ]
                    )
                    
                    // Section 3
                    PhilosophySection(
                        number: "03",
                        title: "about.section.3.title",
                        quote: "about.section.3.quote",
                        content: [
                            "about.section.3.body.1",
                            "about.section.3.body.2",
                            "about.section.3.body.3"
                        ]
                    )
                    
                    // Section 4
                    PhilosophySection(
                        number: "04",
                        title: "about.section.4.title",
                        quote: "about.section.4.quote",
                        content: [
                            "about.section.4.body.1",
                            "about.section.4.body.2",
                            "about.section.4.body.3"
                        ]
                    )
                    
                    // Section 5
                    PhilosophySection(
                        number: "05",
                        title: "about.section.5.title",
                        quote: "about.section.5.quote",
                        content: [
                            "about.section.5.body.1",
                            "about.section.5.body.2",
                            "about.section.5.body.3"
                        ]
                    )
                    
                    Divider()
                    
                    // What ChillNote is NOT
                    VStack(alignment: .leading, spacing: 20) {
                        Text(L10n.text("about.not.title"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.textMain)
                        
                        Text(L10n.text("about.not.quote"))
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.textSub)
                        
                        NotSection(
                            icon: "mic.slash.fill",
                            title: "about.not.meetings.title",
                            bodyText: "about.not.meetings.body"
                        )
                        
                        NotSection(
                            icon: "book.closed.fill",
                            title: "about.not.long_form.title",
                            bodyText: "about.not.long_form.body"
                        )
                        
                        NotSection(
                            icon: "clock.badge.exclamationmark.fill",
                            title: "about.not.heavy_workflow.title",
                            bodyText: "about.not.heavy_workflow.body"
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
                .padding(24)
            }
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.textSub.opacity(0.5))
                            .font(.system(size: 24))
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct PhilosophySection: View {
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

struct NotSection: View {
    let icon: String
    let title: LocalizedStringKey
    let bodyText: LocalizedStringKey
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.red.opacity(0.7))
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
