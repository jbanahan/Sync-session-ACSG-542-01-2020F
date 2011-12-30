class Entry < ActiveRecord::Base
  include CoreObjectSupport
  has_many :broker_invoices, :dependent => :destroy
  has_many :broker_invoice_lines, :through => :broker_invoices
  has_many :commercial_invoices, :dependent => :destroy

  belongs_to :lading_port, :class_name=>'Port', :foreign_key=>'lading_port_code', :primary_key=>'schedule_k_code'
  belongs_to :unlading_port, :class_name=>'Port', :foreign_key=>'unlading_port_code', :primary_key=>'schedule_d_code'
  belongs_to :entry_port, :class_name=>'Port', :foreign_key=>'entry_port_code', :primary_key=>'schedule_d_code'

  def can_view? user
    user.view_entries?
  end

  def can_comment? user
    user.comment_entries?
  end

  def can_attach? user
    user.attach_entries?
  end

  def can_edit? user
    user.edit_entries?
  end

  def self.search_secure user, base_object
    return base_object.where("1=1")
  end
end
