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
      @required this.dataSet});

  @override
  _OscilloscopeState createState() => _OscilloscopeState();
}

class _OscilloscopeState extends State<Oscilloscope> {
  double yRange;
  double yScale;

  double zoomFactor = 1.0;
  double prevValue;

  double yMin;
  double yMax;
  List<double> normaliedDataSet;
  ScrollController _scrollController = ScrollController(keepScrollOffset: true);

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

  @override
  Widget build(BuildContext context) {
    scrollToEndIfNeeded(context);
    normalizeDataIfNeeded();
    updateYRangeIfNeeded();
    return GestureDetector(
      onScaleStart: (state){
        prevValue = zoomFactor;
      },
      onScaleUpdate: (state){
        if (widget.isZoomable) {
          setState(() {
            zoomFactor = prevValue * state.scale;
          });
        }
      },
      onScaleEnd: (_){
        prevValue = null;
      },
      child: SingleChildScrollView(
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
                    xScale: widget.xScale,
                    isScrollable: widget.isScrollable
                ),
              ),
            ),
          ),
        ),
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
      yMin = yMin * zoomFactor;
      yMax = yMax * zoomFactor;
      yRange = yMax - yMin;
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
    double width = MediaQuery.of(context).size.width;
    if (!widget.isScrollable) {
      return width;
    }
    if (widget.dataSet.length == 0) {
      return width;
    }
    return widget.dataSet.length.toDouble()*widget.xScale;
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
  _TracePainter(
      {this.showYAxis,
      this.yAxisColor,
      this.yRange,
      this.yMin,
      this.dataSet,
      this.xScale = 1.0,
      this.traceColor = Colors.white,
      this.isScrollable = false
      });

  @override
  void paint(Canvas canvas, Size size) {
    final tracePaint = Paint()
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.0
      ..color = traceColor
      ..style = PaintingStyle.stroke;

    final axisPaint = Paint()
      ..strokeWidth = 1.0
      ..color = yAxisColor;
    double yScale = (size.height / yRange);

    // only start plot if dataset has data
    int length = dataSet.length;

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
        trace.lineTo(p.toDouble() * (xScale*0.95), plotPoint);
      }

      // display the trace
      canvas.drawPath(trace, tracePaint);

      // if yAxis required draw it here
      if (showYAxis) {
        double centerPoint = size.height - (0.0 - yMin) * yScale;
//        double scale = size.height / yRange;
//        print("Center: $centerPoint, ${yRange}");
        Offset yStart = Offset(0.0, centerPoint);
        Offset yEnd = Offset(size.width, centerPoint);
        canvas.drawLine(yStart, yEnd, axisPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) => true;
}