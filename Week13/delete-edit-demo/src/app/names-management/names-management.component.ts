import { Component, OnInit } from '@angular/core';
import {NamesService} from "../../../../../Week11/services-navigation-demo/src/app/_services/names.service";

@Component({
  selector: 'app-names-management',
  templateUrl: './names-management.component.html',
  styleUrls: ['./names-management.component.css']
})
export class NamesManagementComponent implements OnInit {
  public newName;
  public names;

  constructor(
    private namesService: NamesService
  ) { }

  ngOnInit(): void {
    this.namesService.getAll().subscribe(returnNames => {
      this.names = returnNames.docs;
    })
  }

  saveName(): void {
    this.namesService.create(this.newName).subscribe( saveName => {
      this.names.push(saveName);
    })
  }
}
