import SwiftUI
import StoreKit

/// 买断付费墙。原则:语气克制,不倒计时施压,不弹窗轰炸——
/// 深夜焦虑的家长面前,体面比转化率重要。
struct PaywallView: View {
    @ObservedObject private var purchases = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let features: [Feature] = [
        Feature(icon: "thermometer.variable", title: "不限次数的病程记录",
                detail: "体温、用药、物理降温、备注,随时记"),
        Feature(icon: "person.2.fill", title: "多个孩子建档",
                detail: "每个孩子独立的病程与历史"),
        Feature(icon: "lock.iphone", title: "锁屏与灵动岛实时显示",
                detail: "半夜不解锁就能看到距上次用药多久"),
        Feature(icon: "doc.richtext", title: "就诊报告 PDF",
                detail: "一键整理成医生一眼能读的病程单"),
        Feature(icon: "icloud.fill", title: "iCloud 多设备同步",
                detail: "爸爸妈妈两台手机数据一致"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "thermometer.variable")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 84, height: 84)
                        .background(Brand.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.top, 12)

                    VStack(spacing: 6) {
                        Text("解锁「烧退退」完整版")
                            .font(.title2.weight(.bold))
                        Text(trialStatusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        ForEach(features) { feature in
                            HStack(spacing: 14) {
                                Image(systemName: feature.icon)
                                    .font(.title3)
                                    .foregroundStyle(Brand.accent)
                                    .frame(width: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feature.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(feature.detail)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding()
                    .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("一次付费,永久使用。无订阅、无广告。\n无论是否购买,你已有的全部记录永远可以查看、编辑和导出。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Brand.pageBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if purchases.product == nil && !purchases.isLoadingProduct {
                        Text("暂时无法获取价格，请检查 App Store 的“媒体与购买项目”登录状态和网络，然后重试。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            guard purchases.product != nil else {
                                await purchases.loadProduct()
                                return
                            }
                            await purchases.purchase()
                            if purchases.isPurchased { dismiss() }
                        }
                    } label: {
                        if purchases.isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text(purchaseButtonText)
                        }
                    }
                    .buttonStyle(BigActionButtonStyle())
                    .disabled(purchases.isPurchasing || purchases.isLoadingProduct)

                    Button("恢复购买") {
                        Task {
                            await purchases.restore()
                            if purchases.isPurchased { dismiss() }
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(.thinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .alert("提示", isPresented: .init(
                get: { purchases.lastError != nil },
                set: { if !$0 { purchases.lastError = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(purchases.lastError ?? "")
            }
        }
        .onAppear {
            Analytics.shared.track(.paywallShown)
        }
        .task {
            if purchases.product == nil {
                await purchases.loadProduct(showError: false)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, purchases.product == nil else { return }
            Task {
                await purchases.loadProduct(showError: false)
            }
        }
    }

    private var trialStatusText: String {
        if purchases.isPurchased { return "已解锁,感谢支持" }
        if purchases.isInTrial { return "试用中,还剩 \(purchases.trialDaysRemaining) 天" }
        return "试用已结束,买断后可继续记录"
    }

    private var purchaseButtonText: String {
        if let price = purchases.product?.displayPrice {
            return "\(price) 买断,永久使用"
        }
        if purchases.isLoadingProduct {
            return "价格加载中…"
        }
        return "重新加载价格"
    }
}

#Preview {
    PaywallView()
}
