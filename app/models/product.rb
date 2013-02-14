class Product < ActiveRecord::Base
  include CoreObjectSupport
  include StatusableSupport
  include TouchesParentsChangedAt

  CORE_MODULE = CoreModule::PRODUCT

  belongs_to :vendor, :class_name => "Company"
  belongs_to :importer, :class_name => "Company"
  belongs_to :division
  belongs_to :status_rule
  belongs_to :entity_type
  belongs_to :last_updated_by, :class_name=>"User"
  validates	 :unique_identifier, :presence => true
  validates_uniqueness_of :unique_identifier

  has_many   :classifications, :dependent => :destroy
  has_many   :order_lines, :dependent => :destroy
  has_many   :sales_order_lines, :dependent => :destroy
  has_many   :shipment_lines, :dependent => :destroy
  has_many   :delivery_lines, :dependent => :destroy

  accepts_nested_attributes_for :classifications, :allow_destroy => true,
    :reject_if => lambda { |a| a[:country_id].blank?}
  def locked?
    !self.vendor.nil? && self.vendor.locked?
  end
  

  dont_shallow_merge :Product, ['id','created_at','updated_at','unique_identifier','vendor_id']


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
      "products.vendor_id = #{user.company_id}"
    else
      "1=0"
    end
  end

  private

  def default_division
    self.division = Division.first if self.division.nil? && self.division_id.nil?
  end

  def self.batch_bulk_update(user, parameters = {})
    original_user = User.current
    begin
      User.current = user #needed because validate_and_save_module expects User.current to be set but it won't be if coming from Delayed_job.
      update_errors = []
      good_count = nil
      OpenChain::CoreModuleProcessor.bulk_objects(CoreModule::PRODUCT, parameters[:sr_id], parameters[:pk]) do |gc, p|
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
    ensure
      User.current = original_user #put the user back to what it was
    end
  end
  def company_permission? user
    self.importer_id==user.company_id || self.vendor_id == user.company_id || user.company.master? || user.company.linked_companies.include?(self.importer) || user.company.linked_companies.include?(self.vendor)
  end
end
