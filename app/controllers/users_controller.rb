class UsersController < ApplicationController
  skip_before_filter :check_tos, :only => [:show_tos, :accept_tos]
    # GET /users
    # GET /users.xml
    def index
      respond_to do |format|
        format.html {
          if current_user.admin?
              @users = User.where(["company_id = ?",params[:company_id]])
              @company = Company.find(params[:company_id])
              render :layout => 'one_col' # index.html.erb
          else
              error_redirect "You do not have permission to view this user list."
          end
        }
        format.json {
          companies = []
          if current_user.company.master?
            companies = Company.all
          else
            companies = current_user.company.linked_companies
            companies << current_user.company
            master = Company.where(:master=>true).first
            companies << master unless companies.includes?(master)
          end
          render :json => companies.to_json(:only=>[:name],:include=>{:users=>{:only=>[:id,:first_name,:last_name],:methods=>:full_name}})
        }
      end
    end

    # GET /users/1
    # GET /users/1.xml
    def show
      @user = User.find(params[:id])
      redirect_to edit_company_user_path @user
    end

    # GET /users/new
    # GET /users/new.xml
    def new
      admin_secure("Only administrators can create users.") {
        @company = Company.find(params[:company_id])
        @user = @company.users.build
        respond_to do |format|
            format.html # new.html.erb
            format.xml  { render :xml => @user }
        end
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
    # POST /users.xml
    def create
      admin_secure("Only administrators can create users.") {
        @user = User.new(params[:user])
        set_admin_params(@user,params)
        set_debug_expiration(@user)
        @company = @user.company
        respond_to do |format|
            if @user.save
                add_flash :notices, "User created successfully."
                format.html { redirect_to(company_users_path(@company)) }
                format.xml  { render :xml => @user, :status => :created, :location => @user }
            else
                errors_to_flash @user, :now => true
                @company = Company.find(params[:company_id])
                format.html { render :action => "new" }
                format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
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
        respond_to do |format|
            if @user.update_attributes(params[:user])
                add_flash :notices, "Account updated successfully."
                format.html {
                  redirect_to current_user.admin? ? company_users_path(@company) : "/"
                }
                format.xml  { head :ok }
            else
                errors_to_flash @user
                format.html { render :action => "edit" }
                format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
            end
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
    
  private
  def set_debug_expiration(u)
    if current_user.sys_admin? && !params[:debug_expiration_hours].blank?
      u.debug_expires = params[:debug_expiration_hours].to_i.hours.from_now
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
