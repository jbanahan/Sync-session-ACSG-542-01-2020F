require 'spec_helper'

describe EventSubscription do
  describe :subscriptions_for_event do
    context "*_COMMENT_CREATE" do
      it "should find subscriptions who can view parent object" do
        MasterSetup.get.update_attributes(order_enabled:true)
        o = Factory(:order,importer:Factory(:company,importer:true))
        u = Factory(:user,company:o.importer,order_view:true)
        sub = Factory(:event_subscription,user:u,event_type:'ORDER_COMMENT_CREATE',email:true)
        c = o.comments.create!(user_id:Factory(:user).id,body:'abc')
        
        #this is for a user who can't view the order
        Factory(:event_subscription,event_type:'ORDER_COMMENT_CREATE',email:true)

        #this is for a user who hasn't subscribed to email
        Factory(:event_subscription,user:Factory(:user,company:o.importer,order_view:true),event_type:'ORDER_COMMENT_CREATE',email:false)

        s = described_class.subscriptions_for_event 'ORDER_COMMENT_CREATE', 'email', c.id
        expect(s.to_a).to eq [sub]
      end
    end
  end
end
