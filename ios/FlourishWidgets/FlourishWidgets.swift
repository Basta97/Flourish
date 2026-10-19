import SwiftUI
import WidgetKit

private let group = "group.com.basta.bastasaving.shared"

struct SummaryEntry: TimelineEntry {
  let date: Date
  let data: [String: Any]
  var arabic: Bool { (data["locale"] as? String ?? Locale.current.languageCode) == "ar" }
  var hidden: Bool { data["hidden"] as? Bool ?? true }
  var expired: Bool { Date().timeIntervalSince1970 * 1000 >= (data["periodEnd"] as? Double ?? 0) }
  func label(_ key: String, _ english: String, _ arabicText: String) -> String {
    data[key] as? String ?? (arabic ? arabicText : english)
  }
}
struct SummaryProvider: TimelineProvider {
  func placeholder(in context: Context) -> SummaryEntry { SummaryEntry(date: Date(), data: [:]) }
  func getSnapshot(in context: Context, completion: @escaping (SummaryEntry) -> Void) { completion(read()) }
  private func read() -> SummaryEntry {
    let json = UserDefaults(suiteName: group)?.string(forKey: "widget_snapshot") ?? "{}"
    let data = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
    return SummaryEntry(date: Date(), data: data)
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
    let entry = read()
    let end = Date(timeIntervalSince1970: (entry.data["periodEnd"] as? Double ?? 0) / 1000)
    var entries = [entry]
    if end > Date() {
      // A new month cannot display last month's totals as current totals.
      var stale = entry.data
      stale.removeValue(forKey: "income"); stale.removeValue(forKey: "spending")
      entries.append(SummaryEntry(date: end, data: stale))
    }
    completion(Timeline(entries: entries, policy: .after(max(end, Date().addingTimeInterval(1800)))))
  }
}
struct FlourishWidgetView: View {
  let entry: SummaryEntry
  let quick: Bool
  @Environment(\.widgetFamily) private var family
  var body: some View {
    content
      .environment(\.locale, Locale(identifier: entry.arabic ? "ar" : "en"))
      .environment(\.layoutDirection, entry.arabic ? .rightToLeft : .leftToRight)
      .widgetURL(URL(string: "flourish://widget/home"))
  }
  @ViewBuilder private var content: some View {
    if #available(iOS 17.0, *) {
      inner.containerBackground(.background, for: .widget)
    } else {
      inner.padding().background(Color(UIColor.systemBackground))
    }
  }
  private var inner: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(quick ? (entry.arabic ? "إضافة سريعة" : "Quick add") : entry.label("title", "Monthly summary", "الملخص الشهري"), systemImage: "leaf.fill")
        .font(.headline).foregroundColor(.green)
      if !quick {
        if entry.expired {
          Text(entry.label("refreshLabel", "Open Flourish to refresh", "افتح Flourish للتحديث")).font(.caption)
        } else if entry.data["empty"] as? Bool == true {
          Text(entry.label("emptyLabel", "No transactions yet", "لا توجد معاملات بعد")).font(.caption)
        } else {
          total("income", entry.label("incomeLabel", "Income", "الدخل"))
          total("spending", entry.label("spendingLabel", "Spending", "المصروفات"))
        }
      }
      if family == .systemMedium {
        HStack {
          Link(destination: URL(string: "flourish://widget/add")!) {
            Label(entry.label("addLabel", "Add transaction", "إضافة معاملة"), systemImage: "plus.circle.fill")
          }
          Spacer(minLength: 8)
          Link(destination: URL(string: "flourish://widget/template")!) {
            Label(entry.label("templateLabel", "Use template", "استخدام قالب"), systemImage: "bookmark.fill")
          }
        }.font(.caption).padding(.vertical, 6)
      }
      if let millis = entry.data["updatedAt"] as? Double {
        HStack(spacing: 3) {
          Text(entry.label("updatedLabel", "Updated", "آخر تحديث"))
          Text(Date(timeIntervalSince1970: millis / 1000), style: .date)
          Text(Date(timeIntervalSince1970: millis / 1000), style: .time)
        }.font(.system(size: 9)).foregroundColor(.secondary)
      }
      if (entry.data["missingRates"] as? Int ?? 0) > 0 {
        Text(entry.label("refreshLabel", "Open Flourish to refresh", "افتح Flourish للتحديث")).font(.caption2)
      }
    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
  private func total(_ key: String, _ label: String) -> some View {
    HStack {
      Text(label)
      Spacer(minLength: 4)
      Text("\(entry.hidden ? "••••" : (entry.data[key] as? String ?? "—")) \(entry.data["currency"] as? String ?? "EGP")")
    }.font(.caption).minimumScaleFactor(0.7).lineLimit(1)
  }
}
struct MonthlySummaryWidget: Widget {
  let kind = "FlourishMonthlySummary"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SummaryProvider()) { entry in FlourishWidgetView(entry: entry, quick: false) }
      .configurationDisplayName(LocalizedStringKey("Monthly summary"))
      .description(LocalizedStringKey("Income and spending for your reporting month."))
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}
struct QuickAddWidget: Widget {
  let kind = "FlourishQuickAdd"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SummaryProvider()) { entry in FlourishWidgetView(entry: entry, quick: true) }
      .configurationDisplayName(LocalizedStringKey("Quick add"))
      .description(LocalizedStringKey("Add a transaction or use a saved template."))
      .supportedFamilies([.systemMedium])
  }
}
@main struct FlourishWidgetBundle: WidgetBundle {
  var body: some Widget { MonthlySummaryWidget(); QuickAddWidget() }
}
