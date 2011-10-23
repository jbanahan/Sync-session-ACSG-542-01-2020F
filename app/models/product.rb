class Product < ActiveRecord::Base

  include CustomFieldSupport
  include StatusableSupport
  include ShallowMerger
  include TouchesParentsChangedAt
  include EntitySnapshotSupport

  CORE_MODULE = CoreModule::PRODUCT

  belongs_to :vendor, :class_name => "Company"
  belongs_to :division
  belongs_to :status_rule
  belongs_to :entity_type
  validates	 :unique_identifier, :presence => true
  validates_uniqueness_of :unique_identifier

  has_many   :classifications, :dependent => :destroy
  has_many   :order_lines, :dependent => :destroy
  has_many   :sales_order_lines, :dependent => :destroy
  has_many   :shipment_lines, :dependent => :destroy
  has_many   :delivery_lines, :dependent => :destroy
  has_many   :histories, :dependent => :destroy
  has_many   :attachments, :as => :attachable, :dependent => :destroy
  has_many   :comments, :as => :commentable, :dependent => :destroy
  has_many   :item_change_subscriptions, :dependent => :destroy

  accepts_nested_attributes_for :classifications, :allow_destroy => true,
    :reject_if => lambda { |a| a[:country_id].blank?}
  def locked?
    !self.vendor.nil? && self.vendor.locked?
  end

  dont_shallow_merge :Product, ['id','created_at','updated_at','unique_identifier','vendor_id']


  def can_view?(user)
    return user.company.master || (user.company.vendor && user.company == self.vendor)
  end

  def can_edit?(user)
    return user.edit_products?
  end

  def can_create?(user)
    return user.create_products?
  end

  def can_classify?(user)
    can_edit?(user) && user.edit_classifications?
  end

  def can_comment? user
    return user.comment_products? && self.can_view?(user)
  end

  def can_attach? user
    return user.attach_products? && self.can_view?(user)
  end

  def find_same
    found = self.unique_identifier.nil? ? [] : Product.where({:unique_identifier => self.unique_identifier.to_s})
    raise "Found multiple products with the same unique identifier #{self.unique_identifier}" if found.size > 1
    return found.empty? ? nil : found.first
  end

  def self.find_can_view(user)
    if user.company.master
    return Product.all
    elsif user.company.vendor
      return Product.where("vendor_id = ?",user.company.id)
    else
    return []
    end
  end

  def has_orders?
    !self.order_lines.empty?
  end

  def has_shipments?
    !self.shipment_lines.empty?
  end

  def has_deliveries?
    !self.delivery_lines.empty?
  end

  def has_sales_orders?
    !self.sales_order_lines.empty? 
  end

  #Classify for other countries based on the classifications that already exist for the base_country provided.
  def auto_classify(base_country)
    base_classification = nil
    self.classifications.each {|c| base_classification = c if c.country==base_country}
    Country.import_locations.each do |country|
      unless base_country==country
        c = nil
        self.classifications.each {|pc| c = pc if pc.country==country}
        c = self.classifications.build(:country_id => country.id) if c.nil?
        load_tariff_record(base_country,base_classification,c)
      end
    end
  end

  #Replace the current classifications with the given collection of classifications and writes this product with the new classifications to the database
  #Any classification in the existing product that doesn't have a matching one by country in the new set is left alone
  def replace_classifications new_classifications
    begin
      Product.transaction do
        new_classifications.each do |nc|
          self.classifications.where(:country_id=>nc.country_id).destroy_all #clear existing for this country
          c = self.classifications.build
          c.shallow_merge_into nc
          c.country_id = nc.country_id #this isn't shallow merged
          nc.tariff_records.each do |nt|
            t = c.tariff_records.build
            t.shallow_merge_into nt
          end
        end
        self.save!
        return true
      end
    rescue ActiveRecord::RecordNotSaved
      return false
    end
  end

	def self.search_secure user, base_object
    if user.company.master
      return base_object.where("1=1")
    elsif user.company.vendor
      return base_object.where(:vendor_id => user.company)
    else
      return base_object.where("1=0")
    end
  end

  private

  def default_division
    self.division = Division.first if self.division.nil? && self.division_id.nil?
  end

  def load_tariff_record(base_country,base_classification,to_classify)
    if to_classify.tariff_records.empty? #if the classification already has records, leave it alone
      base_classification.tariff_records.each do |base_tariff|
        to_load = to_classify.tariff_records.build
        if !base_tariff.hts_1.blank? && base_tariff.hts_1.length > 5
          official_tariff = OfficialTariff.where(:country_id=>base_country).where(:hts_code=>base_tariff.hts_1).first
          unless official_tariff.nil?
            matches = official_tariff.find_matches to_classify.country
            matches.delete_if {|m| m.meta_data.auto_classify_ignore}
            to_load.hts_1 = matches.first.hts_code if matches.length==1
            to_load.hts_1_matches = matches
          end
        end
        if !base_tariff.hts_2.blank? && base_tariff.hts_2.length > 5
          official_tariff = OfficialTariff.where(:country_id=>base_country).where(:hts_code=>base_tariff.hts_2).first
          unless official_tariff.nil?
            matches = official_tariff.find_matches to_classify.country
            matches.delete_if {|m| m.meta_data.auto_classify_ignore}
            to_load.hts_2 = matches.first.hts_code if matches.length==1
            to_load.hts_2_matches = matches
          end
        end
        if !base_tariff.hts_3.blank? && base_tariff.hts_3.length > 5
          official_tariff = OfficialTariff.where(:country_id=>base_country).where(:hts_code=>base_tariff.hts_3).first
          unless official_tariff.nil?
            matches = official_tariff.find_matches to_classify.country
            matches.delete_if {|m| m.meta_data.auto_classify_ignore}
            to_load.hts_3 = matches.first.hts_code if matches.length==1
            to_load.hts_3_matches = matches
          end
        end
      end
    end
  end

  def self.batch_bulk_update(user, parameters = {})
    update_errors = []
    good_count = nil
    OpenChain::CoreModuleProcessor.bulk_objects(parameters[:sr_id], parameters[:pk]) do |gc, p|
      good_count = gc if good_count.nil?
      if p.can_edit?(user)
        success = lambda {|o| }
        failure = lambda {|o, errors|
          good_count += -1
          errors.full_messages.each {|m| update_errors << "Error updating product #{o.unique_identifier}: #{m}"}
        }
        before_validate = lambda {|o| OpenChain::CoreModuleProcessor.update_status o}
        OpenChain::CoreModuleProcessor.validate_and_save_module parameters, p, parameters[:product], success, failure, :before_validate=>before_validate
      else
        good_count += -1
        update_errors << "You do not have permission to edit product #{p.unique_identifier}."
      end
    end

    subject = body = ""
    if update_errors.empty?
      subject = body = "Product update complete - #{ApplicationController::Helper.instance.pluralize good_count, CoreModule::PRODUCT.label.downcase}."
    else
      # Create message for errors
      subject = "Product update complete - #{update_errors.length} ERRORS"
      body = update_errors.join("\n")
    end
    Message.create(:user=>user, :subject=>subject, :body=>body)
  end
end
