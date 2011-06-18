class MessagesController < ApplicationController
  # GET /messages
  # GET /messages.xml
  def index
    @messages = Message.where({:user_id => current_user.id, :folder => 'inbox'}).order("created_at DESC").paginate(:per_page=>20, :page=>params[:page])

    respond_to do |format|
      format.html { render }# index.html.erb
      format.xml  { render :xml => @messages }
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
    update_message_count
    render :text => @message_count.to_s
  end
  
  def read_all
    current_user.messages.update_all :viewed => true
    render :text => "yes"
  end

  def message_count
    render :json => @message_count.to_json
  end
end
