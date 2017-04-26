module ConfigMigrations; module LL; class Sow1141
  def up
    dates = [1.week.ago, 2.weeks.ago, 3.weeks.ago, 4.weeks.ago]
    count = 0
    User.find_in_batches(batch_size: (User.count/4)) do |group|
      group.each { |user| user.update_attribute(:password_changed_at, dates[count]) }
      count += 1
    end
  end

  def down
    User.update_all(password_changed_at: nil)
  end
end; end; end