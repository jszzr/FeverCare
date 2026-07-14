# FeverCare(退烧记录)模块开发契约

一款纯本地、买断制的儿童发烧护理记录 iOS App。iOS 17+,SwiftUI + SwiftData + Swift Charts + ActivityKit,禁止任何第三方依赖。

## 合规红线(最高优先级)

本应用**只记录事实**。任何界面、文案、逻辑中:
- 禁止剂量计算、按体重推算、剂量参考表;
- 禁止"可以再喂了"、"距下次可用药还有 X 小时"等建议式表述——只允许陈述事实:"距上次服用布洛芬已过 3 小时 12 分";
- 禁止诊断类表述;体温分级色仅作视觉参考(Theme.swift 的 `Temp.color/levelLabel` 已定义,直接用);
- 固定文案一律用 `AppCopy` 中的常量,不要自造免责声明。

## 先读这些核心文件(它们是唯一契约,不得修改)

- /Users/zhirui/FeverCare/App/Models/Models.swift — `Child` / `Episode` / `CareEvent` / `CareEventKind`
- /Users/zhirui/FeverCare/App/Support/Theme.swift — `TempUnit` / `Temp` / `Brand` / `BigActionButtonStyle` / `Fmt`
- /Users/zhirui/FeverCare/App/Support/AppCopy.swift — 全部固定文案
- /Users/zhirui/FeverCare/Shared/FeverActivityAttributes.swift — Live Activity 数据契约
- /Users/zhirui/FeverCare/App/LiveActivity/LiveActivityController.swift — `LiveActivityController.shared.sync(episode:)`
- /Users/zhirui/FeverCare/App/RootView.swift — Tab 结构与 `[Child].selected(byID:)`

## 全局约定

- 所有用户可见文本用简体中文;支持深色模式(深夜是核心使用场景);触控目标要大。
- 温度内部一律存摄氏(`temperatureC`);显示时经 `Temp.display/number`。单位偏好:
  `@AppStorage("tempUnit") private var tempUnitRaw = TempUnit.celsius.rawValue`,
  `private var unit: TempUnit { TempUnit(rawValue: tempUnitRaw) ?? .celsius }`
- 当前孩子:`@AppStorage("selectedChildID") private var selectedChildID = ""`,配合 `children.selected(byID:)`。
- 任何数据增删改之后:`try? modelContext.save()`,然后 `LiveActivityController.shared.sync(episode: child.activeEpisode)`(病程结束后传结束前的那个 episode 或 nil 均可,sync 内部会判断)。
- 体温输入范围 34.0–43.0、步进 0.1,默认 38.5;快捷档位 [36.5, 37.5, 38.0, 38.5, 39.0, 39.5, 40.0]。
- 用药名输入提供快捷 chips:本病程用过的药名(`episode.medicationNames`)+ `AppCopy.commonMedicationNames`,可自由输入。
- 每条记录的时间默认"现在",但必须可改(补记场景);所有事件必须可编辑、可删除(竞品最大差评就是录错不能改)。
- 视图文件放在指定目录,每个 struct 独立清晰;不要写单元测试;不要动 project.yml。

## 模块清单(每个模块只写自己的文件,严禁触碰他人文件)

### A. 记录主页 — App/Views/Home/
- `HomeView.swift`:`struct HomeView: View`。NavigationStack;顶部孩子切换(Menu);
  - 无活跃病程:大按钮"开始记录发烧"(创建 Episode 并立即弹出体温记录 sheet),下方展示最近一次病程摘要(若有);
  - 有活跃病程:最新体温大字展示(Temp.number + 分级色)+ 测量时间;"已持续 X"(病程时长);每个用过的药名一张卡片:"距上次服用〔药名〕已过 X"(用 `Fmt.hoursMinutes` + TimelineView 每分钟刷新);四个大按钮:记录体温 / 记录用药 / 物理降温 / 备注(BigActionButtonStyle,用药按钮用蓝色系 tint);内嵌 `TemperatureChartView(episode:compact:true)` 预览,点击进 `EpisodeDetailView(episode:)`;工具栏"结束病程"(confirmationDialog 确认,设置 endedAt = Date())。
  - 页面底部小字 `AppCopy.disclaimerShort`。
- `RecordSheets.swift`:三个 sheet:
  - `TemperatureRecordSheet(episode:)`:大数字显示 + Slider/步进,快捷档位 chips,DatePicker(compact) 时间,保存;
  - `MedicationRecordSheet(episode:)`:药名 TextField + 快捷 chips、时间、可选备注,保存;
  - `ExtraRecordSheet(episode:kind:)`:kind 为 .cooling 或 .note,备注文本 + 时间,保存。
  - 保存后关闭 sheet;遵循"数据变更后 save + sync"约定。

