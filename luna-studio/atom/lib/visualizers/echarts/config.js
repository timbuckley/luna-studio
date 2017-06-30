var cfgHelper = require("../visualization-config-helper.js")

module.exports = function (type) {
    var plotPattern = { constructor: ["Stream", "List"]
                      , fields:      [{constructor: ["Int", "Real"], fields: { any: true }}]
                      };
    var multiPlotPattern = { constructor: ["Stream", "List"]
                           , fields:      [ { constructor: ["List"]
                                            , fields: [{constructor: ["Int", "Real"], fields: { any: true }}] }
                                          ]
                           };
    var histogramPattern = { constructor: ["List"]
                           , fields:      [ { constructor: ["Pair"]
                                            , fields: [ { constructor: ["Text", "Int", "Real"]
                                                        , fields: { any: true } }
                                                      , { constructor: ["Int", "Real"]
                                                        , fields: { any: true } }
                                                      ]
                                            }
                                          ]
                           };
    var mapHistogramPattern = { constructor: ["Map"]
                              , fields:      [ { constructor: ["Text", "Int", "Real"]
                                               , fields: { any: true } }
                                             , { constructor: ["Int", "Real"]
                                               , fields: { any: true } }
                                             ]
                              };
    var plotVisualizer = (cfgHelper.matchesType(type, plotPattern) || cfgHelper.matchesType(type, multiPlotPattern)) ? [{name: "plot", path: "plot.html"}] : [];
    var histogramVisualizer = (cfgHelper.matchesType(type, histogramPattern) || cfgHelper.matchesType(type, mapHistogramPattern)) ? [{name: "histogram", path: "histogram.html"}] : [];
    return [].concat(plotVisualizer, histogramVisualizer);
};
