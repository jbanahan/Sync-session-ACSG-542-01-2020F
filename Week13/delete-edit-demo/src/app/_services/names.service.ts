import { Injectable } from '@angular/core';
import { HttpClient } from "@angular/common/http";
import { Observable } from "rxjs";
import { environment } from "../../environments/environment";
import {Person} from "../_models/person.model";
import {map} from "rxjs/operators";

@Injectable({
  providedIn: 'root'
})
export class NamesService {

  constructor(private httpClient: HttpClient) { }

  getAll(): Observable<any> {
    return this.httpClient.get<any>(`${environment.apiUrl}/names`)
  }

  create( newName ): Observable<Person> {
    return this.httpClient.post<any>(`${environment.apiUrl}/name`, {name: newName})
      .pipe(map(newName => new Person(newName.name)));
  }

  destroy( name ): Observable<any> {
    return this.httpClient.delete(`${environment.apiUrl}/name/${name._id}`)
  }

  removeName( arrayNames, nameToRemove ): any{
    for (let i = 0; i <= arrayNames.length; i++) {
      if (arrayNames[i]._id === nameToRemove._id) {
        arrayNames.splice(i, 1);
        return arrayNames;
      }
    }
  }
}
