class SurveysController < ApplicationController
  def index
    if current_user.view_surveys?
      @surveys = Survey.where(:company_id=>current_user.company_id, :archived => false)

      # sort_by is used because it only needs to look up sort key values once, instead of several times the standard
      # sort uses.  Since the key values come via query lookups, this saves tons of time.
      @surveys = @surveys.sort_by do |s|
        log = s.most_recent_response_log
        # We want the most recently updated to appear first, so reverse the times and make them negative
        log.nil? ? 0 : -log.updated_at.to_i
      end

      if params[:show_archived].to_s == 'true'
        @archived_surveys = Survey.where(:company_id=>current_user.company_id, :archived => true)
      end
    else
      error_redirect "You do not have permission to view surveys."
    end
  end
  def show
    if !current_user.view_surveys?
      error_redirect "You do not have permission to view surveys."
      return
    end
    @survey = Survey.find params[:id]
    if @survey.company_id!=current_user.company_id
      error_redirect "You cannot view surveys that aren't from your company."
      return
    end

    respond_to do |format|
      format.html {
        if params[:show_archived_responses] == "true" && @survey.can_edit?(current_user)
          @show_archived = true
        end
        # order by most recently updated to oldest (null being oldest - nothing should be null
        # except really old ones anyway)
        # Use sort_by so the sort key calculatoin is done only once, since we're needing to
        # do a DB query to figure this out, tihs is WAY faster than plain sort
        # (.ie it's O(n) instead of (average) O(n log n) or (worst case) O(n²)
        @survey_responses = @survey.survey_responses.was_archived(false).sort_by do |r|
          log = r.most_recent_user_log
          log ? -log.updated_at.to_i : 0
        end
      }
      format.xls do 
        send_excel_workbook @survey.to_xls, (@survey.name.blank? ? "survey" : @survey.name) + ".xls"
      end
    end
  end
  def new
    if current_user.edit_surveys?
      @survey = Survey.new(:company=>current_user.company,:email_subject=>"Email Subject",:email_body=>"h1. Survey Introduction Email\n\nSample Body",:ratings_list=>"Pass\nFail")
    else 
      error_redirect "You do not have permission to edit surveys."
    end
  end
  def edit
    s = Survey.find params[:id]
    if !s.can_edit? current_user
      error_redirect "You cannot edit this survey."
      return
    elsif s.locked?
      error_redirect "You cannot edit a survey that has already been sent."
      return
    end
    @survey = s
  end
  def copy
    s = Survey.find params[:id]
    if !s.can_edit? current_user
      error_redirect "You cannot copy this survey"
    else
      redirect_to edit_survey_path(s.copy!)
    end
  end
  def update
    #inject false warnings where not submitted
    if params[:survey] && params[:survey][:questions_attributes]
      params[:survey][:questions_attributes].each do |k,v|
        v[:warning]="" unless v[:warning]
        v[:require_comment]="" unless v[:require_comment]
        v[:require_attachment]="" unless v[:require_attachment]
      end
    end
    s = Survey.find params[:id]
    if !s.can_edit? current_user
      error_redirect "You cannot edit this survey."
      return
    elsif s.locked?
      error_redirect "You cannot edit a survey that has already been sent."
      return
    end
    s.update_attributes(params[:survey])
    if s.errors.empty?
      add_flash :notices, "Survey saved."
    else
      errors_to_flash s
    end
    redirect_to edit_survey_path(s)
  end
  def create
    if !current_user.edit_surveys?
      error_redirect "You do not have permission to edit surveys."
      return
    end
    s = Survey.new(params[:survey])
    s.company_id = current_user.company_id
    s.created_by = current_user
    s.save
    if s.errors.empty?
      add_flash :notices, "Survey saved."
      redirect_to edit_survey_path(s)
    else
      errors_to_flash s, :now=>true
      @survey = s
      render 'new'
    end
  end
  def destroy
    s = Survey.find params[:id]
    if !s.can_edit? current_user
      error_redirect "You cannot delete this survey."
      return
    elsif s.locked?
      error_redirect "You cannot delete a survey that has already been sent."
      return
    end
    s.destroy
    if s.errors.empty?
      add_flash :notices, "Survey deleted successfully."
      redirect_to surveys_path
    else
      errors_to_flash s, :now=>true
      redirect_to request.referrer.blank? ? '/' : request.referrer
    end
  end
  def show_assign
    s = Survey.find params[:id]
    if !s.can_edit? current_user
      error_redirect "You cannot assign users to this survey."
      return
    end
    @survey = s

    visible_companies = [current_user.company]
    visible_companies += current_user.company.linked_companies.to_a
    visible_companies << Company.where(:master=>true).first
    @visible_companies = visible_companies.uniq.compact.sort_by {|c| c.name.try(:upcase) }

    # Only show groups that are not already assigned to the survey
    @groups = Group.joins("LEFT OUTER JOIN survey_responses ON survey_responses.group_id IS NOT NULL and survey_responses.survey_id = #{@survey.id}").
                where("survey_responses.id IS NULL").uniq.order(:name)
  end
  def assign
    s = Survey.find params[:id]
    if !s.can_edit? current_user
      error_redirect "You cannot assign users to this survey."
      return
    end
    base_object = nil
    if !params[:base_object_id].blank? && !params[:base_object_type].blank?
      cm = CoreModule.find_by_class_name params[:base_object_type], true
      if cm.blank?
        error_redirect "Object type #{params[:base_object_type]} not found."
        return
      end
      bo = cm.klass.find_by_id params[:base_object_id]
      if bo.blank? || !bo.can_view?(current_user)
        error_redirect "#{params[:base_object_type]} #{params[:base_object_id]} not found."
        return
      end
      base_object = bo
    end

    users = params[:assign]
    groups = params[:groups]
    if users.blank? && groups.blank?
      add_flash :errors, "You must assign this survey to at least one user or group."
      redirect_to redirect_location(s)
      return
    end

    cnt = 0
    if !users.blank?
      users.values.each do |uid|
        s.generate_response!(User.find(uid),params[:subtitle],bo).delay.invite_user!
        cnt += 1
      end
      if cnt > 0
        add_flash :notices, "#{cnt} #{"user".pluralize(cnt)} assigned."
      end
    end

    cnt = 0
    if !groups.blank?
      groups.each do |g_id|
        s.generate_group_response!(Group.find(g_id), params[:subtitle],base_object).delay.invite_user!
        cnt += 1
      end

      if cnt > 0
        add_flash :notices, "#{cnt} #{"group".pluralize(cnt)} assigned."
      end
    end
    
    redirect_to redirect_location(s)
  end
  def toggle_subscription
    @survey = Survey.find params[:id]
    if current_user.view_surveys? && @survey.company_id == current_user.company_id
      existing = SurveySubscription.find_by_survey_id_and_user_id(@survey.id, current_user.id)
      if existing
        existing.destroy
      else
        SurveySubscription.create!(:survey_id => @survey.id, :user_id => current_user.id)
      end
    end
    redirect_to request.referrer.blank? ? '/' : request.referrer
  end

  def archive
    s = Survey.find params[:id]
    action_secure(s.can_edit?(current_user), s, module_name: "Survey", verb: "archive", lock_check: false) do 
      s.archived = true
      if s.save
        add_flash :notices, "Survey archived."
      else
        errors_to_flash s
      end 
      redirect_to survey_path s
    end
  end

  def restore
    s = Survey.find params[:id]
    action_secure(s.can_edit?(current_user), s, module_name: "Survey", verb: "restore", lock_check: false) do 
      s.archived = false
      if s.save
        add_flash :notices, "Survey restored."
      else
        errors_to_flash s
      end 
      redirect_to survey_path s
    end
  end

  private 
  def redirect_location s
    params[:redirect_to].blank? ? s : params[:redirect_to]
  end
end
