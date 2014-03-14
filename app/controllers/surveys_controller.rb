class SurveysController < ApplicationController
  def index
    if current_user.view_surveys?
      @surveys = Survey.where(:company_id=>current_user.company_id) 
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

    if params[:show_archived_responses] == "true" && @survey.can_edit?(current_user)
      @show_archived = true
    end

    respond_to do |format|
      format.html
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
    debugger
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
  end
  def assign
    s = Survey.find params[:id]
    if !s.can_edit? current_user
      error_redirect "You cannot assign users to this survey."
      return
    end
    cnt = 0
    params[:assign].values.each do |uid|
      s.generate_response!(User.find(uid),params[:subtitle]).delay.invite_user!
      cnt += 1
    end
    add_flash :notices, "#{help.pluralize cnt, "user"} assigned successfully."
    redirect_to s
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
end
