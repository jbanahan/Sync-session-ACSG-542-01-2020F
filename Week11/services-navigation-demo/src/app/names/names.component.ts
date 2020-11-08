import { Component, OnInit } from '@angular/core';
import { NamesService } from "../_services/names.service";

@Component({
  selector: 'app-names',
  templateUrl: './names.component.html',
  styleUrls: ['./names.component.css']
})
export class NamesComponent implements OnInit {

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
