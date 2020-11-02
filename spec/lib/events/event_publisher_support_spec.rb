describe OpenChain::Events::EventPublisherSupport do

  subject do
    Class.new do
      include OpenChain::Events::EventPublisherSupport
    end
  end

  describe "event_descriptor" do
    let (:object) { Order.new id: 1, order_number: "12345"}
    let! (:master_setup) { stub_master_setup }

    it "generates an event hash for given event type and object" do
      d = subject.event_descriptor :order_create, object
      expect(d).to eq({
                        event_type: "ORDER_CREATE",
                        klass: "Order",
                        id: 1,
                        link: "http://localhost:3000/orders/1",
                        short_message: "Order 12345 created.",
                        long_message: "Order 12345 created."
                      })
    end

    it "raises an error if a bad message_type is given" do
      expect { subject.event_descriptor :create, object}.to raise_error "Invalid event message type 'create' received."
    end
  end
end