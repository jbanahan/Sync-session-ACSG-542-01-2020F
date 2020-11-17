class SurveysController < ApplicationController
  def set_page_title
    @page_title ||= 'Survey' # rubocop:disable Naming/MemoizedInstanceVariableName
  end

  def index
    if current_user.view_surveys?
      @surveys = Survey.where(company_id: current_user.company_id, archived: false)

      # sort_by is used because it only needs to look up sort key values once, instead of several times the standard
      # sort uses.  Since the key values come via query lookups, this saves tons of time.
      @surveys = @surveys.sort_by do |s|
        log = s.most_recent_response_log
        # We want the most recently updated to appear first, so reverse the times and make them negative
        log.nil? ? 0 : -log.updated_at.to_i
      end

      if params[:show_archived].to_s == 'true'
        @archived_surveys = Survey.where(company_id: current_user.company_id, archived: true)
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
    if @survey.company_id != current_user.company_id
      error_redirect "You cannot view surveys that aren't from your company."
      return
    end

    respond_to do |format|
      format.html do
        if params[:show_archived_responses] == "true" && @survey.can_edit?(current_user)
          @show_archived = true
        end
        # order by most recently updated to oldest (null being oldest - nothing should be null
        # except really old ones anyway)
        # Use sort_by so the sort key calculatoin is done only once, since we're needing to
        # do a DB query to figure this out, tihs is WAY faster than plain sort
        # (.ie it's O(n) instead of (average) O(n log n) or (worst case) O(n^2)
        @survey_responses = @survey.survey_responses.was_archived(false).sort_by do |r|
          log = r.most_recent_user_log
          log ? -log.updated_at.to_i : 0
        end
      end
      format.xls do
        send_excel_workbook @survey.to_xls, (@survey.name.presence || "survey") + ".xls"
      end
    end
  end

  def new
    if current_user.edit_surveys?
      @survey = Survey.new(company: current_user.company, email_subject: "Email Subject",
                           email_body: "h1. Survey Introduction Email\n\nSample Body", ratings_list: "Pass\nFail")
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
      # inject false warnings where not submitted
      s = Survey.find params[:id]
      if !s.can_edit? current_user
        add_flash :errors, "You cannot edit this survey."
        return
      elsif s.locked?
        add_flash :errors, "You cannot edit a survey that has already been sent."
        return
      end
      question_validation
      s.update(permitted_params(params))
      errors_to_flash s unless s.errors.empty?
  rescue StandardError => e
      add_flash :errors, e.message
      e.log_me
  ensure
      redirect_path = (defined? s) && s ? edit_survey_path(s) : nil
      render json: {flash: {errors: flash[:errors]}, redirect: redirect_path}
  end

  def question_validation
    if params[:survey] && params[:survey][:questions_attributes]
      counter = 0
      params[:survey][:questions_attributes].each do |_k, v|
        v[:rank] = counter if v[:rank].blank?
        v[:warning] = "" unless v[:warning]
        v[:require_comment] = "" unless v[:require_comment]
        v[:require_attachment] = "" unless v[:require_attachment]
        counter += 1
      end
    end
  end

  def create
      if !current_user.edit_surveys?
        add_flash :errors, "You do not have permission to edit surveys."
        return
      end
      question_validation
      s = Survey.new(permitted_params(params))
      s.company_id = current_user.company_id
      s.created_by = current_user
      s.save
      errors_to_flash s unless s.errors.empty?
  rescue StandardError => e
      add_flash :errors, e.message
      e.log_me
  ensure
      redirect_path = (defined? s) && s ? edit_survey_path(s) : nil
      render json: {flash: {errors: flash[:errors]}, redirect: redirect_path}
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
      errors_to_flash s, now: true
      redirect_to request.referer.presence || '/'
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
    visible_companies << Company.where(master: true).first
    @visible_companies = visible_companies.uniq.compact.sort_by {|c| c.name.try(:upcase) }

    # Only show groups that are not already assigned to the survey
    @groups = Group.joins("LEFT OUTER JOIN survey_responses ON survey_responses.group_id IS NOT NULL and survey_responses.survey_id = #{@survey.id}")
                   .where("survey_responses.id IS NULL").uniq.order(:name)
  end

  def assign
    s = Survey.find params[:id]
    if !s.can_edit? current_user
      error_redirect "You cannot assign users to this survey."
      return
    end
    base_object = nil
    if params[:base_object_id].present? && params[:base_object_type].present?
      cm = CoreModule.find_by(class_name: params[:base_object_type])
      if cm.blank?
        error_redirect "Object type #{params[:base_object_type]} not found."
        return
      end
      bo = cm.klass.find_by id: params[:base_object_id]
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
    if users.present?
      users.each_value do |uid|
        s.generate_response!(User.find(uid), params[:subtitle], bo).delay.invite_user!
        cnt += 1
      end
      if cnt > 0
        add_flash :notices, "#{cnt} #{"user".pluralize(cnt)} assigned."
      end
    end

    cnt = 0
    if groups.present?
      groups.each do |g_id|
        s.generate_group_response!(Group.find(g_id), params[:subtitle], base_object).delay.invite_user!
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
      existing = SurveySubscription.find_by(survey_id: @survey.id, user_id: current_user.id)
      if existing
        existing.destroy
      else
        SurveySubscription.create!(survey_id: @survey.id, user_id: current_user.id)
      end
    end
    redirect_to request.referer.presence || '/'
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
    params[:redirect_to].presence || s
  end

  def permitted_params(params)
    # TODO: For now we are doing a global permit!, which is not the right thing to do.
    # This is to handle a bug in Strong Parameters that was not fixed until 5.
    params.require(:survey).permit!

    # Once we move to Rails 5, we will use the below code.
    # params.require(:survey).except(:company_id, :created_by_id, :updated_at, :archived)
    #     .permit(:email_body, :email_subject, :expiration_days, :name, :ratings_list, :require_contact, :system_code,
    #             :trade_preferences_program_id, :model_field_uid,
    #             questions_attributes: [:content, :choices, :rank, :comment_required_for_choices, :attachment_required_for_choices])
  end
end
