import {Person} from './person';
class Student extends Person {
    gpa: number;
    drinkCoffee() {
        console.log("Yum!")
    }
}

// var fred = new Student("fred")
//  fred.drinkCoffee();