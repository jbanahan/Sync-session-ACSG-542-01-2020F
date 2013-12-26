class Entry < ActiveRecord::Base
  include CoreObjectSupport
  include IntegrationParserSupport
  has_many :broker_invoices, :dependent => :destroy
  has_many :broker_invoice_lines, :through => :broker_invoices
  has_many :commercial_invoices, :dependent => :destroy
  has_many :commercial_invoice_lines, :through => :commercial_invoices
  has_many :commercial_invoice_tariffs, :through => :commercial_invoice_lines
  has_many :entry_comments, :dependent=>:destroy

  belongs_to :importer, :class_name=>"Company"
  belongs_to :lading_port, :class_name=>'Port', :foreign_key=>'lading_port_code', :primary_key=>'schedule_k_code'
  belongs_to :unlading_port, :class_name=>'Port', :foreign_key=>'unlading_port_code', :primary_key=>'schedule_d_code'
  belongs_to :entry_port, :class_name=>'Port', :foreign_key=>'entry_port_code', :primary_key=>'schedule_d_code'
  belongs_to :us_exit_port, :class_name=>'Port', :foreign_key=>'us_exit_port_code', :primary_key=>'schedule_d_code'
  belongs_to :import_country, :class_name=>"Country"

  before_save :update_k84_month

  def locked?
    false
  end

  # can the given user view entries for the given importer
  def self.can_view_importer? importer, user
    user.company.master? || importer.id==user.company_id || user.company.linked_companies.include?(importer)
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

  def can_view? user
    user.view_entries? && company_permission?(user)
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
    c.master? ? "1=1" : "entries.importer_id = #{c.id} or entries.importer_id IN (select child_id from linked_companies where parent_id = #{c.id})"
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
  private
  def company_permission? user
    Entry.can_view_importer? self.importer, user
  end

  def update_k84_month 
    unless self.cadex_accept_date.blank?
      date = self.cadex_accept_date
      month = date.month 
      # Anything after the 24th is the next month
      month += 1 if  date.day > 24
      # Anything after 24th of Dec is going to roll to 13th month..of which there isn't one (unless you want to count Undecimber), 
      # so loop back to 1
      month = (month % 12) if month > 12
      self.k84_month = month
    end
  end
end
