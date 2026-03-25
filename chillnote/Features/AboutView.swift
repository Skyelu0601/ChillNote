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
                        
                        Text("ChillNote")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.textMain)
                        
                        Text("Built for People Who Create")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.textSub)
                        
                        Text("\"Capture the spark.\nShape it later.\"")
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
                    Text("ChillNote is built for people who create: content creators, builders, developers, designers, writers, and anyone whose best ideas tend to arrive before they are fully formed. It helps you catch the spark quickly, then shape it into something clear enough to keep building from.")
                        .font(.body)
                        .foregroundColor(.textMain)
                        .lineSpacing(4)
                    
                    Divider()
                    
                    // Section 1
                    PhilosophySection(
                        number: "01",
                        title: "For Content Creators",
                        quote: "\"Ideas show up in fragments. I need to catch them before they vanish.\"",
                        content: [
                            "Creators rarely get ideas in neat paragraphs. They come as hooks, angles, half-sentences, scenes, titles, and sudden bursts of clarity.",
                            "**The Problem:** By the time you open a blank page and try to type cleanly, the energy of the idea is already fading.",
                            "**The Solution:** ChillNote lets you talk while the idea is still alive, then turns the raw capture into something you can actually return to when it is time to write, record, or publish."
                        ]
                    )
                    
                    // Section 2
                    PhilosophySection(
                        number: "02",
                        title: "For Builders & Developers",
                        quote: "\"The product thought hits while I am walking, debugging, or switching contexts.\"",
                        content: [
                            "Builders do not just have tasks. They have feature ideas, product tradeoffs, naming thoughts, launch notes, and tiny insights that appear in the middle of everything else.",
                            "**The Problem:** Most of those thoughts are too valuable to lose, but too rough to stop and document properly in the moment.",
                            "**The Solution:** ChillNote gives builders a fast capture layer between the thought and the backlog, so rough product instinct can become usable notes instead of forgotten mental tabs."
                        ]
                    )
                    
                    // Section 3
                    PhilosophySection(
                        number: "03",
                        title: "For Creative Workers",
                        quote: "\"I do my best thinking out loud.\"",
                        content: [
                            "Designers, strategists, marketers, filmmakers, researchers, and other creative workers often discover the idea while explaining it to themselves.",
                            "**The Friction:** Typing too early pushes you into editing mode when what you really need is momentum.",
                            "**The Solution:** Speaking keeps you closer to the original thought. ChillNote captures that momentum first, then helps you shape it into clearer language, structure, and next steps."
                        ]
                    )
                    
                    // Section 4
                    PhilosophySection(
                        number: "04",
                        title: "Capture First, Organize After",
                        quote: "\"The first version of a good idea is usually messy.\"",
                        content: [
                            "ChillNote is based on a simple belief: forcing structure too early kills useful thinking.",
                            "**What We Believe:** Capture should feel immediate and forgiving. Organization should happen after the thought is safe.",
                            "**What That Means:** You do not need a polished sentence to save something important. A rough voice note can still become a clean, useful starting point."
                        ]
                    )
                    
                    // Section 5
                    PhilosophySection(
                        number: "05",
                        title: "A Tool for Momentum, Not Maintenance",
                        quote: "\"I want to keep making, not babysit a system.\"",
                        content: [
                            "The goal is not to build another heavy workspace that demands constant upkeep.",
                            "**The Goal:** Reduce the friction between having an idea and keeping it.",
                            "**The Result:** Less time formatting, filing, and rewriting from scratch. More time staying in motion and returning to ideas that still feel usable later."
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
                            bodyText: "ChillNote is not built to be a full meeting transcription system. It is for capturing personal ideas, creative sparks, and rough thinking while they are happening."
                        )
                        
                        NotSection(
                            icon: "book.closed.fill",
                            title: "Not for Long-Form Writing",
                            bodyText: "ChillNote is for the seed, not the whole tree. It helps you catch the raw material for a post, product, script, essay, or concept before you move into full drafting elsewhere."
                        )
                        
                        NotSection(
                            icon: "clock.badge.exclamationmark.fill",
                            title: "Not a Heavy Workflow",
                            bodyText: "If capture feels slow, people stop capturing. ChillNote is meant to stay light, fast, and easy to return to, so it supports creative momentum instead of interrupting it."
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
                        
                        Text("ChillNote is for people who create.\n\nIt exists to help you catch ideas while they are still alive, before they get edited away, delayed, or forgotten. Speak the rough version now. Shape it into something useful when you are ready.")
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
