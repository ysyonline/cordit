# SFX 事件清单 ·《轨迹残响》垂直切片

> 作者：阮和鸣（audio-director）｜任务 AUD-DIR-01｜配套：`design/audio/audio-direction.md`
> 命名约定对齐项目既有风格（snake_case）：`play_sfx` 动作、`npc_01_innkeeper`、`enemy_touched`、`story_phase_changed`
> **本任务只做清单，未下载/复制/修改任何音频文件。** 素材入库走单独的"先登记后复制"流程。

---

## 1. 命名约定

**格式**：`<域>_<动作>[_<修饰>]`，全小写 snake_case。

| 域前缀 | 含义 | 例 |
|---|---|---|
| `ui_` | 菜单 / 对话框 / 交互提示 | `ui_confirm` |
| `map_` | 地图探索交互 | `map_chest_open` |
| `btl_` | 战斗 | `btl_hit_fire` |
| `bgm_` | 音乐轨 track_id | `bgm_battle` |

**变体规则**：事件 id 不带变体号；变体在文件名上区分（`btl_hit_fire_01.wav` / `_02` / `_03`），由 AudioLayer 随机选取、**不重复上一次**。

**总线分配规则**（AudioLayer 内一张常量映射表）：默认 `SFX`；`ui_*` → `UI`；四个"残响"事件 → `Echo`。

---

## 2. 事件清单总表

优先级口径：**P0 = 切片必须有**（缺了明显掉档次）｜**P1 = 有则更好，可整体后移**｜**P2 = 远期（完整版）**
"来源"列：K = Kenney（CC0）｜J = Juhani Junkala 512 SFX（CC0）｜X = bfxr/ChipTone 自制（零许可义务）

### 2.1 UI 组

| 事件 id | 触发时机 | 时长上限 | 音色族 / 描述 | 优先级 | 来源 |
|---|---|---|---|---|---|
| `ui_cursor` | 光标移动 / 指令菜单切换项 | 0.06 s | 暖木；极短软点击，无金属感 | **P0** | K / X |
| `ui_confirm` | 确认（攻击/技能/道具/对话推进） | 0.12 s | 暖木 + 轻微金属泛音；干净收尾 | **P0** | K / X |
| `ui_cancel` | 取消 / 返回上一层 | 0.10 s | 暖木；`ui_confirm` 的下行小二度版 | **P0** | K / X |
| `ui_error` | 选中不可用项（MP 不足 / 置灰项 / Boss 战选逃跑） | 0.15 s | 冲击；短促下行两音，闷 | **P0** | **X**（`ui_cancel` 降调派生，零额外素材） |
| `ui_open` | 菜单打开 | 0.20 s | 暖木；上行两音 | P1 | K |
| `ui_close` | 菜单关闭 | 0.18 s | 暖木；下行两音 | P1 | K |
| `ui_text_blip` | 逐字显示（**仅句末标点/换行**，非每字） | 0.04 s | 暖木；音量 ≤ −14 dB，极轻 | P1 | X |
| `ui_save` | 右下角存档图标闪现 0.5 s | 0.25 s | 金属 + 水晶；轻快两音，带微弱 echo | P1 | K |

### 2.2 探索组

| 事件 id | 触发时机 | 时长上限 | 音色族 / 描述 | 优先级 | 来源 |
|---|---|---|---|---|---|
| `map_chest_open` | 宝箱开启（探索 GDD §3.3 事件模板首个动作 `play_sfx`） | 0.60 s | 金属 + 暖木；锁扣"咔" + 箱盖木响 + 内部微光感 | **P0** | K（RPG Audio） |
| `map_footstep` | 玩家行走，每 0.35 s 一次（非每步） | 0.10 s | 暖木；低音量软踏，3 变体 | P1 | 待核实（Fantozzi）/ X |
| `map_inspect` | 调查点交互 | 0.30 s | 暖木；"翻找"质感，轻 | P1 | K |
| `map_door` | 门 / 传送点 | 0.40 s | 暖木 + 低频；开门吱呀后接一记闷响（空间转换感） | P1 | K |
| `map_item_get` | 获得道具（掉落 / 拾取） | 0.35 s | 金属 + 水晶；上行两音，小奖励感 | P1 | J（powerup） |

