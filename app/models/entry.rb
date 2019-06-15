# == Schema Information
#
# Table name: entries
#
#  across_declaration_accepted            :datetime
#  across_sent_date                       :datetime
#  ams_hold_date                          :datetime
#  ams_hold_release_date                  :datetime
#  aphis_hold_date                        :datetime
#  aphis_hold_release_date                :datetime
#  arrival_date                           :datetime
#  arrival_notice_receipt_date            :datetime
#  atf_hold_date                          :datetime
#  atf_hold_release_date                  :datetime
#  available_date                         :datetime
#  b3_print_date                          :datetime
#  bol_received_date                      :datetime
#  bond_type                              :string(255)
#  broker_invoice_total                   :decimal(12, 2)
#  broker_reference                       :string(255)
#  cadex_accept_date                      :datetime
#  cadex_sent_date                        :datetime
#  cancelled_date                         :datetime
#  cargo_control_number                   :string(255)
#  cargo_manifest_hold_date               :datetime
#  cargo_manifest_hold_release_date       :datetime
#  carrier_code                           :string(255)
#  carrier_name                           :string(255)
#  cbp_hold_date                          :datetime
#  cbp_hold_release_date                  :datetime
#  cbp_intensive_hold_date                :datetime
#  cbp_intensive_hold_release_date        :datetime
#  census_warning                         :boolean
#  charge_codes                           :string(255)
#  commercial_invoice_numbers             :text
#  company_number                         :string(255)
#  consignee_address_1                    :string(255)
#  consignee_address_2                    :string(255)
#  consignee_city                         :string(255)
#  consignee_state                        :string(255)
#  container_numbers                      :text
#  container_sizes                        :string(255)
#  cotton_fee                             :decimal(11, 2)
#  created_at                             :datetime         not null
#  customer_name                          :string(255)
#  customer_number                        :string(255)
#  customer_references                    :text
#  daily_statement_approved_date          :date
#  daily_statement_due_date               :date
#  daily_statement_number                 :string(255)
#  ddtc_hold_date                         :datetime
#  ddtc_hold_release_date                 :datetime
#  delivery_order_pickup_date             :datetime
#  departments                            :text
#  destination_state                      :string(255)
#  direct_shipment_date                   :date
#  division_number                        :string(255)
#  docs_received_date                     :date
#  documentation_request_date             :datetime
#  duty_due_date                          :date
#  edi_received_date                      :date
#  employee_name                          :string(255)
#  entered_value                          :decimal(13, 2)
#  entry_filed_date                       :datetime
#  entry_number                           :string(255)
#  entry_port_code                        :string(255)
#  entry_type                             :string(255)
#  error_free_release                     :boolean
#  eta_date                               :date
#  exam_ordered_date                      :datetime
#  exam_release_date                      :datetime
#  expected_update_time                   :datetime
#  export_country_codes                   :string(255)
#  export_date                            :date
#  export_state_codes                     :string(255)
#  fcl_lcl                                :string(255)
#  fda_hold_date                          :datetime
#  fda_hold_release_date                  :datetime
#  fda_message                            :string(255)
#  fda_pending_release_line_count         :integer
#  fda_release_date                       :datetime
#  fda_review_date                        :datetime
#  fda_transmit_date                      :datetime
#  file_logged_date                       :datetime
#  final_delivery_date                    :datetime
#  final_statement_date                   :date
#  first_7501_print                       :datetime
#  first_do_issued_date                   :datetime
#  first_entry_sent_date                  :datetime
#  first_it_date                          :date
#  first_release_date                     :datetime
#  first_release_received_date            :datetime
#  fiscal_date                            :date
#  fiscal_month                           :integer
#  fiscal_year                            :integer
#  fish_and_wildlife_hold_date            :datetime
#  fish_and_wildlife_hold_release_date    :datetime
#  fish_and_wildlife_secure_facility_date :datetime
#  fish_and_wildlife_transmitted_date     :datetime
#  free_date                              :datetime
#  freight_pickup_date                    :datetime
#  fsis_hold_date                         :datetime
#  fsis_hold_release_date                 :datetime
#  gross_weight                           :integer
#  hmf                                    :decimal(11, 2)
#  hold_date                              :datetime
#  hold_release_date                      :datetime
#  house_bills_of_lading                  :text
#  house_carrier_code                     :string(255)
#  id                                     :integer          not null, primary key
#  import_country_id                      :integer
#  import_date                            :date
#  importer_id                            :integer
#  importer_request_date                  :datetime
#  importer_tax_id                        :string(255)
#  invoice_paid_date                      :datetime
#  isf_accepted_date                      :datetime
#  isf_sent_date                          :datetime
#  it_numbers                             :text
#  k84_due_date                           :date
#  k84_month                              :integer
#  k84_receive_date                       :date
#  lading_port_code                       :string(255)
#  last_7501_print                        :datetime
#  last_billed_date                       :datetime
#  last_exported_from_source              :datetime
#  last_file_bucket                       :string(255)
#  last_file_path                         :string(255)
#  liquidation_action_code                :string(255)
#  liquidation_action_description         :string(255)
#  liquidation_ada                        :decimal(12, 2)
#  liquidation_cvd                        :decimal(12, 2)
#  liquidation_date                       :datetime
#  liquidation_duty                       :decimal(12, 2)
#  liquidation_extension_code             :string(255)
#  liquidation_extension_count            :integer
#  liquidation_extension_description      :string(255)
#  liquidation_fees                       :decimal(12, 2)
#  liquidation_tax                        :decimal(12, 2)
#  liquidation_total                      :decimal(12, 2)
#  liquidation_type                       :string(255)
#  liquidation_type_code                  :string(255)
#  location_of_goods                      :string(255)
#  location_of_goods_description          :string(255)
#  manifest_info_received_date            :datetime
#  master_bills_of_lading                 :text
#  merchandise_description                :string(255)
#  mfids                                  :text
#  monthly_statement_due_date             :date
#  monthly_statement_number               :string(255)
#  monthly_statement_paid_date            :date
#  monthly_statement_received_date        :date
#  mpf                                    :decimal(11, 2)
#  nhtsa_hold_date                        :datetime
#  nhtsa_hold_release_date                :datetime
#  nmfs_hold_date                         :datetime
#  nmfs_hold_release_date                 :datetime
#  ogd_request_date                       :datetime
#  on_hold                                :boolean
#  one_usg_date                           :datetime
#  origin_country_codes                   :string(255)
#  origin_state_codes                     :string(255)
#  other_agency_hold_date                 :datetime
#  other_agency_hold_release_date         :datetime
#  other_fees                             :decimal(11, 2)
#  paperless_certification                :boolean
#  paperless_release                      :boolean
#  pars_ack_date                          :datetime
#  pars_reject_date                       :datetime
#  part_number_request_date               :datetime
#  part_numbers                           :text
#  pay_type                               :integer
#  po_numbers                             :text
#  po_request_date                        :datetime
#  product_lines                          :string(255)
#  recon_flags                            :string(255)
#  release_cert_message                   :string(255)
#  release_date                           :datetime
#  release_type                           :string(255)
#  ship_terms                             :string(255)
#  source_system                          :string(255)
#  special_program_indicators             :string(255)
#  special_tariff                         :boolean
#  split_release_option                   :string(255)
#  split_shipment                         :boolean
#  split_shipment_date                    :datetime
#  store_names                            :text
#  sub_house_bills_of_lading              :text
#  summary_line_count                     :integer
#  summary_rejected                       :boolean
#  tariff_request_date                    :datetime
#  time_to_process                        :integer
#  total_add                              :decimal(13, 4)
#  total_cvd                              :decimal(13, 4)
#  total_duty                             :decimal(12, 2)
#  total_duty_direct                      :decimal(12, 2)
#  total_duty_gst                         :decimal(11, 2)
#  total_entry_fee                        :decimal(11, 2)
#  total_fees                             :decimal(12, 2)
#  total_gst                              :decimal(11, 2)
#  total_invoiced_value                   :decimal(13, 2)
#  total_non_dutiable_amount              :decimal(13, 2)
#  total_packages                         :integer
#  total_packages_uom                     :string(255)
#  total_taxes                            :decimal(12, 2)
#  total_units                            :decimal(12, 3)
#  total_units_uoms                       :string(255)
#  tracking_status                        :integer
#  transport_mode_code                    :string(255)
#  trucker_called_date                    :datetime
#  ult_consignee_code                     :string(255)
#  ult_consignee_name                     :string(255)
#  unlading_port_code                     :string(255)
#  updated_at                             :datetime         not null
#  us_exit_port_code                      :string(255)
#  usda_hold_date                         :datetime
#  usda_hold_release_date                 :datetime
#  value_currency_request_date            :datetime
#  vendor_names                           :text
#  vessel                                 :string(255)
#  voyage                                 :string(255)
#  worksheet_date                         :datetime
#
# Indexes
#
#  index_entries_on_arrival_date           (arrival_date)
#  index_entries_on_broker_reference       (broker_reference)
#  index_entries_on_cargo_control_number   (cargo_control_number)
#  index_entries_on_customer_number        (customer_number)
#  index_entries_on_customer_references    (customer_references)
#  index_entries_on_division_number        (division_number)
#  index_entries_on_entry_number           (entry_number)
#  index_entries_on_entry_port_code        (entry_port_code)
#  index_entries_on_export_date            (export_date)
#  index_entries_on_house_bills_of_lading  (house_bills_of_lading)
#  index_entries_on_import_country_id      (import_country_id)
#  index_entries_on_importer_id            (importer_id)
#  index_entries_on_k84_due_date           (k84_due_date)
#  index_entries_on_po_numbers             (po_numbers)
#  index_entries_on_release_date           (release_date)
#  index_entries_on_tracking_status        (tracking_status)
#  index_entries_on_transport_mode_code    (transport_mode_code)
#  index_entries_on_updated_at             (updated_at)
#

