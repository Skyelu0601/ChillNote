# iOS Instructions

- iOS 主源码位于 `ios/chillnote/`，测试位于 `ios/chillnoteTests/` 和 `ios/chillnoteUITests/`。
- Widget 与分享扩展分别位于 `ios/ChillNoteWidget/` 和 `ios/ChillNoteShareExtension/`。
- 当前产品名是 ChillScript；目录名、Target 名和 Bundle ID 中的 `chillnote` / `ChillNote` 是历史技术名称。
- 不要修改 Bundle ID、App Group、Keychain Group、URL Scheme、StoreKit 商品 ID 或签名能力，除非用户明确要求并接受迁移影响。
- SwiftUI 用户可见文案必须遵守仓库根目录 `docs/i18n/I18N_RULES.md`。
- 新代码优先沿用现有架构和 `L10n.text(...)`，不要额外引入第二套本地化入口。

## Verification

```bash
npm run lint:i18n
xcodebuild -project ios/chillnote.xcodeproj -scheme chillnote -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' build
```
