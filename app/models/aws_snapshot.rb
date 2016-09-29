class AwsSnapshot < ActiveRecord::Base
  belongs_to :aws_backup_session, inverse_of: :aws_snapshots

  def tags
    j = self.tags_json
    j.blank? ? {} : ActiveSupport::JSON.decode(j)
  end

  def tags= tags
    if tags.nil?
      self.tags_json = nil
    else
      self.tags_json = ActiveSupport::JSON.encode(tags)  
    end
  end
end