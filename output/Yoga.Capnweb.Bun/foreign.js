class BunWsBridge {
  #listeners = { message: [], close: [], error: [], open: [] };
  #ws;
  constructor(ws) { this.#ws = ws; this.readyState = 1; }
  send(data) { this.#ws.send(data); }
  close(code, reason) { this.#ws.close(code, reason); }
  addEventListener(type, fn) { this.#listeners[type]?.push(fn); }
  removeEventListener(type, fn) {
    const arr = this.#listeners[type];
    if (arr) { const i = arr.indexOf(fn); if (i >= 0) arr.splice(i, 1); }
  }
  _dispatch(type, event) {
    for (const fn of this.#listeners[type] ?? []) fn(event);
  }
}

export const toBrowserWebSocketImpl = (bunWs) => () => new BunWsBridge(bunWs);

export const dispatchMessageImpl = (bridge, data) => () => {
  const str = typeof data === "string" ? data : new TextDecoder().decode(data);
  bridge._dispatch("message", { data: str });
};

export const dispatchCloseImpl = (bridge, code, reason) => () => {
  bridge._dispatch("close", { code, reason });
};

export const dispatchErrorImpl = (bridge, error) => () => {
  bridge._dispatch("error", { error });
};
