describe OpenChain::Registries::CustomizedApiResponseRegistry do 

  subject { described_class }

  let (:service) {
    Class.new {
      def self.customize_order_response order, user, order_hash, params
        order_hash["customized"] = true
        order_hash
      end

      def self.customize_shipment_response shipment, user, shipment_hash, params
        shipment_hash["customized"] = true
        shipment_hash
      end

      def self.customize_product_response product, user, product_hash, params
        product_hash["customized"] = true
        product_hash
      end
    }
  }

  before :each do 
    subject.register service
  end

  describe "customize_order_response" do
    it "customizes responses" do
      expect(subject.customize_order_response Order.new, User.new, {}, {}).to eq({"customized" => true})
    end
  end

  describe "customize_shipment_response" do
    it "customizes responses" do
      expect(subject.customize_shipment_response Shipment.new, User.new, {}, {}).to eq({"customized" => true})
    end
  end

  describe "customize_product_response" do
    it "customizes responses" do
      expect(subject.customize_product_response Product.new, User.new, {}, {}).to eq({"customized" => true})
    end
  end

end 