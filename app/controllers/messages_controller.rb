class MessagesController < ApplicationController
  newrelic_ignore only: [:message_count]

  skip_action_callback :require_user, :new_relic, :set_user_time_zone, :log_request, :log_run_as_request, :set_cursor_position,
                       :force_reset, :log_last_request_time, only: :message_count

  def set_page_title
    @page_title = 'Tools'
  end

  # GET /messages
  # GET /messages.xml
  def index
    @messages = Message.where({user_id: current_user.id, folder: 'inbox'}).order("created_at DESC")

    respond_to do |format|
      format.html { render layout: !params[:nolayout] } # index.html.erb
      format.xml  { render xml: @messages }
    end
  end

  def new
    sys_admin_secure do
      @message = Message.new
    end
  end

  def create
    sys_admin_secure do
      params[:message].each {|k, v| params[:message][k] = help.strip_tags(v)}
      m = Message.create(permitted_params(params))
      errors_to_flash m, now: true
      if m.errors.blank?
        add_flash :notices, "Your message has been sent."
        redirect_to messages_path
      else
        @message = m
        render :new
      end
    end
  end

  # DELETE /messages/1
  # DELETE /messages/1.xml
  def destroy
    @message = Message.find(params[:id])
    if @message.user == current_user
      @message.destroy
      errors_to_flash @message
      respond_to do |format|
        format.html { redirect_to(messages_url) }
        format.xml  { head :ok }
      end
    else
      error_redirect "You do not have permission to delete another user's message."
    end
  end

  def read
    @message = Message.find(params[:id])
    if @message.user == current_user
      @message.viewed = !@message.viewed
      if !@message.save
        errors_to_flash @message
      end
    else
      add_flash :errors, "You do not have permission to change another user's message."
    end
    render html: Message.unread_message_count(current_user.id)
  end

  def read_all
    current_user.messages.update_all viewed: true # rubocop:disable Rails/SkipsModelValidations
    render json: {ok: 'ok'}
  end

  def message_count
    distribute_reads do
      if params[:user_id]
        render json: Message.unread_message_count(params[:user_id])
      else
        error_redirect "User ID is required."
      end
    end
  end

  def new_bulk
    admin_secure do
      @companies = Company.all
    end
  end

  def send_to_users
    admin_secure do
      body = RedCloth.new(params[:message_body]).to_html
      Message.delay.send_to_users(params[:receivers], help.strip_tags(params[:message_subject]), body)
      add_flash :notices, "Message sent."
      redirect_to request.referer
    end
  end

  private

    def permitted_params(params)
      params.require(:message).permit(:user_id, :body, :subject)
    end
end
