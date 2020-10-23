import { NgModule } from '@angular/core';
import { Routes, RouterModule } from '@angular/router';
import {ExpressionExampleComponent} from "./expression-example/expression-example.component";

const routes: Routes = [
  {path: 'expression-example', component: ExpressionExampleComponent}
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
