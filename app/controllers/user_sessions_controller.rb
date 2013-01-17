class UserSessionsController < ApplicationController
  skip_before_filter :require_user

  # GET /user_sessions/new
  # GET /user_sessions/new.xml
  def new
    @user_session = UserSession.new

    respond_to do |format|
      format.html { render :layout => 'one_col' }# new.html.erb
      format.xml  { render :xml => @user_session }
    end
  end

  # POST /user_sessions
  # POST /user_sessions.xml
  def create
    @user_session = UserSession.new(params[:user_session])

    respond_to do |format|
      if @user_session.save
        add_flash :notices, "Login successful."
        c = @user_session.user
        if @user_session.user.host_with_port.nil?
          @user_session.user.host_with_port = request.host_with_port
          @user_session.user.save
        end
        
        History.create({:history_type => 'login', :user_id => c.id, :company_id => c.company_id})
        format.html { redirect_back_or_default(:root) }
        format.xml  { render :xml => @user_session, :status => :created, :location => @user_session }
      else
        errors_to_flash @user_session, :now => true
        format.html { render :action => "new" }
        format.xml  { render :xml => @user_session.errors, :status => :unprocessable_entity }
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
      format.xml  { head :ok }
    end
  end
end
