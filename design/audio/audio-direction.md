# 音频方向文档 ·《轨迹残响》垂直切片

> 作者：阮和鸣（audio-director）｜任务 AUD-DIR-01｜阶段：Sprint 3 并行（P2，不阻塞主线）
> 依据正本：`design/concept/game-concept.md`（三大支柱）、`design/gdd/battle-system-gdd.md`（§3.3 三步呈现 / §3.5 结算 / §4.8 战场即场景）、`design/gdd/map-exploration-gdd.md`（§3.1 五图分区 / §3.3 `play_sfx`）、`design/art-bible/art-direction-skeleton.md`（五色板 + 统一性守则）、`docs/architecture/godot4-architecture-adr.md`（A2 目录 / A3 Autoload 边界 / A7 动作白名单）、`design/art-bible/credits-template.md` + `assets/LICENSE-ASSETS.md`（许可账本）
> 状态：初稿，3 个决策点待用户拍板（见 §8）
> 配套文件：`design/audio/sfx-event-list.md`（SFX 事件清单总表 + E3-S5 专项，可直接交程基岩）

---

## 0. 使用方式与范围裁决

### 0.1 先说清一个前提：本文档不是"作曲委托"，是"选材 + 验收标准"

切片走零采购开源路线，没有作曲预算，也**没有作曲人力**（用户是前端工程师，每周 5-10h）。因此本文档的"音乐方向"有两个用途，请区别对待：

| 用途 | 适用章节 | 现在用得上吗 |
|---|---|---|
| ① 现成素材的**筛选与验收标准** | §1.3 音色定调、§2.4 选材 checklist、§5 音源候选 | ✅ 立刻可用 |
| ② 若未来自己作曲/改编时的**创作简报** | §1.5 残响动机、§2.1 编制/调式/BPM | ⏸ P2 远期，先存档 |

**我不建议切片内自作曲。** 用现成 CC0/CC-BY 素材做"选材 + 派生变体"（§2.3）是唯一符合产能口径的路径。

### 0.2 范围分层

- **P0** = 30 分钟切片必须有，缺了会明显掉档次
- **P1** = 有则更好，Sprint 时间不够可整体后移
- **P2** = 远期项（完整版），切片内不做，写出来是为了防止以后忘记或重复讨论

### 0.3 纪律边界（本任务已遵守）

- [x] 只产出方向文档，**未下载、未复制、未修改任何音频文件**
- [x] 未 git commit
- [x] 所有推荐音源标注许可；许可未核实的明确标"待核实"
- [x] CC-BY-SA / GPL-only 资产一律不列入候选

---

## 1. 音频身份：从三大支柱推导

### 1.1 听觉定位（一句话）

**SNES 晚期的 16-bit JRPG 声音——有限波形、有限同时发音数、温暖而非华丽；打击反馈清脆且信息量足，音乐负责"这是一段旅程"而不是"这是一场史诗"。**

### 1.2 支柱 → 听觉的推导

| 支柱 | 玩法事实 | 听觉必须做到 | 听觉禁止 |
|---|---|---|---|
| **一 · 战术回合制**（每场战斗都是一道小谜题） | 速度队列可见、三系克制可验证、击退 | 战斗 BGM 是**中板、有驱动力但不催促**的——玩家在思考，不是在逃命；命中音必须能**听出属性**（火/冰/雷音色可辨 = 弱点的第二反馈通道） | 不要高速双踩鼓/不要 EDM 式 build-up（会逼玩家快点点完） |
| **二 · 角色驱动叙事**（怀旧温情） | 30 分钟全靠对话框 + 头像，无过场 | 小镇音乐**温暖、有人味、克制**；UI 音**软**，不打断阅读节奏 | 不要煽情弦乐/不要电影感 swell（撑不起 16-bit 画面，且抢对话的戏） |
| **三 · 小而密的探索**（每 30 秒一次发现） | 宝箱 / 调查点 / 隐藏小路 | 探索交互音要有"叮"的**小奖励感**（宝箱、拾取）；遗迹音乐**收敛好奇心**而非恐怖 | 不要环境恐怖音效（不是恐怖游戏）；不要每步都响的脚步音（30 分钟会烦） |

### 1.3 ★ 与美术同频：分辨率对齐原则（本文档最重要的定调）

美术守则已定 16x16 tile、2.5 头身、单一素材家族。**音频必须遵守同一条纪律：声音的"分辨率"要匹配画面的"分辨率"。**

> **原则**：像素画 = 有限色板 + 有限像素 → 音频 = **有限波形 + 有限同时发音数 + 无真实录音乐器**。

