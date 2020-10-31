import { Component } from '@angular/core';
import { faAngular } from '@fortawesome/free-brands-svg-icons';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  title = 'data-binding-and-directives';
  faAngular = faAngular;
  isTrue = false;

  someTextVariable = "";

  myPictureLocation: string = "../assets/images/stegosaurus.jpg"

  someFunctionName = function () {
    // alert("Hello World!");
    this.isTrue = !this.isTrue;
  }
}
