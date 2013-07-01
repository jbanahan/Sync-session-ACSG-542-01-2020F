class ScheduledReportsController < ApplicationController

  def index
    @user = User.find_by_id params[:user_id]
    action_secure(!@user.nil? && (current_user.admin? || current_user.id == @user.id), @user, {:verb=>"view", :module_name => "Scheduled Report List"}) do
      searches = SearchSetup.for_user(@user).order("name ASC")
      custom_reports = CustomReport.for_user(@user).order("name ASC")

      if searches.blank? && custom_reports.blank?
        error_redirect "#{@user.username} does not have any reports." 
      else

        # Turn our list of reports into an object suitable to pass to grouped_options_for_select, sort the modules to preserve order
        modules = searches.collect{|r| r.module_type}.uniq.sort
        
        module_hash = {}
        modules.each{|m| module_hash[m] = []}

        # What's happening below with the sr/cr delimited values is that we're inserting an indicator in the select's value to indicate if the value
        # is a search or a custom report.  This allows us to handle both types of items directly in the same controller

        searches.sort{|a,b| a.name.upcase <=> b.name.upcase}.each do |r|
          module_hash[r.module_type] << [make_search_select_label(r), "sr~#{r.id}"]
        end

        custom_report_title = "Custom Report"
        module_hash[custom_report_title] = []
        custom_reports.each do |r|
          module_hash[custom_report_title] << [make_custom_report_select_label(r), "cr~#{r.id}"]
        end

        @reports = []
        module_hash.each_pair do |k, v|
          module_name = (k == custom_report_title) ? custom_report_title :  CoreModule.find_by_class_name(k).label 
          @reports << [module_name, v] if module_name
        end


        respond_to do |f|
          f.html
        end
      end
    end
  end

  def give_reports 
    @user = User.find_by_id params[:user_id]
    action_secure(!@user.nil? && (current_user.admin? || current_user.id == @user.id), @user, {:verb=>"give", :module_name => "Scheduled Report List"}) do
      # search_setup_id -> searches / custom report ids
      # assign_to_user_id -> user ids to assign the searches / reports to

      # All the search id's will be prefaced with sr~, Custom Reports will be prefaced with cr~
      count = 0
      params[:search_setup_id].each do |search_identifier|
        type, id = search_identifier.split "~"

        search = ((type == "sr") ? SearchSetup.find_by_id(id) : ((type == "cr") ? CustomReport.find_by_id(id): nil))

        if search
          users = User.find_all_by_id(params[:assign_to_user_id])

          users.each do |assign_to|
            search.give_to assign_to, !params[:copy_schedules].nil?
            count += 1
          end
        end
      end
      
      add_flash :notices, "#{count} reports copied."
      redirect_to user_scheduled_reports_path(@user)
    end
  end

  private 
    def make_search_select_label report
      # The label should be the (*) name + last run date
      access = report.last_accessed
      # Instead of showing blank times, show unused for searches that have never been run
      access = (access.blank? ? "[unused]" : access.strftime("%m/%d/%Y %l:%M %p"))
      "#{(report.search_schedules.blank?) ? " " : "* "}#{report.name} - #{access}"
    end

    def make_custom_report_select_label report
      last_run = report.report_results.order("run_at DESC").first
      last_run = (last_run.blank? ? "[unused]" : last_run.run_at.strftime("%m/%d/%Y %l:%M %p"))
      "#{(report.search_schedules.blank?) ? " " : "* "}#{report.name} - #{last_run}"
    end
end
