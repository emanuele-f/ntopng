// 2018 - ntop.org

var schema_2_label = {};
var data_2_label = {};

function initLabelMaps(_schema_2_label, _data_2_label) {
  schema_2_label = _schema_2_label;
  data_2_label = _data_2_label;
};

function getSerieLabel(schema, serie) {
  var data_label = serie.label;

  if(schema_2_label[schema])
    return schema_2_label[schema];

  if(data_2_label[data_label])
    return data_2_label[data_label];

  if(data_label != "bytes") {
    if(serie.tags.protocol)
      return serie.tags.protocol + " (" + data_label + ")";
    else if(serie.tags.category)
      return serie.tags.category + " (" + data_label + ")";
  } else {
      if(serie.tags.protocol)
        return serie.tags.protocol;
      else if(serie.tags.category)
        return serie.tags.category;
  }

  // default
  return capitaliseFirstLetter(data_label);
}

// Value formatter
function getValueFormatter(schema, series) {
  if(series && series.length && series[0].label) {
    var label = series[0].label;

    if(label.contains("bytes"))
      return fbits;
    else if(label.contains("packets"))
      return fpackets;
    else if(label.contains("flows"))
      return fflows;
  }

  // fallback
  return fint;
}

// add a new updateStackedChart function
function attachStackedChartCallback(chart, schema_name, url, chart_id, params) {
  var pending_request = null;
  var d3_sel = d3.select(chart_id);
  var $chart = $(chart_id);

  //var spinner = $("<img class='chart-loading-spinner' src='" + spinner_url + "'/>");
  var spinner = $('<i class="chart-loading-spinner fa fa-spinner fa-lg fa-spin"></i>');
  $chart.parent().css("position", "relative");

  chart.updateStackedChart = function (tstart, tend) {
    if(pending_request)
      pending_request.abort();
    else
      spinner.appendTo($chart.parent());

    if(tstart) params.epoch_begin = tstart;
    if(tend) params.epoch_end = tend;

    // Load data via ajax
    pending_request = $.get(url, params, function(data) {
      // Adapt data
      var res = [];
      var series = data.series;

      for(var j=0; j<series.length; j++) {
        var values = [];
        var serie_data = series[j].data;

        var t = data.start;
        for(var i=0; i<serie_data.length; i++) {
          values[i] = [t, serie_data[i] ];
          t += data.step;
        }

        res.push({
          key: getSerieLabel(schema_name, series[j]),
          yAxis: 1,
          values: values,
          type: "area",
        });
      }

      // get the value formatter
      var formatter = getValueFormatter(schema_name, series);
      chart.yAxis1.tickFormat(formatter);
      chart.interactiveLayer.tooltip.valueFormatter(formatter);

      // todo stop loading indicator
      d3_sel.datum(res).transition().duration(500).call(chart);
      nv.utils.windowResize(chart.update);
      pending_request = null;
      spinner.remove();
    });
  }
}
