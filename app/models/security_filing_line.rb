# == Schema Information
#
# Table name: security_filing_lines
#
#  commercial_invoice_number :string(255)
#  country_of_origin_code    :string(255)
#  created_at                :datetime         not null
#  hts_code                  :string(255)
#  id                        :integer          not null, primary key
#  line_number               :integer
#  manufacturer_name         :string(255)
#  mid                       :string(255)
#  part_number               :string(255)
#  po_number                 :string(255)
#  quantity                  :integer
#  security_filing_id        :integer
#  updated_at                :datetime         not null
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

  attr_accessible :commercial_invoice_number, :country_of_origin_code, :hts_code, 
    :line_number, :manufacturer_name, :mid, :part_number, :po_number, :quantity, 
    :security_filing_id
  
  belongs_to :security_filing
  has_many :piece_sets


  validates_uniqueness_of :line_number, :scope => :security_filing_id	
end