具体禁令（写在验收 checklist 里）：
- ❌ 真实录制的钢琴 / 弦乐 / 交响（这些是"高清"音色，配 16-bit 像素会像给像素画贴了张照片）
- ❌ 现代 EDM 音色（supersaw、modern drum kit、侧链泵音）
- ❌ 电影 trailer 式的 riser / braam / 大混响空间
- ✅ 方波 / 三角波 / 脉冲 / 噪声 / 简单 FM（= SNES 的 PCM + FM 合成语汇）
- ✅ 编曲上接受" loops 感"（SNES 游戏本来就是短 loop，这与切片体量天然契合）

**这条原则是后续所有音色选择的唯一裁判。** 找到的素材若违反它，宁可不用。

### 1.4 声音调色板（Sound Palette）—— 与美术五色板 1:1 对齐

美术已有五色板（art-direction-skeleton §二.3）。音频建同构的五族音色，**同一个"颜色"在视听上表达同一种情绪**：

| 音色族 | 合成语汇 | 对应美术色 | 用途 |
|---|---|---|---|
| **暖木 / 日常 Warm** | 三角波 + 软 attack，中低频，无打击感 | 羊皮纸 `#E8DCC0` | 小镇 UI、对话推进、脚步、开门、宝箱开启 |
| **冲击 / 强调 Impact** | 噪声爆 + 短 decay 方波 | 赤陶红 `#A6423A` | 受击、遇敌转场、UI 确认 / 错误 |
| **金属 / 成就 Metal** | FM 金属 + 三角波泛音 | 徽章金 `#D9A94E` | 物理攻击、升级、稀有拾取、胜利 fanfare |
| **水晶 / 元素 Crystal** | 高频正弦 + 极快 attack（<5ms） | 橄榄绿 `#6B8E4E`（借用为"自然 / 元素"） | 火 / 冰 / 雷法术、治疗、净化 |
| **低频 / 压迫 Drone** | 低通锯齿 + 长 release | 夜色紫灰 `#4A3B52` | 遗迹、Boss、蓄力 telegraph、失败 |

**三系元素音色（支柱一的核心，必须可辨）**：

| 系 | 音色规格 | decay | 备注 |
|---|---|---|---|
| 火 | 低频 whoomp（80–150 Hz 骤降）+ 中频噪声爆裂 | 0.35 s | 暖、有体积感 |
| 冰 | 高频起音（2–4 kHz）+ 玻璃碎裂式多点瞬态 | 0.50 s | 唯一允许"亮到刺耳"的音；带短 delay |
| 雷 | 白噪 zap + 快速 pitch sweep down，attack < 5 ms | 0.25 s | 最硬、最短、最干脆 |

> 玩家要能**闭眼听出**这一发是火还是雷。这是弱点的第二反馈通道（第一是浮动数字颜色）。

### 1.5 ★ "残响"签名（Leitmotif / 听觉签名）

游戏叫《轨迹残响》。把"残响"做成**听觉签名**，是零成本且高度贴合品牌的一步：

**动机（P2 远期，供自作曲/改编用）**：`D → G → F`（上行纯四度 + 下行大二度），时值 1:1:2。
- 小镇曲：三角波/长笛音色柔奏；战斗曲：断奏失真方波；Boss 曲：低八度作 bass riff；失败时 F 不落回，改为 pitch bend 下行（"残响中断"）。

**立即可行的轻量版（P0，推荐现在就做）**：不追求旋律动机，改为——
> **只给三个关键情绪事件加 delay / echo 尾音**：弱点命中、弱点发现、胜利 fanfare、失败音。

理由：现成素材之间不可能有共同动机，但**共同的后期处理**可以立刻让它们听起来属于同一款游戏；而"残响"只出现在情绪峰值点，比全局加效果更克制、更精准。

**实现成本**：Godot 里加一条 `Echo` 总线挂 `AudioEffectDelay`，这 4 个事件改走这条总线（见 §6.1）。零素材成本。

---

## 2. 音乐方向

### 2.1 基调规格

> 双用途声明：作为**选材标准**时，只取"音色族 / BPM / 情绪"三条硬指标；作为**远期创作简报**时才看编制与调式。

| 项 | 规格 |
|---|---|
| 编制（远期简报） | 主旋律 = 脉冲/方波 lead；和声 = 三角波 pad + 拨弦 arpeggio；低音 = 三角/锯齿 bass；打击 = 压缩感强的简易鼓组（SNES 风，非现代 drum kit） |
| 调式（远期简报） | 小镇 / 道路：大调或 Lydian（#4 给"旅行感"）；遗迹：自然小调或 Dorian（神秘但不邪恶）；Boss：小调 + 半音和声 |
| BPM 区间 | 小镇 92–104｜道路 100–112｜遗迹 84–96｜普通战斗 108–124｜Boss 132–148 |
| 混响 | 统一**短**混响（0.8–1.5 s）。禁止大厅混响——16-bit 时代是 delay 不是 reverb |
| 单曲峰值 | ≤ −1 dBFS；RMS −18 ~ −14 dBFS（素材来源不一，入库统一归一化） |

