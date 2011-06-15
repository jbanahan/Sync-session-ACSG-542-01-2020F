class Product < ActiveRecord::Base

  include CustomFieldSupport
  include StatusableSupport
  include ShallowMerger
  include TouchesParentsChangedAt

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

  def find_same
    found = Product.where({:unique_identifier => self.unique_identifier.to_s})
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
end
