import Foundation

// MARK: - User-selectable languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case zhHans = "zh-Hans"
    case ja
    case de
    case es

    var id: String { rawValue }

    /// Native name shown in the language picker (always written in its own language).
    var nativeName: String {
        switch self {
        case .system: return ""
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .ja: return "日本語"
        case .de: return "Deutsch"
        case .es: return "Español"
        }
    }

    /// Maps the user's preferred system languages onto the supported set.
    static func resolveSystem() -> AppLanguage {
        for preferred in Locale.preferredLanguages {
            if preferred.hasPrefix("zh") { return .zhHans }
            if preferred.hasPrefix("ja") { return .ja }
            if preferred.hasPrefix("de") { return .de }
            if preferred.hasPrefix("es") { return .es }
            if preferred.hasPrefix("en") { return .en }
        }
        return .en
    }
}

// MARK: - Appearance

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

// MARK: - Translation table
//
// Code-level localization: the app is assembled into an .app bundle by script
// (no Xcode project), so .lproj / String Catalog plumbing would be fragile.
// A struct per language gives compile-time completeness: adding a field to
// L10nTable breaks every table literal until all five languages provide it.

struct L10nTable {
    // Common / menu bar
    var statusBar: String
    var dock: String
    var all: String
    var menuBarManager: String
    var appsCount: String
    var noApps: String
    var noAppsInCategory: String
    var noAppsFound: String
    var total: String
    var open: String
    var quit: String
    var cancel: String
    // Detail info rows
    var infoType: String
    var infoPID: String
    var searchPlaceholder: String
    var settingsDots: String
    var quitAppTitle: String
    var openMainWindow: String
    var selectAppPrompt: String
    // Main window tabs
    var windowTabApps: String
    var windowTabSettings: String
    var sectionAppearance: String
    var appearanceSystem: String
    var appearanceLight: String
    var appearanceDark: String
    var sectionLanguage: String
    var languageSystem: String
    var sectionDock: String
    var showDockIcon: String
    var showDockIconCaption: String
    var launchAtLogin: String
    var launchAtLoginCaption: String
    var sectionRefresh: String
    var scanInterval: String
    // Settings — Menu bar icon
    var sectionAggIcon: String
    var aggIconCaption: String
    var iconTypeDots: String
    var iconTypeGrid: String
    var iconTypeChevron: String
    var iconTypeSquare: String
    var iconTypeCircle: String
    var iconTypeTransparent: String
    // Resident bar context menu
    var removeFromPanel: String
    // App detail pane
    var pinToMenuBar: String
    var unpinFromMenuBar: String
    var statusbarActivateHint: String
    // Menu bar occlusion (notch / overflow)
    var notchWarningTitle: String
    var notchWarningMainBody: String
    var notchWarningPinnedBody: String
    // Popover overview
    var memoryUsage: String
    var popoverClose: String
    // Global hotkey
    var hotKeyTitle: String
    var hotKeyOpenMainWindow: String
    var hotKeyRecording: String
    var hotKeyNone: String
    var hotKeyClear: String
    var hotKeyConflict: String
    // Overview — resident apps
    var residentAppsTitle: String
    // Quit confirmation (popover row — quitting a tracked app)
    var quitConfirmTitle: String
    var quitConfirmMessage: String
    // Quit confirmation (footer — quitting Topiary itself)
    var quitTopiaryConfirmTitle: String
    var quitTopiaryConfirmMessage: String
}