### 2.2 分区音乐清单（切片最小集 = 4 首正本 + 3 首派生）

| # | 分区 | track_id | 覆盖场景 | 情绪目标 | 循环长度 | 优先级 | 候选来源 |
|---|---|---|---|---|---|---|---|
| 1 | **战斗** | `bgm_battle` | B1–B4 四场普通战斗 | 专注 + 轻度紧迫——"这是一道要解的题"，不是"血战" | 60–90 s | **P0** | Juhani Junkala《5 Chiptunes (Action)》CC0 |
| 2 | **小镇** | `bgm_town` | 小镇 + 2 内嵌室内 + 主菜单 | 温暖、日常、有人味；不煽情 | 90–150 s | **P0** | CodeManu《8-bit Music Pack》CC-BY 3.0（取最慢/最少打击的一轨） |
| 3 | **遗迹** | `bgm_ruin` | f1 + f2（f2 走派生变体） | 神秘 + 收敛的好奇；**不恐怖** | 90–120 s | **P0** | 同上 / 《5 Chiptunes》最慢的一轨 |
| 4 | **BOSS** | `bgm_boss` | B5 遗迹核心 | 压轴 + 蓄力 telegraph 的紧张；**全切片唯一允许"燃"的地方** | 60–90 s | **P0** | Juhani Junkala《5 Chiptunes (Action)》最激烈的一轨 |
| 5 | 道路 | `bgm_road` | 道路 | 同小镇但推进感更强 | 派生 | P1 | `bgm_town` 派生（Change Speed +8%） |
| 6 | 遗迹深处 | `bgm_ruin_deep` | f3 Boss 前厅 | 压抑、留白、为 Boss 铺垫 | 派生 | P1 | `bgm_ruin` 派生（lowpass 2 kHz + 降速 4%） |
| 7 | 事件 | `bgm_event` | 剧情关键节点 / 结尾钩子 | 收束 + 未解之谜 | 派生 | P1 | `bgm_town` 派生（取最安静的 30–60 s 段落循环） |

**★ 关键结论：7 个分区槽位，实际只需找到 4 首素材。** 另外 3 首由 Audacity 派生（§2.3），零新增素材、零新增许可条目。这是"体量克制"的落地手法。

**选材优先顺序**（按切片内累计播放时长 × 情绪权重）：
1. `bgm_battle` — 5 场战斗 × 2–5 分钟，累计播放最长
2. `bgm_town` — 开场第一耳 + 反复回城，第一印象
3. `bgm_ruin` — 遗迹三层占流程中段
4. `bgm_boss` — 压轴但只播一次
5. 三个派生变体（Audacity，各 15–20 分钟）

> **排期提醒（给主理人）**：**SFX 先于 BGM。** E3-S5 在 Sprint 3 第 2 周就要用打击反馈音效；BGM 可以整体延到 Sprint 4–5 打磨期，不阻塞 M3。BGM 甚至可以在 M3 收口后、打包试玩视频前才补。

### 2.3 派生变体策略（省素材的关键手法，Audacity 15–20 min/首）

| 手法 | 操作 | 用于 |
|---|---|---|
| 降速 + 降调 | Effect → Change Speed（−4%，同时改音高） | `bgm_ruin_deep`：更沉、更压抑 |
| Lowpass | Effect → Low-Pass Filter @ 2 kHz | `bgm_ruin_deep` / `bgm_ruin`（f2 版）："在地下、隔了一层"的听感 |
| 提速 | Change Speed（+8%） | `bgm_road`：推进感 |
| 挑段落循环 | 取原曲最安静的 30–60 s 做无缝循环 | `bgm_event` |

> ⚠️ **诚实标注**：Audacity **做不了音源分离**。上表"去鼓""只留旋律"的真实做法是**挑段落**，不是分离音轨。若某首曲子没有合适的无鼓段落，就退回到 lowpass + 降速方案，不要幻想能干净地去掉鼓。

### 2.4 选材验收 checklist（每首曲子入库前逐条勾）

- [ ] **无缝循环**：loop 点无咔哒；OGG 必须设 `loop_offset`（见 §6.6）
- [ ] **时长 ≥ 60 s**：短于 60 s 的 loop 在 5 分钟战斗里必听腻
- [ ] **音色符合 §1.3 分辨率对齐原则**：曲内无真实管弦 / 录音钢琴 / 现代 EDM 音色
- [ ] **无人声 / 无歌词**（OGA 部分曲目有人声）
- [ ] **许可核对**：以页面 **License 栏原文**为准（不是描述正文里的自称）
- [ ] **响度归一**：峰值 ≤ −1 dBFS，RMS −18 ~ −14 dBFS

