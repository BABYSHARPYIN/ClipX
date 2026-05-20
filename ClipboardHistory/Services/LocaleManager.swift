import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable {
    case system = "system"
    case en = "en"
    case zhHans = "zh-Hans"

    var label: String {
        switch self {
        case .system: return "Auto"
        case .en: return "English"
        case .zhHans: return "中文"
        }
    }
}

@MainActor
final class LocaleManager: ObservableObject {
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "app_language") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.system.rawValue
        language = AppLanguage(rawValue: raw) ?? .system
    }

    var effectiveLanguage: AppLanguage {
        if language == .system {
            let preferred = Bundle.main.preferredLocalizations.first ?? "en"
            return preferred.hasPrefix("zh") ? .zhHans : .en
        }
        return language
    }

    var isZh: Bool { effectiveLanguage == .zhHans }

    // MARK: - String lookups

    func tr(_ key: String) -> String {
        let table = isZh ? zh : en
        return table[key] ?? key
    }

    private let en: [String: String] = [
        "app.title": "ClipX - Copy less, paste more",
        "app.about": "About ClipX",
        "app.feedback": "Feedback",
        "app.quit": "Quit",
        "app.hotkey": "Shortcut",
        "app.settings": "Settings...",
        "app.language": "Language",

        "about.title": "ClipX",
        "about.subtitle": "Copy less, paste more",
        "about.description": "A lightweight macOS menu bar clipboard tool",
        "about.built": "Built with SwiftUI by Rio",

        "about.contact": "Questions or suggestions?",
        "about.thanks": "Thank you for using ClipX",

        "feedback.title": "Send Feedback",
        "feedback.hint": "Describe your issue...",
        "feedback.send": "Send",
        "feedback.sent": "Mail client opened",
        "feedback.subtitle": "Found a bug or have a suggestion? Tell us about it",

        "hotkey.title": "Shortcut",
        "hotkey.desc": "Set global shortcut for ClipX",
        "hotkey.record": "Click to record",
        "hotkey.recording": "Press shortcut...",
        "hotkey.reset": "Reset default",
        "hotkey.clear": "Clear",

        "settings.general": "General",
        "settings.hotkey": "Shortcut",
        "settings.startup": "Startup",
        "settings.launchAtLogin": "Launch at Login",
        "settings.launchAtLogin.desc": "Automatically start ClipX when you log in",

        "search.placeholder": "Search...",
        "search.empty": "No clipboard history",
        "search.noMatch": "No matches",

        "filter.all": "All",
        "filter.text": "Text",
        "filter.image": "Image",
        "filter.video": "Video",
        "filter.file": "File",

        "type.text": "Text",
        "type.image": "Image",

        "footer.items": " records",
        "footer.clearAll": "Clear All",

        "row.copied": "Copied",
        "row.justNow": "just now",
        "row.minAgo": "m ago",
        "row.hrAgo": "h ago",
        "row.dayAgo": "d ago",
    ]

    private let zh: [String: String] = [
        "app.title": "ClipX - Copy less, paste more",
        "app.about": "关于 ClipX",
        "app.feedback": "反馈",
        "app.quit": "退出",
        "app.hotkey": "快捷键",
        "app.settings": "设置...",
        "app.language": "语言",

        "about.title": "ClipX",
        "about.subtitle": "Copy less, paste more",
        "about.description": "一款轻量的 macOS 菜单栏剪切板工具",
        "about.built": "由 Rio 用 SwiftUI 构建",

        "about.contact": "遇到问题或建议？",
        "about.thanks": "感谢你的使用",

        "feedback.title": "发送反馈",
        "feedback.hint": "请描述你遇到的问题...",
        "feedback.send": "发送",
        "feedback.sent": "已打开邮件客户端",
        "feedback.subtitle": "遇到问题或有建议？请告诉我们",

        "hotkey.title": "快捷键",
        "hotkey.desc": "设置唤出 ClipX 的全局快捷键",
        "hotkey.record": "点击录制",
        "hotkey.recording": "按下快捷键...",
        "hotkey.reset": "恢复默认",
        "hotkey.clear": "清除",

        "settings.general": "通用",
        "settings.hotkey": "快捷键",
        "settings.startup": "启动",
        "settings.launchAtLogin": "开机自动启动",
        "settings.launchAtLogin.desc": "登录时自动启动 ClipX",

        "search.placeholder": "搜索...",
        "search.empty": "暂无剪切板历史",
        "search.noMatch": "无匹配结果",

        "filter.all": "全部",
        "filter.text": "文本",
        "filter.image": "图片",
        "filter.video": "视频",
        "filter.file": "文件",

        "type.text": "文本",
        "type.image": "图片",

        "footer.items": " 条记录",
        "footer.clearAll": "清除全部",

        "row.copied": "已复制",
        "row.justNow": "刚刚",
        "row.minAgo": " 分钟前",
        "row.hrAgo": " 小时前",
        "row.dayAgo": " 天前",
    ]
}