enum L10n {
    static let en = L10nTable(
        statusBar: "Status Bar",
        dock: "Dock",
        all: "All",
        menuBarManager: "Menu Bar Manager",
        appsCount: "%d apps",
        noApps: "No Apps",
        noAppsInCategory: "No apps in this category.",
        noAppsFound: "No apps found.",
        total: "Total",
        open: "Open",
        quit: "Quit",
        cancel: "Cancel",
        infoType: "Type",
        infoPID: "PID",
        searchPlaceholder: "Search...",
        settingsDots: "Settings...",
        quitAppTitle: "Quit Topiary",
        openMainWindow: "Open Main Window",
        selectAppPrompt: "Select an app to see its details.",
        windowTabApps: "Apps",
        windowTabSettings: "Settings",
        sectionAppearance: "Appearance",
        appearanceSystem: "System",
        appearanceLight: "Light",
        appearanceDark: "Dark",
        sectionLanguage: "Language",
        languageSystem: "System",
        sectionDock: "Dock",
        showDockIcon: "Show Dock icon",
        showDockIconCaption: "The Dock icon appears while the main window is open and hides when it closes.",
        launchAtLogin: "Launch at Login",
        launchAtLoginCaption: "Start Topiary automatically at login to claim a stable spot near the right edge of the menu bar.",
        sectionRefresh: "Refresh",
        scanInterval: "Menu bar scan interval",
        sectionAggIcon: "Menu Bar Icon",
        aggIconCaption: "Choose the icon Topiary shows in the menu bar.",
        iconTypeDots: "Three Dots",
        iconTypeGrid: "Grid",
        iconTypeChevron: "Chevron",
        iconTypeSquare: "Square",
        iconTypeCircle: "Circle",
        iconTypeTransparent: "Transparent",
        removeFromPanel: "Remove from panel",
        pinToMenuBar: "Pin to Menu Bar",
        unpinFromMenuBar: "Unpin from Menu Bar",
        statusbarActivateHint: "This app has no Dock icon. “Open” re-launches it to the front.",
        notchWarningTitle: "Menu Bar Space Is Full",
        notchWarningMainBody: "Topiary's menu bar icon is hidden behind the notch — the menu bar ran out of room. Quit or remove some menu bar apps to free space; the icon comes back automatically.",
        notchWarningPinnedBody: "%d pinned app icons are hidden behind the notch or an overcrowded menu bar. Quit or remove some menu bar apps to bring them back.",
        memoryUsage: "Memory Usage",
        popoverClose: "Close",
        hotKeyTitle: "Global Hotkey",
        hotKeyOpenMainWindow: "Summon main window",
        hotKeyRecording: "Press shortcut…",
        hotKeyNone: "Disabled",
        hotKeyClear: "Clear",
        hotKeyConflict: "This shortcut is already taken — please choose another.",
        residentAppsTitle: "Resident Apps",
        quitConfirmTitle: "Quit “%@”?",
        quitConfirmMessage: "This will terminate the app immediately.",
        quitTopiaryConfirmTitle: "Quit Topiary?",
        quitTopiaryConfirmMessage: "Topiary will stop managing your menu bar apps."
    )

    static let zhHans = L10nTable(
        statusBar: "菜单栏",
        dock: "程序坞",
        all: "全部",
        menuBarManager: "菜单栏管理器",
        appsCount: "%d 个应用",
        noApps: "无应用",
        noAppsInCategory: "此分类下没有应用。",
        noAppsFound: "未找到应用。",
        total: "总计",
        open: "打开",
        quit: "退出",
        cancel: "取消",
        infoType: "类型",
        infoPID: "PID",
        searchPlaceholder: "搜索…",
        settingsDots: "设置…",
        quitAppTitle: "退出 Topiary",
        openMainWindow: "打开主窗口",
        selectAppPrompt: "在左侧选择应用以查看详情。",
        windowTabApps: "应用",
        windowTabSettings: "设置",
        sectionAppearance: "外观",
        appearanceSystem: "跟随系统",
        appearanceLight: "浅色",
        appearanceDark: "深色",
        sectionLanguage: "语言",
        languageSystem: "跟随系统",
        sectionDock: "程序坞",
        showDockIcon: "在程序坞显示图标",
        showDockIconCaption: "主面板打开时显示程序坞图标，关闭后自动隐藏。",
        launchAtLogin: "登录时启动",
        launchAtLoginCaption: "登录后自动启动 Topiary，抢占菜单栏右侧的稳定位置。",
        sectionRefresh: "刷新",
        scanInterval: "菜单栏扫描间隔",
        sectionAggIcon: "菜单栏图标",
        aggIconCaption: "选择 Topiary 在菜单栏显示的图标。",
        iconTypeDots: "三个点",
        iconTypeGrid: "网格",
        iconTypeChevron: "箭头",
        iconTypeSquare: "方形",
        iconTypeCircle: "圆形",
        iconTypeTransparent: "透明",
        removeFromPanel: "从面板移除",
        pinToMenuBar: "常驻菜单栏",
        unpinFromMenuBar: "取消常驻",
        statusbarActivateHint: "此应用没有程序坞图标，「打开」会重新唤起它的窗口。",
        notchWarningTitle: "菜单栏空间不足",
        notchWarningMainBody: "Topiary 的菜单栏图标被刘海遮挡（菜单栏已满）。退出或移除部分菜单栏应用腾出空间后，图标会自动恢复显示。",
        notchWarningPinnedBody: "有 %d 个常驻应用图标被刘海或拥挤的菜单栏遮挡。退出或移除部分菜单栏应用即可恢复显示。",
        memoryUsage: "内存占用",
        popoverClose: "关闭",
        hotKeyTitle: "全局快捷键",
        hotKeyOpenMainWindow: "唤起主窗口",
        hotKeyRecording: "按下快捷键…",
        hotKeyNone: "未设置",
        hotKeyClear: "清除",
        hotKeyConflict: "该快捷键已被其他应用占用，请更换一个。",
        residentAppsTitle: "常驻应用",
        quitConfirmTitle: "退出「%@」？",
        quitConfirmMessage: "该应用将被立即终止。",
        quitTopiaryConfirmTitle: "退出 Topiary？",
        quitTopiaryConfirmMessage: "Topiary 将停止管理你的菜单栏应用。"
    )