### 2.5 远期项（完整版，切片内不做）

- 独立室内曲（客栈 / 民宅各一）、标题画面曲、菜单曲
- 队员聊天专属曲、支线专属曲
- 动态分层混音（战斗血量阈值触发乐器层增减）——需要 stems，远超开源素材能力
- FamiStudio 自作曲（零许可风险，但学习成本远超切片预算）

---

## 3. SFX 事件清单

→ 见配套文件 **`design/audio/sfx-event-list.md`**（含命名约定、四组事件总表、E3-S5 专项规格、实装接线清单）。

摘要：**P0 = 16 条事件**（其中 `ui_error` 可由 `ui_cancel` 派生 → 实际需入库素材 15 条）；P1 = 10 条；P2 = 4 条。

---

## 4. E3-S5 打击反馈专项

→ 见 **`design/audio/sfx-event-list.md` §3**（遇敌转场 / 受击 / 克制命中 / 弱点发现 / 胜利 / 失败六类，含逐条时序、时长上限、音色规格、与视觉的对齐点、降级方案，可直接交程基岩实装）。

---

## 5. 音源候选与许可账本

### 5.1 已核实（可直接取用）

| 条目 | 作者 | 来源 URL | 许可 | 用途 |
|---|---|---|---|---|
| **512 Sound Effects (8-bit style)** | Juhani Junkala (SubspaceAudio) | `opengameart.org/content/512-sound-effects-8-bit-style` | **CC0 1.0** | ★ **主 SFX 池**。分类齐全（Simple Damage / Powerup / Fanfare / Menu / Explosions / Weapons / Movement），与 16-bit 定调原生匹配 |
| **5 Chiptunes (Action)** | Juhani Junkala (SubspaceAudio) | `opengameart.org/content/5-chiptunes-action` | **CC0 1.0** | ★ **BGM 首选**。5 轨、全部无缝循环；OGA 标签含 `RPG::Music` / `RPG::Music::Battle`。原始分发为 WAV，需转 OGG |
| **8-bit Music Pack (Loopable)** | CodeManu | `opengameart.org/content/8-bit-music-pack-loopable` | **CC-BY 3.0** | ★ BGM 次选 / 小镇与遗迹首选。6 轨（bgm_action_1–5 + bgm_menu），NES 风偏暖。原始为 MP3，需转 OGG |
| Interface Sounds (100) | Kenney | `kenney.nl/assets/interface-sounds` | **CC0** | `ui_cursor` / `ui_confirm` / `ui_cancel` |
| UI Audio (50) | Kenney | `kenney.nl/assets/ui-audio` | **CC0** | UI 音补充池 |
| Impact Sounds (130) | Kenney | `kenney.nl/assets/impact-sounds` | **CC0** | `btl_hit_*` / 遇敌转场 B 层底料 |
| RPG Audio (50) | Kenney | `kenney.nl/assets/rpg-audio` | **CC0** | `map_chest_open` / `btl_heal` / fanfare 底料 |
| Digital Audio (60) | Kenney | `kenney.nl/assets/digital-audio` | **CC0** | 元素音改造底料 |
| Music Jingles | Kenney | `kenney.nl/assets/music-jingles` | **CC0** | `btl_victory` / `btl_defeat` fanfare 底料 |

> Kenney 全站资产均为 CC0（含全部音频包），无署名义务（自愿致谢即可）。
> **注意**：Kenney 的 logo 不可用于本项目，音效文件与许可本身无此限制。

### 5.2 待核实（取用前必须核对 OGA 页面 License 栏原文）

| 条目 | 作者 | 来源 URL | 许可 | 用途 |
|---|---|---|---|---|
| RPG Sound Pack | artisticdude | `opengameart.org/content/rpg-sound-pack` | **待核实** | 剑击 / 脚步补充（若 Kenney + Juhani 不够用） |
| Fantozzi's Footsteps | Fantozzi（qubodup 提交） | `opengameart.org/content/fantozzis-footsteps-grasssand-stone` | **待核实** | `map_footstep` 地表变体 |
| Battle Theme A | （多作者条目） | `opengameart.org/content/battle-theme-a` | **待核实** | Boss 曲备选 |

> 这三条例入候选但**未核实**——按先登记后入库纪律，取用前必须由林绘澄或我核对页面 License 栏并截图留证。

### 5.3 禁用清单（许可红线，与 credits-template §一 一致）

