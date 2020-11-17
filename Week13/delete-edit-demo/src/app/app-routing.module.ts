import { NgModule } from '@angular/core';
import { Routes, RouterModule } from '@angular/router';
import {NamesManagementComponent} from "./names-management/names-management.component";

const routes: Routes = [
  {path: 'names-management', component: NamesManagementComponent}
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
