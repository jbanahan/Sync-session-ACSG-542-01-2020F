module Helpers

  # Use this method when you need to evaluate a full excel row as an array
  # There's some underlying comparison that fails when comparing arrays
  # and using an excel date 
  #
  # ie. sheet.row(0) == [excel_date(Date.new(2013, 1, 1))]
  def excel_date date
    #Excel internally stores date values as days since Jan 1, 1900
    excel_start_date = Date.new(1899, 12, 30).jd
    (date.jd - excel_start_date).to_f
  end
end