import { Component, OnInit } from '@angular/core';
import {NamesService} from "../_services/names.service";

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

  deleteName(nameToDelete): void {
    this.namesService.destroy(nameToDelete).subscribe(success => {
      this.names = this.namesService.removeName(this.names, nameToDelete);
    }, error => {
      console.log(error);
    })
  }

  newEditName(person): void {}

  saveEditedName(): void {}
}