class Entry < ActiveRecord::Base
  include CoreObjectSupport
  include IntegrationParserSupport

  attr_accessible :across_declaration_accepted, :across_sent_date, 
    :ams_hold_date, :ams_hold_release_date, :aphis_hold_date, 
    :aphis_hold_release_date, :arrival_date, :arrival_notice_receipt_date, 
    :atf_hold_date, :atf_hold_release_date, :available_date, :b3_print_date, 
    :bol_received_date, :bond_type, :broker_invoice_total, :broker_reference, 
    :cadex_accept_date, :cadex_sent_date, :cancelled_date, :cargo_control_number, 
    :cargo_manifest_hold_date, :cargo_manifest_hold_release_date, :carrier_code, 
    :carrier_name, :cbp_hold_date, :cbp_hold_release_date, 
    :cbp_intensive_hold_date, :cbp_intensive_hold_release_date, :census_warning, 
    :charge_codes, :commercial_invoice_numbers, :company_number, 
    :consignee_address_1, :consignee_address_2, :consignee_city, :consignee_state, 
    :container_numbers, :container_sizes, :cotton_fee, :customer_name, 
    :customer_number, :customer_references, :daily_statement_approved_date, 
    :daily_statement_due_date, :daily_statement_number, :ddtc_hold_date, 
    :ddtc_hold_release_date, :delivery_order_pickup_date, :departments, 
    :destination_state, :direct_shipment_date, :division_number, 
    :docs_received_date, :documentation_request_date, :duty_due_date, 
    :edi_received_date, :employee_name, :entered_value, :entry_filed_date, 
    :entry_number, :entry_port_code, :entry_type, :error_free_release, :eta_date, 
    :exam_ordered_date, :exam_release_date, :expected_update_time, 
    :export_country_codes, :export_date, :export_state_codes, :fcl_lcl, 
    :fda_hold_date, :fda_hold_release_date, :fda_message, 
    :fda_pending_release_line_count, :fda_release_date, :fda_review_date, 
    :fda_transmit_date, :file_logged_date, :final_delivery_date, 
    :final_statement_date, :first_7501_print, :first_do_issued_date, 
    :first_entry_sent_date, :first_it_date, :first_release_date, 
    :first_release_received_date, :fiscal_date, :fiscal_month, 
    :fiscal_year, :fish_and_wildlife_hold_date, :fish_and_wildlife_hold_release_date, 
    :fish_and_wildlife_secure_facility_date, :fish_and_wildlife_transmitted_date, 
    :free_date, :freight_pickup_date, :fsis_hold_date, :fsis_hold_release_date, 
    :gross_weight, :hmf, :hold_date, :hold_release_date, :house_bills_of_lading, 
    :house_carrier_code, :import_country_id, :import_date, :importer_id, :importer, 
    :importer_request_date, :importer_tax_id, :invoice_paid_date, :isf_accepted_date, 
    :isf_sent_date, :it_numbers, :k84_due_date, :k84_month, :k84_receive_date, 
    :lading_port_code, :lading_port, :last_7501_print, :last_billed_date, 
    :last_exported_from_source, :last_file_bucket, :last_file_path, 
    :liquidation_action_code, :liquidation_action_description, :liquidation_ada, 
    :liquidation_cvd, :liquidation_date, :liquidation_duty, 
    :liquidation_extension_code, :liquidation_extension_count, 
    :liquidation_extension_description, :liquidation_fees, :liquidation_tax, 
    :liquidation_total, :liquidation_type, :liquidation_type_code, 
    :location_of_goods, :location_of_goods_description, 
    :manifest_info_received_date, :master_bills_of_lading, 
    :merchandise_description, :mfids, :monthly_statement_due_date, 
    :monthly_statement_number, :monthly_statement_paid_date, 
    :monthly_statement_received_date, :mpf, :nhtsa_hold_date, 
    :nhtsa_hold_release_date, :nmfs_hold_date, :nmfs_hold_release_date, 
    :ogd_request_date, :on_hold, :one_usg_date, :origin_country_codes, 
    :origin_state_codes, :other_agency_hold_date, :other_agency_hold_release_date, 
    :other_fees, :paperless_certification, :paperless_release, :pars_ack_date, 
    :pars_reject_date, :part_number_request_date, :part_numbers, :pay_type, 
    :po_numbers, :po_request_date, :product_lines, :recon_flags, 
    :release_cert_message, :release_date, :release_type, :ship_terms, 
    :source_system, :special_program_indicators, :special_tariff, 
    :split_release_option, :split_shipment, :split_shipment_date, :store_names, 
    :sub_house_bills_of_lading, :summary_line_count, :summary_rejected, 
    :tariff_request_date, :time_to_process, :total_add, :total_cvd, :total_duty, 
    :total_duty_direct, :total_duty_gst, :total_entry_fee, :total_fees, :total_gst, 
    :total_invoiced_value, :total_non_dutiable_amount, :total_packages, 
    :total_packages_uom, :total_taxes, :total_units, :total_units_uoms, 
    :tracking_status, :transport_mode_code, :trucker_called_date, 
    :ult_consignee_code, :ult_consignee_name, :unlading_port_code, :unlading_port,
    :us_exit_port_code, :usda_hold_date, :usda_hold_release_date, 
    :value_currency_request_date, :vendor_names, :vessel, :voyage, :worksheet_date, 
    :import_country, :ca_entry_port, :updated_at

  # Tracking status is about whether an entry has been fully prepared
  # It does not report on release status, just whether the entry has been
  # prepared for presentation to customs
  TRACKING_STATUS_CREATED ||= 0 #Entry has been keyed but not sent to customs
  TRACKING_STATUS_OPEN ||= 1 #Entry has been sent to customs
  TRACKING_STATUS_CLOSED ||= 2 #Entry will never be sent to customs

  has_many :broker_invoices, dependent: :destroy, autosave: true, inverse_of: :entry
  has_many :broker_invoice_lines, through: :broker_invoices
  has_many :commercial_invoices, dependent: :destroy, inverse_of: :entry, autosave: true
  has_many :commercial_invoice_lines, through: :commercial_invoices
  has_many :commercial_invoice_tariffs, through: :commercial_invoice_lines
  has_many :entry_comments, dependent: :destroy, inverse_of: :entry, autosave: true
  has_many :containers, dependent: :destroy, inverse_of: :entry, autosave: true
  has_one :daily_statement_entry, inverse_of: :entry

  belongs_to :importer, :class_name=>"Company"
  belongs_to :lading_port, :class_name=>'Port', :foreign_key=>'lading_port_code', :primary_key=>'schedule_k_code'
  belongs_to :unlading_port, :class_name=>'Port', :foreign_key=>'unlading_port_code', :primary_key=>'schedule_d_code'
  belongs_to :us_entry_port, :class_name=>'Port', :foreign_key=>'entry_port_code', :primary_key=>'schedule_d_code'
  belongs_to :ca_entry_port, :class_name=>'Port', :foreign_key=>'entry_port_code', :primary_key=>'cbsa_port'
  belongs_to :us_exit_port, :class_name=>'Port', :foreign_key=>'us_exit_port_code', :primary_key=>'schedule_d_code'
  belongs_to :import_country, :class_name=>"Country"

  before_save :update_k84
  before_save :update_tracking_status

  KEWILL_SOURCE_SYSTEM ||= "Alliance"
  FENIX_SOURCE_SYSTEM ||= "Fenix"

  def locked?
    false
  end

  # can the given user view entries for the given importer
  def self.can_view_importer? importer, user
    user.view_entries? && (user.company.master? || importer.id==user.company_id || user.company.linked_companies.include?(importer))
  end


  #find any broker invoices by source system and broker reference and link them to this entry
  #will replace any existing entry link in the invoices
  def link_broker_invoices
    BrokerInvoice.where(:source_system=>self.source_system,:broker_reference=>self.broker_reference).each do |bi|
      bi.update_attributes(:entry_id=>self.id)
    end
    self.reload
  end

  # Return true if transport mode is 10 or 11.  This is a US-specific method.
  def ocean?
    ['10','11'].include? self.transport_mode_code
  end

  # Return true if transport mode is 40 or 41.  This is a US-specific method.
  def air?
    ['40', '41'].include? self.transport_mode_code
  end

  def ocean_mode? 
    code = self.transport_mode_code.to_i
    return false unless code > 0

    Entry.get_transport_mode_codes_us_ca("SEA").include? code
  end

  def air_mode?
    code = self.transport_mode_code.to_i
    return false unless code > 0

    Entry.get_transport_mode_codes_us_ca("AIR").include? code
  end

  def rail_mode?
    code = self.transport_mode_code.to_i
    return false unless code > 0

    Entry.get_transport_mode_codes_us_ca("RAIL").include? code
  end

  def truck_mode?
    code = self.transport_mode_code.to_i
    return false unless code > 0

    Entry.get_transport_mode_codes_us_ca("TRUCK").include? code
  end

  # Converts a descriptive mode label to an int array of codes, including codes for both the US and Canada (the mode
  # codes for these countries do not overlap).  Unknown mode labels will return an empty array.  Case-insensitive.
  def self.get_transport_mode_codes_us_ca mode_descriptor
    transport_mode_codes = []
    case mode_descriptor.to_s.upcase
      when 'AIR'
        transport_mode_codes = [40,41,1]
      when 'SEA'
        transport_mode_codes = [10,11,9]
      when 'RAIL'
        transport_mode_codes = [20,21,6]
      when 'TRUCK'
        transport_mode_codes = [30,31,2]
    end
    transport_mode_codes
  end

  def value_for_tax
    return nil unless self.canadian?
    values = self.commercial_invoices.map(&:value_for_tax).compact
    values.length == 0 ? nil : values.sum
  end

  def canadian?
    import_country && import_country.iso_code == "CA"
  end

  def can_view? user
    user.view_entries? && company_permission?(user)
  end

  def entry_port
    self.canadian? ? self.ca_entry_port : self.us_entry_port
  end

  def can_comment? user
    user.comment_entries? && company_permission?(user)
  end

  def can_attach? user
    user.attach_entries? && company_permission?(user)
  end

  def can_edit? user
    user.edit_entries? && user.company.broker?
  end

  def self.search_secure user, base_object
    base_object.where(Entry.search_where(user))
  end

  # where clause for search secure
  def self.search_where user
    search_where_by_company_id user.company
  end

  def self.search_where_by_company_id company_id
    if company_id.is_a?(Company)
      c = company_id
    else
      c = Company.find company_id
    end
    
    c.master? ? "1=1" : "(entries.importer_id = #{c.id} or entries.importer_id IN (select child_id from linked_companies where parent_id = #{c.id}))"
  end

  #has liquidation fields
  def liquidation_data?
    self.liquidation_date ||
    (self.liquidation_duty.to_f > 0) ||
    (self.liquidation_fees.to_f > 0) ||
    (self.liquidation_tax.to_f > 0) ||
    (self.liquidation_ada.to_f > 0) ||
    (self.liquidation_cvd.to_f > 0) ||
    (self.liquidation_total.to_f > 0) ||
    (self.liquidation_extension_count.to_f > 0) ||
    !self.liquidation_extension_description.blank? ||
    !(self.liquidation_extension_code.blank? || self.liquidation_extension_code == '00') ||
    !self.liquidation_action_description.blank? ||
    !(self.liquidation_action_code.blank? || self.liquidation_action_code == '00') ||
    !self.liquidation_type.blank? ||
    !(self.liquidation_type_code.blank? || self.liquidation_type_code == '00')
  end

  def split_master_bills_of_lading 
    split_newline_values self.master_bills_of_lading
  end

  def split_house_bills_of_lading
    split_newline_values self.house_bills_of_lading
  end

  def purge! date_purged: Time.zone.now
    Lock.db_lock(self) do
      EntryPurge.create!(broker_reference: broker_reference,
                         country_iso: self.import_country.try(:iso_code),
                         source_system: source_system,
                         date_purged: date_purged)
      raise "Entry could not be deleted, #{self.errors.full_messages}" unless self.destroy
    end
  end

  def self.purged? source_system, broker_reference, source_system_export_date
    EntryPurge.where(source_system: source_system, broker_reference: broker_reference).where("date_purged >= ?", source_system_export_date).exists?
  end

  def first_sale_savings
    line_amounts = []
    commercial_invoices.each do |inv|
      inv.commercial_invoice_lines.each {|cil| line_amounts << cil.first_sale_savings }
    end

    line_amounts.compact.sum
  end
  
  def populated_holds
    if canadian?
      raise RuntimeError, "Only valid for US entries!"
    else
      populated_us_holds
    end
  end

  def active_holds
    if canadian?
      raise RuntimeError, "Only valid for US entries!"
    else
      active_us_holds
    end
  end

  def hold_attributes
    if canadian?
      raise RuntimeError, "Only valid for US entries!"
    else
      all_us_holds.map{ |h| {hold: h[:hold][:attribute], release: h[:release][:attribute]}}
    end
  end

  def split_release_option_value
    case self.split_release_option.to_s
    when "1"
      "Hold All"
    when "2"
      "Incremental"
    else
      ""
    end
  end

  def total_billed_duty_amount
    amt = BigDecimal("0")
    broker_invoices.each {|i| amt += i.total_billed_duty_amount }
    amt
  end

  def total_duty_taxes_fees_amount
    [self.total_duty, self.total_taxes, self.total_fees, self.total_add, self.total_cvd].compact.sum
  end

  def split_shipment_date= date
    super date
    self.split_shipment = date.present?
  end

  def milestone_view_data
    if canadian?
      milestones = []
      milestones << {label: "Departed", value: direct_shipment_date, ship_mode: transport_mode_code}

      case entry_type.to_s.upcase
      when "AB", "LV", "V"
        milestones << {label: "Released", value: release_date, text: entry_port.try(:name)}
        milestones << {label: "Cadex Aquittal", value: cadex_accept_date}
      when "H", "C"
        milestones << {label: "Released", value: (release_date.presence || k84_receive_date), text: entry_port.try(:name)}
        milestones << {label: "Cadex Aquittal", value: k84_receive_date}
      end

      milestones << {label: "K84 Due", value: (k84_due_date.nil? ? nil : (k84_due_date - 1.day))}

      milestones
    else
      [
        {label: "Departed", value: export_date, text: lading_port.try(:name), ship_mode: transport_mode_code}, 
        {label: "Arrived", value: arrival_date, text: entry_port.try(:name)}, 
        {label: "Released", value: release_date}, 
        {label: "Duty Due", value: daily_statement_due_date},
        {label: "Liquidated", value: liquidation_date}
      ]
    end
  end
  
  private

  def populated_us_holds
    all_us_holds.select{ |pair| pair[:hold][:value].present? }
  end

  def active_us_holds
    populated_us_holds.reject{ |pair| pair[:release][:value].present? }
  end

  def all_us_holds
    [{hold: {mfid: :ent_ams_hold_date, attribute: :ams_hold_date, value: ams_hold_date}, release: {mfid: :ent_ams_hold_release_date, attribute: :ams_hold_release_date, value: ams_hold_release_date}}, 
     {hold: {mfid: :ent_aphis_hold_date, attribute: :aphis_hold_date, value: aphis_hold_date}, release: {mfid: :ent_aphis_hold_release_date, attribute: :aphis_hold_release_date, value: aphis_hold_release_date}}, 
     {hold: {mfid: :ent_atf_hold_date, attribute: :atf_hold_date, value: atf_hold_date}, release: {mfid: :ent_atf_hold_release_date, attribute: :atf_hold_release_date, value: atf_hold_release_date}}, 
     {hold: {mfid: :ent_cargo_manifest_hold_date, attribute: :cargo_manifest_hold_date, value: cargo_manifest_hold_date}, release: {mfid: :ent_cargo_manifest_hold_release_date, attribute: :cargo_manifest_hold_release_date, value: cargo_manifest_hold_release_date}},
     {hold: {mfid: :ent_cbp_hold_date, attribute: :cbp_hold_date, value: cbp_hold_date}, release: {mfid: :ent_cbp_hold_release_date, attribute: :cbp_hold_release_date, value: cbp_hold_release_date}},
     {hold: {mfid: :ent_cbp_intensive_hold_date, attribute: :cbp_intensive_hold_date, value: cbp_intensive_hold_date}, release: {mfid: :ent_cbp_intensive_hold_release_date, attribute: :cbp_intensive_hold_release_date, value: cbp_intensive_hold_release_date}},
     {hold: {mfid: :ent_ddtc_hold_date, attribute: :ddtc_hold_date, value: ddtc_hold_date}, release: {mfid: :ent_ddtc_hold_release_date, attribute: :ddtc_hold_release_date, value: ddtc_hold_release_date}},
     {hold: {mfid: :ent_fda_hold_date, attribute: :fda_hold_date, value: fda_hold_date}, release: {mfid: :ent_fda_hold_release_date, attribute: :fda_hold_release_date, value: fda_hold_release_date}},
     {hold: {mfid: :ent_fsis_hold_date, attribute: :fsis_hold_date, value: fsis_hold_date}, release: {mfid: :ent_fsis_hold_release_date, attribute: :fsis_hold_release_date, value: fsis_hold_release_date}},
     {hold: {mfid: :ent_nhtsa_hold_date, attribute: :nhtsa_hold_date, value: nhtsa_hold_date}, release: {mfid: :ent_nhtsa_hold_release_date, attribute: :nhtsa_hold_release_date, value: nhtsa_hold_release_date}},
     {hold: {mfid: :ent_nmfs_hold_date, attribute: :nmfs_hold_date, value: nmfs_hold_date}, release: {mfid: :ent_nmfs_hold_release_date, attribute: :nmfs_hold_release_date, value: nmfs_hold_release_date}},
     {hold: {mfid: :ent_usda_hold_date, attribute: :usda_hold_date, value: usda_hold_date}, release: {mfid: :ent_usda_hold_release_date, attribute: :usda_hold_release_date, value: usda_hold_release_date}},
     {hold: {mfid: :ent_other_agency_hold_date, attribute: :other_agency_hold_date, value: other_agency_hold_date}, release: {mfid: :ent_other_agency_hold_release_date, attribute: :other_agency_hold_release_date, value: other_agency_hold_release_date}},
     {hold: {mfid: :ent_fish_and_wildlife_hold_date, attribute: :fish_and_wildlife_hold_date, value: fish_and_wildlife_hold_date}, release: {mfid: :ent_fish_and_wildlife_hold_release_date, attribute: :fish_and_wildlife_hold_release_date, value: fish_and_wildlife_hold_release_date}, additional_fields: [:ent_fish_and_wildlife_secure_facility_date]}]
  end     

  def company_permission? user
    Entry.can_view_importer? self.importer, user
  end

  def update_tracking_status
    #never automatically override closed
    return true if self.tracking_status == Entry::TRACKING_STATUS_CLOSED

    case self.source_system
    when 'Fenix'
      if self.across_sent_date # Open if sent to customs electronically
        self.tracking_status = Entry::TRACKING_STATUS_OPEN
      elsif self.entry_type && self.entry_type.capitalize == 'V'
        self.tracking_status = Entry::TRACKING_STATUS_OPEN
      else
        self.tracking_status = Entry::TRACKING_STATUS_CREATED
      end
    when 'Alliance'
      if self.entry_filed_date # Open if sent to customs
        self.tracking_status = Entry::TRACKING_STATUS_OPEN
      else
        self.tracking_status = Entry::TRACKING_STATUS_CREATED
      end
    else
      self.tracking_status = Entry::TRACKING_STATUS_OPEN
    end
    true
  end
  
  def update_k84
    k84_basis = nil

    if entry_number.to_s.starts_with?("119810") && (["V", "H", "C"].include? entry_type.to_s.upcase)
      k84_basis = k84_receive_date
    else
      k84_basis = cadex_accept_date
    end

    unless k84_basis.blank?
      month = k84_basis.month 
      # Anything after the 24th is the next month
      month += 1 if  k84_basis.day > 24
      # Anything after 24th of Dec is going to roll to 13th month..of which there isn't one (unless you want to count Undecimber), 
      # so loop back to 1
      month = (month % 12) if month > 12
      year = month==1 && k84_basis.month == 12 ? k84_basis.year + 1 : k84_basis.year
      self.k84_month = month
      self.k84_due_date = Date.new(year,month,25)
    end
  end
end
