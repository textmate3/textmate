// The TextMate object HTML output pages call into.
//
// The legacy bridge handed the page a live Objective-C object, so system() could
// block and return its result inline. WKWebView runs the page in another process
// and offers no synchronous path, so system() returns a promise now.
//
// Most of the old surface still works unchanged: passing a callback, and calling
// cancel/write/close or assigning onreadoutput/onreaderror on the returned value,
// all behave as before. Only reading outputString or errorString directly from the
// return value cannot work, because those require the command to have finished. That
// case throws with instructions rather than returning undefined, which would render
// wrong output silently.
(function () {
	if (window.TextMate) return;

	var post    = function (msg) { return window.webkit.messageHandlers.textmate.postMessage(msg); };
	var nextId  = 0;
	var streams = {};   // taskId -> { onreadoutput, onreaderror }

	// Native calls this as the command writes, so streaming handlers keep working.
	window.__tmBridgeEmit = function (taskId, which, text) {
		var handlers = streams[taskId];
		if (!handlers) return;
		var handler = which === 'error' ? handlers.onreaderror : handlers.onreadoutput;
		if (typeof handler === 'function') handler(text);
	};

	var unavailable = function (property, command) {
		return new Error(
			'TextMate.system() is asynchronous in TextMate 3, so .' + property +
			' is not available on the value it returns.\n\n' +
			'    was:  var out = TextMate.system(cmd, null).' + property + ';\n' +
			'    now:  TextMate.system(cmd, function (task) { var out = task.' + property + '; });\n' +
			'    or:   var out = (await TextMate.system(cmd, null)).' + property + ';\n\n' +
			'  command: ' + command
		);
	};

	// Forwarded to the running command; these never needed the result.
	var liveMethods = { cancel: 1, write: 1, close: 1 };
	var liveSetters = { onreadoutput: 1, onreaderror: 1 };

	TextMate = {
		system: function (command, handler) {
			var taskId = ++nextId;
			streams[taskId] = {};

			var promise = post({ method: 'system', taskId: taskId, command: command }).then(function (result) {
				delete streams[taskId];
				if (typeof handler === 'function') handler(result);
				return result;
			});

			return new Proxy(promise, {
				get: function (target, property) {
					if (property === 'outputString' || property === 'errorString')
						throw unavailable(property, command);

					if (liveMethods[property])
						return function (arg) { return post({ method: property, taskId: taskId, string: arg }); };

					if (liveSetters[property])
						return streams[taskId] ? streams[taskId][property] : undefined;

					var value = target[property];
					return typeof value === 'function' ? value.bind(target) : value;
				},
				set: function (target, property, value) {
					if (liveSetters[property] && streams[taskId])
						streams[taskId][property] = value;
					else
						target[property] = value;
					return true;
				}
			});
		},

		log: function (message) {
			post({ method: 'log', message: String(message) });
		},

		openFile: function (path, options) {
			post({ method: 'openFile', path: path, options: options === undefined ? null : options });
		},

		get isBusy () { return this._isBusy; },
		set isBusy (flag) { this._isBusy = flag; post({ method: 'setBusy', value: !!flag }); },

		get progress () { return this._progress; },
		set progress (value) { this._progress = value; post({ method: 'setProgress', value: Number(value) }); }
	};

	window.TextMate = TextMate;
})();
