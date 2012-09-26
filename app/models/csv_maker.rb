class CsvMaker
  require 'csv'

  attr_accessor :include_links

  def initialize opts={}
    inner_opts = {:include_links=>false}.merge(opts)
    @include_links = inner_opts[:include_links]
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
        row.each_with_index {|v,i| row[i] = v.gsub(/\n/,' ').gsub(/\r/,' ') if v.respond_to?(:gsub)}
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

end
