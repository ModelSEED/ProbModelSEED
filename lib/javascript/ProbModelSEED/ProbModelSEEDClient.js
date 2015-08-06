

function ProbModelSEED(url, auth, auth_cb) {

    this.url = url;
    var _url = url;
    var deprecationWarningSent = false;

    function deprecationWarning() {
        if (!deprecationWarningSent) {
            deprecationWarningSent = true;
            if (!window.console) return;
            console.log(
                "DEPRECATION WARNING: '*_async' method names will be removed",
                "in a future version. Please use the identical methods without",
                "the'_async' suffix.");
        }
    }

    if (typeof(_url) != "string" || _url.length == 0) {
        _url = "http://p3.theseed.org/services/ProbModelSEED";
    }
    var _auth = auth ? auth : { 'token' : '', 'user_id' : ''};
    var _auth_cb = auth_cb;


    this.list_gapfill_solutions = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.list_gapfill_solutions",
        [input], 1, _callback, _errorCallback);
};

    this.list_gapfill_solutions_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.list_gapfill_solutions", [input], 1, _callback, _error_callback);
    };

    this.manage_gapfill_solutions = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.manage_gapfill_solutions",
        [input], 1, _callback, _errorCallback);
};

    this.manage_gapfill_solutions_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.manage_gapfill_solutions", [input], 1, _callback, _error_callback);
    };

    this.list_fba_studies = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.list_fba_studies",
        [input], 1, _callback, _errorCallback);
};

    this.list_fba_studies_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.list_fba_studies", [input], 1, _callback, _error_callback);
    };

    this.delete_fba_studies = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.delete_fba_studies",
        [input], 1, _callback, _errorCallback);
};

    this.delete_fba_studies_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.delete_fba_studies", [input], 1, _callback, _error_callback);
    };

    this.export_model = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.export_model",
        [input], 1, _callback, _errorCallback);
};

    this.export_model_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.export_model", [input], 1, _callback, _error_callback);
    };

    this.export_media = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.export_media",
        [input], 1, _callback, _errorCallback);
};

    this.export_media_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.export_media", [input], 1, _callback, _error_callback);
    };

    this.get_model = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.get_model",
        [input], 1, _callback, _errorCallback);
};

    this.get_model_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.get_model", [input], 1, _callback, _error_callback);
    };

    this.delete_model = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.delete_model",
        [input], 1, _callback, _errorCallback);
};

    this.delete_model_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.delete_model", [input], 1, _callback, _error_callback);
    };

    this.list_models = function (_callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.list_models",
        [], 1, _callback, _errorCallback);
};

    this.list_models_async = function (_callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.list_models", [], 1, _callback, _error_callback);
    };

    this.list_model_edits = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.list_model_edits",
        [input], 1, _callback, _errorCallback);
};

    this.list_model_edits_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.list_model_edits", [input], 1, _callback, _error_callback);
    };

    this.manage_model_edits = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.manage_model_edits",
        [input], 1, _callback, _errorCallback);
};

    this.manage_model_edits_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.manage_model_edits", [input], 1, _callback, _error_callback);
    };

    this.get_feature = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.get_feature",
        [input], 1, _callback, _errorCallback);
};

    this.get_feature_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.get_feature", [input], 1, _callback, _error_callback);
    };

    this.compare_regions = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.compare_regions",
        [input], 1, _callback, _errorCallback);
};

    this.compare_regions_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.compare_regions", [input], 1, _callback, _error_callback);
    };

    this.plant_annotation_overview = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.plant_annotation_overview",
        [input], 1, _callback, _errorCallback);
};

    this.plant_annotation_overview_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.plant_annotation_overview", [input], 1, _callback, _error_callback);
    };

    this.ModelReconstruction = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.ModelReconstruction",
        [input], 1, _callback, _errorCallback);
};

    this.ModelReconstruction_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.ModelReconstruction", [input], 1, _callback, _error_callback);
    };

    this.FluxBalanceAnalysis = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.FluxBalanceAnalysis",
        [input], 1, _callback, _errorCallback);
};

    this.FluxBalanceAnalysis_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.FluxBalanceAnalysis", [input], 1, _callback, _error_callback);
    };

    this.GapfillModel = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.GapfillModel",
        [input], 1, _callback, _errorCallback);
};

    this.GapfillModel_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.GapfillModel", [input], 1, _callback, _error_callback);
    };
 

    /*
     * JSON call using jQuery method.
     */
    function json_call_ajax(method, params, numRets, callback, errorCallback) {
        var deferred = $.Deferred();

        if (typeof callback === 'function') {
           deferred.done(callback);
        }

        if (typeof errorCallback === 'function') {
           deferred.fail(errorCallback);
        }

        var rpc = {
            params : params,
            method : method,
            version: "1.1",
            id: String(Math.random()).slice(2),
        };

        var beforeSend = null;
        var token = (_auth_cb && typeof _auth_cb === 'function') ? _auth_cb()
            : (_auth.token ? _auth.token : null);
        if (token != null) {
            beforeSend = function (xhr) {
                xhr.setRequestHeader("Authorization", token);
            }
        }

        var xhr = jQuery.ajax({
            url: _url,
            dataType: "text",
            type: 'POST',
            processData: false,
            data: JSON.stringify(rpc),
            beforeSend: beforeSend,
            success: function (data, status, xhr) {
                var result;
                try {
                    var resp = JSON.parse(data);
                    result = (numRets === 1 ? resp.result[0] : resp.result);
                } catch (err) {
                    deferred.reject({
                        status: 503,
                        error: err,
                        url: _url,
                        resp: data
                    });
                    return;
                }
                deferred.resolve(result);
            },
            error: function (xhr, textStatus, errorThrown) {
                var error;
                if (xhr.responseText) {
                    try {
                        var resp = JSON.parse(xhr.responseText);
                        error = resp.error;
                    } catch (err) { // Not JSON
                        error = "Unknown error - " + xhr.responseText;
                    }
                } else {
                    error = "Unknown Error";
                }
                deferred.reject({
                    status: 500,
                    error: error
                });
            }
        });

        var promise = deferred.promise();
        promise.xhr = xhr;
        return promise;
    }
}


