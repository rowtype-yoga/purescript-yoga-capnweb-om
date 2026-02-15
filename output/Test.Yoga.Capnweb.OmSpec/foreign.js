import { RpcTarget } from "capnweb";

class TestApi extends RpcTarget {
  ping(msg) { return "pong: " + msg; }
  add(a, b) { return a + b; }
  pushItems(callback) {
    let i = 0;
    return new Promise((resolve) => {
      const interval = setInterval(async () => {
        i++;
        try {
          await callback({ index: i, value: "item-" + i });
        } catch (e) {
          clearInterval(interval);
          resolve();
          return;
        }
        if (i >= 5) {
          clearInterval(interval);
          resolve();
        }
      }, 10);
    });
  }
}

export const mkTestTarget = () => new TestApi();

export const delayMs = (ms) => new Promise(r => setTimeout(r, ms));
