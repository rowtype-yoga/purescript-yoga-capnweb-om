import { RpcSession as RpcSessionClass, newWebSocketRpcSession } from "capnweb";

const toPromise = (rpcPromise) => new Promise((resolve, reject) => {
  rpcPromise.then(resolve, reject);
});

class Connection {
  constructor(session, stub) {
    this.session = session;
    this.stub = stub;
  }
}

class MessagePortTransport {
  #port; #queue = []; #waiting = null;
  constructor(port) {
    this.#port = port;
    port.start();
    port.addEventListener("message", (e) => {
      if (this.#waiting) { const w = this.#waiting; this.#waiting = null; w(e.data); }
      else this.#queue.push(e.data);
    });
  }
  send(msg) { this.#port.postMessage(msg); return Promise.resolve(); }
  receive() {
    if (this.#queue.length > 0) return Promise.resolve(this.#queue.shift());
    return new Promise(r => { this.#waiting = r; });
  }
  close() { this.#port.close(); }
}

export const connectImpl = (url) => () => {
  const stub = newWebSocketRpcSession(url);
  return new Connection(null, stub);
};

export const connectPairImpl = (localMain) => () => {
  const { port1, port2 } = new MessageChannel();
  const serverTransport = new MessagePortTransport(port1);
  const serverSession = new RpcSessionClass(serverTransport, localMain);
  const clientTransport = new MessagePortTransport(port2);
  const clientSession = new RpcSessionClass(clientTransport);
  const stub = clientSession.getRemoteMain();
  return new Connection(clientSession, stub);
};

export const disposeImpl = (conn) => () => {
  if (conn.stub[Symbol.dispose]) conn.stub[Symbol.dispose]();
};

export const dupImpl = (stub) => () => stub.dup();

export const disposeStubImpl = (stub) => () => {
  if (stub[Symbol.dispose]) stub[Symbol.dispose]();
};

export const callImpl = (conn, method, args) => toPromise(conn.stub[method](...args));
export const call0Impl = (conn, method) => toPromise(conn.stub[method]());
export const call1Impl = (conn, method, a) => toPromise(conn.stub[method](a));
export const call2Impl = (conn, method, a, b) => toPromise(conn.stub[method](a, b));

export const callWithCallbackImpl = (conn, method, callback) => {
  const wrappedCb = (value) => callback(value)();
  return toPromise(conn.stub[method](wrappedCb));
};

export const getStatsImpl = (conn) => () => conn.session.getStats();

export const drainImpl = (conn) => conn.session.drain();
