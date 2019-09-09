# == Schema Information
#
# Table name: security_filings
#
#  ams_match_date                :datetime
#  booking_number                :string(255)
#  broker_customer_number        :string(255)
#  cbp_updated_at                :datetime
#  container_numbers             :string(255)
#  countries_of_origin           :text(65535)
#  created_at                    :datetime         not null
#  delete_accepted_date          :datetime
#  entry_numbers                 :string(255)
#  entry_port_code               :string(255)
#  entry_reference_numbers       :string(255)
#  estimated_vessel_arrival_date :date
#  estimated_vessel_load_date    :date
#  estimated_vessel_sailing_date :date
#  file_logged_date              :datetime
#  first_accepted_date           :datetime
#  first_sent_date               :datetime
#  host_system                   :string(255)
#  host_system_file_number       :string(255)
#  house_bills_of_lading         :string(255)
#  id                            :integer          not null, primary key
#  importer_account_code         :string(255)
#  importer_id                   :integer
#  importer_tax_id               :string(255)
#  lading_port_code              :string(255)
#  last_accepted_date            :datetime
#  last_event                    :datetime
#  last_file_bucket              :string(255)
#  last_file_path                :string(255)
#  last_sent_date                :datetime
#  late_filing                   :boolean
#  manufacturer_names            :text(65535)
#  master_bill_of_lading         :string(255)
#  notes                         :text(65535)
#  po_numbers                    :string(255)
#  scac                          :string(255)
#  status_code                   :string(255)
#  status_description            :string(255)
#  time_to_process               :integer
#  transaction_number            :string(255)
#  transport_mode_code           :string(255)
#  unlading_port_code            :string(255)
#  updated_at                    :datetime         not null
#  us_customs_first_file_date    :datetime
#  vessel                        :string(255)
#  vessel_departure_date         :datetime
#  voyage                        :string(255)
#
# Indexes
#
#  index_security_filings_on_container_numbers           (container_numbers)
#  index_security_filings_on_entry_numbers               (entry_numbers)
#  index_security_filings_on_entry_reference_numbers     (entry_reference_numbers)
#  index_security_filings_on_estimated_vessel_load_date  (estimated_vessel_load_date)
#  index_security_filings_on_first_accepted_date         (first_accepted_date)
#  index_security_filings_on_first_sent_date             (first_sent_date)
#  index_security_filings_on_host_system                 (host_system)
#  index_security_filings_on_host_system_file_number     (host_system_file_number)
#  index_security_filings_on_house_bills_of_lading       (house_bills_of_lading)
#  index_security_filings_on_importer_id                 (importer_id)
#  index_security_filings_on_master_bill_of_lading       (master_bill_of_lading)
#  index_security_filings_on_po_numbers                  (po_numbers)
#  index_security_filings_on_transaction_number          (transaction_number)
#

class SecurityFiling < ActiveRecord::Base
  include CoreObjectSupport 
  include IntegrationParserSupport

  attr_accessible :ams_match_date, :booking_number, :broker_customer_number, 
    :cbp_updated_at, :container_numbers, :countries_of_origin, 
    :delete_accepted_date, :entry_numbers, :entry_port_code, 
    :entry_reference_numbers, :estimated_vessel_arrival_date, 
    :estimated_vessel_load_date, :estimated_vessel_sailing_date, 
    :file_logged_date, :first_accepted_date, :first_sent_date, :host_system, 
    :host_system_file_number, :house_bills_of_lading, :importer_account_code, 
    :importer_id, :importer_tax_id, :lading_port_code, :last_accepted_date, 
    :last_event, :last_file_bucket, :last_file_path, :last_sent_date, 
    :late_filing, :manufacturer_names, :master_bill_of_lading, :notes, 
    :po_numbers, :scac, :status_code, :status_description, :time_to_process, 
    :transaction_number, :transport_mode_code, :unlading_port_code, 
    :us_customs_first_file_date, :vessel, :vessel_departure_date, :voyage
  
  belongs_to :lading_port, :class_name=>'Port', :foreign_key=>'lading_port_code', :primary_key=>'schedule_k_code'
  belongs_to :unlading_port, :class_name=>'Port', :foreign_key=>'unlading_port_code', :primary_key=>'schedule_d_code'
  belongs_to :entry_port, :class_name=>'Port', :foreign_key=>'entry_port_code', :primary_key=>'schedule_d_code'
  
  belongs_to :importer, :class_name=>'Company'
  has_many :security_filing_lines, -> { order(:line_number) }, dependent: :destroy, autosave: true
  has_many :piece_sets, :through=>:security_filing_lines

  validates_uniqueness_of :host_system_file_number, {:scope=>:host_system, :if=>lambda {!self.host_system_file_number.blank?}}
  scope :not_matched, -> { where(:status_code=>"ACCNOMATCH") }

  def can_view? user
    user.view_security_filings? && company_permission?(user) 
  end

  def can_edit? user
    user.edit_security_filings? && user.company.master?
  end

  def can_attach? user
    user.attach_security_filings? && user.company.master?
  end

  def can_comment? user
    user.comment_security_filings? && user.company.master?
  end

  def matched?
    self.status_code == "ACCMATCH"
  end

  def self.search_secure user, base_object
    base_object.where(search_where(user))
  end

  # where clause for search secure
  def self.search_where user
    user.company.master? ?  "1=1" : "security_filings.importer_id = #{user.company_id} or security_filings.importer_id IN (select child_id from linked_companies where parent_id = #{user.company_id})"
  end
  
  private
  def company_permission? user
    self.importer_id==user.company_id || user.company.master? || user.company.linked_companies.include?(self.importer)
  end
end
