module Api; module V1; class ProductsController < Api::V1::ApiCoreModuleControllerBase
  
  def core_module
    CoreModule::PRODUCT
  end

  def by_uid
    product = base_relation.where(unique_identifier: params[:uid]).first
    render_obj product
  end

  def render_obj obj
    if obj
      obj.freeze_all_custom_values_including_children
    end
    super obj
  end

  def model_fields
    render_model_field_list CoreModule::PRODUCT
  end

  def index 
    render_search core_module
  end

  def show
    render_show core_module
  end

  def create
    do_create core_module
  end

  def update
    do_update core_module
  end

  def save_object obj_hash
    generic_save_object obj_hash
  end

  def find_object_by_id id
    base_relation.where(id: id).first
  end

  def base_relation
    # Don't pre-load custom values, they'll be loaded later by the custom value freeze (which is actually more efficient)
    Product.includes(classifications: [:tariff_records])
  end

  def obj_to_json_hash obj
    product_fields = limit_fields(
      [:prod_uid, :prod_ent_type, :prod_name, :prod_uom, :prod_changed_at, :prod_last_changed_by, :prod_created_at, :prod_ven_name, :prod_ven_syscode, 
       :prod_div_name, :prod_imp_name, :prod_imp_syscode] + 
      custom_field_keys(CoreModule::PRODUCT)
    )

    class_fields = limit_fields (
      [:class_cntry_name, :class_cntry_iso] + custom_field_keys(CoreModule::CLASSIFICATION)
    )

    tariff_fields = limit_fields(
      [:hts_line_number, :hts_hts_1, :hts_hts_1_schedb, :hts_hts_2, :hts_hts_2_schedb, :hts_hts_3, :hts_hts_3_schedb] + 
      custom_field_keys(CoreModule::TARIFF)
    )

    to_entity_hash(obj, product_fields + class_fields + tariff_fields)
  end
  
end; end; end