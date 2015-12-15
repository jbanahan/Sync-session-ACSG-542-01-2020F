module Api; module V1; class MessagesController < Api::V1::ApiController
  def index
    messages = paginate(current_user.messages.order('created_at desc'))
    message_hashes = messages.collect do |m|
      h = {id:m.id,subject:m.subject,body:m.body}
      h[:viewed] = true if m.viewed?
      h
    end
    render json: {messages: message_hashes}
  end

  def count
    render json: {message_count: Message.unread_message_count(params[:user_id])}
  end

  def paginate collection
    page = !params['page'].blank? && params['page'].to_s.match(/^\d*$/) ? params['page'].to_i : 1
    per_page = !params['per_page'].blank? && params['per_page'].to_s.match(/^\d*$/) ? params['per_page'].to_i : 10
    per_page = 50 if per_page > 50
    collection.paginate(per_page:per_page,page:page)
  end
  private :paginate
end; end; end