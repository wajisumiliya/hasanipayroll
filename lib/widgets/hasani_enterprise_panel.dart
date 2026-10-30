import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'modern_admin_overview.dart';

/// Reference-inspired responsive admin command center.
/// No sample figures are presented as genuine financial or attendance data.
class HasaniEnterprisePanel extends StatelessWidget {
  const HasaniEnterprisePanel({
    super.key, required this.metrics, required this.branches,
    required this.gross, required this.net, required this.deductions,
    required this.month, required this.onNavigate, required this.onGross,
    required this.onNet, required this.breakdown, required this.tools,
    this.reports,
  });
  final AdminOverviewMetrics metrics;
  final Map<String,String> branches;
  final double gross,net,deductions;
  final DateTime month;
  final ValueChanged<int> onNavigate;
  final VoidCallback onGross,onNet;
  final Widget breakdown,tools;
  final Widget? reports;

  static const navy=Color(0xff10213B), blue=Color(0xff2764E9),
    teal=Color(0xff0FBAA2), green=Color(0xff11B873),
    red=Color(0xffF04B59), amber=Color(0xffF7A531),
    violet=Color(0xff8B5CF6), muted=Color(0xff687C99), border=Color(0xffE5ECF5);
  String currency(num v)=>NumberFormat.currency(locale:'en_MY',symbol:'RM ',decimalDigits:0).format(v);