| 禁用 | 原因 |
|---|---|
| ❌ **CC-BY-SA（任何版本）** | 会污染整包分发许可，项目红线 |
| ❌ **GPL / LGPL-only 音频** | OGA 接受 GPL 投稿，音乐区尤其多；会与分发冲突 |
| ❌ **Freesound 的 Sampling+** | 非 CC 许可，自带再分发限制，不是"免费=随便用" |
| ❌ **CC-BY-NC / CC-BY-ND 一切** | NC 禁止商用、ND 禁止修改（我们要做响度归一与降速，ND 直接不可用） |
| ⚠️ **SubspaceAudio 的 itch.io 付费包** | 该作者在 OGA 页面导流到 itch.io 的 "400 Indie Game Music Loops" / "1000 Retro Sound Effects" / "6000 Retro Sound Effects" **均为付费包**，违反本项目零采购纪律 → **只取 OGA 上标注 CC0 的免费条目** |

### 5.4 自制兜底路线（★ 零许可风险，强烈建议用于关键音）

| 工具 | 说明 | 许可 |
|---|---|---|
| **bfxr**（`bfxr.net`） | 8-bit 音效生成器，含 triangle / breaker / pink noise 波形，导出 WAV | 输出归你自己，**不产生任何许可义务，不进 CREDITS** |
| **jsfxr**（`sfxr.me`） | 无需账号的在线版 sfxr，Coin/Laser/Explosion/Jump/Hit 预设一键出变体 | 同上 |
| **ChipTone**（`sfbgames.itch.io/chiptone`） | 波形与滤波器控制更强，适合 power-up / hit / UI | 同上（CC0） |
| **Audacity** | 裁剪 / 响度归一 / Change Speed / Low-Pass | 免费开源 |

**建议**：`ui_*`、`btl_hit_*`、`btl_weak_hit`、`btl_weak_reveal` 这几类**短音效**优先 bfxr 自制。理由有三：
1. 许可义务为零，账本永不恶化；
2. 音色天然落在 §1.3 的 16-bit 语汇里；
3. 这是 R1、R2 两个风险的共同兜底（见 §7）。

### 5.5 CREDITS 预登记行（草稿，供林绘澄并入 `assets/CREDITS.md`）

**A 区（原样）**：
```
| 512 Sound Effects (8-bit style) | Juhani Junkala (SubspaceAudio) | https://opengameart.org/content/512-sound-effects-8-bit-style | CC0 1.0 | （入库日） | 否 |
| 5 Chiptunes (Action) | Juhani Junkala (SubspaceAudio) | https://opengameart.org/content/5-chiptunes-action | CC0 1.0 | （入库日） | 否（WAV→OGG 转码，见 B 区） |
| Kenney Audio Packs（Interface / UI / Impact / RPG / Digital / Music Jingles） | Kenney | https://kenney.nl/assets | CC0 1.0 | （入库日） | 否（自愿致谢，无署名义务） |
```

**B 区（修改）**：
```
| 8-bit Music Pack (Loopable) —— OGG 转码 + 响度归一 + 派生变体版 | CodeManu | https://opengameart.org/content/8-bit-music-pack-loopable | CC-BY 3.0 | （入库日） | MP3→OGG 转码、响度归一至 −16 dBFS RMS、派生变体（降速/lowpass），原始作品署名保留 |
```

**账本影响核算**：

| 项 | 现状 | 音频入库后 |
|---|---|---|
| CC0 | 3 | **10**（3 图 + Kenney 音频 1 合并行 + Juhani 2） |
| CC-BY | 3 | **4**（+CodeManu 1） |
| OFL | 1 | 1 |
| **CC-BY-SA / GPL** | **0** | **0（红线保持）** |

> 说明：Kenney 若逐包下载建议拆成 6 行（每包自带 license.txt）；若一次性取用可合并为 1 行以控制 CREDITS 膨胀——请林绘澄按实际取用方式定。

---

## 6. 混音与实现策略（Godot 4.7.x）

> 本节是**规格建议**，不是实现代码。最终实现由程基岩定；标注 ★ 的条目需与他确认。

### 6.1 总线结构

```
Master   (0 dB)
├── BGM    (−10 dB)   音乐；可选挂 AudioEffectCompressor（sidechain = SFX）做 ducking
├── SFX    (−6 dB)    常规音效
├── UI     (−8 dB)    UI / 菜单音
└── Echo   (−12 dB)   ★ 挂 AudioEffectDelay，只服务 4 个"残响"事件
                        （btl_weak_hit / btl_weak_reveal / btl_victory / btl_defeat）
```

