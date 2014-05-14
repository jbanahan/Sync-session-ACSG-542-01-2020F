class UsersController < ApplicationController
  skip_before_filter :check_tos, :only => [:show_tos, :accept_tos]
    # GET /users
    def index
      respond_to do |format|
        format.html {
          if current_user.admin?
              @users = User.where(["company_id = ?",params[:company_id]]).order(:username)
              @company = Company.find(params[:company_id])
              render :layout => 'one_col' # index.html.erb
          else
              error_redirect "You do not have permission to view this user list."
          end
        }
        format.json {
          companies = current_user.company.visible_companies_with_users.includes(:users)
          render :json => companies.to_json(:only=>[:name],:include=>{:users=>{:only=>[:id,:first_name,:last_name],:methods=>:full_name}})
        }
      end
    end

    # GET /users/1
    def show
      @user = User.find(params[:id])
      redirect_to edit_company_user_path @user.company, @user
    end

    # GET /users/new
    def new
      admin_secure("Only administrators can create users.") {
        @company = Company.find(params[:company_id])
        @user = @company.users.build
      }
    end

    # GET /users/1/edit
    def edit
      @user = User.find(params[:id])
      action_secure(@user.can_edit?(current_user),@user,{:lock_check=>false,:module_name=>"user",:verb=>"edit"}) {
        @company = @user.company
      }
    end

    # POST /users
    def create
      admin_secure("Only administrators can create users.") {
        # Strip the password and password confirmation values otherwise the User call gets mad
        # on attribute assignment since they're not accessible
        password = params[:user].delete :password
        password_confirmation = params[:user].delete :password_confirmation

        @user = User.new(params[:user])
        set_admin_params(@user,params)
        set_debug_expiration(@user)
        set_password_reset(@user)
        @user.password = password
        @company = @user.company
        User.transaction do
          if @user.save && @user.update_user_password(password, password_confirmation)
            add_flash :notices, "User created successfully."
            redirect_to(company_users_path(@company))
          else
            errors_to_flash @user, :now => true
            @company = Company.find(params[:company_id])
            render :action => "new"
            # Rollback is swallowed by the transaction block
            raise ActiveRecord::Rollback, "Bad user create."
          end
        end
      }
    end

    # PUT /users/1
    # PUT /users/1.xml
    def update
      @user = User.find(params[:id])
      action_secure(@user.can_edit?(current_user), @user, {:lock_check=>false,:verb=>"edit",:module_name=>"user"}) {
        @company = @user.company
        set_admin_params(@user,params)
        set_debug_expiration(@user)
        set_password_reset(@user)
        # Deleting password params because they're not set as accessible in the user model
        if @user.update_user_password(params[:user].delete(:password), params[:user].delete(:password_confirmation)) && @user.update_attributes(params[:user])
            add_flash :notices, "Account updated successfully."

            # If the user is updating their own account then it's possible they've updated their password, in which case their remember token is invalid (it's re-generated
            # whenever the user password is modified). The easiest thing to do here is just always re-log them in which will reset their remember token cookie.
            if current_user.id == @user.id
              sign_in(@user) do |status|
                if status.success?
                  redirect_to current_user.admin? ? company_users_path(@company) : "/"
                else
                  redirect_to login_path
                end
              end
            else
              redirect_to current_user.admin? ? company_users_path(@company) : "/"
            end
        else
          errors_to_flash @user
          render :action => "edit"
        end
      }
    end

    def email_new_message
      current_user.email_new_messages = !!params[:email_new_messages]
      current_user.save
      redirect_to messages_path
    end

    def disable
      toggle_enabled
    end

    def enable
      toggle_enabled
    end

    def enable_run_as
      if current_user.admin?
        u = User.find_by_username params[:username]
        if u
          current_user.run_as = u
          current_user.save
          redirect_to "/"
        else
          error_redirect "User with username #{params[:username]} not found."
        end
      else
        error_redirect "You must be an administrator to run as a different user."
      end
    end
    def disable_run_as
      if @run_as_user
        @run_as_user.run_as = nil
        @run_as_user.save
        add_flash :notices, "Run As disabled."
      end
      redirect_to '/'
    end
    
  def hide_message
    if params[:message_name].blank?
      render :json=>{error:'Message Name missing.'}
    else
      current_user.add_hidden_message params[:message_name]
      current_user.save!
      render :json=>{'OK'=>'OK'}
    end
  end

  def show_bulk_upload
    admin_secure("Only administrators can create users.") {
      @company = Company.find(params[:company_id])
      @user = @company.users.build
    }
  end

  def preview_bulk_upload
    @company = Company.find(params[:company_id])
    begin
      render json: {results: parse_bulk_csv(params['bulk_user_csv'])}
    rescue
      render json: {error: $!.message}, status: 400
    end
  end
  def bulk_upload
    admin_secure("Only administrators can create users.") {
      count = 0
      company = Company.find(params[:company_id])
      results = parse_bulk_csv(params['bulk_user_csv'])
      begin
        User.transaction do 
          results.each do |res|
            res.merge! params[:user]
            u = company.users.build res
            # Password is no longer an accessible attribute, so set it
            # manually. Setting the password here updates the encrypted password
            # as well.
            u.password = res['password']
            u.save!
            count += 1
          end
        end
        render json: {count:count}
      rescue
        render json: {error:$!.message}, status: 400
      end
    }
  end

  def bulk_invite
    admin_secure("Only administrators can send invites to users.") {
      if params[:id].blank?
        add_flash :errors, "Please select at least one user."
      else
        User.delay.send_invite_emails params[:id]
        add_flash :notices, "The user invite #{"email".pluralize(params[:id].length)} will be sent out shortly."
      end

      redirect_to company_users_path params[:company_id]
    }
  end

  def move_to_new_company
    admin_secure("Only administrators can move other users to a new company."){
      destination_company = Company.find(params[:destination_company_id])
      params[:id].each do |user_id|
        user = User.find(user_id)
        user.company = destination_company
        user.save!
      end if params[:id] #ignore the whole block if no users were selected

      redirect_to :back
    }
  end
  
  def find_by_email
    admin_secure "Only admins can use this page" do
      email = params[:email]
      if !email.blank?
        u = User.find_by_email email 
        if u.nil?
          add_flash :errors, "User not found with email: #{email}"
        else
          redirect_to [u.company,u]
        end
      end
    end 
  end

  def set_homepage
    if params[:homepage]
      uri = nil
      if params[:homepage].blank?
        uri = ""
      else
        uri = URI.parse params[:homepage]
        # We want to strip the scheme and host from the URL since we want it to always be relative to the current server/ http scheme 
        # that is in effect on the login homepage redirect
        uri = uri.path + (uri.query ? ("?"+uri.query) : "") + (uri.fragment ? ("#" + uri.fragment): "")
      end
      current_user.update_attributes! homepage: uri

      render :json=>{'OK'=>'OK'}
    else
      render :json=> {error: "Homepage URL missing."}
    end
  end

  private
  def parse_bulk_csv data
    rval = []
    CSV.parse(data) do |row|
      next if row.empty?
      raise "Every row must have 5 elements." unless row.size == 5
      rval << {'username'=>row[0],'email'=>row[1],'first_name'=>row[2],'last_name'=>row[3],'password'=>row[4]}
    end
    rval
  end
  def set_debug_expiration(u)
    if current_user.sys_admin? && !params[:debug_expiration_hours].blank?
      u.debug_expires = params[:debug_expiration_hours].to_i.hours.from_now
    end
  end
  def set_password_reset(u)
    if current_user.sys_admin?
      u.password_reset = params[:password_reset] == 'true' ? true : false
    end
  end
  def set_admin_params(u,p)
    if current_user.admin?
      u.admin = !p[:is_admin].nil? && p[:is_admin]=="true"
      u.sys_admin = !p[:is_sys_admin].nil? && p[:is_sys_admin]=="true"
      u.disabled = !p[:is_disabled].nil? && p[:is_disabled]=="true"
    end
  end

  def toggle_enabled
    @user = User.find(params[:id])
    action_secure(@user.can_edit?(current_user),@user,{:lock_check=>false,:module_name=>"user",:verb=>"change"}) {
      msg_word = @user.disabled ? "enabled" : "disabled"
      @user.disabled = !@user.disabled
      add_flash :notices, "#{@user.fullName} was #{msg_word}." if @user.save
      errors_to_flash @user
      redirect_to company_user_path(@user.company,@user) 
    }
  end
end
