class CsvMaker
  require 'csv'

  attr_accessor :columns
  attr_accessor :opts
  attr_accessor :all_modules

  def make(current_search, core_module, results)
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

    if core_module==CoreModule::PRODUCT
      return handle_product core_module, current_search, results
    else
      return handle_other core_module, current_search, results
    end
  end

  def handle_product(core_module,current_search,results)
    x = CSV.generate(self.opts) do |csv|
      results.each do |r|
        if self.all_modules.include?(CoreModule::CLASSIFICATION) || self.all_modules.include?(CoreModule::TARIFF)
          r.classifications.each do |rc|
            if self.all_modules.include?(CoreModule::TARIFF)
              rc.tariff_records.each do |rt|
                csv << make_row({CoreModule::PRODUCT => r, CoreModule::CLASSIFICATION => rc, CoreModule::TARIFF => rt})
              end
            else
              csv << make_row({CoreModule::PRODUCT => r, CoreModule::CLASSIFICATION => rc})
            end
          end
        else
          csv << make_row({CoreModule::PRODUCT => r})
        end
      end
    end
  end

  def make_row(obj_hash)
    row = []
    self.columns.each do |col|
      if(col.model_field_uid=="_blank") 
        row << ""
      else
        mf = ModelField.find_by_uid(col.model_field_uid)
        row << mf.process_export(obj_hash[mf.core_module])
      end
    end
    row
  end

  def handle_other(core_module,current_search,results)
    x = CSV.generate(self.opts) do |csv|
      results.each do |r|
        to_append = []
        current_search.search_columns.order("rank ASC").each do |c|
          mf = ModelField.find_by_uid(c.model_field_uid)
          if mf.uid==:_blank || mf.core_module==core_module
            to_append << mf.process_export(r)
          else
            joined = ""
            
            core_module.children(mf.core_module,r).each do |child|
              joined << "#{mf.process_export child}"
            end
            to_append << joined
          end
        end
        csv << to_append
      end
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
