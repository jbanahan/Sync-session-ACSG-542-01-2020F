describe OpenChain::CustomHandler::CustomViewSelector do

  subject { described_class }

  let (:user) { User.new }

  describe '#order_view' do
    let (:order) { Order.new }
  
    after :each do
      described_class.register_handler nil
    end

    context "with cache configured" do 

      before :each do 
        expect(MasterSetup).to receive(:current_code_version).and_return "some value"
      end

      it 'should pass through to registered handler' do
        handler = Class.new do
          attr_accessor :user, :order
          def order_view o, u
            @user = u
            @order = o

            return 'path/to/file.html'
          end
        end.new

        subject.register_handler handler

        expect(subject.order_view(order, user)).to eq 'path/to/file.html?c=some%20value'
        expect(handler.user).to be user
        expect(handler.order).to be order
      end
    end
    
    it 'should return nil if no registered handler' do
      expect(subject.order_view(order, user)).to be_nil
    end
    it "should return nil if regiestered handler doesn't implement method" do
      handler = Class.new
      subject.register_handler handler
      expect(subject.order_view(order, user)).to be_nil
    end
  end

  describe '#shipment_view' do

    let (:shipment) { Shipment.new }
    after(:each) do
      subject.register_handler nil
    end

    context "with cache configured" do 

      before :each do 
        expect(MasterSetup).to receive(:current_code_version).and_return "cache"
      end

      it 'should pass through to registered handler' do
        handler = Class.new do
          attr_accessor :user, :shipment
          def shipment_view s, u
            @user = u
            @shipment = s
          
            return 'x'
          end
        end.new 

        subject.register_handler handler

        expect(subject.shipment_view(shipment, user)).to eq 'x?c=cache'
        expect(handler.shipment).to be shipment
        expect(handler.user).to be user
      end
    end

    it 'should return nil if no registered handler' do
      expect(subject.shipment_view(shipment, user)).to be_nil
    end

    it "should return nil if regiestered handler doesn't implement method" do
      handler = Class.new
      subject.register_handler handler
      expect(subject.shipment_view(shipment, user)).to be_nil
    end
  end

  describe "add_cache_parameter" do
    it "appends a cache parameter to given url" do
      expect(subject.add_cache_parameter "/path/to/file.html", cache_value: "val").to eq "/path/to/file.html?c=val"
    end

    it "handles cache values with special chars" do
      expect(subject.add_cache_parameter "/path/to/file.html", cache_value: "val val").to eq "/path/to/file.html?c=val%20val"
    end

    it "appends cache values to existing url params" do
      expect(subject.add_cache_parameter "/path/to/file.html?existing=p", cache_value: "val").to eq "/path/to/file.html?existing=p&c=val"
    end

    it "hands page parameters" do
      expect(subject.add_cache_parameter "/path/to/file.html?existing=p#hash", cache_value: "val").to eq "/path/to/file.html?existing=p&c=val#hash"
    end
  end
end
