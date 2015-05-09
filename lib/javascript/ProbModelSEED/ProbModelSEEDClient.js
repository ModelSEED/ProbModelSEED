

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

    var _auth = auth ? auth : { 'token' : '', 'user_id' : ''};
    var _auth_cb = auth_cb;


    this.import_media = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.import_media",
        [input], 1, _callback, _errorCallback);
};

    this.import_media_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.import_media", [input], 1, _callback, _error_callback);
    };

    this.reconstruct_fbamodel = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.reconstruct_fbamodel",
        [input], 1, _callback, _errorCallback);
};

    this.reconstruct_fbamodel_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.reconstruct_fbamodel", [input], 1, _callback, _error_callback);
    };

    this.flux_balance_analysis = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.flux_balance_analysis",
        [input], 1, _callback, _errorCallback);
};

    this.flux_balance_analysis_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.flux_balance_analysis", [input], 1, _callback, _error_callback);
    };

    this.gapfill_model = function (input, _callback, _errorCallback) {
    return json_call_ajax("ProbModelSEED.gapfill_model",
        [input], 1, _callback, _errorCallback);
};

    this.gapfill_model_async = function (input, _callback, _error_callback) {
        deprecationWarning();
        return json_call_ajax("ProbModelSEED.gapfill_model", [input], 1, _callback, _error_callback);
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