  Widget card(String title, Widget body,{Widget? action})=>Container(
    padding:const EdgeInsets.all(13),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
      border:Border.all(color:border),boxShadow:const [BoxShadow(color:Color(0x0A183B6A),blurRadius:14,offset:Offset(0,3))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text(title,style:const TextStyle(color:navy,fontSize:14,fontWeight:FontWeight.w800))),
        if(action!=null) action]),const SizedBox(height:12),body,
    ]));

  Widget metric(String label,String value,IconData icon,Color color,{VoidCallback? onTap})=>
    Material(color:Colors.white,borderRadius:BorderRadius.circular(12),child:InkWell(
      onTap:onTap,borderRadius:BorderRadius.circular(12),
      child:Container(padding:const EdgeInsets.all(12),
        decoration:BoxDecoration(border:Border.all(color:border),borderRadius:BorderRadius.circular(12)),
        child:Row(children:[
          Container(width:40,height:40,decoration:BoxDecoration(color:color.withValues(alpha:.10),borderRadius:BorderRadius.circular(10)),
            child:Icon(icon,color:color,size:22)),
          const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(label,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w600,color:muted),maxLines:2),
            const SizedBox(height:4),
            FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,
              child:Text(value,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:navy))),
          ]))
        ]))));

  Widget tiled(double width,List<Widget> widgets,{double min=190,double gap=10}) {
    final count=math.max(1,((width+gap)/(min+gap)).floor());
    final tileWidth=(width-gap*(count-1))/count;
    return Wrap(spacing:gap,runSpacing:gap,children:[
      for(final w in widgets) SizedBox(width:tileWidth,child:w)
    ]);
  }
  Widget pair(double width,Widget a,Widget b,{double breakpoint=870,double first=.55}) {
    if(width<breakpoint)return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[a,const SizedBox(height:10),b]);
    return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Expanded(flex:(first*100).round(),child:a),const SizedBox(width:10),
      Expanded(flex:((1-first)*100).round(),child:b)]);
  }
  Widget bar(String label,double value,double maximum,Color color,{String? formatted})=>
    Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text(label,style:const TextStyle(fontSize:11.5,color:navy))),
        Text(formatted??currency(value),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:navy))]),
      const SizedBox(height:6),
      ClipRRect(borderRadius:BorderRadius.circular(5),child:LinearProgressIndicator(
        value:maximum<=0?0:(value/maximum).clamp(0.0,1.0),
        minHeight:13,backgroundColor:const Color(0xffEDF2FA),color:color))
    ]));
  Widget heading(String title,String subtitle)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800,color:navy)),
    const SizedBox(height:3),Text(subtitle,style:const TextStyle(fontSize:10,color:muted))
  ]);
  Widget chip(String text,Color color)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
    decoration:BoxDecoration(color:color.withValues(alpha:.10),borderRadius:BorderRadius.circular(7)),
    child:Text(text,style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:color)));

  Widget financial() {
    final max=math.max(1.0,[gross,net,deductions].reduce(math.max));
    return Column(children:[
      bar('Gross Salary',gross,max,blue),
      bar('Net Salary',net,max,teal),
      bar('Deductions',deductions,max,red),
      const SizedBox(height:8),
      Row(children:[
        Expanded(child:OutlinedButton(onPressed:onGross,child:const Text('Gross details'))),
        const SizedBox(width:8),
        Expanded(child:OutlinedButton(onPressed:onNet,child:const Text('Net details')))
      ])
    ]);
  }
  Widget payrollSplit()=>Column(children:[
    SizedBox(height:122,child:Row(children:[
      SizedBox(width:114,height:114,child:CustomPaint(
        painter:_RingPainter([math.max(net,0.0),math.max(deductions,0.0)],[green,amber]),
        child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('GROSS',style:TextStyle(fontSize:9,color:muted,fontWeight:FontWeight.w700)),
          FittedBox(fit:BoxFit.scaleDown,child:Text(currency(gross),
            style:const TextStyle(fontSize:14,color:navy,fontWeight:FontWeight.w900)))
        ])))),
      const SizedBox(width:14),
      Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        _legend('Net Salary',currency(net),green),
        const SizedBox(height:12),
        _legend('Deductions',currency(deductions),amber),
      ])),
    ])),
    const Divider(height:18),
    const Text('Paid, pending and instant settlement figures require verified payment-status records.',
      style:TextStyle(fontSize:10,color:muted))
  ]);
  Widget _legend(String label,String value,Color color)=>Row(children:[
    Container(width:9,height:9,decoration:BoxDecoration(color:color,shape:BoxShape.circle)),
    const SizedBox(width:6),
    Expanded(child:Text(label,style:const TextStyle(fontSize:10,color:muted))),
    Text(value,style:const TextStyle(fontSize:11,color:navy,fontWeight:FontWeight.w700)),
  ]);
  Widget attendance() {
    final present=metrics.present,late=metrics.lateIds?.length,absent=metrics.notChecked,off=metrics.offIds?.length;
    Widget small(String label,String value,Color color,IconData icon)=>Container(
      padding:const EdgeInsets.all(9),
      decoration:BoxDecoration(color:color.withValues(alpha:.08),borderRadius:BorderRadius.circular(9)),
      child:Row(children:[Icon(icon,size:19,color:color),const SizedBox(width:8),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(label,style:const TextStyle(fontSize:10,color:muted)),
          Text(value,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:navy))
        ]))]));
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      LayoutBuilder(builder:(context,c)=>tiled(c.maxWidth,[
        small('Present',present?.toString()??'—',green,Icons.how_to_reg),
        small('Missing',absent?.toString()??'—',red,Icons.person_off_outlined),
        small('Late',late?.toString()??'—',amber,Icons.schedule),
        small('On leave / off',off?.toString()??'—',blue,Icons.event_busy),
      ],min:130,gap:8)),
      const SizedBox(height:13),
      heading('Attendance Monitoring','Live status for the selected branch'),
      const SizedBox(height:10),
      if(metrics.checkedIn==null) const Text('Attendance records have not loaded.',style:TextStyle(color:muted,fontSize:11))
      else ...[
        bar('Checked-in employees',metrics.checkedIn!.length.toDouble(),math.max(1,metrics.activeIds.length).toDouble(),green,
          formatted:'${metrics.checkedIn!.length} / ${metrics.activeIds.length}'),
        bar('Late check-ins',(late??0).toDouble(),math.max(1,metrics.activeIds.length).toDouble(),amber,formatted:'${late??0}'),
      ],
      const SizedBox(height:10),
      Align(alignment:Alignment.centerRight,child:TextButton.icon(
        onPressed:()=>onNavigate(4),icon:const Icon(Icons.arrow_forward,size:15),label:const Text('Review attendance')))
    ]);
  }
  Widget branchTable() {
    final groups=<String,int>{};
    for(final e in metrics.people) {
      final id=AdminOverviewMetrics.key(e['branch_id']);
      if(id.isNotEmpty)groups[id]=(groups[id]??0)+1;
    }
    final sorted=groups.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    return Column(children:[
      const Row(children:[
        Expanded(flex:4,child:Text('BRANCH',style:TextStyle(color:muted,fontSize:10,fontWeight:FontWeight.w800))),
        Expanded(child:Text('STAFF',textAlign:TextAlign.right,style:TextStyle(color:muted,fontSize:10,fontWeight:FontWeight.w800))),
        SizedBox(width:76,child:Text('STATUS',textAlign:TextAlign.right,style:TextStyle(color:muted,fontSize:10,fontWeight:FontWeight.w800)))
      ]),
      const Divider(height:14),
      if(sorted.isEmpty) const Padding(padding:EdgeInsets.all(10),child:Text('No branch records available')),
      for(final entry in sorted.take(7)) Padding(
        padding:const EdgeInsets.symmetric(vertical:6),child:Row(children:[
          Expanded(flex:4,child:Text(branches[entry.key]??entry.key,overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontSize:11,color:navy,fontWeight:FontWeight.w700))),
          Expanded(child:Text('${entry.value}',textAlign:TextAlign.right,style:const TextStyle(fontSize:11))),
          const SizedBox(width:8),
          chip('Active',green)
        ])),
      Align(alignment:Alignment.centerRight,child:TextButton(
        onPressed:()=>onNavigate(2),child:const Text('View all branches')))
    ]);
  }
  Widget salaryAnalytics()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    heading('Salary Components (RM)','Verified gross, net and deductions'),
    const SizedBox(height:7),financial(),
    const Divider(height:18),
    heading('Salary Increment Review','View and approve recorded changes'),
    const SizedBox(height:7),
    OutlinedButton.icon(onPressed:()=>onNavigate(3),
      icon:const Icon(Icons.trending_up,size:17),label:const Text('Open detailed salary records'))
  ]);
  Widget actions()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    LayoutBuilder(builder:(context,c)=>tiled(c.maxWidth,[
      _action('Run Payroll',Icons.play_circle_fill,blue,()=>onNavigate(3)),
      _action('Generate Payslips',Icons.receipt_long,green,()=>onNavigate(12)),
      _action('Export Excel',Icons.table_chart,teal,()=>onNavigate(6)),
      _action('Review Attendance',Icons.calendar_month,violet,()=>onNavigate(4)),
      _action('Approvals',Icons.task_alt,amber,()=>onNavigate(3)),
    ],min:115,gap:8))
  ]);
  Widget _action(String label,IconData icon,Color color,VoidCallback tap)=>Material(
    color:color.withValues(alpha:.08),borderRadius:BorderRadius.circular(9),
    child:InkWell(onTap:tap,borderRadius:BorderRadius.circular(9),
      child:Padding(padding:const EdgeInsets.symmetric(horizontal:8,vertical:13),
        child:Column(children:[Icon(icon,color:color,size:25),const SizedBox(height:7),
          Text(label,textAlign:TextAlign.center,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w700,color:navy))]))));

  @override
  Widget build(BuildContext context)=>LayoutBuilder(builder:(context,c){
    final width=math.max(1.0,c.maxWidth);
    final rate=metrics.activeIds.isEmpty||metrics.present==null?'—':
      '${(metrics.present!/metrics.activeIds.length*100).toStringAsFixed(1)}%';
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      tiled(width,[
        metric('Total Employees','${metrics.people.length}',Icons.groups,blue,onTap:()=>onNavigate(1)),
        metric('Monthly Payroll',currency(gross),Icons.account_balance_wallet,blue,onTap:onGross),
        metric('Net Payroll',currency(net),Icons.check_circle,green,onTap:onNet),
        metric('Deductions',currency(deductions),Icons.schedule,red),
        metric('Attendance Rate',rate,Icons.bar_chart,teal,onTap:()=>onNavigate(4)),
        metric('Missing Check-ins','${metrics.notChecked??'—'}',Icons.timer,violet,onTap:()=>onNavigate(4)),
      ],min:width>=1250?185:190),
      const SizedBox(height:11),
      pair(width,
        card('Monthly Payroll Overview',Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          heading(DateFormat('MMMM yyyy').format(month),'Payroll breakdown for the selected month'),
          const SizedBox(height:7),financial(),
          const Text('Historical trends appear when monthly payroll history is connected.',
            style:TextStyle(fontSize:10,color:muted)),
        ])),
        card('Payroll Split',payrollSplit()),first:.60),
      const SizedBox(height:10),
      pair(width,card('Attendance Monitoring',attendance()),
        card('Salary Analytics',salaryAnalytics()),first:.53),
      const SizedBox(height:10),
      pair(width,card('Branch Monitoring',branchTable()),
        Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          card('Quick Actions',actions()),
          const SizedBox(height:10),
          card('Pending Approvals & Alerts',Column(children:[
            _alert('Attendance review','Open missing and late check-ins',red,()=>onNavigate(4)),
            _alert('Payroll review','Review salary calculations',amber,()=>onNavigate(3)),
            _alert('Branch reporting','Review branch activity',blue,()=>onNavigate(9)),
          ]))
        ]),first:.53),
      const SizedBox(height:8),
      ExpansionTile(key:const PageStorageKey('enterprise-details'),title:const Text('Detailed payroll breakdown'),
        children:[breakdown]),
      ExpansionTile(key:const PageStorageKey('enterprise-management'),title:const Text('Additional management tools'),
        children:[tools]),
      if(reports!=null) ExpansionTile(title:const Text('Payroll reports and exports'),children:[reports!]),
    ]);
  });
  Widget _alert(String title,String subtitle,Color color,VoidCallback action)=>InkWell(
    onTap:action,child:Padding(padding:const EdgeInsets.symmetric(vertical:7),
    child:Row(children:[Icon(Icons.notification_important_outlined,color:color,size:20),
      const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:navy)),
        Text(subtitle,style:const TextStyle(fontSize:10,color:muted))])),
      const Icon(Icons.chevron_right,size:17,color:muted)])));
}
class _RingPainter extends CustomPainter {
  _RingPainter(this.values,this.colors);
  final List<double> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas,Size size){
    final r=Rect.fromLTWH(10,10,size.width-20,size.height-20);
    final p=Paint()..style=PaintingStyle.stroke..strokeWidth=13;
    canvas.drawArc(r,0,math.pi*2,false,p..color=const Color(0xffE9EFF7));
    final total=values.fold<double>(0,(a,b)=>a+b);
    if(total<=0)return;
    var start=-math.pi/2;
    for(var i=0;i<values.length;i++){
      final sweep=math.pi*2*values[i]/total;
      canvas.drawArc(r,start,sweep,false,p..color=colors[i]);
      start+=sweep;
    }
  }
  @override bool shouldRepaint(covariant _RingPainter old)=>old.values.toString()!=values.toString();
}
