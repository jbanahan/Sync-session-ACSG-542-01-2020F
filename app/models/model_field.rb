class ModelField
  attr_accessor :model
  attr_accessor :field
  attr_accessor :label
  attr_accessor :sort_rank
  attr_accessor :detail
  attr_accessor :import_lambda
  attr_accessor :export_lambda
  
  def initialize(rank,model, field, label, options={})
    @sort_rank = rank
    @model = model
    @field = field
    @label = label
    @detail = options[:detail].nil? ? false : options[:detail]
    @import_lambda = options[:import_lambda].nil? ? lambda {|obj,data| 
      obj.send("#{@field}=".intern,data)
      return "#{@label} set to #{data}"
    } : options[:import_lambda]
    @export_lambda = options[:export_lambda].nil? ? lambda {|obj|
      obj.send("#{@field}")
    } : options[:export_lambda]
  end
  
  #code to process when importing a field
  def process_import(obj,data)
    @import_lambda.call(obj,data)
  end
  
  def process_export(obj)
    obj.nil? ? '' : @export_lambda.call(obj)
  end
  
  def detail?
    @detail
  end
  
  def uid
    return "#{@model}-#{@field}-#{@label}"
  end
end
