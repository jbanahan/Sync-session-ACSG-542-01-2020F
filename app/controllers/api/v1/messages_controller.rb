module Api; module V1; class MessagesController < Api::V1::ApiController
  before_action :require_admin, only: [:create]
  def index
    messages = paginate(current_user.messages.order('created_at desc'))
    message_hashes = messages.collect do |m|
      message_hash(m)
    end
    render json: {messages: message_hashes}
  end

  def create
    Message.create!(permitted_params(params))
    render json: {ok: 'ok'}
  end

  def count
    render json: {message_count: Message.unread_message_count(params[:user_id])}
  end

  def mark_as_read
    m = current_user.messages.find(params[:id])
    m.update(viewed: true)
    render json: {message: message_hash(m)}
  end

  private

    def paginate collection
      page = params['page'].present? && params['page'].to_s.match(/^\d*$/) ? params['page'].to_i : 1
      per_page = params['per_page'].present? && params['per_page'].to_s.match(/^\d*$/) ? params['per_page'].to_i : 10
      per_page = 50 if per_page > 50
      collection.paginate(per_page: per_page, page: page)
    end

    def message_hash m
      h = {id: m.id, subject: m.subject, body: m.body}
      h[:viewed] = true if m.viewed?
      h
    end

    def permitted_params(params)
      params.require(:message).permit(:user_id, :body, :subject)
    end
end; end; end