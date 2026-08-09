export class AsyncTtlCache<T> {
  constructor(
    private readonly ttlMilliseconds: number,
    private readonly now: () => number = Date.now,
  ) {}

  private value?: T;
  private expiresAt = 0;
  private pending?: Promise<T>;

  get(loader: () => Promise<T>): Promise<T> {
    if (this.value !== undefined && this.now() < this.expiresAt) {
      return Promise.resolve(this.value);
    }
    if (this.pending) return this.pending;

    const request = loader();
    this.pending = request;
    return request.then((value) => {
      this.value = value;
      this.expiresAt = this.now() + this.ttlMilliseconds;
      return value;
    }).finally(() => {
      this.pending = undefined;
    });
  }
}
