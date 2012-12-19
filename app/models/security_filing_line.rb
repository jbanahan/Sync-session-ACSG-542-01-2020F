class SecurityFilingLine < ActiveRecord::Base
  include LinesSupport
  include CustomFieldSupport
  include ShallowMerger
  belongs_to :security_filing
  has_many :piece_sets


  validates_uniqueness_of :line_number, :scope => :security_filing_id	
end
