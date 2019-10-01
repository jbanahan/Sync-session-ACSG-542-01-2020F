require 'open_chain/url_support'

class CsvMaker
  require 'csv'
  include OpenChain::UrlSupport

  attr_accessor :include_links
  attr_accessor :include_rule_links
  attr_accessor :no_time

  def initialize opts={}
    inner_opts = {:include_links=>false,:include_rule_links=>false,:no_time=>false}.merge(opts)
    @include_links = inner_opts[:include_links]
    @include_rule_links = inner_opts[:include_rule_links]
    @no_time = inner_opts[:no_time]
  end

  def make_from_results results, columns, module_chain, user, search_criterions = []
    generate results, columns, search_criterions, module_chain, user
  end

  def make_from_search_query search_query, search_query_opts = {}
    ss = search_query.search_setup
    errors = []
    raise errors.first unless ss.downloadable?(errors, search_query_opts[:single_page])
    max_results = ss.max_results(search_query.user)

    columns = search_query.search_setup.search_columns.order('rank ASC')
    row_number = 1
    base_objects = {}
    report = CSV.generate(prep_opts(columns, search_query.user)) do |csv|
      search_query_opts[:raise_max_results_error] = true
      search_query.execute(search_query_opts) do |row_hash|
        #it's ok to fill with nil objects if we're not including links because it'll save a lot of DB calls
        key = row_hash[:row_key]
        base_objects[key] ||= ((self.include_links || self.include_rule_links) ? ss.core_module.find(key) : nil)

        row = []
        row_hash[:result].each {|v| row << format_value(v) }
        row << (base_objects[key] ? base_objects[key].view_url : "") if self.include_links
        row << (base_objects[key] ? validation_results_url(obj: base_objects[key]) : "") if self.include_rule_links
        
        csv << row

        row_number += 1
      end
    end
    [report, row_number - 1]
  end

  private
  
  def generate results, columns, criterions, module_chain, user
    CSV.generate(prep_opts(columns, user)) do |csv|
      GridMaker.new(results,columns,criterions,module_chain,user).go do |row,obj| 
        row << obj.view_url if self.include_links
        row << validation_results_url(obj: obj) if self.include_rule_links
        row.each_with_index {|v,i| row[i] = format_value(v) }
        csv << row
      end
    end
  end

  def prep_opts columns, user
    opts = {:write_headers=>true,:row_sep => "\r\n",:headers=>[]} 
    columns.each do |c|
      opts[:headers] << model_field_label(c.model_field_uid, user)
    end
    opts[:headers] << "Links" if self.include_links
    opts[:headers] << "Business Rule Links" if self.include_rule_links
    opts
  end

  def model_field_label(model_field_uid, user) 
    r = ""
    return "" if model_field_uid.nil?
    mf = ModelField.find_by_uid(model_field_uid)
    return mf.can_view?(user) ? mf.label : ModelField.disabled_label
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
