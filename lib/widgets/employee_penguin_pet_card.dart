import 'package:flutter/material.dart';
import '../services/neon_api.dart';

/// Server-backed penguin companion. Pet age and care cooldowns are authoritative.
class EmployeePenguinPetCard extends StatefulWidget {
  const EmployeePenguinPetCard({super.key});
  @override
  State<EmployeePenguinPetCard> createState()=>_EmployeePenguinPetCardState();
}
class _EmployeePenguinPetCardState extends State<EmployeePenguinPetCard> {
  Map<String,dynamic>? pet;
  bool busy=false;
  String? error;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load([String? action]) async {
    if(busy)return;
    setState((){busy=true;error=null;});
    try {
      final data=await NeonApi.jsonRequest(
        action==null?'/api/employee/penguin':'/api/employee/penguin/$action',
        method:action==null?'GET':'POST',
      );
      if(mounted)setState(()=>pet=Map<String,dynamic>.from(data['pet'] as Map));
    } catch (_) {
      if(mounted)setState(()=>error='Penguin home is temporarily unavailable.');
    } finally {if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context) {
    final stage=pet?['stage']?.toString()??'egg';
    final days=pet?['ageDays']??0;
    final fed=pet?['fedToday']==true,played=pet?['playedToday']==true;
    return Card(
      clipBehavior:Clip.antiAlias,
      child:Container(
        decoration:const BoxDecoration(gradient:LinearGradient(
          begin:Alignment.topCenter,end:Alignment.bottomCenter,
          colors:[Color(0xFFB6DFF4),Color(0xFFF3FBFF)])),
        padding:const EdgeInsets.all(18),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('MY LIVING PENGUIN',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:Color(0xFF173D60))),
          const SizedBox(height:12),
          Center(child:Semantics(
            label:'Penguin growth stage: $stage',
            child:AnimatedSwitcher(duration:const Duration(milliseconds:400),
              child:PenguinIllustration(key:ValueKey(stage),stage:stage)),
          )),
          Center(child:Text('${pet?['nickname']??'Pingu'} • Day $days • ${stage.toUpperCase()}',
            style:const TextStyle(fontWeight:FontWeight.w700))),
          const SizedBox(height:12),
          if(error!=null) Text(error!,style:const TextStyle(color:Colors.red)),
          if(pet==null && busy)const Center(child:CircularProgressIndicator()),
          Wrap(spacing:8,runSpacing:8,children:[
            FilledButton.icon(onPressed:busy||pet==null||fed?null:()=>_load('feed'),
              icon:const Icon(Icons.set_meal),label:Text(fed?'Fed today':'Feed fish')),
            OutlinedButton.icon(onPressed:busy||pet==null||played?null:()=>_load('play'),
              icon:const Icon(Icons.sports_esports),label:Text(played?'Played today':'Play')),
            IconButton(tooltip:'Refresh penguin',onPressed:busy?null:()=>_load(),
              icon:const Icon(Icons.refresh)),
          ]),
          const SizedBox(height:6),
          const Text('Your penguin grows with time, even when you are away. Feeding and play become available again after 24 hours.',
            style:TextStyle(fontSize:12,color:Color(0xFF425F74))),
        ]),
      ),
    );
  }
}
class PenguinIllustration extends StatefulWidget {
  const PenguinIllustration({super.key,required this.stage});
  final String stage;
  @override
  State<PenguinIllustration> createState()=>_PenguinIllustrationState();
}
class _PenguinIllustrationState extends State<PenguinIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController motion=AnimationController(vsync:this,
    duration:const Duration(seconds:3))..repeat(reverse:true);
  @override
  void dispose(){motion.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>SizedBox(height:190,width:210,
    child:AnimatedBuilder(animation:motion,builder:(context,child)=>
      Transform.translate(offset:Offset(0,motion.value*3),child:child),
      child:CustomPaint(painter:_PenguinPainter(widget.stage))));
}
class _PenguinPainter extends CustomPainter {
  _PenguinPainter(this.stage);
  final String stage;
  @override
  void paint(Canvas c,Size s){
    final body=Paint()..color=const Color(0xFF202F3A);
    final white=Paint()..color=const Color(0xFFF8FBFD);
    final orange=Paint()..color=const Color(0xFFEFA547);
    c.drawOval(Rect.fromLTWH(25,166,160,18),Paint()..color=const Color(0x44265A78));
    if(stage=='egg'){
      c.drawOval(Rect.fromLTWH(63,30,85,132),white);
      c.drawArc(Rect.fromLTWH(63,30,85,132),0,6.28,false,
        Paint()..color=const Color(0xFFB6C9D3)..style=PaintingStyle.stroke..strokeWidth=3);
      return;
    }
    final scale=stage=='chick'?.73:stage=='juvenile'?.87:1.0;
    c.save();c.translate(s.width/2,166);c.scale(scale);c.translate(-s.width/2,-166);
    c.drawOval(Rect.fromLTWH(55,40,100,125),body);
    c.drawOval(Rect.fromLTWH(72,79,66,81),white);
    c.drawOval(Rect.fromLTWH(43,95,26,63),body);
    c.drawOval(Rect.fromLTWH(141,95,26,63),body);
    c.drawOval(Rect.fromLTWH(65,154,36,15),orange);
    c.drawOval(Rect.fromLTWH(112,154,36,15),orange);
    c.drawCircle(const Offset(88,83),5,white);
    c.drawCircle(const Offset(124,83),5,white);
    c.drawCircle(const Offset(89,83),2.5,body);
    c.drawCircle(const Offset(125,83),2.5,body);
    final beak=Path()..moveTo(96,96)..lineTo(115,96)..lineTo(106,109)..close();
    c.drawPath(beak,orange);
    c.restore();
  }
  @override
  bool shouldRepaint(covariant _PenguinPainter old)=>old.stage!=stage;
}