    static let ja = L10nTable(
        statusBar: "ステータスバー",
        dock: "ドック",
        all: "すべて",
        menuBarManager: "メニューバーマネージャー",
        appsCount: "%d 個のアプリ",
        noApps: "アプリなし",
        noAppsInCategory: "このカテゴリにアプリはありません。",
        noAppsFound: "アプリが見つかりません。",
        total: "合計",
        open: "開く",
        quit: "終了",
        cancel: "キャンセル",
        infoType: "種類",
        infoPID: "PID",
        searchPlaceholder: "検索…",
        settingsDots: "設定…",
        quitAppTitle: "Topiary を終了",
        openMainWindow: "メインウィンドウを開く",
        selectAppPrompt: "左のアプリを選択すると詳細が表示されます。",
        windowTabApps: "アプリ",
        windowTabSettings: "設定",
        sectionAppearance: "外観",
        appearanceSystem: "システムに従う",
        appearanceLight: "ライト",
        appearanceDark: "ダーク",
        sectionLanguage: "言語",
        languageSystem: "システムに従う",
        sectionDock: "ドック",
        showDockIcon: "ドックにアイコンを表示",
        showDockIconCaption: "メインウィンドウが開いている間だけドックにアイコンを表示し、閉じると隠れます。",
        launchAtLogin: "ログイン時に起動",
        launchAtLoginCaption: "ログイン後に Topiary を自動起動し、メニューバー右側の安定した位置を確保します。",
        sectionRefresh: "更新",
        scanInterval: "メニューバーのスキャン間隔",
        sectionAggIcon: "メニューバーアイコン",
        aggIconCaption: "Topiary がメニューバーに表示するアイコンを選択します。",
        iconTypeDots: "3 つのドット",
        iconTypeGrid: "グリッド",
        iconTypeChevron: "シェブロン",
        iconTypeSquare: "四角",
        iconTypeCircle: "円",
        iconTypeTransparent: "透明",
        removeFromPanel: "パネルから削除",
        pinToMenuBar: "メニューバーに常駐",
        unpinFromMenuBar: "常駐を解除",
        statusbarActivateHint: "このアプリにはドックアイコンがありません。「開く」で前面に再表示します。",
        notchWarningTitle: "メニューバーに空きがありません",
        notchWarningMainBody: "メニューバーが満杯で、Topiary のアイコンがノッチの裏に隠れています。メニューバーアプリをいくつか終了すると、アイコンは自動的に戻ります。",
        notchWarningPinnedBody: "%d 個のピン留めアイコンがノッチや混雑したメニューバーに隠れています。メニューバーアプリを終了すると表示されます。",
        memoryUsage: "メモリ使用率",
        popoverClose: "閉じる",
        hotKeyTitle: "グローバルショートカット",
        hotKeyOpenMainWindow: "メインウィンドウを呼び出す",
        hotKeyRecording: "ショートカットを入力…",
        hotKeyNone: "未設定",
        hotKeyClear: "クリア",
        hotKeyConflict: "このショートカットは既に使用されています。別のものを設定してください。",
        residentAppsTitle: "常駐アプリ",
        quitConfirmTitle: "「%@」を終了しますか？",
        quitConfirmMessage: "このアプリは直ちに終了します。",
        quitTopiaryConfirmTitle: "Topiary を終了しますか？",
        quitTopiaryConfirmMessage: "Topiary はメニューバーアプリの管理を停止します。"
    )

