/**
 * Minimal game loop for the core module.
 * Coordinates update and render callbacks without relying on globals.
 */
export class GameLoop {
  #scheduler;
  #update;
  #render;
  #maxDeltaSeconds;
  #running = false;
  #frameHandle = null;
  #lastTimeSeconds = 0;

  constructor({
    update,
    render = () => {},
    scheduler = defaultScheduler,
    maxDeltaSeconds = 0.25,
  } = {}) {
    if (typeof update !== "function" || typeof render !== "function") {
      throw new TypeError("update and render must be functions");
    }

    if (!Number.isFinite(maxDeltaSeconds) || maxDeltaSeconds <= 0) {
      throw new RangeError("maxDeltaSeconds must be greater than zero");
    }

    this.#update = update;
    this.#render = render;
    this.#scheduler = scheduler;
    this.#maxDeltaSeconds = maxDeltaSeconds;
  }

  get running() {
    return this.#running;
  }

  start() {
    if (this.#running) {
      return;
    }

    this.#running = true;
    this.#lastTimeSeconds = this.#scheduler.now() / 1000;
    this.#frameHandle = this.#scheduler.request(this.#tick);
  }

  stop() {
    if (!this.#running) {
      return;
    }

    this.#running = false;

    if (this.#frameHandle !== null) {
      this.#scheduler.cancel(this.#frameHandle);
      this.#frameHandle = null;
    }
  }

  #tick = (timestampMilliseconds) => {
    if (!this.#running) {
      return;
    }

    const nowSeconds = timestampMilliseconds / 1000;
    const deltaSeconds = Math.min(
      Math.max(nowSeconds - this.#lastTimeSeconds, 0),
      this.#maxDeltaSeconds,
    );

    this.#lastTimeSeconds = nowSeconds;
    this.#update(deltaSeconds);
    this.#render(deltaSeconds);

    if (this.#running) {
      this.#frameHandle = this.#scheduler.request(this.#tick);
    }
  };
}

const defaultScheduler = Object.freeze({
  request(callback) {
    return globalThis.requestAnimationFrame(callback);
  },

  cancel(handle) {
    globalThis.cancelAnimationFrame(handle);
  },

  now() {
    return globalThis.performance.now();
  },
});

export function createGameLoop(options) {
  return new GameLoop(options);
}
