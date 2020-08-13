// Copyright (c) 2018, Steve Rogers. All rights reserved. Use of this source code
// is governed by an Apache License 2.0 that can be found in the LICENSE file.
library oscilloscope;

import 'dart:math' as Math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:math';
/// A widget that defines a customisable Oscilloscope type display that can be used to graph out data
///
/// The [dataSet] arguments MUST be a List<double> -  this is the data that is used by the display to generate a trace
///
/// All other arguments are optional as they have preset values
///
/// [showYAxis] this will display a line along the yAxisat 0 if the value is set to true (default is false)
/// [yAxisColor] determines the color of the displayed yAxis (default value is Colors.white)
///
/// [yAxisMin] and [yAxisMax] although optional should be set to reflect the data that is supplied in [dataSet]. These values
/// should be set to the min and max values in the supplied [dataSet].
///
/// For example if the max value in the data set is 2.5 and the min is -3.25  then you should set [yAxisMin] = -3.25 and [yAxisMax] = 2.5
/// This allows the oscilloscope display to scale the generated graph correctly.
///
/// You can modify the background color of the oscilloscope with the [backgroundColor] argument and the color of the trace with [traceColor]
///
/// The [padding] argument allows space to be set around the display (this defaults to 10.0 if not specified)
///
/// NB: This is not a Time Domain trace, the update frequency of the supplied [dataSet] determines the trace speed.
class Oscilloscope extends StatefulWidget {
  final List<double> dataSet;
  final double yAxisMin;
  final double yAxisMax;
  final double padding;
  final Color backgroundColor;
  final Color traceColor;
  final Color yAxisColor;
  final bool showYAxis;
  final double xScale;
  final bool isScrollable;
  final bool isZoomable;
  final bool isAdaptiveRange;
  final bool willNormalizeData;
  final GridDrawingSetting gridDrawingSetting;
  final double strokeWidth;
  Function(double x, double y) onScaleChange;

  Oscilloscope(
      {this.traceColor = Colors.white,
        this.backgroundColor = Colors.black,
        this.yAxisColor = Colors.white,
        this.padding = 10.0,
        this.yAxisMax = 1.0,
        this.yAxisMin = 0.0,
        this.showYAxis = false,
        this.xScale = 1.0,
        this.isScrollable = false,
        this.isZoomable = false,
        this.isAdaptiveRange = false,
        this.willNormalizeData = false,
        this.gridDrawingSetting,
        this.strokeWidth = 2.0,
        @required this.dataSet,
        this.onScaleChange
      });

  @override
  _OscilloscopeState createState() => _OscilloscopeState();
}

class _OscilloscopeState extends State<Oscilloscope> {
  double yRange;
  double yScale;

  double yZoomFactor = 1.0;
  double xZoomFactor = 1.0;
  double prevXValue;
  double prevYValue;

  double verticalDragStart;

  double yMin;
  double yMax;
  List<double> normaliedDataSet;
  ScrollController _scrollController = ScrollController(keepScrollOffset: true);

