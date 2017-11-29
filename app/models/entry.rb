class Entry < ActiveRecord::Base
  include CoreObjectSupport
  include IntegrationParserSupport

  # Tracking status is about whether an entry has been fully prepared
  # It does not report on release status, just whether the entry has been
  # prepared for presentation to customs
  TRACKING_STATUS_CREATED ||= 0 #Entry has been keyed but not sent to customs
  TRACKING_STATUS_OPEN ||= 1 #Entry has been sent to customs
  TRACKING_STATUS_CLOSED ||= 2 #Entry will never be sent to customs

  has_many :broker_invoices, dependent: :destroy, autosave: true, inverse_of: :entry
  has_many :broker_invoice_lines, :through => :broker_invoices
  has_many :commercial_invoices, :dependent => :destroy, :autosave => true
  has_many :commercial_invoice_lines, :through => :commercial_invoices
  has_many :commercial_invoice_tariffs, :through => :commercial_invoice_lines
  has_many :entry_comments, :dependent => :destroy, :autosave => true
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
  # Return true if transport mode is 10 or 11
  def ocean?
    ['10','11'].include? self.transport_mode_code
  end

  def air?
    ['40', '41'].include? self.transport_mode_code
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
    ActiveRecord::Base.transaction do
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
    commercial_invoice_lines.map {|cil| cil.first_sale_savings }.compact.sum
  end

  def set_on_hold
    canadian? ? set_ca_on_hold : set_us_on_hold
  end
  
  def set_hold_date
    canadian? ? set_ca_hold_date : set_us_hold_date
  end

  def set_hold_release_date
    canadian? ? set_ca_hold_release_dates : set_us_hold_release_date
  end                       
  
  def all_holds
    if canadian?
      raise RuntimeError, "Only valid for US entries!"
    else
      all_us_holds
    end
  end

  def hold_attributes
    if canadian?
      raise RuntimeError, "Only valid for US entries!"
    else
      us_holds.map{ |h| {hold: h[:hold][:attribute], release: h[:release][:attribute]}}
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
  
  private

  def set_us_on_hold
    self.on_hold = self.one_usg_date ? false : us_holds.reject{ |pair| pair[:release][:value].present? }.map{ |p| p[:hold][:value]}.compact.present?
  end

  def set_us_hold_date
    self.hold_date = us_holds.map{ |pair| pair[:hold][:value] }.compact.min
  end

  def set_us_hold_release_date
    set_on_hold
    if self.one_usg_date 
      self.hold_release_date = self.one_usg_date
    elsif self.on_hold?
      self.hold_release_date = nil 
    else
      self.hold_release_date = us_holds.map{ |pair| pair[:release][:value] }.compact.max
    end
  end

  def all_us_holds
    us_holds.select{ |pair| pair[:hold][:value].present? }
  end

  def us_holds
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
     {hold: {mfid: :ent_other_agency_hold_date, attribute: :other_agency_hold_date, value: other_agency_hold_date}, release: {mfid: :ent_other_agency_hold_release_date, attribute: :other_agency_hold_release_date, value: other_agency_hold_release_date}}]
  end     

  def set_ca_on_hold
    self.on_hold = self.hold_date && !self.hold_release_date ? true : false
  end

  def set_ca_hold_date
    self.hold_date = self.exam_ordered_date
  end

  def set_ca_hold_release_dates
    self.hold_release_date = self.exam_release_date = self.release_date
  end

  def split_newline_values values
    values.blank? ? [] : values.split(/\r?\n */)
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
