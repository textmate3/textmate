window.addEventListener("error", function(event) {
	webkit.messageHandlers.textmate.postMessage({
		command: "log",
		payload: {
			level:    "error",
			message:  event.message,
			filename: event.filename,
			lineno:   event.lineno,
			colno:    event.colno
		}
	});
});

let TextMate = {
	log(str) {
		webkit.messageHandlers.textmate.postMessage({
			command: "log",
			payload: {
				message: str
			}
		});
	},
	nextCallbackId: 1,
	callbacks: new Map(),
	version:	  null,
	copyright: null
};