    static let de = L10nTable(
        statusBar: "Statusleiste",
        dock: "Dock",
        all: "Alle",
        menuBarManager: "Menüleisten-Manager",
        appsCount: "%d Apps",
        noApps: "Keine Apps",
        noAppsInCategory: "Keine Apps in dieser Kategorie.",
        noAppsFound: "Keine Apps gefunden.",
        total: "Gesamt",
        open: "Öffnen",
        quit: "Beenden",
        cancel: "Abbrechen",
        infoType: "Typ",
        infoPID: "PID",
        searchPlaceholder: "Suchen…",
        settingsDots: "Einstellungen…",
        quitAppTitle: "Topiary beenden",
        openMainWindow: "Hauptfenster öffnen",
        selectAppPrompt: "Wähle links eine App aus, um Details zu sehen.",
        windowTabApps: "Apps",
        windowTabSettings: "Einstellungen",
        sectionAppearance: "Erscheinungsbild",
        appearanceSystem: "System",
        appearanceLight: "Hell",
        appearanceDark: "Dunkel",
        sectionLanguage: "Sprache",
        languageSystem: "System",
        sectionDock: "Dock",
        showDockIcon: "Dock-Symbol anzeigen",
        showDockIconCaption: "Das Dock-Symbol erscheint, solange das Hauptfenster offen ist, und verschwindet beim Schließen.",
        launchAtLogin: "Bei der Anmeldung starten",
        launchAtLoginCaption: "Topiary automatisch bei der Anmeldung starten, um einen stabilen Platz rechts in der Menüleiste zu sichern.",
        sectionRefresh: "Aktualisieren",
        scanInterval: "Scanintervall der Menüleiste",
        sectionAggIcon: "Menüleistensymbol",
        aggIconCaption: "Wählen Sie das Symbol, das Topiary in der Menüleiste zeigt.",
        iconTypeDots: "Drei Punkte",
        iconTypeGrid: "Raster",
        iconTypeChevron: "Chevron",
        iconTypeSquare: "Quadrat",
        iconTypeCircle: "Kreis",
        iconTypeTransparent: "Transparent",
        removeFromPanel: "Aus dem Panel entfernen",
        pinToMenuBar: "In die Menüleiste pinnen",
        unpinFromMenuBar: "Nicht mehr pinnen",
        statusbarActivateHint: "Diese App hat kein Dock-Symbol. „Öffnen“ holt sie erneut nach vorn.",
        notchWarningTitle: "Menüleiste ist voll",
        notchWarningMainBody: "Das Topiary-Symbol wird vom Notch verdeckt — die Menüleiste ist voll. Beende oder entferne einige Menüleisten-Apps; das Symbol erscheint automatisch wieder.",
        notchWarningPinnedBody: "%d angepinnte Symbole sind hinter dem Notch bzw. einer überfüllten Menüleiste verborgen. Beende oder entferne einige Menüleisten-Apps, um sie wieder anzuzeigen.",
        memoryUsage: "Speichernutzung",
        popoverClose: "Schließen",
        hotKeyTitle: "Globaler Kurzbefehl",
        hotKeyOpenMainWindow: "Hauptfenster aufrufen",
        hotKeyRecording: "Kurzbefehl drücken…",
        hotKeyNone: "Nicht festgelegt",
        hotKeyClear: "Löschen",
        hotKeyConflict: "Dieser Kurzbefehl ist bereits belegt — bitte einen anderen wählen.",
        residentAppsTitle: "Angepinnte Apps",
        quitConfirmTitle: "„%@“ beenden?",
        quitConfirmMessage: "Die App wird sofort beendet.",
        quitTopiaryConfirmTitle: "Topiary beenden?",
        quitTopiaryConfirmMessage: "Topiary hört auf, deine Menüleisten-Apps zu verwalten."
    )

