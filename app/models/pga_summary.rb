# == Schema Information
#
# Table name: pga_summaries
#
#  agency_code                  :string(255)
#  agency_processing_code       :string(255)
#  commercial_description       :string(255)
#  commercial_invoice_tariff_id :integer          not null
#  created_at                   :datetime
#  disclaimer_type_code         :string(255)
#  id                           :integer          not null, primary key
#  program_code                 :string(255)
#  sequence_number              :integer
#  tariff_regulation_code       :string(255)
#  updated_at                   :datetime
#
# Indexes
#
#  index_pga_summaries_on_commercial_invoice_tariff_id  (commercial_invoice_tariff_id)
#

class PgaSummary < ActiveRecord::Base
  attr_accessible :agency_code, :agency_processing_code, :commercial_description, :disclaimer_type_code, :program_code, :tariff_regulation_code, :sequence_number

  belongs_to :commercial_invoice_tariff, inverse_of: :pga_summaries
end
