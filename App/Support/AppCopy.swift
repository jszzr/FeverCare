import Foundation

/// 全 app 统一文案。合规红线:本应用只记录事实,绝不出现剂量计算、
/// "可以再喂了"、"建议用药"等任何医疗建议表述。
enum AppCopy {
    static let appName = "烧退退"

    static let disclaimer = """
    本应用仅用于记录体温、用药时间等事实信息,不提供任何医疗建议。\
    用药种类、剂量与间隔请遵医嘱或药品说明书;\
    如孩子出现持续高热、精神萎靡、抽搐等情况,请立即就医。
    """

    static let disclaimerShort = "仅记录事实,不构成医疗建议;用药请遵医嘱。"

    static let privacy = """
    数据保存在你的设备上;如你登录了 iCloud,会经由你自己的 iCloud 私有空间在你的设备之间同步。\
    我们没有服务器,任何人(包括开发者)都无法访问你的数据。
    """

    static let onboardingWelcome = "孩子发烧的夜里,帮你记清每一次体温和用药,交接不断层,复诊说得清。"

    static let reportFooter = "本报告由「烧退退」根据用户手动录入的数据生成,仅供就诊参考,不构成医疗建议。"

    /// 常见退烧药名,仅作为输入便利的快捷选项(名称联想),不构成用药推荐。
    static let commonMedicationNames = ["布洛芬", "对乙酰氨基酚"]

    static let trialNote = "全部功能免费试用 \(PurchaseManager.trialDays) 天,之后一次买断、永久使用;已有记录永远可查看导出。"

    static let analyticsNote = """
    匿名使用统计在当前版本中尚未启用，不会发送任何统计数据。\
    如后续启用，将只统计功能使用次数和 App 版本，不含体温、用药或孩子信息。
    """
}
