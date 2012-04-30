class DrawbackImportLine < ActiveRecord::Base
  include LinesSupport

  has_many :duty_calc_import_file_lines, :dependent=>:destroy

  scope :not_in_duty_calc_file, lambda { joins("left outer join duty_calc_import_file_lines on drawback_import_lines.id = duty_calc_import_file_lines.drawback_import_line_id").where("duty_calc_import_file_lines.id is null") }
  # Output a string matching the DutyCalc ASCII import format
  def duty_calc_line
    [
      self.entry_number,
      self.import_date.strftime("%m/%d/%Y"),
      self.received_date.strftime("%m/%d/%Y"),
      "",
      self.port_code,
      "%0.2f" % float_or_zero(self.box_37_duty),
      "%0.2f" % float_or_zero(self.box_40_duty),
      "",
      "%0.2f" % float_or_zero(self.total_invoice_value),
      "%0.2f" % float_or_zero(self.total_mpf),
      "1",
      "",
      self.id.to_s,
      "",
      "",
      self.country_of_origin_code,
      "",
      "",
      self.part_number,
      self.part_number,
      self.hts_code,
      self.description,
      self.unit_of_measure,
      "",
      "%0.9f" % float_or_zero(self.quantity), #quantity imported
      "%0.9f" % float_or_zero(self.quantity), #quantity available
      "",
      "%0.7f" % float_or_zero(self.unit_price),
      "",
      "",
      "",
      "%0.9f" % float_or_zero(self.rate),
      "",
      "",
      "",
      "%0.9f" % float_or_zero(self.duty_per_unit),
      "7",
      "",
      (self.ocean? ? "Y" : "")
    ].to_csv
  end



  private

  def float_or_zero val
    val.blank? ? 0 : val
  end
  def fix_width str, length, ljust=true
    r = ""
    unless str.blank?
      r = str
      r = r[0,length] if r.length > length
    end
    if ljust
      r = r.ljust(length)
    else
      r = r.rjust(length)
    end
    r
  end
end
