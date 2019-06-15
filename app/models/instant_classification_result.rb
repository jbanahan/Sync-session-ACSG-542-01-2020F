# == Schema Information
#
# Table name: instant_classification_results
#
#  created_at  :datetime         not null
#  finished_at :datetime
#  id          :integer          not null, primary key
#  run_at      :datetime
#  run_by_id   :integer
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_instant_classification_results_on_run_by_id  (run_by_id)
#

class InstantClassificationResult < ActiveRecord::Base
  attr_accessible :finished_at, :run_at, :run_by_id
  
  belongs_to :run_by, :class_name=>"User"
  has_many :instant_classification_result_records
end
