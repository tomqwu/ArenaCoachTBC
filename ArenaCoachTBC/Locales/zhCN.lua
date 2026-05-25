-- ArenaCoachTBC - Simplified Chinese (zh-CN) locale
local ADDON_NAME, ns = ...
ns = ns or {}
ns.locales = ns.locales or {}

ns.locales.zhCN = {
    -- Modes
    OPEN          = "开",
    KILL          = "杀",
    SWAP          = "切",
    DEFEND        = "守",
    RESET         = "断战",

    -- Priorities
    PRIO_LOW      = "低",
    PRIO_MEDIUM   = "中",
    PRIO_HIGH     = "高",
    PRIO_URGENT   = "紧急",

    -- Slash/help
    HELP_HEADER   = "ArenaCoachTBC 命令：",
    HELP_TOGGLE   = "/acc toggle           - 显示/隐藏框体",
    HELP_LOCK     = "/acc lock / unlock    - 锁定/解锁框体",
    HELP_TEST     = "/acc test [print]     - 14秒 UI 实时演示（或 'print' 仅文字版）",
    HELP_DEBUG    = "/acc debug            - 切换调试日志",
    HELP_RESET    = "/acc reset            - 重置存档变量",
    HELP_STRAT    = "/acc strategy safe|balanced|greedy - 设定策略激进度",
    HELP_ENEMY    = "/acc enemy <c1> ... <c5> - 模拟敌方阵容",
    HELP_SELFTEST = "/acc selftest [verbose] - 客户端内自检",
    HELP_SIMULATE = "/acc simulate [key|stop] - 回放脚本化场景",
    HELP_TRACE    = "/acc trace [on|off|dump|clear|status] - 决策追踪日志",
    HELP_RECORD   = "/acc record [on|off|dump|clear|status] - 记录战斗日志用于离线回放",
    HELP_WHATIF    = "/acc whatif <子命令>  - 重放录像并比较结果",
    TEST_DEMO_START = "|cffc8a86b[ACC]|r 演示开始 — 14秒 RMP 3v3 推演（模式切换、爆发提示、防御警报、对手习惯提示）。",
    TEST_DEMO_END   = "|cffc8a86b[ACC]|r 演示结束。/acc test print 可查看仅文字版本。",
    TEST_DEMO_NO_UI = "|cffc8a86b[ACC]|r 演示需要游戏内 UI（仅在客户端中可用）。",

    -- v2.1.3: 防御 / 重置模式的本地化原因
    REASON_DEFEND_TRAINED      = "防御 - 治疗被集火",
    REASON_DEFEND_LOW_HEALER   = "防御 - 治疗血量低",
    REASON_DEFEND_ENEMY_LUST   = "防御 - 敌方嗜血",
    REASON_DEFEND_MULTI_BURST  = "防御 - 多人爆发",
    REASON_DEFEND_HEALER_CC    = "防御 - 我方治疗被控",
    REASON_DEFEND_TRIPLE_DPS   = "防御 - 三 DPS 阵容（无起手）",
    REASON_RESET               = "重置 - 无明确目标",

    -- M14 (v2.1): 战场模式提示
    CALL_FLAG_CARRIER_LOW    = "夺旗者血量低 - 压上",
    CALL_INCOMING_PLAYERS    = "敌方来袭",
    CALL_BASE_UNDER_ATTACK   = "据点被攻 - 调度",
    CALL_BG_DEFEND           = "回血 - 集火检测",
    CALL_BG_RES_TIMER        = "复活倒计时中",
    HELP_BUGREPORT = "/acc bugreport       - 打印脱敏问题报告",
    BUGREPORT_HEADER = "问题报告内容：",
    HELP_HELP     = "/acc help             - 显示帮助",

    -- SelfTest
    SELFTEST_HEADER = "ArenaCoachTBC 自检：",

    -- Simulator
    SIMULATE_HEADER  = "可用场景（/acc simulate <key>）：",
    SIMULATE_STOPPED = "模拟已停止",

    -- Recommendation reasons / callouts
    REASON_DEFAULT       = "等待开局...",
    REASON_OPEN_HEALER   = "开局打对面治疗",
    REASON_OPEN_TARGET   = "开 %s",
    REASON_KILL_TARGET   = "压 %s",
    REASON_SWAP_TARGET   = "切 %s",
    REASON_DEFEND        = "防守，先回血",
    REASON_RESET         = "断战 / 拉柱子 / 喝水",
    REASON_IMMUNITY      = "目标免疫 (%s)",
    REASON_LOW_HEALTH    = "治疗血量低于 %d%%",
    REASON_TRINKET_DOWN  = "饰品 CD",
    REASON_MS_ACTIVE     = "致死打击在身",
    REASON_BURST_READY   = "爆发 CD 就绪",

    -- Callout strings
    CALL_FREEDOM_WAR     = "给战士自由",
    CALL_FREEDOM_ENH     = "给增强自由",
    CALL_PURGE           = "驱散 %s",
    CALL_HOJ_KILL        = "无敌锤上焦点",
    CALL_CYCLONE_OFF     = "飓风副治疗",
    CALL_EARTHSHOCK_HEAL = "下一个治疗法术地震打断",
    CALL_TREMOR_FEAR     = "战栗图腾防恐惧",
    CALL_GROUND_POLY     = "接地图腾防变羊",
    CALL_GROUND_DC       = "接地图腾防死亡缠绕",
    CALL_DISP_POLY       = "驱散变形",
    CALL_DISP_FROST      = "驱散冰环",
    CALL_CLEANSE_ROOTS   = "清除定身",
    CALL_MANA_BURN_PLAN  = "准备法力燃烧",
    CALL_PAIN_SUP_READY  = "痛苦压制就绪",
    CALL_BOP_READY       = "保护之手就绪",
    CALL_AVOID_OVERCHASE = "别追太深",
    CALL_PEEL_PRIEST     = "保牧师",
    CALL_PEEL_DRUID      = "保德鲁伊",
    CALL_LOW_MANA_PUSH   = "治疗蓝量低 - 压上",

    -- UI labels
    UI_TITLE             = "竞技场教练",
    UI_NO_ARENA          = "未在竞技场",
    -- v2.1.6: 目标信息行
    UI_HP_LABEL          = "血量",
    UI_KILL_PROB_LABEL   = "击杀率",
    UI_BURST_READY       = "可爆发",

    -- Comp-match confidence badges
    COMP_BADGE_SPEC_CONFIRMED = "天赋已确认",
    COMP_BADGE_CLASS_GUESSED  = "仅按职业推测",

    -- Chain callouts (M8 #62)
    CHAIN_RMP_SAP_INTO_KIDNEY     = "闷棍治疗，肾击目标",
    CHAIN_RMP_FEAR_INTO_BURST     = "尖叫锁场配合法师爆发",
    CHAIN_WMS_SHEEP_INTO_TRAIN    = "羊治疗，战士MS连击",
    CHAIN_WLD_FEAR_INTO_CYCLONE   = "恐惧链接龙卷剥离",
    CHAIN_WLP_FEAR_INTO_HOJ       = "恐惧接审判惩戒",
    CHAIN_JUNGLE_TRAP_INTO_CYCLONE = "陷阱治疗，龙卷副目标",
    CHAIN_BEAST_TRAP_INTO_INTERCEPT = "陷阱与驱散后战士截击",
    CHAIN_TSG_HOJ_INTO_INTERCEPT  = "审判后战士截击",
    CHAIN_TRIPLE_CASTER_OVERLAP   = "恐惧+羊群叠加锁场",
    CHAIN_RP_KIDNEY_INTO_BLIND    = "肾击爆发后致盲重置",
    CHAIN_RD_KIDNEY_INTO_CYCLONE  = "盗贼肾击+德鲁伊龙卷锁场",
    CHAIN_SHATTER_NOVA_INTO_SHEEP = "冰环定身后羊副目标",
    CHAIN_STEP_PREFIX             = "步骤",
    CHAIN_PICKED_PREFIX           = "连锁",

    -- M9 #65: profile-driven callouts
    CALL_FAKE_KICK_2          = "对方踢第一次治疗，假打第二个",
    CALL_SAVE_TREMOR_HOJ      = "对方习惯换人解恐惧 - 留陷阱图腾对审判",
    CALL_BURST_BLOCK_INCOMING = "对方可能冰块 - 暂停爆发",

    -- M10 #69: pattern recognition callouts
    CALL_PATTERN_RMP_CHEAP_BLIND     = "肾击+致盲连击 - 剥离并使用饰品",
    CALL_PATTERN_SHATTER_NOVA_SHEEP  = "冰法连击 - 解冰环",
    CALL_PATTERN_FEAR_INTO_POLY      = "恐惧+羊群组合即将到来 - 准备解控",
    CALL_PATTERN_HUNTER_TRAP_SCATTER = "陷阱+驱散连击 - 准备群驱散",
    CALL_PATTERN_HOJ_INTO_INTERCEPT  = "审判+截击叠加目标 - 切防御",

    -- Debug
    DEBUG_PREFIX         = "[ACC]",
    DEBUG_ENABLED        = "调试开启",
    DEBUG_DISABLED       = "调试关闭",
    DEBUG_RESET_DONE     = "存档已重置，/reload 生效",
    DEBUG_STRAT_SET      = "策略激进度设置为：%s",
    DEBUG_UNKNOWN_CMD    = "未知命令，请输入 /acc help",

    -- Test mode comps
    TEST_HEADER          = "运行测试阵容：",
    TEST_COMP_LABEL      = "阵容 #%d：%s",
}
