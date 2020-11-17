# == Schema Information
#
# Table name: product_factories
#
#  address_id :integer
#  id         :integer          not null, primary key
#  product_id :integer
#
# Indexes
#
#  index_product_factories_on_address_id_and_product_id  (address_id,product_id)
#  index_product_factories_on_product_id_and_address_id  (product_id,address_id) UNIQUE
#

class ProductFactory < ActiveRecord::Base
  # The touch here is so that we touch the product when a manufacturer is removed
  belongs_to :product, touch: true, inverse_of: :product_factories
  belongs_to :address
end
