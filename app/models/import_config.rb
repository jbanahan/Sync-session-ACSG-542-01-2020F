class ImportConfig < ActiveRecord::Base  
  
  validate :ic_validation
  validates_presence_of :name, :model_type, :file_type
  
  has_many :import_config_mappings, :dependent => :destroy
  has_many :imported_files, :dependent => :destroy
  
  accepts_nested_attributes_for :import_config_mappings, :reject_if => lambda { |a| a[:model_field_uid].blank? }
  
  def new_detail_object
    OrderLine.new if self.model_type == CoreModule::ORDER.class_name
  end
  
  def ic_validation
    OrderImportConfigValidator.new.validate(self) if self.model_type == CoreModule::ORDER.class_name
    ProductImportConfigValidator.new.validate(self) if self.model_type == CoreModule::PRODUCT.class_name
  end
  
  #@todo reimplement with proper active record where instead of loop
  def has_model_field_mapped(core_module,field)
    f = false
    self.import_config_mappings.each do |m|
      f = f || m.model_field_uid == core_module.find_model_field(field).uid
    end
    return f
  end
  

end

class ImportConfigValidator
  
  def field_check(import_config,core_module,field,message)
    import_config.errors[:base] << message unless import_config.has_model_field_mapped core_module, field
  end
end

class ProductImportConfigValidator < ImportConfigValidator
  def validate(c)
    if c.import_config_mappings.size > 0
      field_check c, CoreModule::PRODUCT, :unique_identifier, "All product mappings must contain the Unique Identifier field."
      field_check c, CoreModule::PRODUCT, :vendor_id, "All product mappings must contain the Vendor ID field."
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
    field_check @ic, CoreModule::ORDER_LINE, :product_unique_identifier, "All order mappings that have line level values must have the Product Unique Identifier."
  end
  
  def has_order_number_mapping
    field_check @ic, CoreModule::ORDER, :order_number, "All order mappings must contain the Order Number field."    
  end
  
  def detail_check
    return @has_detail unless @has_detail.nil? 
    @ic.import_config_mappings.each do |m|
      @has_detail = @has_detail || m.find_model_field.core_module != CoreModule::ORDER       
    end
    return @has_detail
  end
end