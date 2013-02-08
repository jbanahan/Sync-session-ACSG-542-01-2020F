class UserSessionsController < ApplicationController
  skip_before_filter :require_user
  skip_before_filter :verify_authenticity_token, :only=> [:create]


  def index
    if current_user
      redirect_to root_path
    else
      redirect_to new_user_session_path
    end
  end
  # GET /user_sessions/new
  # GET /user_sessions/new.xml
  def new
    if current_user
      redirect_to root_path
    else
      @user_session = UserSession.new

      respond_to do |format|
        format.html { render :layout => 'one_col' }# new.html.erb
      end
    end
  end

  # POST /user_sessions
  # POST /user_sessions.xml
  def create
    @user_session = UserSession.new(params[:user_session])

    respond_to do |format|
      if @user_session.save
        c = @user_session.user
        if @user_session.user.host_with_port.nil?
          @user_session.user.host_with_port = request.host_with_port
          @user_session.user.save
        end
        
        History.create({:history_type => 'login', :user_id => c.id, :company_id => c.company_id})
        format.html do 
          add_flash :notices, "Login successful."
          redirect_back_or_default(:root)
        end
        format.json { head :ok }
      else
        format.html do 
          errors_to_flash @user_session, :now => true
          render :action => "new" 
        end
        format.json { render :json => {"errors"=>@user_session.errors.full_messages}}
      end
    end
  end

  # DELETE /user_sessions/1
  # DELETE /user_sessions/1.xml
  def destroy
    @user_session = UserSession.find
    @user_session.destroy if @user_session #would be nil if logout action is hit when user is not logged in (Lighthouse ticket 199)

    respond_to do |format|
      add_flash :notices, "You are logged out.  Thanks for visiting."
      format.html { redirect_to new_user_session_path }
    end
  end
end
