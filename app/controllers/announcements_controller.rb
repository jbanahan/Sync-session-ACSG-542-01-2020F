class AnnouncementsController < ApplicationController

  def index_for_user
    # find announcements of type 'all' along with those of type 'users' that are associated with current_user
    qry = <<-SQL
        LEFT OUTER JOIN user_announcement_markers uam ON announcements.id = uam.announcement_id AND uam.user_id = ?
      WHERE (uam.hidden = false OR uam.hidden IS NULL)
        AND announcements.start_at < NOW()
        AND announcements.end_at > ?
        AND (announcements.category = "all" OR uam.id IS NOT NULL)
      ORDER BY announcements.created_at DESC
    SQL
    @announcements = Announcement.select("announcements.id, announcements.start_at, announcements.title, uam.confirmed_at")
                                 .joins ActiveRecord::Base.sanitize_sql_array([qry, current_user.id, Time.zone.now - 30.days])
    render layout: false
  end

  def show_modal
    @user = current_user
    @announcements = params[:ids] ? Announcement.where(id: params[:ids].split(",")).order(created_at: :desc) : @user.new_announcements
    @no_confirm = params[:no_confirm]

    render partial: "show_modal"
  end

end
