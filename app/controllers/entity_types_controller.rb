class EntityTypesController < ApplicationController

  HIDE_FROM_EDIT_SCREEN = [:prod_ven_id,:prod_ven_syscode,:prod_div_id,:prod_system_code,:prod_class_count]

  def index
    admin_secure {
      @entity_types = EntityType.all
    }
  end
  def edit
    admin_secure {
      prep_edit_screen EntityType.find(params[:id])
    }
  end
  def update
    admin_secure {
      entity_type = EntityType.find params[:id]
      entity_type.transaction do
        entity_type.update_attributes params[:entity_type]
        entity_type.entity_type_fields.destroy_all
        new_fields = params[:entity_type_fields]
        new_fields.each do |mfid,val|
          entity_type.entity_type_fields.create!(:model_field_uid=>mfid)
        end
      end
      add_flash :notices, "Update successful"
      redirect_to edit_entity_type_path entity_type
    }
  end
  def new
    admin_secure {
      prep_edit_screen EntityType.new(:module_type=>CoreModule::PRODUCT.class_name) #hard coded to product for now
      render 'edit'
    }    
  end
  def create
    admin_secure {
      EntityType.transaction do
        et = EntityType.create params[:entity_type]
        if et.errors.empty?
          new_fields = params[:entity_type_fields]
          new_fields.each {|mfid,val| et.entity_type_fields.create!(:model_field_uid=>mfid)}
          add_flash :notices, "Save successful"
          redirect_to edit_entity_type_path et
        else
          errors_to_flash et, :now=>true
          prep_edit_screen et
          render 'edit'
        end
      end
    }
  end

  private
  def prep_edit_screen et
    @entity_type = et
    base_fields = CoreModule.find_by_class_name(@entity_type.module_type).model_fields.clone
    #remove fields that we know we shouldn't show
    base_fields.delete_if {|k,v| HIDE_FROM_EDIT_SCREEN.include? k}
    @all_fields = base_fields.values
    @active_uids = @entity_type.entity_type_fields.collect {|f| f.model_field_uid.to_sym}
  end
end
