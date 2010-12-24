class UsersController < ApplicationController
    # GET /users
    # GET /users.xml
    def index
        if current_user.company.master
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
        if @user.can_view?(current_user)
            respond_to do |format|
                format.html # show.html.erb
                format.xml  { render :xml => @user }
            end
        else
            error_redirect "You do not have permission to view this user."
        end
    end

    # GET /users/new
    # GET /users/new.xml
    def new
        @company = Company.find(params[:company_id])
        err_msg = change_check(current_user.company.master,@company,'create')
        if err_msg.nil?
            @user = @company.users.build
            respond_to do |format|
                format.html # new.html.erb
                format.xml  { render :xml => @user }
            end
        else
            error_redirect err_msg
        end
    end

    # GET /users/1/edit
    def edit
        @user = User.find(params[:id])
        @company = @user.company
        err_msg = change_check(@user.can_edit?(current_user),@company,'create')
        if err_msg.nil?
            render :layout => 'one_col'
        else
            error_redirect err_msg
        end
    end

    # POST /users
    # POST /users.xml
    def create
        @user = User.new(params[:user])
        @company = @user.company
        err_msg = change_check(current_user.company.master,@company,'create')
        if err_msg.nil?
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
        else
            error_redirect err_msg
        end
    end

    # PUT /users/1
    # PUT /users/1.xml
    def update
        @user = User.find(params[:id])
        @company = @user.company
        err_msg = change_check(@user.can_edit?(current_user),@company,'edit')
        if err_msg.nil?
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
        else
            error_redirect err_msg
        end
    end

    def disable
        @user = User.find(params[:id])
        @company = @user.company
        err_msg = change_check(@user.can_edit?(current_user),@company,'disable')
        if err_msg.nil?
            @user.disabled = true
            respond_to do |format|
                if @user.save
                    add_flash :notices, "#{@user.full_name} was disabled."
                    format.html { redirect_to(company_user_path(@company,@user)) }
                    format.xml  { head :ok }
                else
                    errors_to_flash @user
                    format.html { redirect_to(company_user_path(@company,@user)) }
                    format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
                end
            end
        else
            error_redirect err_msg
        end
    end

    def enable
        @user = User.find(params[:id])
        @company = @user.company        
        err_msg = change_check(@user.can_edit?(current_user),@company,'enable')
        if err_msg.nil?
            @user.disabled = false
            respond_to do |format|
                if @user.save
                    add_flash :notices, "#{@user.full_name} was enabled."
                    format.html { redirect_to(company_user_path(@company,@user)) }
                    format.xml  { head :ok }
                else
                    errors_to_flash @user
                    format.html { redirect_to(company_user_path(@company,@user)) }
                    format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
                end
            end
        else
            error_redirect err_msg
        end
    end
    
    private
    def change_check(permission_check,company,verb='edit')
        return "You do not have permission to #{verb} users." unless permission_check
        return "You cannot #{verb} users for a locked company." if !company.nil? && company.locked
    end
end
