class Entry < ActiveRecord::Base
  include CoreObjectSupport
  include IntegrationParserSupport

  # Tracking status is about whether an entry has been fully prepared
  # It does not report on release status, just whether the entry has been
  # prepared for presentation to customs
  TRACKING_STATUS_CREATED ||= 0 #Entry has been keyed but not sent to customs
  TRACKING_STATUS_OPEN ||= 1 #Entry has been sent to customs
  TRACKING_STATUS_CLOSED ||= 2 #Entry will never be sent to customs

  has_many :broker_invoices, :dependent => :destroy
  has_many :broker_invoice_lines, :through => :broker_invoices
  has_many :commercial_invoices, :dependent => :destroy, :autosave => true
  has_many :commercial_invoice_lines, :through => :commercial_invoices
  has_many :commercial_invoice_tariffs, :through => :commercial_invoice_lines
  has_many :entry_comments, :dependent=>:destroy
  has_many :containers, dependent: :destroy, inverse_of: :entry

  belongs_to :importer, :class_name=>"Company"
  belongs_to :lading_port, :class_name=>'Port', :foreign_key=>'lading_port_code', :primary_key=>'schedule_k_code'
  belongs_to :unlading_port, :class_name=>'Port', :foreign_key=>'unlading_port_code', :primary_key=>'schedule_d_code'
  belongs_to :us_entry_port, :class_name=>'Port', :foreign_key=>'entry_port_code', :primary_key=>'schedule_d_code'
  belongs_to :ca_entry_port, :class_name=>'Port', :foreign_key=>'entry_port_code', :primary_key=>'cbsa_port'
  belongs_to :us_exit_port, :class_name=>'Port', :foreign_key=>'us_exit_port_code', :primary_key=>'schedule_d_code'
  belongs_to :import_country, :class_name=>"Country"

  before_save :update_k84
  before_save :update_tracking_status

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
    search_where_by_company_id user.company_id
  end

  def self.search_where_by_company_id company_id
    c = Company.find company_id
    c.master? ? "1=1" : "(entries.importer_id = #{c.id} or entries.importer_id IN (select child_id from linked_companies where parent_id = #{c.id}))"
  end

  #has liquidation fields
  def liquidation_data?
    self.liquidation_date ||
    (self.liquidation_duty && self.liquidation_duty > 0) ||
    (self.liquidation_fees && self.liquidation_fees > 0) ||
    (self.liquidation_tax && self.liquidation_tax > 0) ||
    (self.liquidation_ada && self.liquidation_ada > 0) ||
    (self.liquidation_cvd && self.liquidation_cvd > 0) ||
    (self.liquidation_total && self.liquidation_total > 0) ||
    (self.liquidation_extension_count && self.liquidation_extension_count > 0) ||
    !self.liquidation_extension_description.blank? ||
    self.liquidation_extension_code != '00' ||
    !self.liquidation_action_description.blank? ||
    self.liquidation_action_code != '00' ||
    !self.liquidation_type.blank? ||
    self.liquidation_type_code != '00' 
  end

  def split_master_bills_of_lading 
    split_newline_values self.master_bills_of_lading
  end

  def split_house_bills_of_lading
    split_newline_values self.house_bills_of_lading
  end

  private
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

    if entry_number.to_s.starts_with?("119810") && entry_type.to_s.upcase == "V"
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
