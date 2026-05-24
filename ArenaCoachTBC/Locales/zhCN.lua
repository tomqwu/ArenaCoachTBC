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
    HELP_TEST     = "/acc test             - 跑测试敌方阵容",
    HELP_DEBUG    = "/acc debug            - 切换调试日志",
    HELP_RESET    = "/acc reset            - 重置存档变量",
    HELP_STRAT    = "/acc strategy safe|balanced|greedy - 设定策略激进度",
    HELP_ENEMY    = "/acc enemy <c1> ... <c5> - 模拟敌方阵容",
    HELP_SELFTEST = "/acc selftest [verbose] - 客户端内自检",
    HELP_SIMULATE = "/acc simulate [key|stop] - 回放脚本化场景",
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

    -- UI labels
    UI_TITLE             = "竞技场教练",
    UI_NO_ARENA          = "未在竞技场",
    UI_FRIENDLY_CDS      = "己方冷却",
    UI_ENEMY_CDS         = "敌方冷却",

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
