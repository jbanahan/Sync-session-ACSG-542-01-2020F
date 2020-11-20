export class Person {
  name: string;

  constructor(name: string = '') {
    this.name = name;
  }

  public sayHi(): string {
    return 'Hi my name is ' + this.name;
  }
}
