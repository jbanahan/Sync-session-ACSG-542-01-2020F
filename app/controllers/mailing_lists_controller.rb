class MailingListsController < ApplicationController
  def index
    @company = Company.find(params[:company_id])
    @mailing_lists = @company.mailing_lists
  end

  def update
    @company = Company.find(params[:company_id])
    action_secure(@company.can_edit?(current_user), @company, {:verb => "edit", :module_name=>"company"}) {
      @mailing_list = @company.mailing_lists.find(params[:id])
      if save_mailing_list(@mailing_list, params)
        if @mailing_list.non_vfi_email_addresses.present?
          add_flash(:notices, "Distribution List #{@mailing_list.name} contains the following non-VFITrack email addresses: #{@mailing_list.non_vfi_email_addresses}")
        end
        redirect_to(company_mailing_lists_path(@company))
      else
        render action: 'edit'
      end
    }
  end

  def create
    @company = Company.find(params[:company_id])
    action_secure(@company.can_edit?(current_user), @company, {:verb => "edit", :module_name=>"company"}) {
      @mailing_list = MailingList.new(params[:mailing_list])
      if save_mailing_list(@mailing_list, params)
        if @mailing_list.non_vfi_email_addresses.present?
          add_flash(:notices, "Distribution List '#{@mailing_list.name}' contains the following non-VFITrack email addresses: #{@mailing_list.non_vfi_email_addresses}")
        end
        redirect_to(company_mailing_lists_path(@company))
      else
        render action: 'new'
      end
    }
  end

  def bulk_delete
    @company = Company.find(params[:company_id])
    action_secure(@company.can_edit?(current_user), @company, {:verb => "edit", :module_name=>"company"}) {
      if params[:delete].present?
        ids = params[:delete].keys
        @company.mailing_lists.where(id: ids).destroy_all
        add_flash :notices, "Distribution List(s) deleted successfully."
      end
      redirect_to company_mailing_lists_path(@company)
    }
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
    mailing_list.assign_attributes(params[:mailing_list])
    if mailing_list.save
      true
    else
      errors_to_flash @mailing_list, now: true
      false
    end
  end
end