要点：
- **Echo 总线是 §1.5"残响签名"的实现载体**。它的能量是叠加的，所以音量压到 −12 dB，避免比干声还响。
- `AudioEffectDelay` 建议参数：delay 180–220 ms、feedback 0.25–0.35、dry 0.7 / wet 0.3（具体数值以实听为准）。
- **BGM ducking 是可选的**：战斗里命中音多，若觉得音乐被盖，可在 BGM 总线挂 `AudioEffectCompressor` 并把 `sidechain` 设为 `SFX`。这是 Godot 原生支持的，零额外代码。切片内不必须。

### 6.2 音量默认值

| 总线 | 默认 | 备注 |
|---|---|---|
| Master | 0 dB | |
| BGM | −10 dB | **素材响度差异大**，每首曲子还要在资源上再叠一个 −12 ~ −4 dB 的逐轨校准值 |
| SFX | −6 dB | |
| UI | −8 dB | UI 音要"软"，不打断阅读 |
| Echo | −12 dB | 叠加能量，必须压低 |

> 切片**不做音量设置 UI**（ADR A3 明确不建 SettingsManager）。若日后需要，常量放 Main，不新建 Autoload。

### 6.3 ★ 节点挂载策略（回应 ADR A3：不建 AudioManager）

**ADR A3 原文**：「不要建 `Global.gd` 大杂烩；不要建 AudioManager / SettingsManager——切片内音效走 Should-have，到时再评估。」

**我的评估结论：不需要第 5 个 Autoload。** 音频节点挂在 `Main.tscn` 常驻层即可（`SceneRouter` 只替换 World 层，Main 不被销毁），调用入口走已有的 `EventBus`。

```
Main.tscn（常驻根，SceneRouter 不碰它）
├── World            ← SceneRouter 替换（地图 / 战斗）
├── UILayer          ← 常驻（对话框 / 菜单 / 过渡遮罩）
└── AudioLayer       ← 【新增】常驻
    ├── BgmPlayer    AudioStreamPlayer   bus=BGM   （单实例；切歌 crossfade）
    ├── SfxPool      Node
    │   ├── Sfx0 … Sfx5   AudioStreamPlayer   bus=SFX（6 路 round-robin）
    ├── UiPlayer     AudioStreamPlayer   bus=UI    （单实例；新音打断旧音）
    └── EchoPlayer   AudioStreamPlayer   bus=Echo  （单实例；4 个残响事件）
```

**★ 为什么音频节点必须在 Main 常驻层——这是 E3-S5 能否出声的硬前置条件**

遇敌转场黑屏只有 0.2 s，且 `SceneRouter` 会销毁/重建 World 层的场景。若 `AudioStreamPlayer` 挂在地图或战斗场景内，切场景瞬间节点被销毁，**声音立刻被掐断**。转场音（尤其是黑屏后那一记 impact）必然发不出来。

**调用入口（零新增 Autoload，完全符合 A3 + A1 铁律 2）**：

```gdscript
## autoload/event_bus.gd —— 仅新增两行声明
## （符合 A3 职责：只声明信号，不存状态、不写逻辑）
signal sfx_requested(sfx_id: String)                  # 一次性音效
signal bgm_requested(track_id: String, fade: float)    # BGM 切换；fade = 交叉淡入淡出秒数
```

- `AudioLayer._ready()` 内 connect 这两个信号，负责实际的节点调度。
- 任何系统要出声，只需 `EventBus.sfx_requested.emit("btl_weak_hit")`。
- 战斗逻辑（`scripts/core/battle_logic.gd`）**仍然零 `get_node()`**——它只管 emit 信号，A1 铁律 3 不受影响。✅

> 备选方案（**不推荐**）：新增第 5 个 Autoload `AudioManager`。ADR 虽未禁止 5 个（气味线是 >6），但点名不建 AudioManager，且 EventBus 方案与架构更同构。若程基岩判断 EventBus 信号会让调用方太啰嗦，可退回此方案——**请他拍板**。

### 6.4 事件命名与接线（对接已有 `play_sfx` 动作）

**命名约定**：`snake_case`，格式 `<域>_<动作>[_<修饰>]`。对齐项目既有命名（`play_sfx`、`npc_01_innkeeper`、`enemy_touched`、`story_phase_changed`）。

| 域前缀 | 含义 |
|---|---|
| `ui_` | 菜单 / 对话框 |
| `map_` | 地图探索 |
| `btl_` | 战斗 |
| `bgm_` | 音乐轨（track_id） |

**与事件系统的接线**（架构 A7 动作白名单已有 `play_sfx`）：

```json
{ "type": "play_sfx", "id": "map_chest_open" }
```
→ 执行器一行：`EventBus.sfx_requested.emit(action.id)`

