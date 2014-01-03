class CustomReportsController < ApplicationController
  def new
    type = params[:type]
    if type.blank?
      error_redirect "You must specify a report type."
    else
      report_class = Kernel.const_get(type)
      if report_class.blank? || !inheritance?(report_class)
        error_redirect "Type must be a CustomReport." 
      elsif !report_class.can_view? current_user
        error_redirect "You do not have permission to view this report."
      else
        @report_obj = report_class.new
        @custom_report_type = type
      end
    end
  end

  def show
    rpt = CustomReport.find params[:id]
    if rpt.user_id != current_user.id
      error_redirect "You cannot run reports assigned to another user."
    else
      @report_obj = rpt
    end
  end

  def copy
    base = CustomReport.for_user(current_user).find(params[:id])
    if base.nil?
      error_redirect "Report with ID #{params[:id]} not found."
    else
      new_name = params[:new_name]
      new_name = "Copy of #{base.name}" if new_name.empty?
      c = base.deep_copy(new_name)
      add_flash :notices, "Report copied successfully."
      redirect_to custom_report_path(c)
    end
  end
  def give
    base = CustomReport.for_user(current_user).find(params[:id])
    if base.nil?
      error_redirect "Report with ID #{params[:id]} not found."
    else
      other_user = User.find(params[:other_user_id])
      if current_user.company.master? || other_user.company_id==current_user.company_id || other_user.company.master?
        base.give_to other_user
        add_flash :notices, "Report #{base.name} has been given to #{other_user.full_name}."
        redirect_to custom_report_path(base)
      else
        error_redirect "You do not have permission to give this report to user with ID #{params[:other_user_id]}."
      end
    end
  end

  def update
    rpt = CustomReport.find params[:id]
    if rpt.user_id != current_user.id
      error_redirect "You cannot edit reports assigned to another user."
    else
      CustomReport.transaction do
        rpt.search_columns.destroy_all
        #strip fields not accessible to user
        sca = params[:custom_report][:search_columns_attributes]
        strip_fields sca unless sca.blank?
        scp = params[:custom_report][:search_criterions_attributes]
        strip_fields scp unless scp.blank?

        rpt.update_attributes(params[:custom_report])

        if rpt.errors.any?
          errors_to_flash rpt
          flash.keep
          raise ActiveRecord::Rollback
        end
      end
      
      redirect_to custom_report_path(rpt)
    end
  end
  def create
    type = params[:custom_report_type]
    klass = nil
    begin 
      klass = Kernel.const_get(type)
    rescue
      #do nothing
    end
    if klass.blank? || !inheritance?(klass)
      error_redirect "Type must be a CustomReport"
    elsif !klass.can_view? current_user
      error_redirect "You do not have permission to use the #{klass.template_name} report."
    else
      #strip fields not accessible to user
      sca = params[:custom_report][:search_columns_attributes]
      strip_fields sca unless sca.blank?
      scp = params[:custom_report][:search_criterions_attributes]
      strip_fields scp unless scp.blank?

      #add user parameter
      params[:custom_report][:user_id] = current_user.id

      rpt = klass.create!(params[:custom_report])
      redirect_to custom_report_path(rpt)
    end
  end
  def destroy
    rpt = CustomReport.find params[:id]
    if rpt.user_id != current_user.id
      error_redirect "You cannot edit reports assigned to another user."
    else
      rpt.destroy
      redirect_to '/reports'
    end
  end

  def preview
    rpt = CustomReport.find params[:id]
    if rpt.user_id != current_user.id
      render :text=>"You cannot preview another user's report."
    else
      @rpt = rpt
      render :partial=>'preview'
    end
  end
  def run
    rpt = CustomReport.find params[:id]
    if rpt.user_id != current_user.id
      error_redirect "You cannot run another user's report."
    else
      ReportResult.run_report! rpt.name, current_user, rpt.class, {:friendly_settings=>["Report Template: #{rpt.class.template_name}"],:custom_report_id=>rpt.id}
      add_flash :notices, "Your report has been scheduled. You'll receive a system message when it finishes."
      redirect_to custom_report_path(rpt)
    end
  end
  private 
  def strip_fields hash
    hash.delete_if {|k,v| !ModelField.find_by_uid(v[:model_field_uid]).can_view?(current_user)}
  end
  def inheritance? klass
    k = klass
    while !k.nil?
      return true if k==CustomReport
      k = k.superclass
    end
    false
  end
end
