export class Person {
    name: string;
    age: number;
    constructor(passedName: string, passedAge?: number) {
        this.name = passedName;
        this.age = passedAge;
    }
}
