import { Component, OnInit } from '@angular/core';
import {NamesService} from "../_services/names.service";
import {NgbModal} from "@ng-bootstrap/ng-bootstrap";

@Component({
  selector: 'app-names-management',
  templateUrl: './names-management.component.html',
  styleUrls: ['./names-management.component.css']
})
export class NamesManagementComponent implements OnInit {
  public newName;
  public names;
  public editName = {name: ''};

  constructor(
    private namesService: NamesService,
    private modalService: NgbModal
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

  newEditName(content, person): void {
    this.editName = person;

    this.modalService.open(content).result.then((result) => {
      this.saveEditedName();
    }, (reason) => {})
  }

  saveEditedName(): void {}
}
