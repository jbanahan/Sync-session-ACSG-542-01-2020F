# == Schema Information
#
# Table name: system_identifiers
#
#  code       :string(255)      not null
#  company_id :integer
#  created_at :datetime         not null
#  id         :integer          not null, primary key
#  system     :string(255)      not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_system_identifiers_on_company_id_and_system  (company_id,system)
#  index_system_identifiers_on_system_and_code        (system,code) UNIQUE
#

# This class exists as a means of having multiple identifiers for external feeds
# as a way to uniquely identify a single company entity.
# 
# For instance, we may get 315 data for an importer.  The 315 may reference that 
# importer using "Code A", while another feed like an 856 from another carrier might
# reference that importer using "Code B"
class SystemIdentifier < ActiveRecord::Base
  attr_accessible :code, :company_id, :system, :company
  
  belongs_to :company, inverse_of: :system_identifiers

  validates_presence_of :system, :code

  def self.system_identifier_code company, system
    # allow passing an integer value or the actual Company object
    id = company.respond_to?(:id) ? company.id : company

    SystemIdentifier.where(company_id: id, system: system).limit(1).pluck(:code).first
  end
end
