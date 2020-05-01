module Api; module V1; class AnnouncementsController < Api::V1::ApiController

  def confirm
    ids = params['announcement_ids'].split(",")
    Lock.db_lock(current_user) do
      ancs = Announcement.joins("LEFT OUTER JOIN user_announcement_markers uam ON announcements.id = uam.announcement_id AND uam.user_id = #{current_user.id}")
                         .where("uam.confirmed_at IS NULL")
                         .where(id: ids)

      ancs.each { |a| a.user_announcement_markers.create! user_id: current_user.id, confirmed_at: Time.zone.now }
    end
    render json: {'OK' => 'OK'}
  end

  def count
    render json: {count: current_user.new_announcements.count}
  end

  def hide_from_user
    a = Announcement.find params[:id]
    a.hide_from_user(current_user.id)
    render json: {'OK' => 'OK'}
  end

end; end; end
