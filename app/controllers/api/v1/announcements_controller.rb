module Api; module V1; class AnnouncementsController < Api::V1::ApiController

  def confirm
    Lock.db_lock(current_user) do
      ancs = Announcement.joins("LEFT OUTER JOIN user_announcement_markers uam ON announcements.id = uam.announcement_id AND uam.user_id = #{current_user.id}")
                         .where("uam.confirmed_at IS NULL")
                         .where(id: params['anc_ids'])

      ancs.each { |a| a.user_announcement_markers.create! user_id: current_user.id, confirmed_at: Time.zone.now }
      ancs.select { |a| Array.wrap(params[:email_anc_ids]).map(&:to_i).include? a.id }.each do |email_anc|
        OpenMailer.send_announcement(email_anc.id, current_user.id).deliver_later
      end
    end
    render json: {'OK' => 'OK'}
  end

  def count
    count = nil
    # Run this query on the replica database
    distribute_reads { count = {count: current_user.new_announcements.count} }
    render json: count
  end

  def hide_from_user
    a = Announcement.find params[:id]
    a.hide_from_user(current_user.id)
    render json: {'OK' => 'OK'}
  end

end; end; end
