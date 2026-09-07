import SwiftUI
import SwiftData

struct MaintenanceHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [MaintenanceRecord]
    @State private var showingAdd = false
    @State private var recordToEdit: MaintenanceRecord?
    @State private var recordToDelete: MaintenanceRecord?
    @State private var deleteError: String?
    let vehicle: Vehicle

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        let vehicleID = vehicle.id
        _records = Query(
            filter: #Predicate<MaintenanceRecord> { $0.vehicle?.id == vehicleID },
            sort: [SortDescriptor(\MaintenanceRecord.date, order: .reverse)]
        )
    }

    var body: some View {
        List {
            ForEach(records) { record in
                Button {
                    recordToEdit = record
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.serviceType).font(.headline)
                        Text(record.date, format: .dateTime.month().day().year())
                        HStack {
                            Text("\(record.mileage.formatted()) miles")
                            if let cost = record.cost {
                                Text("Cost: \(NSDecimalNumber(decimal: cost).stringValue)")
                            }
                        }
                        if !record.shopName.isEmpty { Text(record.shopName) }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                }
                .accessibilityHint("View and edit service details")
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) { recordToDelete = record }
                    Button("Edit") { recordToEdit = record }.tint(.blue)
                }
            }
        }
        .overlay {
            if records.isEmpty {
                ContentUnavailableView {
                    Label("No Maintenance Yet", systemImage: "wrench.and.screwdriver")
                } description: {
                    Text("Record the first service for this vehicle.")
                } actions: {
                    Button("Add Service") { showingAdd = true }.buttonStyle(.borderedProminent)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Service", systemImage: "plus") { showingAdd = true }
            }
        }
        .sheet(isPresented: $showingAdd) { AddMaintenanceRecordView(vehicle: vehicle) }
        .sheet(item: $recordToEdit) { AddMaintenanceRecordView(vehicle: vehicle, record: $0) }
        .confirmationDialog("Delete this service record?", isPresented: Binding(
            get: { recordToDelete != nil }, set: { if !$0 { recordToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete Record", role: .destructive) {
                if let record = recordToDelete { delete(record) }
                recordToDelete = nil
            }
            Button("Cancel", role: .cancel) { recordToDelete = nil }
        } message: { Text("This removes only this maintenance record.") }
        .alert("Could Not Delete Service", isPresented: Binding(
            get: { deleteError != nil }, set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: { Text(deleteError ?? "Please try again.") }
    }

    private func delete(_ record: MaintenanceRecord) {
        modelContext.delete(record)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deleteError = "The record could not be deleted. \(error.localizedDescription)"
        }
    }
}
