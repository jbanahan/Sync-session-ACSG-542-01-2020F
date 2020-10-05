class MailingListsController < ApplicationController
  def index
    @company = Company.find(params[:company_id])
    @mailing_lists = @company.mailing_lists
  end

  def update
    @company = Company.find(params[:company_id])
    action_secure(@company.can_edit?(current_user), @company, {verb: "edit", module_name: "company"}) do
      @mailing_list = @company.mailing_lists.find(params[:id])
      if save_mailing_list(@mailing_list, params)
        if @mailing_list.non_vfi_email_addresses.present?
          add_flash(:notices, "Distribution List #{@mailing_list.name} contains the following non-VFITrack email addresses: #{@mailing_list.non_vfi_email_addresses}")
        end
        redirect_to(company_mailing_lists_path(@company))
      else
        render action: 'edit'
      end
    end
  end

  def create
    @company = Company.find(params[:company_id])
    action_secure(@company.can_edit?(current_user), @company, {verb: "edit", module_name: "company"}) do
      @user = User.find(params[:mailing_list][:user_id])
      @mailing_list = @company.mailing_lists.new(permitted_params(params))
      @mailing_list.user = @user
      if save_mailing_list(@mailing_list, params)
        if @mailing_list.non_vfi_email_addresses.present?
          add_flash(:notices, "Distribution List '#{@mailing_list.name}' contains the following non-VFITrack email addresses: #{@mailing_list.non_vfi_email_addresses}")
        end
        redirect_to(company_mailing_lists_path(@company))
      else
        render action: 'new'
      end
    end
  end

  def bulk_delete
    @company = Company.find(params[:company_id])
    action_secure(@company.can_edit?(current_user), @company, {verb: "edit", module_name: "company"}) do
      if params[:delete].present?
        ids = params[:delete].keys
        @company.mailing_lists.where(id: ids).destroy_all
        add_flash :notices, "Distribution List(s) deleted successfully."
      end
      redirect_to company_mailing_lists_path(@company)
    end
  end

  def new
    @company = Company.find(params[:company_id])
    @mailing_list = @company.mailing_lists.build
  end

  def edit
    @company = Company.find(params[:company_id])
    @mailing_list = @company.mailing_lists.find(params[:id])
  end

  def save_mailing_list(mailing_list, params)
    mailing_list.assign_attributes(permitted_params(params))
    # There's no point in making the user create a system code on their own..just create a code internally to use based on the name and company.
    # NOTE: We're already validating that the list name can't be duplicated in the same company, so this below code should work all the time without
    # raising an error (since it's validated).
    if mailing_list.system_code.blank?
      mailing_list.system_code = "#{mailing_list.name.to_s.parameterize.underscore}_#{mailing_list.company_id}"
    end

    if mailing_list.save
      true
    else
      errors_to_flash @mailing_list, now: true
      false
    end
  end

  private

  def permitted_params(params)
    params.require(:mailing_list).except(:user_id, :company_id).permit(:email_addresses, :hidden, :name, :system_code)
  end
end