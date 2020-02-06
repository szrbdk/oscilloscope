/// Demo of using the oscilloscope package
///
/// In this demo 2 displays are generated showing the outputs for Sine & Cosine
/// The scope displays will show the data sets  which will fill the yAxis and then the screen display will 'scroll'
import 'package:flutter/material.dart';
import 'package:oscilloscope/oscilloscope.dart';
import 'dart:math';
import 'dart:async';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: "Oscilloscope Display Example",
      home: Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  @override
  _ShellState createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  List<double> traceSine = List();
  List<double> traceCosine = List();
  double radians = 0.0;
  Timer _timer;

  var isNegative = false;

  var heightScale = 1.0;

//  ScrollController _scrollController = ScrollController(keepScrollOffset: true);
  /// method to generate a Test  Wave Pattern Sets
  /// this gives us a value between +1  & -1 for sine & cosine
  _generateTrace(Timer t) {
    // generate our  values
//    var sv = sin((radians * pi));
    var sv = Random().nextDouble()*(Random().nextDouble()*100) * (Random().nextBool() ? 1 : -1);
    if (DateTime.now().second == 30 || DateTime.now().second == 0) {
      isNegative = !isNegative;
    }
    var cv = 5 * (isNegative ? 1 : -1);

    // Add to the growing dataset
    setState(() {
      traceSine.add(sv);
      traceCosine.add(cv.toDouble());
    });

    // adjust to recyle the radian value ( as 0 = 2Pi RADS)
    radians += 0.05;
    if (radians >= 2.0) {
      radians = 0.0;
    }
  }

  @override
  initState() {
    super.initState();
    // create our timer to generate test values
    _timer = Timer.periodic(Duration(milliseconds: 128), _generateTrace);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  double prevScale;

  @override
  Widget build(BuildContext context) {
    // Create A Scope Display for Sine
    Widget scopeOne = Oscilloscope(
      showYAxis: true,
      yAxisColor: Colors.orange,
      padding: 20.0,
      backgroundColor: Colors.white,
      traceColor: Colors.black,
      yAxisMax: 1000*heightScale,
      yAxisMin: -1000*heightScale,
      xScale: 5.0,
      dataSet: traceSine,
      isScrollable: false,
      isZoomable: true,
      gridDrawingSetting: GridDrawingSetting(
          true,true, 
          xAxisGridSpace: 10,
          yAxisGridSpace: 10,
          gridColor: Colors.black26.withAlpha(50)
      ),
    );
//    Widget scopeOne = GestureDetector(
//      onScaleStart: (state){
//        prevScale = heightScale;
//      },
//      onScaleUpdate: (state){
//        print("Scale State: ${state.verticalScale}");
//        setState(() {
//          heightScale = prevScale * state.scale;
//        });
//      },
//      onScaleEnd: (_){
//        prevScale = null;
//      },
//      child: Oscilloscope(
//        showYAxis: true,
//        yAxisColor: Colors.orange,
//        padding: 20.0,
//        backgroundColor: Colors.white,
//        traceColor: Colors.black,
//        yAxisMax: 1000*heightScale,
//        yAxisMin: -1000*heightScale,
//        xScale: 5.0,
//        dataSet: traceSine,
//        isScrollable: true,
//      ),
//    );

    // Create A Scope Display for Cosine
    Oscilloscope scopeTwo = Oscilloscope(
      showYAxis: true,
      padding: 20.0,
      backgroundColor: Colors.black,
      traceColor: Colors.yellow,
      yAxisMax: 10.0,
      yAxisMin: -10.0,
      xScale: 5.0,
      dataSet: traceCosine,
      isZoomable: true,
    );

    // Generate the Scaffold
    return Scaffold(
      appBar: AppBar(
        title: Text("OscilloScope Demo"),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            onPressed: (){
              setState(() {
                heightScale = heightScale + 0.1;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.minimize),
            onPressed: (){
              setState(() {
                heightScale = heightScale - 0.1;
              });
            },
          )
        ],
      ),
      body:

      Column(
        children: <Widget>[
          Expanded(flex: 1, child: scopeOne),
//          Expanded(
//            flex: 1,
//            child: scopeTwo,
//          ),
        ],
      ),
    );
  }
  double getWidth(BuildContext context){
    double minWidth = MediaQuery.of(context).size.width; 
//    if (traceSine.length <= minWidth) {
//      return minWidth;
//    }else{
      return traceSine.length.toDouble()*5.0;
//    }
  }
}
