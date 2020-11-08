import { NgModule } from '@angular/core';
import { Routes, RouterModule } from '@angular/router';
import {NamesComponent} from "./names/names.component";

const routes: Routes = [
  {path: 'names-management', component: NamesComponent}
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
