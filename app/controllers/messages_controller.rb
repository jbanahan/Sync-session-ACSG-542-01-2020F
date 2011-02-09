class MessagesController < ApplicationController
  # GET /messages
  # GET /messages.xml
  def index
    @messages = Message.where({:user_id => current_user.id, :folder => 'inbox'}).order("created_at DESC")

    respond_to do |format|
      format.html { render }# index.html.erb
      format.xml  { render :xml => @messages }
    end
  end

=begin
  # GET /messages/1
  # GET /messages/1.xml
  def show
    @message = Message.find(params[:id])
    if @message.user == current_user
      if !@message.read
        @message.read = true
        @message.save
      end      
      update_message_count
      respond_to do |format|
        format.html # show.html.erb
        format.xml  { render :xml => @message }
      end
    else
      error_redirect "You do not have permission to view another user's message."
    end
  end

  # GET /messages/new
  # GET /messages/new.xml
  def new
    @message = Message.new
    @message.user = current_user

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @message }
    end
  end

  # GET /messages/1/edit
  def edit
    @message = Message.find(params[:id])
    if @message.user != current_user
      error_redirect "You do not have permission to edit another user's message."
    end
  end

  # POST /messages
  # POST /messages.xml
  def create
    @message = Message.new(params[:message])
    if @message.user == current_user
  
      respond_to do |format|
        if @message.save
          add_flash :notices, "Message saved."
          format.html { redirect_to(@message) }
          format.xml  { render :xml => @message, :status => :created, :location => @message }
        else
          errors_to_flash @message, :now => true
          format.html { render :action => "new" }
          format.xml  { render :xml => @message.errors, :status => :unprocessable_entity }
        end
      end
    else
      error_redirect "You do not have permission to create a message for another user."
    end
  end

  # PUT /messages/1
  # PUT /messages/1.xml
  def update
    @message = Message.find(params[:id])
    if @message.user == current_user
      respond_to do |format|
        if @message.update_attributes(params[:message])
          add_flash :notices, "Message saved."
          format.html { redirect_to(@message) }
          format.xml  { head :ok }
        else
          errors_to_flash @message, :now => true
          format.html { render :action => "edit" }
          format.xml  { render :xml => @message.errors, :status => :unprocessable_entity }
        end
      end
    else
      error_redirect "You do not have permission to edit a message for another user."
    end
  end
=end

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
end
