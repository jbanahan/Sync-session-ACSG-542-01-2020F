class CustomReportsController < ApplicationController
  def new
    type = params[:type]
    report_class = find_custom_report_class(type)

    if report_class.nil?
      error_redirect "You must specify a report type."
    else
      if !report_class.can_view? current_user
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
    report_class = find_custom_report_class(type)

    if report_class.nil?
      error_redirect "You must specify a report type."
    elsif !report_class.can_view? current_user
      error_redirect "You do not have permission to use the #{report_class.template_name} report."
    else
      #strip fields not accessible to user
      sca = params[:custom_report][:search_columns_attributes]
      strip_fields sca unless sca.blank?
      scp = params[:custom_report][:search_criterions_attributes]
      strip_fields scp unless scp.blank?

      #add user parameter
      params[:custom_report][:user_id] = current_user.id

      rpt = report_class.create(params[:custom_report])

      if rpt.errors.any?
        errors_to_flash rpt
        @report_obj = rpt
        @custom_report_type = type
        render action: "new"
      else
        redirect_to custom_report_path(rpt)  
      end
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
      render html: "You cannot preview another user's report."
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
    hash.delete_if {|k,v| mf = ModelField.find_by_uid(v[:model_field_uid]); !(mf.can_view?(current_user) && mf.user_accessible?)}
  end

  def find_custom_report_class report_class
    # We're completely avoiding instantiating the class in any way that comes in from the params because that opens us
    # up to the potential for remote code executions (see http://gavinmiller.io/2016/the-safesty-way-to-constantize/)
    # Instead, what we're doing is providing a whitelist of known classes that CAN be used as a custom report and returning
    # the class that matches what the params are specifying.
    custom_report = CustomReport.descendants.find do |klass|
      klass.name == report_class
    end

    if custom_report.nil?
      StandardError.new("#{current_user.username} attempted to access an invalid custom report of type '#{report_class}'.").log_me
    end

    custom_report
  end
end
