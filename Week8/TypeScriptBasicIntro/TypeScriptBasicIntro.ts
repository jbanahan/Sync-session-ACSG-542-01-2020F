var somethingThatIsAString: string = "anything we want";

function myFunction(age: number, name: string): void {
    console.log(age);
}

// Todo: Remove this any!
var thing: any = "asdf";
thing = 1234;

class Person {
    name: string;
    age: number;
    constructor(passedName: string, passedAge?: number) {
        this.name = passedName;
        this.age = passedAge;
    }
}

var jeff = new Person("Jeff", 77);

