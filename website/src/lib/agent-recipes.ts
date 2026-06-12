import type { NoteDTO } from "./chillnote-api";

export type AgentRecipeCategory = "think" | "shape" | "publish";

export type AgentRecipe = {
  id: string;
  icon: string;
  name: string;
  description: string;
  prompt: string;
  category: AgentRecipeCategory;
  isBuiltInLogic?: boolean;
  requiresInstruction?: boolean;
  defaultInstruction?: string;
};

export type CaptionPackBuildOptions = {
  platforms: string[];
  goal: string;
  tone: string;
  outputStyle: "Concise" | "Balanced" | "Detailed";
};

export type BuildAgentRecipeOptions = {
  captionPack?: CaptionPackBuildOptions;
  brandVoiceSample?: string;
};

export const recipeCategoryLabels: Record<AgentRecipeCategory, string> = {
  think: "Think",
  shape: "Shape",
  publish: "Act",
};

export const defaultSavedRecipeIds = ["hook_generator", "caption_pack", "humanizer"];

export const agentRecipes: AgentRecipe[] = [
  {
    id: "brainstorm",
    icon: "💡",
    name: "Brainstorm",
    description: "Generate diverse angles to expand a thought.",
    category: "think",
    prompt: `You are brainstorming based on a user's existing note (not a chat message). Generate 5 distinct, creative angles or ideas to expand upon their initial thought.

- Keep the output in the same language as the note.
- Encourage divergent thinking while keeping suggestions practical.
- Use short, clear bullet points.

Output only the 5 ideas.`,
  },
  {
    id: "why_viral",
    icon: "📈",
    name: "Why Viral",
    description: "Analyze why an idea might spread.",
    category: "think",
    prompt: `You are analyzing why a piece of content might spread based on a user's existing note (not a chat message). Explain the likely viral mechanics without pretending you have real platform metrics.

- Keep the output in the same language as the note.
- Identify the core promise, emotional trigger, audience, tension, novelty, and shareability.
- Separate what is strong from what is weak or missing.
- Give 3 concrete ways to make the idea more shareable while staying truthful.
- Avoid vague advice like "make it more engaging"; be specific.

Output as:
1. Viral thesis
2. Why it could spread
3. What holds it back
4. How to strengthen it`,
  },
  {
    id: "summarize",
    icon: "📝",
    name: "Summarize",
    description: "Condense long text into a short summary.",
    category: "think",
    prompt: `You are summarizing a user's existing note (not a chat message). Keep the note's original intent and tone, and summarize only what's actually in the note.

- Write in the same language as the note.
- Keep key facts, decisions, and action items.
- If the note is short, give a one-sentence summary or a tightened rewrite.
- If the note is long or messy, use bullets to make it easier to scan.
- If something is unclear or conflicting, flag it briefly instead of guessing.`,
  },
  {
    id: "translate",
    icon: "🌍",
    name: "Translate",
    description: "Translate notes into another language.",
    category: "shape",
    prompt: "(Built-in Logic) Uses a dynamic translation engine. The target language is selected at runtime.",
    isBuiltInLogic: true,
    requiresInstruction: true,
    defaultInstruction: "English",
  },
  {
    id: "humanizer",
    icon: "✍️",
    name: "Humanizer",
    description: "Make text sound more natural and less AI-written.",
    category: "shape",
    prompt: `You are editing a user's existing note (not a chat message) to make it sound more natural, human-written, and specific.

Work privately in two passes:
1. Scan the note for the 29 AI-writing patterns below and rewrite the affected parts.
2. Ask yourself what still sounds obviously AI-generated, then revise once more.

- Keep the output in the same language as the note.
- Preserve the note's core meaning, facts, structure, and intended audience.
- Replace stiff, padded, promotional, or over-polished phrasing with simpler, more concrete wording.
- Vary sentence rhythm where it helps, but do not add fake personality, fake citations, fake anecdotes, or unsupported claims.
- Keep useful first-person voice, uncertainty, humor, and rough edges when they fit the original note.
- Preserve formatting (headings, lists, line breaks).
- If the note is already natural, make only light edits.

Check and remove these 29 AI-writing patterns:
1. Inflated significance, legacy, or broader-trend claims: "pivotal moment", "testament", "underscores its importance", "reflects broader", "sets the stage", "evolving landscape".
2. Notability name-dropping: lists of media outlets, experts, or social proof without a concrete point.
3. Superficial "-ing" analysis: dangling phrases like "highlighting", "reflecting", "showcasing", "contributing to", "ensuring", "fostering".
4. Promotional language: "boasts", "vibrant", "rich", "profound", "renowned", "breathtaking", "must-visit", "stunning", "nestled", "in the heart of".
5. Vague attribution: "experts argue", "observers note", "industry reports suggest", "some critics say" unless the source is specific in the note.
6. Formulaic challenges/future sections: "Despite these challenges...", "continues to thrive", "future outlook", "challenges and legacy".
7. Overused AI vocabulary: actually, additionally, align with, crucial, delve, enduring, enhance, garner, highlight, interplay, intricate, key, landscape, pivotal, showcase, tapestry, testament, underscore, valuable, vibrant.
8. Copula avoidance: replace "serves as", "stands as", "functions as", "represents", "features", "boasts", "offers" with simpler "is", "has", or a direct verb when clearer.
9. Negative parallelisms and tailing negations: "not only... but...", "not just X, it is Y", and clipped endings like ", no guessing" or ", no wasted motion".
10. Forced rule of three: lists or adjective triples that exist only to sound complete.
11. Synonym cycling: using many labels for the same thing when repeating the clearest term would be better.
12. False ranges: "from X to Y" pairs that are not a real scale or useful contrast.
13. Passive voice and subjectless fragments: clarify the actor when it improves the sentence, especially lines like "No configuration needed" or "The results are preserved automatically."
14. Em dash overuse: replace unnecessary em dashes with commas, periods, parentheses, or cleaner sentence breaks.
15. Boldface overuse: remove mechanical bolding unless it genuinely helps the note.
16. Inline-header vertical lists: avoid repetitive bullets like "**Performance:** Performance improved"; convert to natural prose or cleaner bullets.
17. Title Case headings: use natural sentence-style headings unless the original format requires title case.
18. Decorative emojis: remove emoji decoration unless it is clearly part of the user's voice or original meaning.
19. Curly quotation marks: prefer straight quotes unless the note's language or format clearly expects typographic quotes.
20. Chatbot artifacts: remove "Of course", "Certainly", "Great question", "I hope this helps", "let me know", and "Would you like me to..." when pasted into content.
21. Knowledge-cutoff disclaimers: remove "as of my last update", "based on available information", "details are limited" unless the uncertainty is genuinely part of the note.
22. Sycophantic tone: remove excessive agreement or flattery such as "You're absolutely right" and "excellent point."
23. Filler phrases: shorten "in order to" to "to", "due to the fact that" to "because", "at this point in time" to "now", and similar padding.
24. Excessive hedging: reduce stacked qualifiers like "could potentially possibly be argued" to a single honest qualifier.
25. Generic positive conclusions: remove vague endings like "the future looks bright", "exciting times lie ahead", and "journey toward excellence."
26. Hyphenated word-pair overuse: remove unnecessary hyphens from common word pairs when grammar allows it, while keeping technical or required compounds.
27. Persuasive authority tropes: simplify "the real question is", "at its core", "fundamentally", "the heart of the matter", and similar ceremony.
28. Signposting announcements: remove "let's dive in", "let's explore", "let's break this down", "here's what you need to know", and "without further ado."
29. Fragmented headers: remove one-line warmups after headings when they only restate the heading.

Output only the humanized text.`,
  },
  {
    id: "expand",
    icon: "🪄",
    name: "Expand",
    description: "Stretch a brief idea into richer detail.",
    category: "shape",
    prompt: `You are expanding a user's existing note (not a chat message). Elaborate only what the note already suggests, keeping the original intent and tone.

- Keep the output in the same language as the note.
- Do not invent new facts; add detail by clarifying, giving plausible examples, or drawing out implications already present.
- If the note is very short, provide a conservative expansion without adding new facts.
- Preserve formatting if the note has structure.`,
  },
  {
    id: "style_match",
    icon: "🎙️",
    name: "Brand Voice",
    description: "Rewrite a note in your saved writing voice.",
    category: "shape",
    prompt: "(Built-in Logic) Rewrites the note in the creator's saved brand voice.",
    isBuiltInLogic: true,
  },
  {
    id: "hook_generator",
    icon: "🎣",
    name: "Hooks",
    description: "Turn a raw idea into catchy hooks or titles.",
    category: "shape",
    prompt: `You are an expert copywriter looking at a user's raw note (not a chat message). Generate 5 punchy, compelling hooks or tweet openers based on the content.

- Keep the output in the same language as the note.
- Do not use clickbait or hype. Focus on curiosity and value.
- Provide a mix of direct and question-based hooks.

Output only the 5 hooks.`,
  },
  {
    id: "caption_pack",
    icon: "📣",
    name: "Caption Pack",
    description: "Create ready-to-post captions for TikTok, Shorts, and Reels.",
    category: "publish",
    prompt: "(Built-in Logic) Generates platform-ready captions from creator inspiration notes.",
    isBuiltInLogic: true,
  },
  {
    id: "youtube_script",
    icon: "🎬",
    name: "YouTube Script",
    description: "Turn a note into a YouTube video script.",
    category: "publish",
    prompt: `You are turning a user's existing note into a YouTube video script. The note was not written for chat. Produce a clean, recordable script that stays faithful to the note's intent and tone.

- Keep the script in the same language as the note.
- Structure it as: Hook -> Main Points -> Summary -> CTA.
- Use short, spoken-friendly sentences.
- If the note is long, compress to the most useful points.
- Do not add new facts; expand only what the note supports.
- Keep it concise enough to record comfortably.

Output only the script.`,
  },
  {
    id: "repurpose_pack",
    icon: "♻️",
    name: "Repurpose Pack",
    description: "Turn one long post into native versions for X, LinkedIn, and more",
    category: "publish",
    prompt: "(Built-in Logic) Atomizes one long-form note into native posts for multiple platforms.",
    isBuiltInLogic: true,
  },
];

