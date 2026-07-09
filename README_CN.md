# GBVSR-LobbyFPSUnlocker 中文说明

> 基于 [UE4SS](https://docs.ue4ss.com) 的《碧蓝幻想 Versus:Rising》(Steam 版,UE 4.27)大厅帧率解锁 mod。

## 作用

GBVSR 中**大厅被锁 30 帧**,其余场景(战斗、菜单等)60 帧。本 mod 把大厅帧率解锁到与游戏其他场景一致。

游戏通过固定时间步机制锁帧(`UEngine::bUseFixedFrameRate = true` + `UEngine::FixedFrameRate`)。大厅值为 30,战斗为 60。`t.MaxFPS` 与平滑帧率范围不起作用(走的是固定时间步路径),因此本 mod 直接针对该机制。

## 工作原理

保留 `bUseFixedFrameRate = true`(关掉会破坏其他场景的游戏速度),只改 `FixedFrameRate` 的值:

- 大厅设 `FixedFrameRate = 30` → mod 检测到,改成你配置的目标值(默认 60)。
- 战斗设 `FixedFrameRate = 60` → 不在触发区间 → **mod 不动**。
- 离开大厅时游戏自己会写回 60,无需 mod 恢复。

检测方式是**纯阈值**:只有当 `FixedFrameRate` 处在 `[25, 35]`(大厅原始值 30±5)区间内时才会修改。这样:

- 无需 map 名检测(本作大厅的 `LoadMap`/`InitGameState` 钩子不稳定触发)。
- 不使用会刷屏写 C++ 错误日志的 `GetName()`。
- 不干扰战斗场景。

整体由 `LoopAsync` 看门狗(`250ms` 周期,可配置)轮询驱动,并附加 `PostLoadMap` 钩子作为能触发时的即时响应。

## 环境要求

- **UE4SS**(推荐 v3.0.0 以上;在 v3.0.1 Beta,commit `e39e9c8` 上测试通过)。
  如果你能在 `RED\Binaries\Win64\` 看到 `UE4SS.dll`,就说明已装好。
- 启用 **ConsoleEnablerMod**(随 UE4SS 附带),用于 `lobbyfps` 控制台命令。
  mod 本身不依赖它也能跑,但用控制台调帧/排错就需要它。

本仓库的最新发布里提供一个**自带 UE4SS 整合包**(见 [Releases](https://github.com/Butterfly0v0/GBVSR-LobbyFPSUnlocker/releases))。
如果你从未安装过 UE4SS,只需下载这一个压缩包即可。

## 安装

### 方式 A — 自带 UE4SS 的整合包(尚未安装 UE4SS 的新用户)

1. 从 [Releases 页面](https://github.com/Butterfly0v0/GBVSR-LobbyFPSUnlocker/releases)
   下载最新的 `GBVSR-LobbyFPSUnlocker-vX.Y.Z.zip`。包内已含 UE4SS v3.0.1 Beta(commit `e39e9c8`)+ 本 mod。
2. 找到游戏安装目录,通常为
   `C:\Program Files (x86)\Steam\steamapps\common\Granblue Fantasy Versus Rising`
   (Steam 里右键游戏 → 管理 → 浏览本地文件)。
3. 打开其中的 `RED\Binaries\Win64\` 子目录。
4. 把压缩包里的**所有文件**解压到该 `Win64` 目录下。解压后应能看到如下新增内容:
   ```
   Win64\
       dwmapi.dll                (UE4SS 代理 DLL,游戏自动加载)
       UE4SS.dll                 (UE4SS 主加载器)
       patternsleuth_bind.dll    (UE4SS 依赖)
       UE4SS-settings.ini        (UE4SS 设置;此版本默认不自动弹出调试窗口)
       READ-THIS-FIRST.md        (安装说明,内容与本节一致)
       Changelog.md              (UE4SS 更新日志)
       UE4SS-README.md           (UE4SS 自带 README,改名以避免冲突)
       cache\  liveview\  watches\
       Mods\
           mods.txt
           GBVSR-LobbyFPSUnlocker\   <-- 本 mod
           ConsoleEnablerMod\        <-- 启用 F10 控制台
           ... 其它标准 UE4SS 示例 mod
   ```
5. 启动游戏,进入大厅即自动生效。

### 方式 B — 你已安装 UE4SS

1. 下载整合包(只用其中的 mod 文件夹)**或**直接克隆本仓库 / 单独取 `GBVSR-LobbyFPSUnlocker` 文件夹。
2. 把 mod 文件夹复制到 UE4SS 的 mods 目录:
   ```
   <GBVSR 安装目录>\RED\Binaries\Win64\Mods\GBVSR-LobbyFPSUnlocker\
       enabled.txt
       config.txt
       Scripts\main.lua
   ```
3. 如果你的 `Mods\mods.txt` 存在,追加一行(顺序无关):
   ```
   GBVSR-LobbyFPSUnlocker : 1
   ```
4. 如果你的 UE4SS 使用每 mod 一个 `enabled.txt` 文件(本 mod 文件夹内已包含),mod 会自动启动,无需额外操作。

使用方式 B **无需**覆盖你现有的 `UE4SS.dll`、`dwmapi.dll`、`UE4SS-settings.ini`。

## 配置

所有设置都在 mod 目录下的 `config.txt`。修改后重启游戏,或在控制台输入 `lobbyfps reload` 热加载。

| 键                  | 默认值 | 说明                                                              |
| ------------------- | ------ | ----------------------------------------------------------------- |
| `target_fps`        | `60`   | 大厅将设置到的帧率,如 `60` / `120` / `144` / `240`。             |
| `trigger_fps`       | `30`   | 仅当 `FixedFrameRate` 等于该值(大厅原始值)时才干预。           |
| `trigger_tolerance` | `5`    | 触发容差,实际触发区间为 `[trigger_fps - tol, trigger_fps + tol]`。 |
| `watchdog_ms`       | `250`  | 看门狗周期(毫秒),周期越短响应越快但 CPU 开销略增。              |
| `log_apply`        | `true` | 每次真正写入都打一行日志。                                        |

### 示例

```ini
; 默认: 大厅 -> 60 帧
target_fps=60

; 高刷显示器: 大厅 -> 144 帧
target_fps=144
```

## 控制台命令(需 ConsoleEnablerMod,F10 呼出)

| 命令               | 说明                                                                |
| ------------------ | ------------------------------------------------------------------- |
| `lobbyfps`         | 打印当前状态(当前 `FixedFrameRate`、强制标志)。                    |
| `lobbyfps force`   | 无视阈值检测,强制写 `target_fps` 到 `FixedFrameRate`。仅用于验证/测试。 |
| `lobbyfps restore` | 关闭强制,恢复阈值检测逻辑。                                        |
| `lobbyfps reload`  | 不重启游戏,重新读取 `config.txt`。                                 |
| `lobbyfps list`    | 打印 `Engine.bUseFixedFrameRate` 与 `Engine.FixedFrameRate`。       |

## 如何确认生效

1. 启动游戏,进入大厅。
2. 大厅应运行在你的 `target_fps`(默认 60)。
3. F10 控制台输入 `lobbyfps list`,确认:
   ```
   Engine:
     bUseFixedFrameRate = true
     FixedFrameRate = 60.0
   ```
4. 进入战斗,仍应为 60 帧。
5. 回大厅,游戏会再次将 `FixedFrameRate` 设为 30,看门狗在下个周期内改回目标值。

## 目录结构

```
GBVSR-LobbyFPSUnlocker/
├── enabled.txt          # 空标记文件,UE4SS 据此加载本 mod
├── config.txt           # 用户可编辑的设置(见"配置")
└── Scripts/
    └── main.lua         # mod 逻辑
```

## 故障排除

**mod 没生效。**
- F10 控制台输入 `lobbyfps list`。如果没有任何输出,说明 mod 没加载 → 看 `RED\Binaries\Win64\UE4SS.log`,确认 mod 文件夹里有 `enabled.txt`(空文件即可),以及 `Mods\mods.txt` 里有 `GBVSR-LobbyFPSUnlocker : 1`。
- 如果 `lobbyfps list` 有输出但 `FixedFrameRate` 没变,检查 `config.txt` 中 `trigger_fps`/`trigger_tolerance` 是否覆盖大厅值(默认 `30 ± 5 = [25, 35]`,对默认游戏是对的)。

**战斗里游戏速度异常。**
- 本 mod 只在 `FixedFrameRate` 处于 `[25, 35]`(默认)区间内写入,不会碰战斗。如果你误把 `trigger_fps` 配置成接近 60 的值,恢复默认后运行 `lobbyfps reload`。

**想锁非标准帧率(比如 90)。**
- 改 `config.txt` 里 `target_fps=90`,运行 `lobbyfps reload` 即可。

**`UE4SS.log` 大量报错。**
- 确认不是其他 mod(比如旧版 FrameRateDiag)在刷屏。本 mod 不调用 `GetName()`,也不产生错误日志。

## 限制说明

- 配置文件用相对路径 `Mods/GBVSR-LobbyFPSUnlocker/config.txt`,依赖 UE4SS 把工作目录设为游戏的 `Binaries\Win64`(默认行为)。如果你大量自定义过 `UE4SS-settings.ini` 路径,可改 `main.lua` 顶部的 `CONFIG_PATH`。
- 本 mod 仅读写 `UEngine::FixedFrameRate`(以及只读 `bUseFixedFrameRate` 用于显示)。永不关闭固定时间步,不操作平滑帧率 cvar,不修改 `GameUserSettings`。
- 未经联网验证。这是单机/视觉 mod;只影响大厅速度(无对战要素)而不影响比赛结果。在线使用请自行斟酌。

## 许可证

[MIT](LICENSE)。源代码与配置按原样提供。

## 致谢

- [UE4SS](https://docs.ue4ss.com) — 本 mod 所运行的框架。
- 早期诊断版本 FrameRateDiag 帮助确立了"本作中 `t.MaxFPS` 无效、`bUseFixedFrameRate` 才是实际机制"这一关键事实。