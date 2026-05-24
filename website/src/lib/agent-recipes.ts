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
    description: "Analyze why an idea may spread and how to strengthen it.",
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
    description: "Compress a note while keeping key facts and action items.",
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
    description: "Translate notes into a selected target language.",
    category: "shape",
    prompt: "(Built-in Logic) Uses a dynamic translation engine.",
    isBuiltInLogic: true,
    requiresInstruction: true,
    defaultInstruction: "English",
  },
  {
    id: "humanizer",
    icon: "✍️",
    name: "Humanizer",
    description: "Make AI-ish writing sound more natural and specific.",
    category: "shape",
    prompt: `You are editing a user's existing note (not a chat message) to make it sound more natural, human-written, and specific.

Work privately in two passes:
1. Scan the note for AI-writing patterns and rewrite the affected parts.
2. Ask yourself what still sounds obviously AI-generated, then revise once more.

- Keep the output in the same language as the note.
- Preserve the note's core meaning, facts, structure, and intended audience.
- Replace stiff, padded, promotional, or over-polished phrasing with simpler, more concrete wording.
- Vary sentence rhythm where it helps, but do not add fake personality, fake citations, fake anecdotes, or unsupported claims.
- Preserve formatting (headings, lists, line breaks).
- If the note is already natural, make only light edits.

Output only the humanized text.`,
  },
  {
    id: "expand",
    icon: "🪄",
    name: "Expand",
    description: "Elaborate a note without inventing unsupported facts.",
    category: "shape",
    prompt: `You are expanding a user's existing note (not a chat message). Elaborate only what the note already suggests, keeping the original intent and tone.

- Keep the output in the same language as the note.
- Do not invent new facts; add detail by clarifying, giving plausible examples, or drawing out implications already present.
- If the note is very short, provide a conservative expansion without adding new facts.
- Preserve formatting if the note has structure.`,
  },
  {
    id: "style_match",
    icon: "🎭",
    name: "Style Match",
    description: "Create a fresh piece in the style of the source note.",
    category: "shape",
    prompt: `You are writing a new piece in the style of a reference text from the user's existing notes (not a chat message). Use the reference for tone, pacing, structure, and rhetorical moves, but do not copy distinctive sentences, phrases, claims, or proprietary wording.

- Keep the output in the same language as the note unless the notes clearly request another language.
- If multiple notes are provided, treat the first note as the style reference and the remaining notes as source material for the new piece.
- If only one note is provided, infer the style from that note and create a fresh piece on the same idea without reusing its wording.
- Preserve the intended audience and format when they are clear.
- Keep the result original, useful, and ready to edit.
- Do not explain the style analysis unless the note explicitly asks for analysis.

Output only the new piece.`,
  },
  {
    id: "hook_generator",
    icon: "🎣",
    name: "Hooks",
    description: "Generate punchy hooks from a raw idea.",
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
    id: "twitter_post",
    icon: "𝕏",
    name: "X Post",
    description: "Compress a note into a concise high-signal post.",
    category: "publish",
    prompt: `You are turning a user's existing note into a post for X (Twitter). The note was not written for chat. Create a concise, high-signal post that preserves the note's intent and tone.

- Keep the output in the same language as the note.
- Lead with a clear hook or takeaway.
- Prefer short, punchy sentences.
- If the note is long, compress it to the most shareable idea.

Output only the post.`,
  },
  {
    id: "linkedin_post",
    icon: "💼",
    name: "LinkedIn",
    description: "Shape a note into a professional LinkedIn post.",
    category: "publish",
    prompt: `You are turning a user's existing note into a LinkedIn post. The note was not written for chat. Create a clear, professional post that preserves the note's intent and voice.

- Keep the output in the same language as the note.
- Open with the core insight or result.
- Use short paragraphs or bullets for easy scanning.
- Keep it professional and credible; avoid hype.
- If the note is long, focus on the most valuable takeaway.
- End with a gentle discussion prompt only if it naturally fits.

Output only the post.`,
  },
  {
    id: "youtube_script",
    icon: "🎬",
    name: "YouTube Script",
    description: "Turn a note into a concise recordable video script.",
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
];

export function notesContentForRecipe(notes: NoteDTO[]) {
  return notes.map((note) => note.content).join("\n\n---\n\n");
}

export function buildAgentRecipeRequest(recipe: AgentRecipe, notes: NoteDTO[], userInstruction?: string) {
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
    return {
      prompt: `Create a Caption Pack for these selected platforms: TikTok, YouTube Shorts, Instagram Reels.

User goal: Start discussion
Tone: Casual + useful
Output style: Balanced

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
- TikTok caption target: 300-600 characters.
- YouTube Shorts title target: 50-70 characters and must be under 100 characters.
- YouTube Shorts description target: 150-300 characters and must be under 5,000 characters.
- Instagram Reels caption target: 250-500 characters and must be under 2,200 characters.
- If a draft exceeds any platform limit, rewrite it shorter before returning.

Platform rules:
- TikTok: Output Caption and Hashtags. Hashtags must be 5 or fewer.
- YouTube Shorts: Output Title, Description, and Hashtags. Hashtags must be 3 or fewer.
- Instagram Reels: Output Caption and Hashtags. Hashtags must be 5 or fewer.
- For TikTok and Instagram Reels, naturally fold any question or soft call to action into the caption when it fits. Do not create a separate CTA section.

Output format:
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
