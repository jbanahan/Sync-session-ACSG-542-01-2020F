class ImportConfig < ActiveRecord::Base  
  
  validate :ic_validation
  validates_presence_of :name, :model_type, :file_type
  
  has_many :import_config_mappings, :dependent => :destroy
  has_many :imported_files, :dependent => :destroy
  
  accepts_nested_attributes_for :import_config_mappings, :reject_if => lambda { |a| a[:model_field_uid].blank? }




  MODEL_TYPES = {:order => "Order", :product => "Product"}
  
  MODEL_FIELDS = Hash.new
  MODEL_FIELDS[:product] = Hash.new
  [
    [1,:product,:unique_identifier,"Unique Identifier"],
    [3,:product,:name,"Name"],
    [4,:product,:description,"Description"],
    [5,:product,:vendor_id,"Vendor ID"]
  ].each do |m|
    mf = ModelField.new(m[0],m[1],m[2],m[3],m[4].nil? ? {} : m[4])
    MODEL_FIELDS[:product][mf.uid.intern] = mf 
  end
  MODEL_FIELDS[:order] = Hash.new
  [
    [1,:order,:order_number,"Header - Order Number"],
    [2,:order,:order_date,"Header - Order Date"],
    [5,:order,:vendor_id,"Header - Vendor ID"],
    [6,:order,:product_unique_identifier,"Line - Product Unique Identifier",{:detail => true, 
      :import_lambda => lambda {|detail,data| 
        detail.product = Product.where(:unique_identifier => data).first
        return "Line - Product set to #{data}"
        },
      :export_lambda => lambda {|detail|
        detail.product.unique_identifier
        }
      }],
    [7,:order,:line_number,"Line - Line Number",{:detail => true}],
    [8,:order,:ordered_qty,"Line - Order Quantity",{:detail => true}],
    [9,:order,:price_per_unit,"Line - Price / Unit",{:detail => true}]
  ].each do |m|
    mf = ModelField.new(m[0],m[1],m[2],m[3],m[4].nil? ? {} : m[4])
    MODEL_FIELDS[:order][mf.uid.intern] = mf 
  end
  
  def self.add_custom_fields(model_hash,base_class,label_prefix,parameters={})
    max = 0
    model_hash.values.each {|mf| max = mf.sort_rank + 1 if mf.sort_rank > max}
    base_class.new.custom_definitions.each_with_index do |d,index|
      class_symbol = base_class.to_s.downcase
      mf = ModelField.new(max+index,class_symbol,"custom_#{d.id}".intern,"#{label_prefix}#{d.label}",parameters.merge({:custom_id=>d.id}))
      model_hash[mf.uid.intern] = mf
    end
  end
	ImportConfig.add_custom_fields(MODEL_FIELDS[:order],Order,"Header - ")
	ImportConfig.add_custom_fields(MODEL_FIELDS[:order],OrderLine,"Line - ",{:detail => true})
  ImportConfig.add_custom_fields(MODEL_FIELDS[:product],Product,"")
    
  def self.sorted_model_hash(model)
    return MODEL_FIELDS[model].sort {|a,b| (a[1].sort_rank == b[1].sort_rank) ? a[1].uid <=> b[1].uid : a[1].sort_rank <=> b[1].sort_rank}
  end
  
  def new_base_object
    Kernel.const_get(MODEL_TYPES[self.model_type.intern]).new
  end
  
  def new_detail_object
    OrderLine.new if self.model_type.intern == :order
  end
  
  def ic_validation
    OrderImportConfigValidator.new.validate(self) if self.model_type == MODEL_TYPES[:order]
    ProductImportConfigValidator.new.validate(self) if self.model_type == MODEL_TYPES[:product]
  end
  
  def self.find_model_field(model,field)
    MODEL_FIELDS[model].values.each do |mf|
      return mf if mf.field == field
    end
    return nil
  end
  
  #@todo reimplement with proper active record where instead of loop
  def has_model_field_mapped(model,field)
    f = false
    self.import_config_mappings.each do |m|
      f = f || m.model_field_uid == ImportConfig.find_model_field(model,field).uid
    end
    return f
  end
  

end

class ImportConfigValidator
  
  def field_check(import_config,model,field,message)
    import_config.errors[:base] << message unless import_config.has_model_field_mapped model, field
  end
end

class ProductImportConfigValidator < ImportConfigValidator
  def validate(c)
    if c.import_config_mappings.size > 0
      field_check c, :product, :unique_identifier, "All product mappings must contain the Unique Identifier field."
      field_check c, :product, :vendor_id, "All product mappings must contain the Vendor ID field."
    end
  end
end

class OrderImportConfigValidator < ImportConfigValidator
  @ic
  @has_detail
  def validate(c)
    @ic = c
    @has_detail = nil
    if @ic.import_config_mappings.size > 0
      has_order_number_mapping
      has_product_id if detail_check
    end
  end
  
  private
  
  def has_product_id
    field_check @ic, :order, :product_unique_identifier, "All order mappings that have line level values must have the Product Unique Identifier."
  end
  
  def has_order_number_mapping
    field_check @ic, :order, :order_number, "All order mappings must contain the Order Number field."    
  end
  
  def detail_check
    return @has_detail unless @has_detail.nil? 
    @ic.import_config_mappings.each do |m|
      @has_detail = @has_detail || m.find_model_field.detail?       
    end
    return @has_detail
  end
end