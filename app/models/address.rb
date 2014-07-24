require 'digest/md5'

class Address < ActiveRecord::Base
  belongs_to :company
	belongs_to :country
  before_validation :set_hash_key
  validate :validate_immutable
  has_and_belongs_to_many :products, :join_table=>"product_factories", :foreign_key=>'address_id', :association_foreign_key=>'product_id'

  #make a key that will match the #address_hash if the two addresses are the same
  def self.make_hash_key a
    base = "#{a.name}#{a.line_1}#{a.line_2}#{a.line_3}#{a.city}#{a.state}#{a.postal_code}#{a.company_id}#{a.country_id}#{a.system_code}"
    Digest::MD5.hexdigest base
  end	

	def self.find_shipping
		return self.where(["shipping = ?",true])
	end

  private 
    def set_hash_key
      self.address_hash = self.class.make_hash_key(self) if self.address_hash.blank?
    end
    def validate_immutable
      errors.add(:base,"Addresses cannot be changed.") unless self.address_hash==self.class.make_hash_key(self)
    end

end