export function notesContentForRecipe(notes: NoteDTO[]) {
  return notes.map((note) => note.content).join("\n\n---\n\n");
}

function captionPackStyleInstruction(style: CaptionPackBuildOptions["outputStyle"]) {
  switch (style) {
    case "Concise":
      return `- TikTok caption target: 120-220 characters.
- YouTube Shorts title target: 35-50 characters.
- YouTube Shorts description target: 80-150 characters.
- Instagram Reels caption target: 100-180 characters.`;
    case "Detailed":
      return `- TikTok caption target: 700-1,200 characters.
- YouTube Shorts title target: 70-90 characters.
- YouTube Shorts description target: 300-600 characters.
- Instagram Reels caption target: 600-1,000 characters.`;
    case "Balanced":
    default:
      return `- TikTok caption target: 300-600 characters.
- YouTube Shorts title target: 50-70 characters.
- YouTube Shorts description target: 150-300 characters.
- Instagram Reels caption target: 250-500 characters.`;
  }
}

export function buildAgentRecipeRequest(
  recipe: AgentRecipe,
  notes: NoteDTO[],
  userInstruction?: string,
  options: BuildAgentRecipeOptions = {}
) {
  const combinedContent = notesContentForRecipe(notes);
  const languageRule = `- Keep the output in the same language(s) as the input.
- If the input is mixed-language, preserve each segment's original language instead of normalizing to a single language.
- Do NOT translate unless explicitly requested.`;

  if (recipe.id === "translate") {
    const targetLanguage = userInstruction?.trim() || recipe.defaultInstruction || "English";
    return {
      prompt: `Translate the following notes into ${targetLanguage}.

Notes:
${combinedContent}`,
      systemPrompt: `You are a professional translator.
Rules:
- Translate into ${targetLanguage}.
- Preserve meaning, tone, and formatting (including markdown).
- Keep proper nouns, product names, URLs, code, and hashtags intact unless a standard translation exists.
- Do not localize units, dates, or numbers unless explicitly requested.
- Return only the translated content.`,
    };
  }

  if (recipe.id === "caption_pack") {
    const captionPack = options.captionPack ?? {
      platforms: ["TikTok", "YouTube Shorts", "Instagram Reels"],
      goal: "Start discussion",
      tone: "Casual + useful",
      outputStyle: "Balanced" as const,
    };
    const platforms = captionPack.platforms.length > 0
      ? captionPack.platforms.join(", ")
      : "TikTok, YouTube Shorts, Instagram Reels";

    return {
      prompt: `Create a Caption Pack for these selected platforms: ${platforms}.

User goal: ${captionPack.goal}
Tone: ${captionPack.tone}
Output style: ${captionPack.outputStyle}

Notes:
${combinedContent}`,
      systemPrompt: `You create original platform-ready publishing copy for content creators.

The notes may contain third-party creator inspiration, including descriptions, transcripts, hooks, or author metadata. Treat the notes as a private inspiration library, not source copy to rewrite.

Core rules:
${languageRule}
- Use the notes only to understand the topic, audience, emotional angle, content pattern, and reusable insight.
- Do not copy, closely paraphrase, or preserve distinctive wording from the notes.
- Do not mention the original author unless the notes explicitly ask for attribution.
- Do not invent claims, stats, personal experiences, product promises, discounts, or results that are not supported.
- If the notes do not contain enough substance, write safe, editable platform copy based on the broad idea and avoid specific unsupported claims.
- Return only the Caption Pack. Do not explain your reasoning.

Length and style:
${captionPackStyleInstruction(captionPack.outputStyle)}
- Character counts must include the generated field text, not the label.
- If a draft exceeds any platform limit, rewrite it shorter before returning.

Platform rules:
- TikTok: Output Caption and Hashtags. Caption must be under 2,200 characters. Hashtags must be 5 or fewer.
- YouTube Shorts: Output Title, Description, and Hashtags. Title must be under 100 characters. Description must be under 5,000 characters. Hashtags must be 3 or fewer.
- Instagram Reels: Output Caption and Hashtags. Caption must be under 2,200 characters. Hashtags must be 5 or fewer.
- For TikTok and Instagram Reels, naturally fold any question or soft call to action into the caption when it fits. Do not create a separate CTA section.

Output format:
Use only the selected platforms and keep this exact section style:

## TikTok

Caption:
...

Hashtags:
#creatorworkflow #contentstrategy #shortformvideo #tiktoktips #contentideas

## YouTube Shorts

Title:
...

Description:
...

Hashtags:
#Shorts #ContentStrategy #CreatorTips

## Instagram Reels

Caption:
...

Hashtags:
#contentcreator #creatorworkflow #reelstips #contentstrategy #socialmediatips`,
    };
  }

  if (recipe.id === "style_match") {
    const sample = options.brandVoiceSample?.trim() ?? "";
    if (!sample) {
      return {
        prompt: `Rewrite this note in a natural, consistent writing voice. Preserve its meaning, facts, and structure.

Note:
${combinedContent}`,
        systemPrompt: `You polish a creator's note so it reads naturally and consistently, without changing what it says.
Rules:
${languageRule}
- Preserve all facts, structure, and the note's purpose.
- Do not add new claims or invent details.
- Return only the rewritten note. Do not explain.`,
      };
    }

    return {
      prompt: `Voice sample (the author's own writing - use it only to learn their style):
${sample}

Rewrite the note below so it reads as if the same author wrote it.

Note to rewrite:
${combinedContent}`,
      systemPrompt: `You rewrite a note in the author's personal writing voice, learned from a voice sample.
Rules:
${languageRule}
- Match the voice sample's tone, vocabulary, rhythm, sentence length, and quirks.
- The voice sample is for style only. Do not copy its sentences, phrases, claims, or topic.
- Preserve the note's meaning, facts, and structure. Do not invent new facts.
- Return only the rewritten note. Do not explain.`,
    };
  }

  if (recipe.id === "repurpose_pack") {
    return {
      prompt: `Repurpose this long-form content into native posts for these formats: X Thread, LinkedIn.

Thread length (X Thread / Threads): 6-8 posts.
Tone: Creator voice

Long-form content:
${combinedContent}`,
      systemPrompt: `You repurpose one piece of long-form content (a blog post, video script, transcript, essay, or newsletter) into native posts for multiple platforms. The text is existing content, not a chat message.

Core rules:
${languageRule}
- First identify the single core thesis and 3-5 key takeaways, then reshape them per platform.
- Rewrite natively for each format. Do not truncate the same paragraph and paste it everywhere.
- Do not invent facts, stats, quotes, or results that are not supported by the content.
- Preserve the author's intent and point of view.
- Include a light, natural call to action on each piece when it fits.
- Return only the repurposed posts. Do not explain your reasoning.

Format rules:
- X Thread: numbered posts (1/, 2/, ...). Each post must be 280 characters or fewer. The first post is a standalone hook.
- X Post: one standalone post, 280 characters or fewer, leading with the strongest takeaway.
- LinkedIn: open with the core insight, use short scannable paragraphs, professional and credible, no hype.
- Threads: numbered posts (1/, 2/, ...). Each post must be 500 characters or fewer, conversational tone.
- Newsletter: a 2-3 sentence intro blurb that teases the piece, ending with a [link] placeholder.

Output format:
Use only the selected formats and keep this exact section style:

## X Thread

1/ ...
2/ ...

## X Post

...

## LinkedIn

...

## Threads

1/ ...
2/ ...

## Newsletter

...`,
    };
  }

  return {
    prompt: `Instruction:
${recipe.prompt}

Notes:
${combinedContent}`,
    systemPrompt: `You are a helpful assistant.
Rules:
${languageRule}
- Follow the user's instruction precisely.
- Return only the result without any extra commentary.`,
  };
}
