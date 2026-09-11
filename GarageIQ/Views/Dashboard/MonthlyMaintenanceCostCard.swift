import SwiftUI

struct MonthlyMaintenanceCostCard: View {
    let summary: MonthlyMaintenanceSummary
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maintenance costs").font(.headline)
                    Text(date, format: .dateTime.month(.wide).year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "wrench.and.screwdriver")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
            }

            Text("$\(summary.total.formatted(.number.precision(.fractionLength(2))))")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .accessibilityLabel("Total recorded maintenance cost")
                .accessibilityValue("\(summary.total.formatted(.number.precision(.fractionLength(2)))) dollars")

            Text("Month to date · All vehicles")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            if summary.recordCount == 0 {
                Text("No maintenance recorded this month. Add a service in Maintenance to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(summary.recordCount) service\(summary.recordCount == 1 ? "" : "s") recorded")
                    .font(.subheadline)
                if summary.missingCostCount > 0 {
                    Text("\(summary.missingCostCount) without a cost — excluded from the total.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
    }
}
