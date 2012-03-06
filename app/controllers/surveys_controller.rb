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
      @survey.questions.build
    else 
      error_redirect "You do not have permission to edit surveys."
    end
  end
  def edit
    if !current_user.edit_surveys?
      error_redirect "You do not have permission to edit surveys."
      return
    end
    s = Survey.find params[:id]
    if s.company_id != current_user.company_id
      error_redirect "You cannot edit a survey created by a different company."
      return
    elsif s.locked?
      error_redirect "You cannot edit a survey that has already been sent."
      return
    end
    @survey = s
  end
  def update
    if !current_user.edit_surveys?
      error_redirect "You do not have permission to edit surveys."
      return
    end
    s = Survey.find params[:id]
    if s.company_id != current_user.company_id
      error_redirect "You cannot edit a survey created by a different company."
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
    if !current_user.edit_surveys?
      error_redirect "You do not have permission to delete surveys."
      return
    end
    s = Survey.find params[:id]
    if s.company_id != current_user.company_id
      error_redirect "You cannot delete a survey created by a different company."
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
end
