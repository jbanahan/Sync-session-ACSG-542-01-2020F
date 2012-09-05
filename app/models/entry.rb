class Entry < ActiveRecord::Base
  include CoreObjectSupport
  has_many :broker_invoices, :dependent => :destroy
  has_many :broker_invoice_lines, :through => :broker_invoices
  has_many :commercial_invoices, :dependent => :destroy
  has_many :commercial_invoice_lines, :through => :commercial_invoices
  has_many :commercial_invoice_tariffs, :through => :commercial_invoice_lines

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
    user.edit_entries? && user.company.broker?
  end

  def self.search_secure user, base_object
    base_object.where(Entry.search_where(user))
  end

  # where clause for search secure
  def self.search_where user
    user.company.master? ?  "1=1" : "entries.importer_id = #{user.company_id} or entries.importer_id IN (select child_id from linked_companies where parent_id = #{user.company_id})"
  end

  #get the S3 path for the last file used to update this entry (if one exists)
  def last_file_secure_url(expires_in=60.seconds)
    return nil if self.last_file_bucket.blank? || self.last_file_path.blank?
    AWS::S3.new(AWS_CREDENTIALS).buckets[self.last_file_bucket].objects[self.last_file_path].url_for(:read,:expires=>expires_in,:secure=>true).to_s
  end
  private
  def company_permission? user
    self.importer_id==user.company_id || user.company.master? || user.company.linked_companies.include?(self.importer)
  end
end
