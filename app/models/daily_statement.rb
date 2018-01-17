class DailyStatement < ActiveRecord::Base
  include CoreObjectSupport

  has_many :daily_statement_entries, dependent: :destroy, autosave: true, inverse_of: :daily_statement
  belongs_to :monthly_statement
  belongs_to :importer, class_name: "Company"
  belongs_to :port, class_name: "Port", foreign_key: "port_code", primary_key: 'schedule_d_code'

  def self.search_secure user, base_object
    base_object.where(DailyStatement.search_where(user))
  end

  def self.search_where user
    return "1=0" unless user.view_statements?

    if user.master_company?
      return "1=1"
    else
      company = user.company
      return "(daily_statements.importer_id = #{company.id} or daily_statements.importer_id IN (select child_id from linked_companies where parent_id = #{company.id}))"
    end
  end

  def can_view? user
    return false unless user.view_statements?

    if self.importer_id.nil?
      return user.master_company?
    else 
      return user.master_company? || user.company.id == self.importer_id || user.company.linked_company?(self.importer)
    end
  end

  def can_edit? user
    false
  end

  def final_statement?
    self.status.to_s.upcase == "F"
  end

  def pay_type_description
    case self.pay_type.to_i
    when 1
      "Direct Payment"
    when 2
      "Broker Daily Statement"
    when 3
      "Importer Daily Statement"
    when 6
      "Broker Monthly Statement"
    when 7
      "Importer Monthly Statement"
    else
      ""
    end
  end

  def status_description
    case self.status.to_s.upcase
    when 'F'
      "Final"
    when "P"
      "Preliminary"
    else
      ""
    end
  end

  def final_statement?
    self.status.to_s.upcase == "F"
  end
end