import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/ftracker_provider.dart';

class FinancialTrackerWidget extends StatelessWidget {
  final String? filterType;
  const FinancialTrackerWidget({super.key, this.filterType});

  @override
  Widget build(BuildContext context) {
    final ftrackerProvider = Provider.of<FtrackerProvider>(context);
    final records = ftrackerProvider.records;

    final filteredRecords = filterType == null
        ? records
        : records.where((record) => record.type == filterType).toList();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).primaryColor.withValues(alpha: 0.1)),
              columns: const [
                DataColumn(
                    label: Text('TransID',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Date',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Type',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Category',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Name',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Amount',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Note',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: filteredRecords.map((record) {
                return DataRow(
                  cells: [
                    DataCell(Text(record.transid.toString())),
                    DataCell(
                        Text(DateFormat('MM/dd/yyyy').format(record.date))),
                    DataCell(Text(record.type)),
                    DataCell(Text(record.category)),
                    DataCell(Text(record.name)),
                    DataCell(Text(record.amount.toStringAsFixed(2))),
                    DataCell(Text(record.note ?? '-')),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
