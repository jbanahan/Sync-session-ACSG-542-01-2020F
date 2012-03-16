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
    end
  end
  def new
    if current_user.edit_surveys?
      @survey = Survey.new(:company=>current_user.company)
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
  def update
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
      redirect_to request.referrer
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
      if SurveyResponse.find_by_survey_id_and_user_id(s.id,uid)
        add_flash :notices, "Survey already exists for #{User.find(uid).full_name}, skipping."
      else
        s.generate_response! User.find uid
        cnt += 1
      end
    end
    add_flash :notices, "#{help.pluralize cnt, "user"} assigned successfully."
    redirect_to s
  end
end
