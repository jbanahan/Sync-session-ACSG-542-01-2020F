# == Schema Information
#
# Table name: addresses
#
#  address_hash    :string(255)
#  address_type    :string(255)
#  city            :string(255)
#  company_id      :integer
#  country_id      :integer
#  created_at      :datetime         not null
#  fax_number      :string(255)
#  id              :integer          not null, primary key
#  in_address_book :boolean
#  line_1          :string(255)
#  line_2          :string(255)
#  line_3          :string(255)
#  name            :string(255)
#  phone_number    :string(255)
#  port_id         :integer
#  postal_code     :string(255)
#  shipping        :boolean
#  state           :string(255)
#  system_code     :string(255)
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_addresses_on_address_hash  (address_hash)
#  index_addresses_on_company_id    (company_id)
#  index_addresses_on_port_id       (port_id)
#  index_addresses_on_system_code   (system_code)
#

require 'digest/md5'

class Address < ActiveRecord::Base
  attr_accessible :address_hash, :address_type, :city, :company_id, :company,
    :country_id, :country, :fax_number, :in_address_book, :line_1, :line_2,
    :line_3, :name, :phone_number, :postal_code, :shipping, :state, :system_code,
    :port_id

  belongs_to :company
	belongs_to :country
  belongs_to :port
  before_validation :set_hash_key
  before_destroy :check_in_use
  has_many :product_factories, dependent: :destroy
  has_many :products, through: :product_factories
  # has_and_belongs_to_many :products, :join_table=>"product_factories", :foreign_key=>'address_id', :association_foreign_key=>'product_id'

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

  # make a key that will match the #address_hash if the two addresses are the same
  def self.make_hash_key a
    base = "#{a.name}#{a.line_1}#{a.line_2}#{a.line_3}#{a.city}#{a.state}#{a.postal_code}#{a.country_id}#{a.system_code}"
    if !a.address_type.blank?
      base += "#{a.address_type}"
    end

    Digest::MD5.hexdigest base
  end

  def google_maps_url query_options={}
    inner_opts = {q:"#{self.line_1} #{self.line_2} #{self.line_3}, #{self.city} #{self.state}, #{self.country.try(:iso_code)}",
      key:'AIzaSyD-m0qPlvgU9SZ9eniFuRLF8DJD7CqszZU', zoom:6}
    qry = inner_opts.merge(query_options).to_query
    "https://www.google.com/maps/embed/v1/place?#{qry}"
  end

  def self.find_shipping
		return self.where(["shipping = ?", true])
  end

  def full_address_array skip_name: false
    ary = skip_name ? [] : [self.name]
    [self.line_1, self.line_2, self.line_3].each {|x| ary << x unless x.blank?}

    # last line is combined
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

    ary
  end

  def full_address
    r = full_address_array.join("\n")
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
) LIMIT 1
qry
    return ActiveRecord::Base.connection.execute(query).count == 1
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
