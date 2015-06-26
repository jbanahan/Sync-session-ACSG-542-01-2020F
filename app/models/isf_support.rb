module ISFSupport
  def self.included(base)
    base.instance_eval do
      belongs_to :manufacturer_address, class_name: 'Address'
      belongs_to :seller_address, class_name: 'Address'
      belongs_to :buyer_address, class_name: 'Address'
      belongs_to :ship_to_address, class_name: 'Address'
      belongs_to :container_stuffing_address, class_name: 'Address'
      belongs_to :consolidator_address, class_name: 'Address'
    end
  end

  def make_isf
    ImporterSecurityFiling.from_shipment(self)
  end
end