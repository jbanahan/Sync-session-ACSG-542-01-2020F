import { Injectable } from '@angular/core';
import { Socket } from "ngx-socket-io";

@Injectable({
  providedIn: 'root'
})
export class ChatService {

  constructor(private socket: Socket) { }

  sendMessage(message: string): void {
    this.socket.emit('user message', message);
  }

  getMessages(): any {
    return this.socket.fromEvent('user message');
  }
}