### 2.3 战斗组

| 事件 id | 触发时机 | 时长上限 | 音色族 / 描述 | 优先级 | 来源 |
|---|---|---|---|---|---|
| `btl_encounter` | ★ 遇敌接触 → 转场（E3-S5，两段式，见 §3.1） | A 0.15 s / B 0.45 s | 冲击；A = 上行 swish，B = 低频 impact + 金属泛音 | **P0** | J / K（Impact） |
| `btl_hit_phys` | 物理命中（攻击 / 重斩 / 横扫） | 0.35 s | 金属；中频 300–800 Hz，3 变体 | **P0** | J（damage）/ X |
| `btl_hit_fire` | 火属性命中 | 0.45 s | 水晶；低频 whoomp（80–150 Hz 骤降）+ 中频噪声爆裂，3 变体 | **P0** | J / X |
| `btl_hit_ice` | 冰属性命中 | 0.60 s | 水晶；高频起音 2–4 kHz + 玻璃碎裂式多点瞬态，3 变体 | **P0** | J / X |
| `btl_hit_thunder` | 雷属性命中 | 0.35 s | 水晶；白噪 zap + pitch sweep down，attack < 5 ms，3 变体 | **P0** | J / X |
| `btl_weak_hit` | ★ 克制命中（×1.5 成立），**叠加**在命中音之上 | 0.50 s | 金属/水晶；上行三音琶音（根-五-八），**走 Echo 总线** | **P0** | **X**（建议自制，见 §3.3） |
| `btl_weak_reveal` | ★ 首次命中某敌人弱点（`discovered_weakness_set` 写入时） | 0.40 s | 水晶；"点亮/解锁"感——上行两音 + 明亮铃声，**走 Echo 总线** | **P0** | **X**（建议自制） |
| `btl_resist_hit` | 抗性命中（×0.5） | 0.30 s | 冲击；闷响，明显比正常命中"钝" | P1 | X（`btl_hit_phys` lowpass 派生） |
| `btl_heal` | 治疗 / 群愈 / 净化 | 0.50 s | 水晶；上行柔和琶音，尾音微 echo | **P0** | J（powerup） |
| `btl_guard` | 防御 / 掩护 | 0.30 s | 金属 + 低频；"架住"的短促顿感 | P1 | K |
| `btl_poison` | 中毒每回合扣血（仅 B4/B5） | 0.40 s | 低频；黏滞的下行滑音，轻微不适但不恶心 | P2 | X |
| `btl_enemy_down` | 敌人倒下 | 0.55 s | 冲击 + 金属；垮塌感，短 | **P0** | J |
| `btl_ally_down` | 我方倒下 | 0.70 s | 冲击 + 低频；比敌人倒下更沉、更长 | P1 | J |
| `btl_flee_ok` | 逃跑成功 | 0.50 s | 金属；急促上行 + 收尾 | P1 | J |
| `btl_flee_fail` | 逃跑失败（消耗该角色回合） | 0.30 s | 冲击；短促下坠 | P1 | X |
| `btl_telegraph` | Boss「蓄力」telegraph（GDD §5 AI 模式） | 0.60 s | 低频 Drone；缓慢上行的蓄力感，**提示玩家下回合要防御** | P1 | X / J（alarm） |

### 2.4 反馈 / 结算组

| 事件 id | 触发时机 | 时长上限 | 音色族 / 描述 | 优先级 | 来源 |
|---|---|---|---|---|---|
| `btl_victory` | ★ 胜利 fanfare（结算画面进入时） | 2.00 s | 金属；SNES 风和弦上行（I-IV-V-I 或 IV-V-vi-I），方波 lead + 鼓 fill，**尾音走 Echo 总线** | **P0** | K（Music Jingles）/ J（fanfare） |
| `btl_defeat` | ★ 失败（"残响中断"画面） | 1.50 s | 低频 Drone；下行小调 + lowpass 收尾 + 末端 pitch bend 下行，**走 Echo 总线** | **P0** | **X**（建议自制，需精准控制） |
| `btl_levelup` | 升级提示（结算画面"莉娜 Lv2！"） | 0.80 s | 金属 + 水晶；上行 fanfare 短版 | P1 | J（powerup） |

