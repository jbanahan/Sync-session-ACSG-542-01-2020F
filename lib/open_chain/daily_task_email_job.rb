module OpenChain; class DailyTaskEmailJob
  def self.run_schedulable
    User.where(task_email:true).each do |u|
      OpenMailer.send_tasks(u).deliver!
    end
  end
end; end;