import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/neon_api.dart';

/// Works with USB HID barcode/QR scanners configured to append Enter.
/// The focus stays on the capture field after each scan.
class QrAttendancePage extends StatefulWidget {
  const QrAttendancePage({super.key});
  @override
  State<QrAttendancePage> createState() => _QrAttendancePageState();
}
class _QrAttendancePageState extends State<QrAttendancePage> {
  final controller=TextEditingController();
  final focusNode=FocusNode();
  bool busy=false;
  String? message;
  String? error;
  String? action;
  @override
  void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_) {if(mounted) focusNode.requestFocus();});}
  @override
  void dispose(){controller.dispose();focusNode.dispose();super.dispose();}
  Future<void> scan(String code) async {
    if(busy) return;
    controller.clear();
    if(!code.startsWith('HBQR1_')) {
      setState((){error='Unrecognized barcode. Scan a Hasani-issued employee QR.';message=null;});
      focusNode.requestFocus();
      return;
    }
    setState((){busy=true;error=null;message=null;});
    try {
      final data=await NeonApi.jsonRequest('/api/qr-attendance/scan',body:{'qr_value':code});
      if(!mounted)return;
      HapticFeedback.mediumImpact();
      setState((){
        action=data['action']?.toString();
        message='${data['name']} (${data['employee_id']}) — ${data['action']} recorded at ${data['scanned_at']}';
      });
    }catch(e){
      if(mounted)setState((){error=e.toString();});
    }finally{
      if(mounted){setState((){busy=false;});focusNode.requestFocus();}
    }
  }
  @override
  Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.all(20),
    child:Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:650),
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Icon(Icons.qr_code_scanner,size:60),
        const SizedBox(height:10),
        Text('Live QR Attendance',textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height:8),
        const Text('Connect a USB QR scanner in keyboard (HID) mode with Enter suffix. Scan an employee QR code to save the current server time.',textAlign:TextAlign.center),
        const SizedBox(height:24),
        TextField(controller:controller,focusNode:focusNode,autofocus:true,enabled:!busy,
          decoration:InputDecoration(labelText:'Ready to scan',border:const OutlineInputBorder(),
            suffixIcon:busy?const SizedBox(width:24,height:24,child:Center(child:CircularProgressIndicator(strokeWidth:2))):const Icon(Icons.qr_code)),
          onSubmitted:scan),
        const SizedBox(height:16),
        if(message!=null) Card(color:Colors.green.shade50,child:Padding(padding:const EdgeInsets.all(16),child:Text(message!,style:const TextStyle(color:Colors.black87)))),
        if(error!=null) Card(color:Colors.red.shade50,child:Padding(padding:const EdgeInsets.all(16),child:Text(error!,style:const TextStyle(color:Colors.black87)))),
        const SizedBox(height:12),
        const Text('Scan IN once and OUT once per day. Corrections and overnight shifts require supervisor review. This log does not automatically overwrite approved payroll attendance.',textAlign:TextAlign.center),
      ]),
    )),
  );
}
