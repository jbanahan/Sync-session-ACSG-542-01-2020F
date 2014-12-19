class InstantClassificationsController < ApplicationController

  def index
    admin_secure {
      @instant_classifications = InstantClassification.ranked
    }
  end

  def new
    admin_secure {
      @instant_classification = InstantClassification.new
      Country.import_locations.sort_classification_rank.each do |c|
        @instant_classification.classifications.build(:country => c)
      end
    }
  end

  def create
    admin_secure {
      ic = InstantClassification.new
      updated = false
      InstantClassification.transaction do
        updated = update_instant_classification ic
      end

      if updated
        add_flash :notices, "Instant Classification created successfully."
        redirect_to instant_classifications_path
      else
        errors_to_flash ic, :now=>true
        @instant_classification = ic
        render :action => :new
      end
    }
  end

  def edit
    admin_secure {
      @instant_classification=InstantClassification.find(params[:id])
      Country.import_locations.sort_classification_rank.each do |c|
        @instant_classification.classifications.build(:country => c) if @instant_classification.classifications.find {|cl| cl.country_id == c.id}.nil?
      end
    }
  end

  def update
    admin_secure {
      ic = InstantClassification.find(params[:id])
      begin
        updated = false
        InstantClassification.transaction do
          updated = update_instant_classification ic
        end

        if updated
          add_flash :notices, "Instant Classification saved successfully."
          redirect_to instant_classifications_path
        else
          failed ic
        end
      rescue OpenChain::ValidationLogicError
        failed ic
      rescue ActiveRecord::RecordInvalid
        failed ic
      end
    }
  end

  def destroy
    admin_secure {
      ic = InstantClassification.find(params[:id])
      if ic.destroy
        add_flash :notices, "Instant Classification destroyed successfully."
        redirect_to instant_classifications_path
      else
        errors_to_flash ic
        redirect_to edit_instant_classification_path(ic)
      end
    }
  end

  def update_rank 
    admin_secure {
      params[:sort_order].each_with_index do |ic_id,index|
        InstantClassification.find(ic_id).update_attributes(:rank=>index)
      end
      render :text => "" #effectively noop
    }
  end

  private
    def failed ic
      ic.classifications.each do |c|
        ic.errors[:base] += c.errors.full_messages
        c.tariff_records.each {|t| ic.errors[:base] += t.errors.full_messages}
      end
      errors_to_flash ic, :now=>true
      @instant_classification = ic
      render :action=> :edit 
    end

    def update_instant_classification ic
      # All the classifications will be updated by the model field attributes..copy them into a different hash
      # so our assign_attributes call below doesn't bomb due to unknown attributes (since model field names clash w/ attribute names)
      classification_params = {classifications_attributes: params[:instant_classification][:classifications_attributes]}

      instant_class_params = params.with_indifferent_access[:instant_classification]
      instant_class_params.delete :classifications_attributes
      ic.assign_attributes(instant_class_params)

      if ic.update_model_field_attributes(classification_params, exclude_blank_values: true)
        ic.classifications.each do |c|
          OpenChain::FieldLogicValidator.validate! c
        end
        return true
      else
        return false
      end
    end

end
