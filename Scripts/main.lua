-- GBVSR-LobbyFPSUnlocker
-- GOAL: 大厅(Lobby)被锁 30 帧,其余场景 60 帧。进入大厅时把帧数设为目标值,其余场景不动。
--
-- 已实测确认的机制:
--   所有场景都用 bUseFixedFrameRate=true + FixedFrameRate=N 的固定时间步。
--   大厅 N=30,战斗 N=60。t.MaxFPS 无效(走固定时间步路径)。
--
-- 策略(最稳健,无需 map 名检测):
--   * 保留 bUseFixedFrameRate=true 不动(关掉会破坏战斗场景游戏速度)。
--   * 仅当 FixedFrameRate 落在"被锁定的原始大厅帧数"附近(默认 30±5)时,
--     把 FixedFrameRate 改成用户配置的目标值(默认 60)。
--   * 战斗场景是 60(不在触发区间)→ 不改 → 不影响。
--   * 离开大厅时游戏自己会写回 60,无需我们恢复。
--   * 不依赖 LoadMap/InitGameState 钩子(本作大厅不触发),也不依赖 GetFullName(可能拿不到)。
--
-- 外部配置: mod 目录下 config.txt
--   target_fps=60        大厅目标帧数
--   trigger_fps=30       触发阈值:FixedFrameRate 在此±5 范围内才干预
--   watchdog_ms=250      看门狗周期(毫秒)
--   log_apply=true       每次实际写入都打日志
--
-- 控制台命令(F10):
--   lobbyfps            打印当前状态
--   lobbyfps force      无视阈值,强制把 FixedFrameRate 设成目标值
--   lobbyfps restore    关闭强制
--   lobbyfps reload     重新读取 config.txt
--   lobbyfps list       打印 Engine 字段当前值

local MOD_TAG = "[GBVSR-LobbyFPSUnlocker]"
local function logf(fmt, ...) print(MOD_TAG .. " " .. string.format(fmt, ...)) end

------------------------------------------------------------------
-- 配置
------------------------------------------------------------------
-- UE4SS 的 working directory 是 <Game>/Binaries/Win64,故用相对路径即可,无需硬编码安装路径。
local CONFIG_PATH = "Mods/GBVSR-LobbyFPSUnlocker/config.txt"

local Config = {
    target_fps = 60,
    trigger_fps = 30,
    trigger_tolerance = 5,
    watchdog_ms = 250,
    log_apply = true,
}

local function loadConfig()
    local f = io.open(CONFIG_PATH, "r")
    if not f then
        logf("config.txt 不存在,使用默认配置")
        return
    end
    local line = f:read("*l")
    while line do
        local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if key and value and #value > 0 and not line:match("^%s*;") and not line:match("^%s*#") then
            value = value:gsub("^%s+", ""):gsub("%s+$", "")
            if key == "target_fps" then
                local n = tonumber(value)
                if n and n > 0 then Config.target_fps = n end
            elseif key == "trigger_fps" then
                local n = tonumber(value)
                if n and n > 0 then Config.trigger_fps = n end
            elseif key == "trigger_tolerance" then
                local n = tonumber(value)
                if n and n >= 0 then Config.trigger_tolerance = n end
            elseif key == "watchdog_ms" then
                local n = tonumber(value)
                if n and n > 0 then Config.watchdog_ms = n end
            elseif key == "log_apply" then
                value = value:lower()
                Config.log_apply = (value == "true" or value == "1" or value == "yes")
            end
        end
        line = f:read("*l")
    end
    f:close()
    logf("config: target_fps=%d trigger_fps=%d±%d watchdog_ms=%d",
        Config.target_fps, Config.trigger_fps, Config.trigger_tolerance, Config.watchdog_ms)
end
loadConfig()

------------------------------------------------------------------
-- 工具
------------------------------------------------------------------
local function getBool(o, name)
    local ok, v = pcall(function() return o[name] end)
    if ok and type(v) == "boolean" then return v end
    return nil
end
local function getNum(o, name)
    local ok, v = pcall(function() return o[name] end)
    if ok and type(v) == "number" then return v end
    return nil
