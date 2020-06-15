# == Schema Information
#
# Table name: runtime_logs
#
#  created_at           :datetime         not null
#  end                  :datetime
#  id                   :integer          not null, primary key
#  identifier           :string(255)
#  runtime_logable_id   :integer
#  runtime_logable_type :string(255)
#  start                :datetime
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_runtime_logs_on_created_at       (created_at)
#  index_runtime_logs_on_runtime_logable  (runtime_logable_type,runtime_logable_id)
#

class RuntimeLog < ActiveRecord::Base
  attr_accessible :runtime_logable, :identifier, :start, :end
  belongs_to :runtime_logable, polymorphic: true

  def can_view? user
    user.admin?
  end

  def self.find_can_view user
    if user.admin?
      RuntimeLog.all
    end
  end

  def self.purge record_keep_count = 25
    ActiveRecord::Base.connection.exec_query(sanitize_sql_array(["SELECT runtime_logable_id, runtime_logable_type
      FROM runtime_logs
      GROUP BY runtime_logable_id, runtime_logable_type
      HAVING COUNT(id) > ?", record_keep_count])).each do |r|
      logs = RuntimeLog.where(runtime_logable_id: r["runtime_logable_id"], runtime_logable_type: r["runtime_logable_type"]).sort_by(&:created_at).reverse
      logs.each_with_index do |l, i|
        next if i < record_keep_count
        RuntimeLog.find(l.id).destroy
      end
    end
  end
end