### 2.5 计数

| 优先级 | 事件数 | 实际需入库素材 |
|---|---|---|
| **P0** | **16** | **15**（`ui_error` 由 `ui_cancel` 降调派生，零额外素材） |
| P1 | 15 | 14（`btl_resist_hit` 由 `btl_hit_phys` lowpass 派生） |
| P2 | 1 | 1 |
| **合计** | **32 条事件** | **30 条素材**（2 条为派生） |

**P0 的 16 条覆盖**：菜单三键（光标/确认/取消）+ 否定反馈 + 宝箱 + 遇敌转场 + 四系命中（物理/火/冰/雷）+ 克制命中 + 弱点发现 + 治疗 + 敌人倒下 + 胜利 + 失败。

> 一句话说明：**P0 覆盖"玩家每一次按键、每一次出手、每一次胜负"都能听到反馈**——这是 30 分钟切片里听觉体验的全部骨架，P1/P2 只是锦上添花。

---

## 3. E3-S5 打击反馈专项（可直接交付程基岩）

> 依据：EPIC-3 E3-S5「遇敌转场（黑屏 0.2s）；战斗背景截图模糊；受击闪白；克制橙字放大 1.3 倍 + "弱点！"弹字 + 音效钩子」，3h 工时。
> 本节是本 Sprint 唯一会真实用到的音频部分。**六类反馈，逐条给时序与规格。**

### 3.1 遇敌转场 `btl_encounter`

**时序（黑屏总时长 0.2 s，音效分两段）**

| t | 事件 | 说明 |
|---|---|---|
| 0.000 s | 玩家碰撞盒接触敌人 → emit `sfx_requested("btl_encounter")` | 播 **A 层**；同时 SceneRouter 启动黑屏淡入 |
| 0.000–0.120 s | A 层播放 | 上行 swish：方波/噪声 pitch sweep 1 kHz → 4 kHz，0.12 s |
| 0.200 s | 黑屏全黑，战斗场景载入完成 | 播 **B 层**：60–120 Hz 低频 impact + 短金属泛音，0.35 s |
| 0.550 s | B 层结束 | 与战斗 BGM 淡入（0.5 s）交叉 |

- 音色族：冲击（赤陶红 `#A6423A`）
- 时长上限：A ≤ 0.15 s，B ≤ 0.45 s
- ★ **与视觉对齐**：A 层起点 = 黑屏淡入起点；B 层起点 = 全黑那一帧（听觉上"世界切换完成"）
- ★★ **工程硬前置**：AudioLayer 必须挂在 `Main.tscn` 常驻层。若挂在地图或战斗场景内，`SceneRouter` 切场景会销毁节点 → **B 层必然发不出来**。
- **降级**：AudioLayer 来不及做 → 只播 A 层（t=0 在地图侧立即播），B 层放弃。

### 3.2 受击 `btl_hit_phys` / `_fire` / `_ice` / `_thunder`

- **结构**：三层叠加 —— transient（≤ 0.03 s 噪声/click）+ body（0.08–0.20 s 音高体）+ tail（≤ 0.15 s，可选）
- ★★ **与视觉对齐**：**音效 attack 首帧必须与"受击闪白"首帧同帧（±1 帧）**。闪白建议 0.06–0.08 s。这是打击感的生死线——声音晚 2 帧，玩家就会觉得"软"。
- **四系音色规格**（见 `audio-direction.md` §1.4；玩家要能闭眼分辨）：

| 事件 | 频谱 | decay | 备注 |
|---|---|---|---|
| `btl_hit_phys` | 中频 300–800 Hz，金属/钝击 | 0.15 s | |
| `btl_hit_fire` | 低频 whoomp 80–150 Hz 骤降 + 中频噪声爆裂 | 0.35 s | 暖、有体积感 |
| `btl_hit_ice` | 高频 2–4 kHz 起音 + 玻璃碎裂式多点瞬态 | 0.50 s | 唯一允许"亮到刺耳"的音 |
| `btl_hit_thunder` | 白噪 zap + pitch sweep down，attack < 5 ms | 0.25 s | 最硬、最短、最干脆 |

