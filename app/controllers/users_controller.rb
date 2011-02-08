class UsersController < ApplicationController
    # GET /users
    # GET /users.xml
    def index
        if current_user.admin?
            @users = User.where(["company_id = ?",params[:company_id]])
            @company = Company.find(params[:company_id])
            respond_to do |format|
                format.html { render :layout => 'one_col'}# index.html.erb
                format.xml  { render :xml => @users }
            end
        else
            error_redirect "You do not have permission to view this user list."
        end
    end

    # GET /users/1
    # GET /users/1.xml
    def show
      @user = User.find(params[:id])
      action_secure(@user.can_view?(current_user),@user,{:lock_check=>false,:verb=>"view",:module_name=>"user"}) {
        respond_to do |format|
            format.html # show.html.erb
            format.xml  { render :xml => @user }
        end
      }
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
        render :layout => 'one_col'
      }
    end

    # POST /users
    # POST /users.xml
    def create
      admin_secure("Only administrators can create users.") {
        @user = User.new(params[:user])
        set_admin_params(@user,params)
        @company = @user.company
        respond_to do |format|
            if @user.save
                add_flash :notices, "User created successfully."
                format.html { redirect_to(company_user_path(@company,@user)) }
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
        respond_to do |format|
            if @user.update_attributes(params[:user])
                format.html { redirect_to(company_user_path(@company,@user), :notice => 'Account was successfully updated.') }
                format.xml  { head :ok }
            else
                errors_to_flash @user
                format.html { render :action => "edit" }
                format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
            end
        end
      }
    end

    def disable
      toggle_enabled
    end

    def enable
      toggle_enabled
    end
    
  private
  def set_admin_params(u,p)
    u.admin = current_user.admin? && !p[:is_admin].nil? && p[:is_admin]=="true"
    u.sys_admin == current_user.sys_admin? && !p[:is_sys_admin].nil? && p[:is_sys_admin]=="true"
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
