require 'digest/md5'

class Address < ActiveRecord::Base
  belongs_to :company
	belongs_to :country
  before_validation :set_hash_key
  has_and_belongs_to_many :products, :join_table=>"product_factories", :foreign_key=>'address_id', :association_foreign_key=>'product_id'

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
    address_lines = self.line_1.to_s
    address_lines += (" " + self.line_2) unless self.line_2.blank?
    address_lines += (" " + self.line_3) unless self.line_3.blank?
    address_lines.strip!

    city_state_zip = self.city.to_s
    city_state_zip += (" " + self.state) unless self.state.blank?
    city_state_zip += (" " + self.postal_code) unless self.postal_code.blank?
    city_state_zip.strip!

    a = address_lines
    if city_state_zip.length > 0
      a += ", " if a.length > 0
      a += city_state_zip
    end

    iso = self.country.try(:iso_code).to_s.strip
    unless iso.blank?
      a += ", " if a.length > 0
      a += iso
    end

    a
  end

  private
    def set_hash_key
      self.address_hash = self.class.make_hash_key(self)
    end
end
