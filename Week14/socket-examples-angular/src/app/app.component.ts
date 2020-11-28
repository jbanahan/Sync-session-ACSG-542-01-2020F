import { Component, OnInit } from '@angular/core';
import { ChatService } from "./_services/chat.service";

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent implements OnInit {
  newMessage: string;
  messageList: string[] = [];

  constructor(private chatService: ChatService) {
  }

  sendMessage(): void {
    this.chatService.sendMessage((this.newMessage));
    this.newMessage = '';
  }

  ngOnInit() {
    this.chatService.getMessages().subscribe((message: string) => {
      this.messageList.push(message);
    })
  }

}
