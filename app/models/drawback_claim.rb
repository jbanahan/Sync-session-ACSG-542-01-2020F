# == Schema Information
#
# Table name: drawback_claims
#
#  abi_accepted_date           :date
#  bill_amount                 :decimal(11, 2)
#  billed_date                 :date
#  created_at                  :datetime         not null
#  duty_check_amount           :decimal(11, 2)
#  duty_check_received_date    :date
#  duty_claimed                :decimal(11, 2)
#  entry_number                :string(255)
#  exports_end_date            :date
#  exports_start_date          :date
#  hmf_claimed                 :decimal(11, 2)
#  hmf_mpf_check_amount        :decimal(9, 2)
#  hmf_mpf_check_number        :string(255)
#  hmf_mpf_check_received_date :date
#  id                          :integer          not null, primary key
#  importer_id                 :integer
#  liquidated_date             :date
#  mpf_claimed                 :decimal(11, 2)
#  name                        :string(255)
#  net_claim_amount            :decimal(11, 2)
#  planned_claim_amount        :decimal(11, 2)
#  sent_to_client_date         :date
#  sent_to_customs_date        :date
#  total_claim_amount          :decimal(11, 2)
#  total_duty                  :decimal(11, 2)
#  total_export_value          :decimal(11, 2)
#  total_pieces_claimed        :integer
#  total_pieces_exported       :integer
#  updated_at                  :datetime         not null
#
# Indexes
#
#  index_drawback_claims_on_importer_id  (importer_id)
#

class DrawbackClaim < ActiveRecord::Base
  include CoreObjectSupport
  include UpdateModelFieldsSupport

  belongs_to :importer, :class_name=>"Company"
  
  validates_presence_of :importer_id
  validates_presence_of :name

  has_many :drawback_export_histories, inverse_of: :drawback_claim, dependent: :destroy
  has_many :drawback_claim_audits, inverse_of: :drawback_claim, dependent: :destroy
  
  before_save :set_claim_totals

  scope :viewable, lambda {|u|
    return where("1=0") unless u.view_drawback?
    return where("1=1") if u.company.master?
    where("importer_id = ? OR importer_id IN (SELECT child_id from linked_companies where parent_id = ?)",u.company_id,u.company_id)
  }
  # what percent of the pieces exported were claimed
  # returns 0 if either the pieces claimed or pieces exported are nil or 0
  # else returns decimal value of claimed/exported to 3 decimal places
  # example: 
  # 3 pieces claimed
  # 9 pieces exported
  # return value 0.333
  def percent_pieces_claimed
    calc_percent self.total_pieces_claimed, self.total_pieces_exported
  end

  # what percent of the planned claim amount was actually claimed
  # returns 0 if either value is nil or 0
  # rounds to 3 decimal places
  # example:
  # $3 claimed
  # $9 planned
  # return value 0.333
  def percent_money_claimed
    calc_percent self.net_claim_amount, self.planned_claim_amount  
  end
  
  def can_view? user
    user.view_drawback? && (user.company.master? || user.company_id == self.importer_id || user.company.linked_companies.to_a.include?(self.importer)) 
  end

  def can_comment? user
    self.can_view?(user)
  end

  def can_edit? user
    user.edit_drawback? && (user.company.master? || user.company_id == self.importer_id || user.company.linked_companies.to_a.include?(self.importer)) 
  end

  def can_attach?(user)
    can_edit? user
  end

  def self.search_where(user)
    c = user.company.presence || Company.new
    c.master? ? "1=1" : "(#{table_name}.importer_id = #{c.id} or #{table_name}.importer_id IN (select child_id from linked_companies where parent_id = #{c.id}))"
  end

  #find all duty calc export file lines for the importer and claim date range
  def exports_not_in_import
    r = DutyCalcExportFileLine.not_in_imports.where("duty_calc_export_file_lines.importer_id = ?",self.importer_id).order("duty_calc_export_file_lines.export_date DESC")
    r = r.where("export_date >= ?",self.exports_start_date) if self.exports_start_date
    r = r.where("export_date <= ?",self.exports_end_date) if self.exports_end_date
    r
  end

  private
  def calc_percent num, den
    return 0 if num.nil? || den.nil? || den==0
    BigDecimal(BigDecimal.new(num,3) / BigDecimal.new(den)).round(3,BigDecimal::ROUND_DOWN)
  end

  def set_claim_totals
    self.total_claim_amount = (force_num(self.hmf_claimed) + force_num(self.mpf_claimed) + force_num(self.duty_claimed))
    self.net_claim_amount = self.total_claim_amount - force_num(self.bill_amount)
  end

  def force_num x
    x.nil? ? 0 : x
  end
end
