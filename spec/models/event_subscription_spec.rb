require 'spec_helper'

describe EventSubscription do
  let (:master_setup) do
    ms = double("MasterSetup")
    allow(MasterSetup).to receive(:get).and_return(ms)
    ms
  end

  describe "subscriptions_for_event" do
    context "*_COMMENT_CREATE" do
      let (:order) { Factory(:order,importer:Factory(:company,importer:true)) }
      let (:user) { u = Factory(:user,company:order.importer,order_view:true) }
      let (:subscription) { Factory(:event_subscription,user:user,event_type:'ORDER_COMMENT_CREATE',email:true) }

      before :each do
        allow(master_setup).to receive(:order_enabled).and_return true
      end

      it "should find subscriptions who can view parent object" do
        subscription
        c = order.comments.create!(user_id:Factory(:user).id,body:'abc')
        
        #this is for a user who can't view the order
        Factory(:event_subscription,event_type:'ORDER_COMMENT_CREATE',email:true)

        #this is for a user who hasn't subscribed to email
        Factory(:event_subscription,user:Factory(:user,company:order.importer,order_view:true),event_type:'ORDER_COMMENT_CREATE',email:false)

        s = described_class.subscriptions_for_event 'ORDER_COMMENT_CREATE', 'email', c.id
        expect(s.to_a).to eq [subscription]
      end

      it "doesn't find subscriptions associated with a disabled user" do
        subscription
        user.disabled = true
        user.save!

        c = order.comments.create!(user: user, body:'abc')
        expect(described_class.subscriptions_for_event 'ORDER_COMMENT_CREATE', 'email', c.id).to be_blank
      end

      it "returns blank array if comment isn't found" do
        Factory(:event_subscription,user:Factory(:user,company:order.importer,order_view:true),event_type:'ORDER_COMMENT_CREATE',email:false)
        expect(described_class.subscriptions_for_event 'ORDER_COMMENT_CREATE', 'email', -1).to eq []
      end
    end
  end
end
