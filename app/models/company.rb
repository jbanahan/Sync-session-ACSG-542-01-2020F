class Company < ActiveRecord::Base
	validates	:name,	:presence => true
	validate  :master_lock
	has_many	:addresses, :dependent => :destroy
	has_many	:divisions, :dependent => :destroy
	has_many	:vendor_orders, :class_name => "Order", :foreign_key => "vendor_id", :dependent => :destroy
	has_many	:vendor_products, :class_name => "Product", :foreign_key => "vendor_id", :dependent => :destroy
	has_many  :vendor_shipments, :class_name => "Shipment", :foreign_key => "vendor_id", :dependent => :destroy
	has_many  :carrier_shipments, :class_name => "Shipment", :foreign_key => "carrier_id", :dependent => :destroy
	has_many  :customer_sales_orders, :class_name => "SalesOrder", :foreign_key => "customer_id", :dependent => :destroy
	has_many  :users
	has_many	:orders, :through => :divisions, :dependent => :destroy
	has_many	:products, :through => :divisions, :dependent => :destroy
	has_many  :histories, :dependent => :destroy
	
	def self.find_carriers
		return Company.where(["carrier = ?",true])
	end
	
	def self.find_vendors
	  return Company.where(["vendor = ?",true])
	end
	
	def self.find_can_view(user)
	  if user.company.master
	    return Company.where("1=1")
	  else
	    return Company.where(:id => user.company_id)
	  end
	end
	
	def can_edit?(user)
	  return user.company.master
	end
	
	def can_view?(user)
	  if user.company.master
	    return true
	  else
	    return user.company == self
	  end
	end
	
	def self.not_locked
	  Company.where("locked = ? OR locked is null",false)
	end
	
	def self.find_master
	  Company.where(:master => true).first
	end
	
	def customer?
	  
	end
	
	private 
	def master_lock
	  errors.add(:base, "Master company cannot be locked.") if self.master && self.locked
	end
end