end
local function setNum(o, name, v) return pcall(function() o[name] = v end) end

local function getEngine()
    local ok, eng = pcall(function() return FindFirstOf("Engine") end)
    if ok and eng and eng:IsValid() then return eng end
    return nil
end

------------------------------------------------------------------
-- 状态
------------------------------------------------------------------
local ForceUnlock = false
local LastLogged = nil

------------------------------------------------------------------
-- 判定:当前是否需要把 FixedFrameRate 改成 target_fps
------------------------------------------------------------------
local function shouldApply(fixedRate)
    if ForceUnlock then return true end
    if not fixedRate then return false end
    local diff = math.abs(fixedRate - Config.trigger_fps)
    return diff <= Config.trigger_tolerance
end

------------------------------------------------------------------
-- 动作
------------------------------------------------------------------
local function applyIfNeeded(reasonTag)
    local eng = getEngine()
    if not eng then return false end
    local cur = getNum(eng, "FixedFrameRate")
    if not cur then return false end
    if not shouldApply(cur) then return false end
    if cur == Config.target_fps then return false end -- 已是目标值
    local ok = setNum(eng, "FixedFrameRate", Config.target_fps)
    if not ok then
        if LastLogged ~= "fail" then
            logf("[%s] 写 FixedFrameRate=%s 失败", reasonTag or "?", tostring(Config.target_fps))
            LastLogged = "fail"
        end
        return false
    end
    logf("[%s] FixedFrameRate %.1f -> %d", reasonTag or "?", cur, Config.target_fps)
    LastLogged = "ok"
    return true
end

------------------------------------------------------------------
-- 看门狗
------------------------------------------------------------------
local function watchdogTick()
    applyIfNeeded("watchdog")
    return false
end
LoopAsync(Config.watchdog_ms, watchdogTick)
logf("watchdog 已启动 (周期 %dms)。触发条件: |FixedFrameRate-%d|<=%d -> 改成 %d",
     Config.watchdog_ms, Config.trigger_fps, Config.trigger_tolerance, Config.target_fps)

------------------------------------------------------------------
-- LoadMap 钩子(能触发就当即时响应)
------------------------------------------------------------------
RegisterLoadMapPostHook(function(Engine, World)
    local eng = Engine and Engine:IsValid() and Engine or getEngine()
    if eng then
        applyIfNeeded("PostLoadMap")
    end
end)

------------------------------------------------------------------
-- 控制台命令
------------------------------------------------------------------
RegisterConsoleCommandHandler("lobbyfps", function(FullCommand, Parameters, Ar)
    local sub = Parameters and Parameters[1] and tostring(Parameters[1]):lower() or ""
    if sub == "" or sub == "status" then
        local eng = getEngine()
        local cur = eng and getNum(eng, "FixedFrameRate") or nil
        logf("status: force=%s | FixedFrameRate=%s", tostring(ForceUnlock), tostring(cur))
        logf("  触发: |FixedFrameRate-%d|<=%d -> 设成 %d",
            Config.trigger_fps, Config.trigger_tolerance, Config.target_fps)
    elseif sub == "force" then
        ForceUnlock = true
        logf("已强制(无视阈值,target=%d)", Config.target_fps)
    elseif sub == "restore" then
        ForceUnlock = false
        logf("已关闭强制")
    elseif sub == "reload" then
        loadConfig()
    elseif sub == "list" then
        local eng = getEngine()
        if not eng then logf("Engine 不可用"); return true end
        logf("Engine:")
        logf("  bUseFixedFrameRate = %s", tostring(getBool(eng, "bUseFixedFrameRate")))
        logf("  FixedFrameRate     = %s", tostring(getNum(eng, "FixedFrameRate")))
    else
        logf("用法: lobbyfps [status|force|restore|reload|list]")
    end
    return true
end)

logf("loaded。target_fps=%d, trigger: FixedFrameRate in [%d,%d]。",
     Config.target_fps, Config.trigger_fps - Config.trigger_tolerance, Config.trigger_fps + Config.trigger_tolerance)