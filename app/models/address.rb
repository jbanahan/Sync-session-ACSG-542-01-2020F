require 'digest/md5'

class Address < ActiveRecord::Base
  belongs_to :company
	belongs_to :country
  before_validation :set_hash_key
  before_destroy :check_in_use
  has_and_belongs_to_many :products, :join_table=>"product_factories", :foreign_key=>'address_id', :association_foreign_key=>'product_id'

  def can_view? user
    return user.company.master? ||
      user.company_id == self.company_id ||
      user.company.linked_companies.include?(self.company)
  end

  def can_edit? user
    return can_view?(user) && self.company.can_edit?(user)
  end

  def self.search_where user
    return "1=1" if user.company.master?
    return "(addresses.company_id = #{user.company_id} OR addresses.company_id IN (select child_id from linked_companies where parent_id = #{user.company_id}))"
  end

  def self.search_secure user, base_object
    base_object.where search_where user
  end

  #make a key that will match the #address_hash if the two addresses are the same
  def self.make_hash_key a
    base = "#{a.name}#{a.line_1}#{a.line_2}#{a.line_3}#{a.city}#{a.state}#{a.postal_code}#{a.country_id}#{a.system_code}"
    Digest::MD5.hexdigest base
  end

  def google_maps_url query_options={}
    inner_opts = {q:"#{self.line_1} #{self.line_2} #{self.line_3}, #{self.city} #{self.state}, #{self.country.try(:iso_code)}",
      key:'AIzaSyD-m0qPlvgU9SZ9eniFuRLF8DJD7CqszZU',zoom:6}
    qry = inner_opts.merge(query_options).to_query
    "https://www.google.com/maps/embed/v1/place?#{qry}"
  end

  def self.find_shipping
		return self.where(["shipping = ?",true])
  end

  def full_address
    ary = []
    [self.name,self.line_1,self.line_2,self.line_3].each {|x| ary << x unless x.blank?}

    #last line is combined
    last_line = ""
    last_line << self.city unless self.city.blank?
    last_line << ", " if !self.city.blank? && !self.state.blank?
    last_line << self.state unless self.state.blank?
    last_line << " " unless last_line.blank?
    last_line << self.postal_code unless self.postal_code.blank?
    last_line << " " unless last_line.blank?
    last_line << self.country.iso_code if self.country
    last_line.strip!
    ary << last_line unless last_line.blank?

    r = ary.join("\n")
    r = "" if r.nil?
    r
  end

  # is the address in the database and linked to either a hard coded field or a custom one
  def in_use?
    return false unless self.id
    query = <<-qry
SELECT addresses.id
FROM addresses
LEFT OUTER JOIN custom_values ON custom_values.integer_value = addresses.id AND custom_values.custom_definition_id IN (SELECT id from custom_definitions where is_address = 1)
LEFT OUTER JOIN shipments ship_to ON ship_to.ship_to_id = addresses.id
LEFT OUTER JOIN shipments ship_from ON ship_from.ship_from_id = addresses.id
LEFT OUTER JOIN deliveries deliver_to ON deliver_to.ship_to_id = addresses.id
LEFT OUTER JOIN deliveries deliver_from ON deliver_from.ship_from_id = addresses.id
LEFT OUTER JOIN orders order_to ON order_to.ship_to_id = addresses.id
LEFT OUTER JOIN orders order_ship_from ON order_ship_from.ship_from_id = addresses.id
LEFT OUTER JOIN order_lines order_line_ship_to ON order_line_ship_to.ship_to_id = addresses.id
LEFT OUTER JOIN sales_orders sale_to ON sale_to.ship_to_id = addresses.id
LEFT OUTER JOIN product_factories ON product_factories.address_id = addresses.id
WHERE addresses.id = #{self.id}
AND (
  custom_values.id is not null
  OR ship_to.id is not null
  OR ship_from.id is not null
  OR deliver_to.id is not null
  OR deliver_from.id is not null
  OR order_to.id is not null
  OR order_ship_from.id is not null
  OR order_line_ship_to.id is not null
  OR sale_to.id is not null
  OR product_factories.product_id is not null
) LIMIT 1
qry
    return ActiveRecord::Base.connection.execute(query).count == 1
  end

  def self.update_kewill_addresses addresses
    countries = Hash.new do |h, k|
      country = Country.where(iso_code: k).first
      # In case country is missing from the address
      h[k] = country.try(:id)
    end

    Array.wrap(addresses).each do |row|
      row = row.map {|r| r.try(:strip) }

      # First, find the company the address is linked to (creating one if it doesn't exist)
      company = Company.where(alliance_customer_number: row[0].to_s.strip).first_or_create! name: row[1], importer: true

      # All kewill addresses are named w/ leading 0's...strip those, we don't want them.
      address_number = row[2].to_s.gsub(/^0+/, "")
      address = company.addresses.where(system_code: address_number).first_or_initialize
      address.update_attributes! name: row[3], line_1: row[4], line_2: row[5], city: row[6], state: row[7], postal_code: row[8], country_id: countries[row[9]]
    end
  end

  private
    def set_hash_key
      self.address_hash = self.class.make_hash_key(self)
    end

    def check_in_use
      return true unless self.in_use?
      errors.add :base, 'Address cannot be deleted because it is still in use.'
      return false
    end
end
