class InstantClassificationResult < ActiveRecord::Base
  belongs_to :run_by, :class_name=>"User"
  has_many :instant_classification_result_records
end
