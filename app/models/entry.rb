class Entry < ActiveRecord::Base
  include CoreObjectSupport
  has_many :broker_invoices, :dependent => :destroy
  has_many :broker_invoice_lines, :through => :broker_invoices
  has_many :commercial_invoices, :dependent => :destroy
  has_many :commercial_invoice_lines, :through => :commercial_invoices

  belongs_to :importer, :class_name=>"Company"
  belongs_to :lading_port, :class_name=>'Port', :foreign_key=>'lading_port_code', :primary_key=>'schedule_k_code'
  belongs_to :unlading_port, :class_name=>'Port', :foreign_key=>'unlading_port_code', :primary_key=>'schedule_d_code'
  belongs_to :entry_port, :class_name=>'Port', :foreign_key=>'entry_port_code', :primary_key=>'schedule_d_code'
  belongs_to :us_exit_port, :class_name=>'Port', :foreign_key=>'us_exit_port_code', :primary_key=>'schedule_d_code'
  belongs_to :import_country, :class_name=>"Country"

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
    user.edit_entries?
  end

  def self.search_secure user, base_object
    user.company.master? ?  base_object.where("1=1") : base_object.where(:importer_id=>user.company_id)
  end

  private
  def company_permission? user
    self.importer_id==user.company_id || user.company.master?
  end
end