    static let es = L10nTable(
        statusBar: "Barra de estado",
        dock: "Dock",
        all: "Todos",
        menuBarManager: "Gestor de la barra de menú",
        appsCount: "%d aplicaciones",
        noApps: "Sin aplicaciones",
        noAppsInCategory: "No hay aplicaciones en esta categoría.",
        noAppsFound: "No se encontraron aplicaciones.",
        total: "Total",
        open: "Abrir",
        quit: "Salir",
        cancel: "Cancelar",
        infoType: "Tipo",
        infoPID: "PID",
        searchPlaceholder: "Buscar…",
        settingsDots: "Ajustes…",
        quitAppTitle: "Salir de Topiary",
        openMainWindow: "Abrir ventana principal",
        selectAppPrompt: "Selecciona una app a la izquierda para ver los detalles.",
        windowTabApps: "Apps",
        windowTabSettings: "Ajustes",
        sectionAppearance: "Apariencia",
        appearanceSystem: "Sistema",
        appearanceLight: "Claro",
        appearanceDark: "Oscuro",
        sectionLanguage: "Idioma",
        languageSystem: "Sistema",
        sectionDock: "Dock",
        showDockIcon: "Mostrar el icono en el Dock",
        showDockIconCaption: "El icono del Dock aparece con la ventana principal y se oculta al cerrarla.",
        launchAtLogin: "Abrir al iniciar sesión",
        launchAtLoginCaption: "Inicia Topiary automáticamente al iniciar sesión para asegurar un lugar estable en la barra de menús.",
        sectionRefresh: "Actualización",
        scanInterval: "Intervalo de escaneo de la barra de menú",
        sectionAggIcon: "Icono de la barra de menús",
        aggIconCaption: "Elige el icono que Topiary muestra en la barra de menús.",
        iconTypeDots: "Tres puntos",
        iconTypeGrid: "Cuadrícula",
        iconTypeChevron: "Cheurón",
        iconTypeSquare: "Cuadrado",
        iconTypeCircle: "Círculo",
        iconTypeTransparent: "Transparente",
        removeFromPanel: "Quitar del panel",
        pinToMenuBar: "Fijar a la barra de menú",
        unpinFromMenuBar: "Dejar de fijar",
        statusbarActivateHint: "Esta app no tiene icono en el Dock. «Abrir» la trae de nuevo al frente.",
        notchWarningTitle: "La barra de menús está llena",
        notchWarningMainBody: "El icono de Topiary está oculto tras el notch: la barra de menús se quedó sin espacio. Sal o elimina algunas apps de la barra de menús; el icono volverá a aparecer.",
        notchWarningPinnedBody: "%d iconos fijados están ocultos tras el notch o en una barra de menús saturada. Sal o elimina algunas apps de la barra de menús para recuperarlos.",
        memoryUsage: "Uso de memoria",
        popoverClose: "Cerrar",
        hotKeyTitle: "Atajo global",
        hotKeyOpenMainWindow: "Abrir la ventana principal",
        hotKeyRecording: "Pulsa el atajo…",
        hotKeyNone: "Sin atajo",
        hotKeyClear: "Borrar",
        hotKeyConflict: "Este atajo ya está en uso — elige otro.",
        residentAppsTitle: "Apps fijadas",
        quitConfirmTitle: "¿Salir de «%@»?",
        quitConfirmMessage: "La app se cerrará de inmediato.",
        quitTopiaryConfirmTitle: "¿Salir de Topiary?",
        quitTopiaryConfirmMessage: "Topiary dejará de gestionar las apps de tu barra de menús."
    )

    // Memoized: Locale.preferredLanguages is stable within a launch session,
    // and this lookup runs on every view render via SettingsStore.l10n.
    private static let resolvedSystem: AppLanguage = AppLanguage.resolveSystem()

    static func table(for language: AppLanguage) -> L10nTable {
        switch language {
        case .system: return table(for: resolvedSystem)
        case .en: return en
        case .zhHans: return zhHans
        case .ja: return ja
        case .de: return de
        case .es: return es
        }
    }
}
