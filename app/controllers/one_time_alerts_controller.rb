require 'open_chain/name_incrementer'

class OneTimeAlertsController < ApplicationController
  M_CLASS_NAMES = OneTimeAlert::MODULE_CLASS_NAMES

  SEARCH_PARAMS = {
    'inactive' => {:field => 'inactive', :label=> 'Inactive'},
    'name' => {:field => 'name', :label=> 'One Time Alert Name'},
    'creator_name' => {:field => 'creator_name', :label => 'Alert Creator'},
    'created_at' => {:field => 'one_time_alerts.created_at', :label => 'Alert Creation Date'},
    'module_type' => {:field => 'module_type', :label => 'VFI Track Module'},
    'expire_date' => {:field => 'expire_date', :label => 'Expiration Date'},
    'updater_name' => {:field => 'updater_name', :label => 'Exp. Date Updated By'},
    'reference_field_uids' => {:field => 'reference_field_uids', :label => 'Reference Fields'}
  }

  def index
    if OneTimeAlert.can_view? current_user
      show_all = current_user.admin? && params[:display_all]
      enabled_search = create_search(show_all ? :all_enabled : :secure_enabled)
      expired_search = create_search(show_all ? :all_expired : :secure_expired)
      @display_all = params[:display_all]
      @enabled = enabled_search.paginate(:per_page => 20, :page => params[:page])
      @expired = expired_search.paginate(:per_page => 20, :page => params[:page])
      @tab = params[:tab] || "enabled"
      msg = message(params)
      add_flash(:notices, msg, now: true) if msg
    else
      error_redirect "You do not have permission to view One Time Alerts."
    end
  end

  def new
    if OneTimeAlert.can_edit? current_user 
      @alert = OneTimeAlert.new
      @display_all = params[:display_all]
      @cm_list = M_CLASS_NAMES.map do |mc_name| 
        cm = CoreModule.find_by_class_name(mc_name) 
        [cm.class_name, cm.label]
      end.sort_by{ |tuplet| tuplet[1] }
    else
      error_redirect "You do not have permission to create One Time Alerts."
    end
  end

  def edit
    @alert = OneTimeAlert.find params[:id]
    @display_all = params[:display_all]
    if @alert.can_view? current_user
      render :edit
    else
      error_redirect "You do not have permission to edit One Time Alerts."
    end
  end

  def create
    if OneTimeAlert.can_edit? current_user
      today = Date.today
      alert = OneTimeAlert.create!(module_type: params[:module_type], 
                                   user_id: current_user.id,
                                   inactive: true,
                                   expire_date_last_updated_by_id: current_user.id, 
                                   enabled_date: today,
                                   expire_date: today + 1.year)
      redirect_to edit_one_time_alert_path(alert, display_all_param)
    else
      error_redirect "You do not have permission to create One Time Alerts."
    end
  end

  def copy
    if OneTimeAlert.can_edit? current_user
      alert = OneTimeAlert.find params[:id]
      # Don't allow alerts that have been created through the first screen but not configured to be copied
      # Since the update screen requires that name be populated, it's used as a proxy here
      if !alert.name.present?
        error_redirect "This alert can't be copied."
      else
        alert_cpy = copy_alert(alert)
        add_flash :notices, "One Time Alert has been copied."
        redirect_to edit_one_time_alert_path(alert_cpy, display_all_param)
      end
    else
      error_redirect "You do not have permission to copy One Time Alerts."
    end
  end

  def mass_delete
    if OneTimeAlert.can_edit? current_user
      OneTimeAlert.where(id: params[:ids])
                  .select{ |ota| ota.user_id == current_user.id || current_user.admin? }
                  .each(&:destroy)
      add_flash :notices, "Selected One Time Alerts have been deleted."
      redirect_to one_time_alerts_path(display_all_param)
    else
      error_redirect "You do not have permission to edit One Time Alerts."
    end
  end

  def mass_expire
    if OneTimeAlert.can_edit? current_user
      expire_date = Time.zone.now.to_date
      OneTimeAlert.where(id: params[:ids])
                  .select{ |ota| ota.user_id == current_user.id || current_user.admin? }
                  .each{ |ota| ota.update_attributes! expire_date: expire_date }
      add_flash :notices, "Selected One Time Alerts will expire at the end of the day."
      redirect_to one_time_alerts_path(display_all_param)
    else
      error_redirect "You do not have permission to edit One Time Alerts."
    end
  end

  def mass_enable
    if OneTimeAlert.can_edit? current_user
      expire_date = Time.zone.now.to_date + 1.year
      OneTimeAlert.where(id: params[:ids])
                  .select{ |ota| ota.user_id == current_user.id || current_user.admin? }
                  .each{ |ota| ota.update_attributes! expire_date: expire_date }
      redirect_to one_time_alerts_path(display_all_param)
      add_flash :notices, "Expire dates for selected One Time Alerts have been extended."
    else
      error_redirect "You do not have permission to edit One Time Alerts."
    end
  end

  def reference_fields_index
    available = M_CLASS_NAMES.map{ |mn| [mn, []]}.to_h
    included  = M_CLASS_NAMES.map{ |mn| [mn, []]}.to_h
    
    admin_secure {
      xrefs = DataCrossReference.hash_ota_reference_fields
      M_CLASS_NAMES.map{ |m_name| CoreModule.find_by_class_name m_name }.each do |cm|
        cm.default_module_chain.model_fields(current_user).each do |mfid, mf|
          h = xrefs[cm.class_name].include?(mfid) ? included : available
          h[cm.class_name] << {"mfid" => mfid.to_s, "label" => mf.label}
          h[cm.class_name].sort_by!{ |mf_summary| mf_summary["label"] }
        end
      end
      @display_all = params[:display_all]
      @available = available.to_json.html_safe
      @included = included.to_json.html_safe
    }
  end

  def log_index
    if OneTimeAlert.can_view? current_user
      @alert = OneTimeAlert.find params[:id]
      @display_all = params[:display_all]
    else
      error_redirect "You do not have permission to view One Time Alerts."
    end
  end

  private

  def display_all_param
    {display_all: params[:display_all]}
  end

  def copy_alert alert
    alert_cpy = alert.dup
    alert_cpy.inactive = true
    alert_cpy.name = OpenChain::NameIncrementer.increment(alert.name, OneTimeAlert.where(user_id: current_user.id).map(&:name))
    alert_cpy.user = alert_cpy.expire_date_last_updated_by = current_user
    alert.search_criterions.each{ |sc| alert_cpy.search_criterions << sc.dup }
    alert_cpy.save!
    alert_cpy
  end

  # Uses subqueries because build_search appends a WHERE clauses, which prevents any top-level grouping
  def base_query
    ref_select = <<-SQL
      (SELECT ota.id AS ota_id, GROUP_CONCAT(sc.model_field_uid SEPARATOR ', ') AS reference_field_uids
       FROM one_time_alerts ota
         LEFT OUTER JOIN search_criterions sc ON ota.id = sc.one_time_alert_id
       GROUP BY ota.id) AS sc_groups
    SQL

    user_select = <<-SQL
      (SELECT id AS creator_id, CONCAT(first_name, ' ', last_name, ' (', username, ')') AS creator_name
       FROM users) AS creator_full_name
    SQL

    updater_select = <<-SQL
      (SELECT id AS updater_id, CONCAT(first_name, ' ', last_name, ' (', username, ')') AS updater_name
      FROM users) AS updater_full_name
    SQL

    OneTimeAlert.select("one_time_alerts.id")
                .select(:inactive)
                .select(:name)
                .select(:creator_name)
                .select("one_time_alerts.created_at")
                .select(:module_type)
                .select(:expire_date)
                .select(:updater_name)
                .select(:reference_field_uids)
                .from(ref_select)
                .joins("INNER JOIN one_time_alerts ON ota_id = one_time_alerts.id")
                .joins("INNER JOIN #{user_select} ON creator_id = one_time_alerts.user_id")
                .joins("LEFT OUTER JOIN #{updater_select} ON updater_id = one_time_alerts.expire_date_last_updated_by_id")
  end

  def all_expired  
    base_query.where("expire_date < ?", today)
  end

  def all_enabled
    base_query.where("expire_date >= ? OR expire_date IS NULL", today)
  end

  def secure_expired
    all_expired.where(user_id: current_user.id)
  end

  def secure_enabled
    all_enabled.where(user_id: current_user.id)
  end

  def today
    Time.zone.now.to_date
  end

  def create_search search_method
    sp = SEARCH_PARAMS.clone
    build_search(sp, 'name', 'created_at', 'd', search_method)
  end

  def message params
    if params[:message] == "update"
      "One Time Alert has been updated." 
    elsif params[:message] == "ref_update"
      "Available reference fields have been updated."
    elsif params[:message] == "delete"
      "One Time Alert has been deleted."
    end
  end
end
