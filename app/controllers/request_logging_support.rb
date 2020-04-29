module RequestLoggingSupport
  extend ActiveSupport::Concern

  def log_request
    return unless current_user && current_user.debug_active?

    RequestLog.build_log_from_request(current_user, request, params).save!
    nil
  end

  def log_run_as_request
    return unless current_user && !run_as_user.nil?

    # Find the current run as session (make one if it's null)
    session = RunAsSession.current_session(run_as_user).first
    if session.nil?
      Lock.acquire("RunAsSession-#{run_as_user.id}") do
        session = RunAsSession.create! user_id: run_as_user.id, run_as_user_id: current_user.id, start_time: Time.zone.now
      end
    end

    Lock.db_lock(session) do
      log = RequestLog.build_log_from_request(run_as_user, request, params)
      log.run_as_session_id = session.id
      log.save!
    end
  end
end