class CsvMaker
  require 'csv'

  attr_accessor :columns
  attr_accessor :opts
  attr_accessor :all_modules

  def make(current_search, results)
    self.opts = {:write_headers=>true,:row_sep => "\r\n"}
    headers = []
    self.all_modules = []
    self.columns = current_search.search_columns.order("rank ASC")
    self.columns.each do |c|
      headers << model_field_label(c.model_field_uid)
      mf = ModelField.find_by_uid(c.model_field_uid)
      self.all_modules << mf.core_module unless mf.uid == :blank || self.all_modules.include?(mf.core_module)
    end
    opts[:headers] = headers 

    x = CSV.generate(self.opts) do |csv|
      gm = GridMaker.new(results,self.columns,current_search.module_chain)
      gm.go {|row,obj| csv << row}
    end
  end

  def model_field_label(model_field_uid) 
    r = ""
    return "" if model_field_uid.nil?
    mf = ModelField.find_by_uid(model_field_uid)
    return "" if mf.nil?
    return mf.label
  end

end
