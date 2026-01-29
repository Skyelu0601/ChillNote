# Coding Guidelines & Best Practices

## 1. Localization (Multi-language Support)
This project targets a global audience (including EN, JA, ZH, ES, DE, FR). **ALL user-facing text must be localized.**

### Rules:
1.  **Never use hardcoded strings** in UI components (e.g., `Text("Settings")` or `Button("Cancel")`).
2.  **Use Localization Keys**:
    *   Format: `category.element.action` (e.g., `home.button.save`, `settings.title.general`).
    *   Use `snake_case` or `camelCase` consistently (currently using `camelCase` for segments like `home.action.selectAll`).
    *   Example: `Text("home.askChillo")` instead of `Text("Ask Chillo")`.
3.  **Update `Localizable.xcstrings`**:
    *   Whenever you introduce a new string key in Swift code, you must add it to `chillnote/Resources/Localizable.xcstrings`.
    *   **CRITICAL**: You only need to provide the **English (en)** value. Do **NOT** attempt to translate into other languages (JA, ZH, etc.) at this stage. Translation is a bulk process done pre-release.
    *   If you cannot edit the binary `.xcstrings` file directly, **explicitly list the new keys and their English default values** in the PR/Response.

### Example Workflow:
**Bad:**
```swift
Button("Delete Note") { ... }
```

**Good:**
```swift
// In Code:
Button("note.action.delete") { ... }

// In Localizable.xcstrings (Mental Model):
// Key: "note.action.delete" -> Value (en): "Delete Note"
// (Leave JA/ZH/DE/FR empty/untranslated for now)
```

## 2. UI & Design
(Add other design rules here as needed, e.g., "Use rounded corners", "Stick to the 'Chill' aesthetic")
