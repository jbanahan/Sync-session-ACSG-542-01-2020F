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
        @instant_classification.classifications.build(:country => c) if @instant_classification.classifications.where(:country_id=>c).empty?
      end
    }
  end

  def create
    admin_secure {
      ic = InstantClassification.new(params[:instant_classification])
      if ic.save
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
        @instant_classification.classifications.build(:country => c) if @instant_classification.classifications.where(:country_id=>c).empty?
      end
    }
  end

  def update
    admin_secure {
      ic = InstantClassification.find(params[:id])
      begin
        InstantClassification.transaction do
          # The only form parameter for instant classification we're expecting is name, so just assign it
          # and then run the update_model_field_attributes
          ic.assign_attributes(name: params[:name]) unless params[:name].blank?

          if ic.update_model_field_attributes(params[:instant_classification], exclude_blank_values: true)
            ic.classifications.each do |c|
              OpenChain::FieldLogicValidator.validate! c
            end
            add_flash :notices, "Instant Classification saved successfully."
            redirect_to instant_classifications_path
          else
            failed ic
          end
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

end
