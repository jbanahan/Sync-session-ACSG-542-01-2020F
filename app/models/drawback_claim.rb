class DrawbackClaim < ActiveRecord::Base

  belongs_to :importer, :class_name=>"Company"
  
  validates_presence_of :importer_id
  validates_presence_of :name
  
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
    calc_percent self.total_claim_amount, self.planned_claim_amount  
  end
  
  def can_view? user
    user.view_drawback? && (user.company.master? || user.company_id == self.importer_id || user.company.linked_companies.to_a.include?(self.importer)) 
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
end