- 变体：每类 3 个，随机不重复上一次（防连击时的机关枪感）
- 单条时长上限：0.60 s

### 3.3 克制命中 `btl_weak_hit`

- **触发**：克制判定 ×1.5 成立（GDD §3.1 击退的同一触发条件）
- **规格**：**不替换**命中音，而是**在其之上叠加**一个上行三音琶音（根-五-八度，如 C-E-G）
- 时长 ≤ 0.50 s；音色用明亮方波 / mallet（严格落在 16-bit 语汇内）
- **总线**：★ `Echo`（这是"残响"签名的第一个落点）
- 音量：比普通命中音 **+2 dB**
- ★ **与视觉对齐时序**：
  - t = 0：命中音 + 琶音第 1 音 + **克制橙字放大 1.3 倍**（同帧）
  - t = +0.08 s：琶音第 2 音 + **"弱点！"弹字出现**（形成音-字对位）
  - t = +0.16 s：琶音第 3 音
- **建议自制（bfxr）而非抓素材**：这是全切片最重要的正反馈音，必须精准对帧且音色与游戏名/调性一致。bfxr 出这个音约 10 分钟，且**零许可义务**。

### 3.4 弱点发现 `btl_weak_reveal`

- **触发**：GDD §3.3 三步呈现的**第 2 步**——**首次**命中该敌人弱点，`discovered_weakness_set` 写入那一刻
- **规格**：与 `btl_weak_hit` **分开**、音色**不同**——一个"点亮 / 解锁"音：上行两音 + 明亮铃声，0.40 s，走 `Echo` 总线，delay 尾巴比 weak_hit 更明显
- ★ **与 `btl_weak_hit` 的时序关系**：

| t | 事件 |
|---|---|
| 0.00 s | `btl_weak_reveal`（点亮音） |
| +0.10 s | `btl_weak_hit`（克制琶音） |
| +0.18 s | "弱点！"弹字 + 弱点图标常驻 |

- ★ **关键区分**：**非首次命中只播 `btl_weak_hit`，不播 `btl_weak_reveal`。** 跨战斗记忆命中的敌人（已在 `discovered_weakness_set` 内）同样只播 weak_hit。这个区分正是 GDD §3.3 三步呈现的听觉落地——玩家会因为"这个音只响一次"而本能地记住弱点。
- **建议自制（bfxr）**，理由同 §3.3。

### 3.5 胜利 `btl_victory`

- **规格**：fanfare 1.2–2.0 s；SNES 风和弦上行（I-IV-V-I 或 IV-V-vi-I）；方波 lead + 鼓 fill；**尾音走 `Echo` 总线**
- ★★ **混音时序**：**BGM 0.6 s 淡出，fanfare 在 BGM 淡出开始后 0.1 s 进入**（交叉 0.5 s）。
  ❌ 禁止"BGM 停 → 静默 → fanfare"——中间那拍静默会让胜利感塌掉。
- **与结算画面对齐**：fanfare 结束后 0.2 s 开始第一条 EXP 逐条弹出
- 时长上限：2.00 s

### 3.6 失败 `btl_defeat`

- **规格**：0.8–1.5 s；**下行小调 + lowpass 收尾**（声音"沉入水中"）+ 末端 pitch bend 下行；**走 `Echo` 总线**
- ★ **与"残响中断"画面文字同帧进入**
- ★★ **设计论证**：GDD §3.5 明确「失败→自动读档至进图存档点，无额外惩罚」，且「不做全灭即回主菜单」——**失败是无惩罚、可立刻重试的**。所以失败乐必须**短、干净、有"中断"感**，玩家 1.5 s 内就该准备好重来。**不做长哀乐，不做沉重弦乐**——音乐惩罚玩家会与"无惩罚"的设计直接打架。
- **建议自制（bfxr + Audacity lowpass）**：需要精准控制 pitch bend 与 lowpass 收尾，现成素材很难刚好合适。