  GlobalKey _widgetKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.willNormalizeData) {
      yMax = 1;
      yMin = 0;
      yRange = 1;
    }else{
      yMax = widget.yAxisMax;
      yMin = widget.yAxisMin;
      yRange = yMax - yMin;
    }
  }

  void notifyScaleChangeIfNeeded(){
    if(widget.onScaleChange == null){
      return;
    }
    widget.onScaleChange(xZoomFactor,yZoomFactor);
  }

  @override
  Widget build(BuildContext context) {
    scrollToEndIfNeeded(context);
    normalizeDataIfNeeded();
    updateYRangeIfNeeded();
    return GestureDetector(
      onVerticalDragUpdate: (details){
        if (widget.isZoomable) {
          setState(() {
            yZoomFactor = yZoomFactor + ((details.primaryDelta >= 0) ? 0.05 : -0.05);
          });
          notifyScaleChangeIfNeeded();
        }
      },
      onScaleStart: (state){
        prevXValue = xZoomFactor;
//        prevYValue = yZoomFactor;
      },
      onScaleUpdate: (state){
        if (widget.isZoomable) {
          setState(() {
            xZoomFactor = prevXValue * state.horizontalScale;
//            yZoomFactor = prevYValue * state.verticalScale;
          });
          notifyScaleChangeIfNeeded();
        }
      },
      onScaleEnd: (_){
        prevXValue = null;
        prevYValue = null;
      },
      child: Stack(
        children: <Widget>[SingleChildScrollView(
          key: _widgetKey,
          physics: ClampingScrollPhysics(),
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: getWidth(context),
            child: Container(
              padding: EdgeInsets.all(widget.padding),
              width: double.infinity,
              height: double.infinity,
              color: widget.backgroundColor,
              child: ClipRect(
                child: CustomPaint(
                  painter: _TracePainter(
                      showYAxis: widget.showYAxis,
                      yAxisColor: widget.yAxisColor,
                      dataSet: normaliedDataSet,
                      traceColor: widget.traceColor,
                      yMin: yMin,
                      yRange: yRange,
                      xScale: widget.xScale * xZoomFactor,
                      isScrollable: widget.isScrollable,
                      gridDrawingSetting: widget.gridDrawingSetting,
                      strokeWidth: widget.strokeWidth
                  ),
                ),
              ),
            ),
          ),
        ),
          Positioned(
            bottom: 0,
            left: 0,
            child: (yZoomFactor != 1.0 || xZoomFactor != 1.0) ? IconButton(
              icon: Icon(Icons.refresh, color: widget.traceColor,),
              onPressed: (){
                setState(() {
                  yZoomFactor = 1.0;
                  xZoomFactor = 1.0;
                  notifyScaleChangeIfNeeded();
                });
              },
            ) : Container(),
          )
        ],
      ),
    );
  }

  void normalizeDataIfNeeded(){
    if (widget.willNormalizeData) {
      normaliedDataSet = getNormalizedData(widget.dataSet);
    }else{
      normaliedDataSet = widget.dataSet;
    }
  }

  List<double> getNormalizedData(List<double> dataSet){
    if (dataSet.length > 0) {
      List<double> dataArray = [];
      double min =  dataSet.reduce(Math.min);
      double max =  dataSet.reduce(Math.max);
      for(int i = 0;i<dataSet.length;i++){
        if (max == min) {
          dataArray.add(0.5);
        }else{
          double normalized = (dataSet[i] - min) / (max-min);
          dataArray.add(normalized);
        }
      }
      return dataArray;
    }else{
      return [];
    }
  }

  void updateYRangeIfNeeded(){
    if (widget.isAdaptiveRange && normaliedDataSet.length > 0) {
      yMin = normaliedDataSet.reduce(Math.min) * 1.1;
      yMax = normaliedDataSet.reduce(Math.max) * 1.1;
    }else{
      yMin = widget.yAxisMin;
      yMax = widget.yAxisMax;
    }
    yMin = yMin;
    yMax = yMax;
    yRange = (yMax - yMin)*yZoomFactor;
  }

  void scrollToEndIfNeeded(BuildContext context){
    if (!widget.isScrollable || context == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_){
      try{
        double width = MediaQuery.of(context).size.width;
        if (widget.dataSet.length*widget.xScale > width) {
          if (!_scrollController.position.isScrollingNotifier.value && _scrollController.offset > _scrollController.position.maxScrollExtent - 100 ) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        }
      }catch(exception){
        print("Got Error from osciloscope: $exception");
      }
    });
  }

  double getWidth(BuildContext context){
    double mediaQueryWidth = MediaQuery.of(context).size.width;
    double width = mediaQueryWidth * xZoomFactor;
    if (!widget.isScrollable) {
      return mediaQueryWidth;
    }
    if (widget.dataSet.length == 0) {
      return width;
    }
    double calculatedWidth = widget.dataSet.length.toDouble()*widget.xScale*xZoomFactor;
    if (calculatedWidth <= mediaQueryWidth) {
      calculatedWidth = mediaQueryWidth;
    }
    return calculatedWidth;
  }
}

