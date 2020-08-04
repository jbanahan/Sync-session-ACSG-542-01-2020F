module Api; module V1; module Admin; class AnnouncementsController < Api::V1::Admin::AdminApiController

  def index
    announcements = {announcements: Announcement.order(created_at: :desc)}
    render json: announcements.to_json
  end

  def new
    render json: {announcement: {excluded_users: excluded_users(nil)}}
  end

  def edit
    anc = Announcement.find(params[:id])
    if anc
      render json: obj_to_json_hash(anc)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def create
    anc = Announcement.create! base_anc_params.merge(selected_user_ids: user_ids)
    if anc.errors.any?
      render_error anc.errors
    else
      render json: {announcement: {id: anc.id}}
    end
  end

  def update
    anc = Announcement.find params[:id]
    anc.update base_anc_params.merge(selected_user_ids: user_ids)
    if anc.errors.any?
      render_error anc.errors
    else
      render json: {'OK' => 'OK'}
    end
  end

  def destroy
    Announcement.find(params[:id]).destroy
    render json: {'OK' => 'OK'}
  end

  # Only updates the text field in preparation for a preview
  def preview_save
    a = Announcement.find params[:id]
    a.text = params[:announcement][:text]
    a.save!
    render json: {'OK' => 'OK'}
  end

  private

  def user_ids
    if params[:announcement][:category].downcase == "users"
      params[:announcement][:selected_users]&.map(&:to_i) || []
    else
      []
    end
  end

  def submitted_start_at
    datetime_with_offset(params[:announcement][:start_at], current_user.time_zone)
  end

  def submitted_end_at
    datetime_with_offset(params[:announcement][:end_at], current_user.time_zone)
  end

  # Adjust for any discrepancy between browser, user time zones.
  def datetime_with_offset dt_str, time_zone
    utc_offset = ActiveSupport::TimeZone[time_zone].now.utc_offset
    if dt_str
      ActiveSupport::TimeZone["UTC"].parse(dt_str) + ((utc_offset - params[:utc_offset]) / (60 * 60)).hours
    end
  end

  def base_anc_params
    new_params = params.deep_dup
    anc = new_params[:announcement]
    anc.merge!({ start_at: submitted_start_at, end_at: submitted_end_at})
    new_params.except(:selected_users)
              .require(:announcement)
              .permit(:start_at, :end_at, :title, :text, :comments, :category, :selected_user_ids)
  end

  def obj_to_json_hash anc
    hsh = {id: anc.id, start_at: anc.start_at, end_at: anc.end_at, text: anc.text, title: anc.title,
           comments: anc.comments, category: anc.category}
    hsh[:selected_users] = anc.selected_users.map { |u| u.api_hash(include_permissions: false) }
    add_companies(hsh[:selected_users])
    hsh[:excluded_users] = excluded_users(anc)
    {announcement: hsh}.to_json
  end

  def excluded_users anc
    # If arg is nil retrieve all users.
    users = User.joins("LEFT OUTER JOIN user_announcements ua on users.id = ua.user_id and ua.announcement_id = #{anc&.id || 0}")
                .where("ua.id IS NULL")
                .non_system_user
                .enabled
                .map { |u| u.api_hash(include_permissions: false) }
    add_companies users
  end

  def add_companies users
    co = Company.where(id: users.map {|u| u[:company_id] }.uniq).inject({}) do |acc, c| # rubocop:disable Style/EachWithObject -- I'll need to send this through QA again if I change it.
      acc[c.id] = {id: c.id, name: c.name, system_code: c.system_code}
      acc
    end
    users.map! {|u| u.merge({"company" => co[u[:company_id]]})}
  end

end; end; end; end