这让两处已写好的设计立刻落地：
1. 探索 GDD §3.3 宝箱事件模板（`play_sfx + give_item + dialogue + set_flag`）
2. EPIC-5 E5-S2 的验收项「9 种动作全部实装（wait/play_sfx 允许空实现占位）」——**可以从"空实现占位"升级为真实装**

### 6.5 池化 / 同发 / 错峰

| 项 | 规格 |
|---|---|
| SFX 池 | 6 路 `AudioStreamPlayer`，round-robin 取空闲（busy 则跳过到下一路） |
| 同 id 节流 | 同一事件 id 在 **50 ms** 内的重复请求丢弃（防连点、防群体技能叠加爆音） |
| **群体技能错峰** | ★ 雷爆 / 横扫 / 敌方群击命中多目标时，**每目标间隔 60–80 ms** 依次播放。既避免瞬间叠 3 声导致削波，又天然产生"扫过一片"的听感——**这是打击感的关键技巧，务必实现** |
| 变体选择 | 每个命中类事件配 3 个变体，随机选取但**不重复上一次**（防连击时的机关枪感） |
| 位置音频 | ❌ **不使用** `AudioStreamPlayer2D`。GDD 无音效定位需求，不引入距离衰减概念 |

### 6.6 资源格式建议

| 用途 | 格式 | 理由 |
|---|---|---|
| **BGM** | **OGG Vorbis**（.ogg），44.1 kHz（或 32 kHz），stereo，q4–q5 | Godot 原生支持、有损压缩体积小、流式播放不占内存。单轨目标 ≤ 2 MB，4 首 < 8 MB |
| **SFX** | **WAV 16-bit PCM，22050 Hz，mono** | SFX 短（<1 s），WAV 零解码延迟、触发最脆；16-bit 风味素材在 22.05 kHz 下完全够用，且天然带一点 lo-fi 质感（**技术限制变成风格优势**）；Godot 会重采样到混音率，不会失真 |
| ❌ MP3 | 不用 | loop 有 encoder padding，循环点会咔哒/空拍；社区公认 OGG 更优 |

**导入设置要点**：
- BGM：勾选 `loop` 并**必须设 `loop_offset`** —— OGG 编码有前导静音（encoder delay），不设会在循环接缝处出现一记空拍或咔哒。这是最容易踩的坑。
- SFX：关闭 loop；可勾 `Trim` 去掉首尾静音，让触发更脆。
- 目录：SFX → `assets/sfx/`（A2 已有）；**BGM → 建议新增 `assets/bgm/`**（A2 小改 1 行，★ 需程基岩确认；若不批准则退到 `assets/sfx/bgm/`）。

### 6.7 性能预算

| 项 | 数值 | 结论 |
|---|---|---|
| 同发语音上限 | SFX 6 + BGM 1 + UI 1 + Echo 1 = **9** | 远低于 Windows 安全区（32 voices） |
| 峰值场景 | 雷爆命中 3 目标（错峰 3 路）+ BGM + Echo = **5** | 安全 |
| 内存 | BGM 流式 < 8 MB；SFX 常驻 WAV ~30 条 × 0.3 s × 22050 × 2 B ≈ **0.4 MB** | 总 < 9 MB，切片零压力 |
| CPU | 9 语音 + 1 个 delay 效果 | 可忽略 |

---

## 7. 风险与备选方案

### R1（最大 · 概率高）：CC0 音乐池与"温暖 JRPG 小镇"不匹配

**现状**：已核实的两个音乐包都偏"动作/街机"——Juhani 那包标题就叫 *Action*，CodeManu 的 5 首文件名就叫 `bgm_action_1–5`。空之轨迹式的温暖城镇曲、日常感，在免费池里**非常稀缺**（免费音乐池的主流是史诗管弦 trailer 风与 lo-fi hiphop，两者都违反 §1.3）。

**影响**：`bgm_town` / `bgm_ruin` 找不到满意的 → 切片听感"太街机、不像 JRPG"，与支柱二"怀旧温情"直接冲突。

**备选方案**：
- **A（推荐）**：**降预期、走氛围路线**。选 action 曲中最慢、打击最少的一轨，做 lowpass + 降速派生（§2.3），情感浓度交给 SFX 和对话去撑，而不是交给旋律。Chained Echoes 相当多场景也走这条路。代价是小镇会偏"安静"而非"温暖"。
- **B（需用户拍板）**：扩大搜索到 **Matthew Pablo（OGA，CC-BY 3.0）** 与 **Kevin MacLeod / incompetech（CC-BY 4.0）**——这两位是**真实录音乐器**，温暖度够，但违反 §1.3 分辨率对齐原则，与 16-bit 视觉同频度低。
  → **权衡题：要"温暖但违和"，还是"统一但街机"？我推荐后者**（视觉一致性是本项目美术侧已确立的第一纪律，音频不应破坏它）。见 §8 决策点 1。
