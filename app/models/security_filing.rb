class SecurityFiling < ActiveRecord::Base
  include CoreObjectSupport 
  belongs_to :importer, :class_name=>'Company'
  has_many :security_filing_lines, :dependent=>:destroy, :order=>'line_number'
  has_many :piece_sets, :through=>:security_filing_lines

  validates_uniqueness_of :host_system_file_number, {:scope=>:host_system, :if=>lambda {!self.host_system_file_number.blank?}}

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