---

### 3.7 实装接线清单（给程基岩 · E3-S5）

按顺序做，前 3 条是 E3-S5 出声的硬前置：

- [ ] **1.** `autoload/event_bus.gd` 新增两行信号声明（只声明，零逻辑，符合 A3 职责）
      ```gdscript
      signal sfx_requested(sfx_id: String)
      signal bgm_requested(track_id: String, fade: float)
      ```
- [ ] **2.** `scenes/main/main.tscn` 新增 `AudioLayer` 常驻节点（BgmPlayer / SfxPool×6 / UiPlayer / EchoPlayer）
- [ ] **3.** 新建 4 条音频总线 `BGM` / `SFX` / `UI` / `Echo`（`default_bus_layout.tres`）；`Echo` 挂 `AudioEffectDelay`
- [ ] **4.** `AudioLayer` 实现：id→流映射常量表、round-robin 池化、**同 id 50 ms 节流**、**群体技能每目标 60–80 ms 错峰**、3 变体随机不重复
- [ ] **5.** E3-S5 六个触发点 emit 信号（§3.1–§3.6 各一处）
- [ ] **6.** （EPIC-5 可复用）`play_sfx` 动作接上：`EventBus.sfx_requested.emit(action.id)` —— 探索 GDD §3.3 宝箱事件模板与 EPIC-5 E5-S2「空实现占位」可升级为真实装

**hook 位置建议**（E3-S5 范围内）：

| 反馈 | emit 位置 |
|---|---|
| `btl_encounter` A 层 | 地图侧碰撞回调（发 `enemy_touched` 的同一处） |
| `btl_encounter` B 层 | 战斗场景 `_ready()` 末尾，或 SceneRouter 切场景完成信号后 |
| `btl_hit_*` / `btl_weak_hit` | 伤害结算函数出口（非 `scripts/core/` 纯函数层——纯函数层只返回结果，emit 放在调用它的视图层，保住 A1 铁律 3） |
| `btl_weak_reveal` | `discovered_weakness_set` 写入 GameData 的同一处 |
| `btl_victory` / `btl_defeat` | 胜利/失败结算流程入口 |

### 3.8 降级方案（S5 的 3h 不够时，按序砍）

1. 保留 4 条命中音 + `btl_encounter`（最小打击感，约 40 min）
2. `ui_error` 复用 `ui_cancel` 降调变体（省 1 条素材）
3. `btl_weak_reveal` 复用 `btl_weak_hit` 的加长版（省 1 条，但损失"只响一次"的记忆强化）
4. 放弃 `btl_resist_hit` / `btl_guard` / `btl_ally_down`（均为 P1）
5. ★ **若素材完全未到位**：用 bfxr 现场生成 6 个占位音（约 15 分钟），**零许可风险**，先把管线跑通，正式素材后换。**管线先通，素材后换**——不要让素材阻塞代码。

---

## 4. 入库核对表（素材正式入库时逐条勾，由林绘澄/阮和鸣执行）

- [ ] `assets/CREDITS.md` 对应行**已先于文件存在**（先登记后复制）
- [ ] 许可栏以**页面 License 栏原文**核对（非描述正文自称）
- [ ] 非 CC-BY-SA / 非 GPL / 非 NC / 非 ND / 非 Sampling+
- [ ] 做过修改（响度归一 / 降速 / lowpass / 转码 / 裁剪）的 → 从 A 区移至 **B 区**并写明修改说明
- [ ] 响度归一：峰值 ≤ −1 dBFS，RMS −18 ~ −14 dBFS
- [ ] BGM 已设 `loop_offset`（OGG encoder delay）
- [ ] 格式：BGM = OGG；SFX = WAV 16-bit / 22050 Hz / mono
- [ ] 音色符合 `audio-direction.md` §1.3 分辨率对齐原则（无真实管弦 / 录音钢琴 / 现代 EDM）
- [ ] 更新 `assets/LICENSE-ASSETS.md` 账本核对行（目标 10×CC0 + 4×CC-BY + 1×OFL，0×SA + 0×GPL）

—— 阮和鸣，SFX 事件清单完毕。