- **C（P2 远期）**：FamiStudio 自作曲。零许可风险、完全贴合，但作曲学习成本远超切片 120h 预算。

### R2（中）：跨来源素材的响度 / 音色不统一

与美术守则第 3 条"混包违和"完全同构——音频同样会"听起来像缝合怪"。

**缓解**：
1. **优先单一来源**：Juhani 一族（SFX + 战斗/Boss 曲）+ CodeManu 一族（小镇/遗迹曲），两族内部各自统一。
2. **跨族必须归一化**：所有入库素材统一响度归一（峰值 −1 dBFS，RMS −16 dBFS）。
3. **关键音一律自制**：`btl_weak_hit` / `btl_weak_reveal` / `btl_victory` / `btl_defeat` 用 bfxr 自制（§5.4），保证它们带有共同的"残响签名"处理，成为全片的听觉锚点。
4. 与美术同源：**孤立来源（只用一次的素材）标记为"高危违和点"**，优先替换。

### R3（中）：E3-S5 转场音被场景切换掐断

**根因**：黑屏仅 0.2 s；若 `AudioStreamPlayer` 挂在被 `SceneRouter` 销毁的场景节点上，声音立刻中断，黑屏后那记 impact 必然发不出来。

**缓解**：AudioLayer 挂 Main 常驻层（§6.3）——这是正解，且是 E3-S5 的前置条件，需在 S5 开工前确认。
**降级**：若来不及做 AudioLayer，只播 A 层（t=0 在地图侧立即播），放弃 B 层。

### R4（低但烦）：逐字打字音会把 30 分钟流程变吵

切片 250–350 条对话，若每字一响 = 数千次触发。

**缓解**：只在**句末标点 / 换行**处响；音量 ≤ −14 dB；优先级降为 **P1（可砍）**；代码里留一个常量开关（不做 UI）。

### R5（低）：OGG loop 的 encoder delay

**缓解**：导入时必设 `loop_offset`（§6.6）。若实听接缝仍有空拍，退回该曲用 WAV loop（4 首 WAV 约 90 MB，切片仍可接受，作为最后降级）。

---

## 8. 待用户拍板项 / Handoff

### 8.1 三个决策点（请用户拍板）

| # | 决策 | 我的推荐 |
|---|---|---|
| **1** | **音乐权衡**：温暖但偏现代录音的 CC-BY 音乐（Matthew Pablo / Kevin MacLeod）vs 统一但偏街机的 CC0 chiptune（Juhani / CodeManu） | **推荐后者**——视觉一致性是本项目美术侧已确立的第一纪律，音频不应破坏它；且 CC0 许可更干净 |
| **2** | **残响签名**：是否接受「弱点命中 / 弱点发现 / 胜利 / 失败 四个音加 delay 回声」作为游戏听觉签名（呼应《轨迹残响》的"残响"） | **推荐接受**——零素材成本，只需一条 Echo 总线 |
| **3** | **BGM 排期**：SFX 优先（Sprint 3 第 2 周 E3-S5 就要用），BGM 延到 Sprint 4–5 打磨期 | **推荐接受**——BGM 不阻塞 M3 |

### 8.2 给程基岩（eng）的确认项

1. ★ **AudioLayer 挂 Main.tscn 常驻层**是否可行（§6.3）——这是 E3-S5 出声的硬前置
2. ★ 是否同意 **EventBus 增 2 个信号**而非新建 `AudioManager` Autoload
3. ★ 新增 `assets/bgm/` 目录（A2 小改 1 行）是否批准
4. E3-S5 六个触发点的具体 emit 位置（见 `sfx-event-list.md` §3.3）

### 8.3 给林绘澄（art）的确认项

1. CREDITS 预登记行（§5.5）并入 `assets/CREDITS.md`；账本核算为 10×CC0 + 4×CC-BY + 1×OFL，**0×SA + 0×GPL 红线保持**
2. Kenney 音频包是合并 1 行还是拆 6 行，按实际取用方式定
3. §5.2 三条"待核实"音源若决定取用，需先核对 OGA 页面 License 栏并留证

### 8.4 下一步建议

1. **立刻可做（不占 Sprint 30h）**：用户拍板后，用 bfxr 花 30 分钟生成 P0 短音效占位，先把 AudioLayer 管线跑通——**管线先通，素材后换**
2. E3-S5 开工前：程基岩确认 §8.2 的 1/2 两条
3. Sprint 4–5：正式素材入库（走"先登记后复制"流程，由林绘澄执行）
4. 打磨期：4 首 BGM 选材 + 3 首派生变体

—— 阮和鸣，音频方向完毕。
