class IncrementFiscalDaysFor1909 < ActiveRecord::Migration
  def up
    change_day(1)
  end

  def down
    change_day(-1)
  end

  private

  def change_day inc
    # Only run this migration on WWW system
    return unless MasterSetup.get.custom_feature?("WWW")
    
    jobs = SchedulableJob.where("opts regexp 'fiscal_day'")
    
    SchedulableJob.transaction do
      jobs.each do |j|
        opts = JSON.parse j.opts
        opts["fiscal_day"] += inc.to_i        
        j.opts = opts.to_json
        j.save!
      end
    end
  end

end