/// A Custom Painter used to generate the trace line from the supplied dataset
class _TracePainter extends CustomPainter {
  final List dataSet;
  final double xScale;
  final double yMin;
  final Color traceColor;
  final Color yAxisColor;
  final bool showYAxis;
  final double yRange;
  final bool isScrollable;
  final GridDrawingSetting gridDrawingSetting;
  final double strokeWidth;

  _TracePainter(
      {this.showYAxis,
        this.yAxisColor,
        this.yRange,
        this.yMin,
        this.dataSet,
        this.xScale = 1.0,
        this.traceColor = Colors.white,
        this.isScrollable = false,
        this.gridDrawingSetting,
        this.strokeWidth = 2.0
      });

  @override
  void paint(Canvas canvas, Size size) {
    final tracePaint = Paint()
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = traceColor
      ..style = PaintingStyle.stroke;

    final axisPaint = Paint()
      ..strokeWidth = 1.0
      ..color = yAxisColor;

    double yScale = (size.height / yRange);
    // only start plot if dataset has data
    int length = dataSet.length;

    //If GRid Drawing is enabled
    if (gridDrawingSetting != null) {
      final gridPaint = Paint()
        ..color = gridDrawingSetting.gridColor
        ..strokeWidth = gridDrawingSetting.strokeWidth;

      if (gridDrawingSetting.drawXAxisGrid) {
        for (int i = 0;i<size.height;i = i + gridDrawingSetting.xAxisGridSpace){
          canvas.drawLine(Offset(0,i.toDouble()), Offset(size.width,i.toDouble()), gridPaint);
        }
      }
      if (gridDrawingSetting.drawYAxisGrid) {
        for (int i = 0;i<size.width;i = i + gridDrawingSetting.yAxisGridSpace){
          canvas.drawLine(Offset(i.toDouble(),0), Offset(i.toDouble(),size.height), gridPaint);
        }
      }
    }

    // if yAxis required draw it here
    if (showYAxis) {
      double centerPoint = size.height - (0.0 - yMin) * yScale;
      Offset yStart = Offset(0.0, centerPoint);
      Offset yEnd = Offset(size.width, centerPoint);
      canvas.drawLine(yStart, yEnd, axisPaint);
    }

    if (length > 0) {
      // transform data set to just what we need if bigger than the width(otherwise this would be a memory hog)
      if (!isScrollable) {
        int maxSize = (size.width.toDouble() ~/ xScale) + 1;
        if (length > maxSize) {
          dataSet.removeRange(0, length - maxSize);
          length = dataSet.length;
        }
      }


      // Create Path and set Origin to first data point
      Path trace = Path();
      trace.moveTo(0.0, size.height - (dataSet[0].toDouble() - yMin) * yScale);

      // generate trace path
      for (int p = 0; p < length; p++) {
        double plotPoint =
            size.height - ((dataSet[p].toDouble() - yMin) * yScale);
        if (p == 0) {
        }
        trace.lineTo(p.toDouble() * (xScale), plotPoint);
      }

      // display the trace
      canvas.drawPath(trace, tracePaint);
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) => true;
}

class GridDrawingSetting{
  final bool drawXAxisGrid;
  final bool drawYAxisGrid;
  final int xAxisGridSpace;
  final int yAxisGridSpace;
  final Color gridColor;
  final double strokeWidth;

  GridDrawingSetting(this.drawXAxisGrid, this.drawYAxisGrid,
      {this.xAxisGridSpace = 10, this.yAxisGridSpace = 10,this.gridColor = Colors.grey,this.strokeWidth = 0.5});
}