### B. 病程详情与图表 — App/Views/Episode/
- `TemperatureChartView.swift`:`struct TemperatureChartView: View { init(episode: Episode, compact: Bool = false) }`。Swift Charts:体温 LineMark+PointMark(点色用 Temp.color),用药事件用 RuleMark(竖线)+ 顶部 pills 图标标注药名;X 轴时间;Y 轴范围约 35–41(clamp 数据);compact 模式高度 ~140、隐藏轴标签细节;空数据时显示占位文案。Y 轴数值按当前单位显示。
- `EpisodeDetailView.swift`:`struct EpisodeDetailView: View { init(episode: Episode) }`。完整图表 + 统计行(最高体温/持续时长/用药次数)+ 按时间倒序的事件 List(图标 `kind.symbolName`、主文案、时间),点击行弹 `EventEditSheet`,支持滑动删除(删除后 save + sync);工具栏放 NavigationLink("导出报告")→ `EpisodeReportView(episode:)`;若病程活跃,工具栏也提供"结束病程"。
- `EventEditSheet.swift`:`struct EventEditSheet: View { init(event: CareEvent) }`。按 kind 编辑对应字段与时间,可删除本条,保存后 save + sync。

### C. 历史病程 — App/Views/History/
- `HistoryView.swift`:`struct HistoryView: View`。NavigationStack + 孩子切换(与 Home 相同模式);List 展示该孩子 `pastEpisodes`(若有活跃病程,顶部单独一组"进行中"):每行为日期范围、持续时长、最高体温(带色)、用药次数;NavigationLink → `EpisodeDetailView(episode:)`;滑动删除整个病程(confirmationDialog 二次确认);空状态插画式占位(SF Symbol + 文案)。

### D. 就诊报告导出 — App/Views/Report/
- `EpisodeReportView.swift`:`struct EpisodeReportView: View { init(episode: Episode) }`。报告预览(ScrollView 内渲染 `ReportPage`)+ 底部"生成 PDF 并分享"大按钮 → `ReportRenderer.renderPDF` → ShareLink/UIActivityViewController 分享。
- `ReportRenderer.swift`:`@MainActor enum ReportRenderer { static func renderPDF(episode: Episode, unit: TempUnit) -> URL? }`。用 ImageRenderer 把 `ReportPage(episode:unit:)` 渲染成单页 PDF(A4 比例 595×842pt,内容多时可多页或压缩行距),写入临时目录返回 URL。
- `ReportPage`(同文件内):医生一眼能读的版式——标题"发烧病程记录"、孩子姓名/年龄、病程起止与时长、统计(最高体温、测温次数、用药次数按药名分列)、`TemperatureChartView(episode:compact:false)`、事件表格(时间 | 类型 | 内容),页脚 `AppCopy.reportFooter`。固定浅色配色(打印友好),温度按传入 unit 显示。

### E. 设置与引导 — App/Views/Settings/
- `SettingsView.swift`:`struct SettingsView: View`。分组:孩子管理(列表 + 添加/编辑/删除,删除需 confirmationDialog 且提示会删除其全部记录);温度单位 Picker(写回 tempUnitRaw);Live Activity 开关 `@AppStorage(LiveActivityController.enabledKey) private var liveActivityEnabled = true`(关闭时调 sync(episode: nil) 结束现有 activity);"隐私与免责"组:展示 `AppCopy.privacy` 与 `AppCopy.disclaimer`;关于(版本号 0.1.0)。
- `ChildEditSheet.swift`:`struct ChildEditSheet: View { init(child: Child?) }`,child 为 nil 时新建:姓名、emoji 选择(给 8-10 个常用儿童 emoji)、出生日期(可选 Toggle+DatePicker)。
- `OnboardingView.swift`:`struct OnboardingView: View`。首启引导单页:App 图标位(SF Symbol thermometer + Brand.accent)、`AppCopy.onboardingWelcome`、三行特性(纯本地存储/锁屏实时显示/一键导出就诊报告,配 SF Symbols)、内嵌新建第一个孩子的姓名输入 + 出生日期(可选),底部小字 `AppCopy.disclaimer`,大按钮"开始使用"(插入 Child 后 RootView 自动切换主界面)。

### F. Live Activity 界面 — Widgets/
⚠️ 本 target 只能 import SwiftUI/WidgetKit/ActivityKit,只能访问 Shared/ 下的 `FeverActivityAttributes`——**不能**使用 App/ 下的任何类型(Temp/Brand/Fmt 都不可用),需要的小工具函数在本文件内自带(可复制 Theme.swift 中 Temp.color 的分级逻辑)。
- `FeverCareWidgetsBundle.swift`:`@main struct FeverCareWidgetsBundle: WidgetBundle { var body: some Widget { FeverLiveActivity() } }`
- `FeverLiveActivity.swift`:`ActivityConfiguration(for: FeverActivityAttributes.self)`:
  - 锁屏视图:左侧孩子名 + "已发烧"计时(`Text(timerInterval: context.attributes.episodeStartedAt...Date.distantFuture, countsDown: false)`);中间最新体温大字(按分级着色,无记录显示"--");右侧/下行:"上次用药〔药名〕" + 已过时长计时(同样用 timerInterval 文本;若无用药显示"尚未用药");深色背景友好,`.activityBackgroundTint` 适当半透明。
  - 灵动岛:compact 左 thermometer 图标、右体温值;minimal 体温值;expanded 左孩子名+发烧时长、右体温、底部上次用药行。

## 完成标准

写完文件后自查:类型/方法名与契约完全一致、只用了 iOS 17 可用 API、无第三方依赖、中文文案、合规红线未触碰。返回:写入的文件列表 + 对外暴露的 API + 你做的任何假设。
