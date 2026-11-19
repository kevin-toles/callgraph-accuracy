export class Repo {
  constructor() {}
  save(item: string): boolean {
    return item.length > 0;
  }
  find(id: number): string {
    return "#" + id;
  }
}
