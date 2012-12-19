class CsvMaker
  require 'csv'

  attr_accessor :include_links
  attr_accessor :no_time

  def initialize opts={}
    inner_opts = {:include_links=>false,:no_time=>false}.merge(opts)
    @include_links = inner_opts[:include_links]
    @no_time = inner_opts[:no_time]
  end
  
  def make_from_search(current_search, results)
    columns = current_search.search_columns.order("rank ASC")
    generate results, columns, current_search.search_criterions, current_search.module_chain, current_search.user
  end

  def make_from_results results, columns, module_chain, user, search_criterions = []
    generate results, columns, search_criterions, module_chain, user
  end

  private

  def generate results, columns, criterions, module_chain, user
    CSV.generate(prep_opts(columns)) do |csv|
      GridMaker.new(results,columns,criterions,module_chain,user).go do |row,obj| 
        row << obj.view_url if self.include_links
        row.each_with_index {|v,i| row[i] = format_value(v) }
        csv << row
      end
    end
  end

  def prep_opts columns
    opts = {:write_headers=>true,:row_sep => "\r\n",:headers=>[]} 
    columns.each do |c|
      opts[:headers] << model_field_label(c.model_field_uid)
    end
    opts[:headers] << "Links" if self.include_links
    opts
  end

  def model_field_label(model_field_uid) 
    r = ""
    return "" if model_field_uid.nil?
    mf = ModelField.find_by_uid(model_field_uid)
    return "" if mf.nil?
    return mf.label
  end

  def format_value val
    return "" if val.blank?
    v = val
    v = v.gsub(/\n/,' ').gsub(/\r/,' ') if v.respond_to?(:gsub)
    if v.respond_to?(:strftime)
      if v.is_a?(Date) || @no_time
        v = v.strftime("%Y-%m-%d")
      else
        v = v.strftime("%Y-%m-%d %H:%M")
      end
    end
    v
  end

end
