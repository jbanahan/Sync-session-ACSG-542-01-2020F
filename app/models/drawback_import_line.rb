class DrawbackImportLine < ActiveRecord::Base
  include LinesSupport

  # Output a string matching the DutyCalc ASCII import format
  def duty_calc_line
    r = ""
    r << fix_width(self.entry_number, 11)
    r << self.import_date.strftime("%m/%d/%Y")
    r << self.received_date.strftime("%m/%d/%Y")
    r << "00/00/0000"
    r << fix_width(self.port_code, 4)
    r << "%011.2f" % float_or_zero(self.box_37_duty)
    r << "%011.2f" % float_or_zero(self.box_40_duty)
    r << "00/00/0000"
    r << "%011.2f" % float_or_zero(self.total_invoice_value)
    r << "%011.2f" % float_or_zero(self.total_mpf)
    r << "01.000000"
    r << "     "
    r << fix_width(self.id.to_s, 30, false)
    r << "".ljust(60)
    r << fix_width(self.country_of_origin_code, 2)
    r << "  "
    r << "".ljust(11)
    r << fix_width(self.part_number, 30) #regular part number
    r << fix_width(self.part_number, 30) #external part number
    r << fix_width(self.hts_code, 10)
    r << fix_width(self.description, 30)
    r << fix_width(self.unit_of_measure, 3)
    r << "01.000000"
    r << "%019.9f" % float_or_zero(self.quantity) #quantity imported
    r << "%019.9f" % float_or_zero(self.quantity) #quantity available
    r << "".ljust(19)
    r << "%017.7f" % float_or_zero(self.unit_price)
    r << "".ljust(51)
    r << "%013.8f" % float_or_zero(self.rate)
    r << "".ljust(39)
    r << "%017.9f" % float_or_zero(self.duty_per_unit)
    r << "7"
    r << " "
    r << (self.ocean? ? "Y" : " ")
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
