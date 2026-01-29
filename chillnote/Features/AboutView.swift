import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header Section
                    VStack(spacing: 16) {
                        Image("chillo_touming")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                        
                        Text("ChillNote")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.textMain)
                        
                        Text("Design Philosophy & Vision")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.textSub)
                        
                        Text("\"Capturing the speed of thought,\none voice at a time.\"")
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
                    Text("ChillNote is not just another note-taking app. It is a tool designed to realign the way we capture, process, and structure our thoughts. By prioritizing voice input and AI-driven organization, ChillNote addresses the friction between the human mind's speed and the limitations of traditional input methods.")
                        .font(.body)
                        .foregroundColor(.textMain)
                        .lineSpacing(4)
                    
                    Divider()
                    
                    // Section 1
                    PhilosophySection(
                        number: "01",
                        title: "For the ADHD & The Hyper-Active Mind",
                        quote: "\"My thoughts run faster than my fingers.\"",
                        content: [
                            "People with ADHD or highly active minds often experience a \"bottleneck\" effect. Their brains generate connections and ideas at a velocity that typing simply cannot match.",
                            "**The Problem:** The cognitive load of typing acts as a brake on the train of thought.",
                            "**The Solution:** Voice is the path of least resistance. By removing the mechanical barrier, we allow the \"stream of consciousness\" to flow freely, ensuring that no spark of genius is lost to the slowness of a keyboard."
                        ]
                    )
                    
                    // Section 2
                    PhilosophySection(
                        number: "02",
                        title: "For the \"Struggling Writer\"",
                        quote: "\"I have the idea, but I can't find the words.\"",
                        content: [
                            "Many possess profound insights but lack the structural skills to organize them. ChillNote is for those who love to express but find raw thoughts chaotic.",
                            "**The Problem:** The gap between *having* an idea and *structuring* it.",
                            "**The Solution:** **AI as the Editor.** ChillNote invites you to \"ramble.\" Pour out fragmented, messy thoughts. The AI acts as a skilled editor, restructuring chaos into clear prose. It empowers you to be a \"thinker\" without needing to be a polished \"writer.\""
                        ]
                    )
                    
                    // Section 3
                    PhilosophySection(
                        number: "03",
                        title: "For Creative Workers",
                        quote: "\"Typing is unnatural; Speaking is instinct.\"",
                        content: [
                            "Humanity has spoken for eons; typing is a recent invention. For creatives, typing can be a distraction.",
                            "**The Friction:** When we type, we micro-manage—fixing typos, adjusting margins. Every micro-decision is a macro-interruption to flow.",
                            "**The Solution:** A disconnect between input and visualization. You speak; the system handles the rest. No more RSI, no more neck pain—just pure creation."
                        ]
                    )
                    
                    // Section 4
                    PhilosophySection(
                        number: "04",
                        title: "For Seekers of Self-Healing",
                        quote: "\"Talk is a way to heal yourself.\"",
                        content: [
                            "In a digital era of \"silent communication,\" we often suppress emotion.",
                            "**Vocalizing as Therapy:** Speaking aloud externalizes internal conflicts. ChillNote serves as a safe space for journaling and retrospective.",
                            "**The Psychology:** Voice carries emotional data that text cannot. Recording becomes a release, an affirmation, and a way to encourage oneself."
                        ]
                    )
                    
                    // Section 5
                    PhilosophySection(
                        number: "05",
                        title: "For the \"Format Haters\"",
                        quote: "\"Life is too short to adjust margins.\"",
                        content: [
                            "Formatting is \"performative work\"—it takes time but adds no content value.",
                            "**The Goal:** One-click perfection.",
                            "**The Result:** Focus entirely on *content*. With a single tap, the app applies professional-grade structure. Reclaim the time wasted on meaningless operational tasks."
                        ]
                    )
                    
                    Divider()
                    
                    // What ChillNote is NOT
                    VStack(alignment: .leading, spacing: 20) {
                        Text("What ChillNote is NOT")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.textMain)
                        
                        Text("\"Defining the boundaries to preserve the 'Chill'.\"")
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.textSub)
                        
                        NotSection(
                            icon: "mic.slash.fill",
                            title: "Not for Meeting Minutes",
                            bodyText: "ChillNote is not a corporate dictaphone. It is for personal reflections and raw inspiration, not the boardroom drone. Use specialized software for hour-long meetings."
                        )
                        
                        NotSection(
                            icon: "book.closed.fill",
                            title: "Not for Long-Form Writing",
                            bodyText: "ChillNote is Mobile-First. It exists to capture transient, fragmented thoughts before they evaporate. It is for the seeds of ideas, not the entire novel."
                        )
                        
                        NotSection(
                            icon: "clock.badge.exclamationmark.fill",
                            title: "The 10-Minute Limit",
                            bodyText: "If it takes more than 10 minutes, it's not Chill. Record, transcript, tidy, done. Keep it light, keep it fast."
                        )
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // Summary
                    VStack(spacing: 16) {
                        Text("Our Vision")
                            .font(.headline)
                            .foregroundColor(.textSub)
                            .textCase(.uppercase)
                        
                        Text("ChillNote is an attempt to use technology to return us to a more natural, healthy, and efficient state of being.\n\nIt is for the dreamers who talk fast, the creators who hurt from typing, and anyone who believes their ideas deserve to be heard, not just written.")
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
    let title: String
    let quote: String
    let content: [String]
    
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
            
            ForEach(content, id: \.self) { paragraph in
                Text(LocalizedStringKey(paragraph))
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
    let title: String
    let bodyText: String
    
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
