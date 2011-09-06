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
    fail_lambda = lambda {|ic|
      ic.classifications.each do |c|
        ic.errors[:base] += c.errors.full_messages
        c.tariff_records.each {|t| ic.errors[:base] += t.errors.full_messages}
      end
      errors_to_flash ic, :now=>true
      @instant_classification = ic
      render :action=> :edit 
    }
    admin_secure {
      ic = InstantClassification.find(params[:id])
      begin
        InstantClassification.transaction do 
          if ic.update_attributes(params[:instant_classification])
            OpenChain::CustomFieldProcessor.new(params).save_classification_custom_fields ic, params[:instant_classification]
            ic.classifications.each do |c|
              OpenChain::FieldLogicValidator.validate! c
            end
            add_flash :notices, "Instant Classification saved successfully."
            redirect_to instant_classifications_path
          else
            fail_lambda.call ic
          end
        end
      rescue OpenChain::ValidationLogicError
        fail_lambda.call ic
      rescue ActiveRecord::RecordInvalid
        fail_lambda.call ic
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

end
