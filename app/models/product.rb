require 'jsonpath'
class Product < ActiveRecord::Base
  include CoreObjectSupport
  include StatusableSupport
  include TouchesParentsChangedAt

  belongs_to :importer, :class_name => "Company"
  belongs_to :division
  belongs_to :status_rule
  belongs_to :entity_type
  belongs_to :last_updated_by, :class_name=>"User"
  validates	 :unique_identifier, :presence => true
  validates_uniqueness_of :unique_identifier

  has_many   :variants, :dependent => :destroy, inverse_of: :product
  has_many   :classifications, :dependent => :destroy
  has_many   :order_lines, :dependent => :destroy
  has_many   :sales_order_lines, :dependent => :destroy
  has_many   :shipment_lines, :dependent => :destroy
  has_many   :delivery_lines, :dependent => :destroy
  has_many   :bill_of_materials_children, :dependent=>:destroy, :class_name=>"BillOfMaterialsLink",
    :foreign_key=>:parent_product_id, :include=>:child_product
  has_many   :bill_of_materials_parents, :dependent=>:destroy, :class_name=>"BillOfMaterialsLink",
    :foreign_key=>:child_product_id, :include=>:parent_product
  has_many   :child_products, :through=>:bill_of_materials_children
  has_many   :parent_products, :through=>:bill_of_materials_parents
  has_and_belongs_to_many :factories, :class_name=>"Address", :join_table=>"product_factories", :foreign_key=>'product_id', :association_foreign_key=>'address_id'
  has_many :product_vendor_assignments, dependent: :destroy
  has_many :vendors, through: :product_vendor_assignments

  accepts_nested_attributes_for :classifications, :allow_destroy => true
  accepts_nested_attributes_for :variants, :allow_destroy => true
  reject_nested_model_field_attributes_if :missing_classification_country?

  dont_shallow_merge :Product, ['id','created_at','updated_at','unique_identifier']


  def locked?
    false
  end

  # returns a hash of arrays with a key of region and an array of all classifications for that region as value
  # * if a country is in multiple regions, then it will be included multiple times
  # * if a country is not in any regions, then it will be included with a nil key
  def classifications_by_region
    r = {}

    used_classifications = Set.new
    all_classifications = self.classifications.collect {|c| c} #holding this in memory so we don't do a .to_a and hit the database

    Region.includes(:countries).each do |reg|
      r[reg] = matched = []
      self.classifications.each do |cls|
        if reg.countries.include?(cls.country)
          matched << cls
          used_classifications << cls
        end
      end
    end

    r[nil] = (all_classifications - used_classifications.to_a)

    return r
  end

  #are there any classifications written to the database
  def saved_classifications_exist?
    r = false
    self.classifications.each do |cls|
      r = true unless cls.new_record?
      break if r
    end
    r
  end

  def can_view?(user)
    return user.view_products? && company_permission?(user)
  end

  def can_edit?(user)
    return user.edit_products? && company_permission?(user)
  end

  def can_create?(user)
    return user.create_products? && company_permission?(user)
  end

  def can_classify?(user)
    can_view?(user) && user.edit_classifications?
  end

  def can_manage_variants?(user)
    can_view?(user) && user.edit_variants?
  end

  def can_comment? user
    return user.comment_products? && self.can_view?(user)
  end

  def can_attach? user
    return user.attach_products? && self.can_view?(user)
  end

  # have any new tariff numbers been added at the 6 digit level for any country since the given time?
  def wto6_changed_after? time_to_compare
    h = self.entity_snapshots.order('created_at desc').where('created_at <= ?',time_to_compare).limit(1).first
    return false if h.nil?
    old_list = get_wto6_list_from_entity_snapshot(h)
    new_list = get_wto6_list_from_current_data
    return (new_list - old_list).size > 0
  end

  # is this product either a parent or child for a bill of materials
  def on_bill_of_materials?
    !self.bill_of_materials_children.empty? || !self.bill_of_materials_parents.empty?
  end

  def find_same
    found = self.unique_identifier.nil? ? [] : Product.where({:unique_identifier => self.unique_identifier.to_s})
    raise "Found multiple products with the same unique identifier #{self.unique_identifier}" if found.size > 1
    return found.empty? ? nil : found.first
  end

  def self.find_can_view(user)
    search_secure user, Product.where("1=1")
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
    base_object.where(search_where(user))
  end

  # where clause for search secure
  def self.search_where user
    if user.company.master
      return "1=1"
    elsif user.company.importer
      "products.importer_id = #{user.company_id} or products.importer_id IN (select child_id from linked_companies where parent_id = #{user.company_id})"
    elsif user.company.vendor
      "products.id IN (select product_id from product_vendor_assignments where vendor_id = #{user.company_id})"
    else
      "1=0"
    end
  end

  # validate all tariff numbers against official tariff and add errors to error[:base]
  def validate_tariff_numbers
    self.classifications.each do |cls|
      country = cls.country
      next if country.official_tariffs.empty? #skip if we don't have the database loaded for this country
      cls.tariff_records.each do |tr|
        self.errors[:base] << "Tariff number #{tr.hts_1} is invalid for #{country.iso_code}" if !tr.hts_1.blank? && !tr.hts_1_official_tariff
        self.errors[:base] << "Tariff number #{tr.hts_2} is invalid for #{country.iso_code}" if !tr.hts_2.blank? && !tr.hts_2_official_tariff
        self.errors[:base] << "Tariff number #{tr.hts_3} is invalid for #{country.iso_code}" if !tr.hts_3.blank? && !tr.hts_3_official_tariff
      end
    end
  end

  def self.missing_classification_country? attributes
    return false unless attributes['id'].blank?

    attributes[:class_cntry_id].blank? && attributes[:class_cntry_name].blank? && attributes[:class_cntry_iso].blank?
  end

  private

  def default_division
    self.division = Division.first if self.division.nil? && self.division_id.nil?
  end

  def company_permission? user
    return true if  self.importer_id==user.company_id
    return true if user.company.master?

    linked_company_ids = user.company.linked_companies.collect {|lc| lc.id}
    return true if linked_company_ids.include?(self.importer_id)

    assignment_ids = linked_company_ids + [user.company_id]
    return true if (self.product_vendor_assignments.collect {|pva| pva.vendor_id} & assignment_ids).length > 0
  end

  def get_wto6_list_from_entity_snapshot es
    r = []
    json = es.snapshot_json(true)
    (1..3).each {|i| r += JsonPath.on(json,"$..hts_hts_#{i}") }
    r.delete_if {|h| h.blank?}
    Set.new(r.collect {|h| h.gsub(/\./,'')[0,6]}).to_a
  end
  
  def get_wto6_list_from_current_data
    r = Set.new
    self.classifications.each do |cls|
      cls.tariff_records.each do |tr|
        [tr.hts_1,tr.hts_2,tr.hts_3].each do |hts|
          if hts && hts.length >= 6
            r << hts[0,6]
          end
        end
      end
      r
    end
    r.to_a
  end
end
