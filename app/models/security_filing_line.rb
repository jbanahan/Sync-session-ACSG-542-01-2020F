# == Schema Information
#
# Table name: security_filing_lines
#
#  id                        :integer          not null, primary key
#  security_filing_id        :integer
#  line_number               :integer
#  quantity                  :integer
#  hts_code                  :string(255)
#  part_number               :string(255)
#  po_number                 :string(255)
#  commercial_invoice_number :string(255)
#  mid                       :string(255)
#  country_of_origin_code    :string(255)
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  manufacturer_name         :string(255)
#
# Indexes
#
#  index_security_filing_lines_on_part_number         (part_number)
#  index_security_filing_lines_on_po_number           (po_number)
#  index_security_filing_lines_on_security_filing_id  (security_filing_id)
#

class SecurityFilingLine < ActiveRecord::Base
  include LinesSupport
  include CustomFieldSupport
  include ShallowMerger
  belongs_to :security_filing
  has_many :piece_sets


  validates_uniqueness_of :line_number, :scope => :security_filing_id	
end
