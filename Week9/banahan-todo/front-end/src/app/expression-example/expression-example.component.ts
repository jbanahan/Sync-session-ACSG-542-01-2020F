import { Component, OnInit } from '@angular/core';

@Component({
  selector: 'expression-example',
  templateUrl: './expression-example.component.html',
  styleUrls: ['./expression-example.component.css']
})
export class ExpressionExampleComponent implements OnInit{
  numberTwo = 2
  people = ['Fred', 'Tom', 'Jason']

  addTwo = function (num: number) {
    return num + 2
  }

  changeTwo = function () {
    this.numberTwo++;
  }

  constructor() { }

  ngOnInit(): void {
  }
}
