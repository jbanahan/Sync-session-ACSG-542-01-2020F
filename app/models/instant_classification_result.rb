# == Schema Information
#
# Table name: instant_classification_results
#
#  id          :integer          not null, primary key
#  run_by_id   :integer
#  run_at      :datetime
#  finished_at :datetime
#  created_at  :datetime
#  updated_at  :datetime
#
# Indexes
#
#  index_instant_classification_results_on_run_by_id  (run_by_id)
#

class InstantClassificationResult < ActiveRecord::Base
  belongs_to :run_by, :class_name=>"User"
  has_many :instant_classification_result_records
end
