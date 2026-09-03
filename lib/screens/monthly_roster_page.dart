import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'supabase_service.dart';

class MonthlyRosterPage extends StatefulWidget {
  final String branchId;
  const MonthlyRosterPage({super.key, required this.branchId});
  @override State<MonthlyRosterPage> createState() => _MonthlyRosterPageState();
}

class _MonthlyRosterPageState extends State<MonthlyRosterPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String search = '';

  Future<List<dynamic>> _load() => Future.wait([
    SupabaseService.getEmployeesByBranch(widget.branchId),
    SupabaseService.getMonthlyRosters(branchId: widget.branchId, year: month.year, month: month.month),
  ]);

  Future<void> _edit(Map<String, dynamic> employee, List<Map<String, dynamic>> rosters) async {
    final id = (employee['employee_id'] ?? employee['id']).toString();
    final starts = List.generate(5, (i) => TextEditingController(text: rosters.where((r) => r['employee_id'].toString()==id && r['week_number']==i+1).firstOrNull?['shift_start']?.toString().substring(0,5) ?? '09:00'));
    final ends = List.generate(5, (i) => TextEditingController(text: rosters.where((r) => r['employee_id'].toString()==id && r['week_number']==i+1).firstOrNull?['shift_end']?.toString().substring(0,5) ?? '17:30'));
    final breaks = List.generate(5, (i) => TextEditingController(text: rosters.where((r) => r['employee_id'].toString()==id && r['week_number']==i+1).firstOrNull?['break_minutes']?.toString() ?? '60'));
    final offDays = List<int?>.generate(5, (i) {
      final value = rosters.where((r) => r['employee_id'].toString()==id && r['week_number']==i+1).firstOrNull?['off_weekday'];
      return value is int ? value : int.tryParse(value?.toString() ?? '');
    });
    const weekdayNames = {1:'Mon',2:'Tue',3:'Wed',4:'Thu',5:'Fri',6:'Sat',7:'Sun'};
    final save = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text('Roster — ${employee['name'] ?? id}'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 8), child: Row(children: [SizedBox(width:65, child: Text('Week ${i+1}')), Expanded(child: TextField(controller: starts[i], decoration: const InputDecoration(labelText:'Start', isDense:true))), const SizedBox(width:8), Expanded(child: TextField(controller: ends[i], decoration: const InputDecoration(labelText:'End', isDense:true))), const SizedBox(width:8), SizedBox(width:95, child: TextField(controller: breaks[i], decoration: const InputDecoration(labelText:'Break', isDense:true), keyboardType: TextInputType.number)), const SizedBox(width:8), SizedBox(width:105, child: DropdownButtonFormField<int?>(initialValue:offDays[i],decoration:const InputDecoration(labelText:'OFF day',isDense:true),items:[const DropdownMenuItem<int?>(value:null,child:Text('None')),...weekdayNames.entries.map((e)=>DropdownMenuItem<int?>(value:e.key,child:Text(e.value)))],onChanged:(v)=>setDialogState(()=>offDays[i]=v)))]),
      )))),
      actions: [TextButton(onPressed:()=>Navigator.pop(context,false), child:const Text('Cancel')), FilledButton(onPressed:()=>Navigator.pop(context,true), child:const Text('Save'))],
    )));
    if (save == true) {
      for (var i=0;i<5;i++) {
        await SupabaseService.saveMonthlyRoster({'branch_id':widget.branchId,'employee_id':id,'roster_year':month.year,'roster_month':month.month,'week_number':i+1,'shift_start':starts[i].text.trim(),'shift_end':ends[i].text.trim(),'break_minutes':int.tryParse(breaks[i].text)??60,'off_weekday':offDays[i],'updated_at':DateTime.now().toUtc().toIso8601String()});
      }
      if (mounted) setState(() {});
    }
    for (final c in [...starts,...ends,...breaks]) { c.dispose(); }
  }

  @override Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future:_load(), builder:(context,snapshot) {
      if(snapshot.connectionState==ConnectionState.waiting) return const Center(child:CircularProgressIndicator());
      if(snapshot.hasError) return Center(child:Text('Unable to load roster:\n${snapshot.error}', textAlign:TextAlign.center));
      final employees=List<Map<String,dynamic>>.from(snapshot.data![0] as List).where((e){final q=search.toLowerCase(); return q.isEmpty || (e['name']??'').toString().toLowerCase().contains(q)||(e['employee_id']??'').toString().toLowerCase().contains(q);}).toList();
      final rosters=List<Map<String,dynamic>>.from(snapshot.data![1] as List);
      return ListView(padding:const EdgeInsets.all(20), children:[
        const Text('Monthly Roster',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)), const SizedBox(height:12),
        Wrap(spacing:10,children:[OutlinedButton.icon(icon:const Icon(Icons.calendar_month),label:Text(DateFormat('MMMM yyyy').format(month)),onPressed:() async {final d=await showDatePicker(context:context,initialDate:month,firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null)setState(()=>month=DateTime(d.year,d.month));}),SizedBox(width:280,child:TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search employee',isDense:true)))]),
        const SizedBox(height:14),
        ...employees.map((e){final id=(e['employee_id']??e['id']).toString();final count=rosters.where((r)=>r['employee_id'].toString()==id).length;return Card(child:ListTile(dense:true,leading:CircleAvatar(child:Text((e['name']??'?').toString()[0])),title:Text((e['name']??id).toString()),subtitle:Text('$id • $count/5 weeks assigned'),trailing:const Icon(Icons.edit_calendar),onTap:()=>_edit(e,rosters)));}),
      ]);
    });
}
