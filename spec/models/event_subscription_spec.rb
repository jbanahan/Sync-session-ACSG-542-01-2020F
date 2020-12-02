describe EventSubscription do
  let (:master_setup) { stub_master_setup }

  describe "subscriptions_for_event" do
    context "*_COMMENT_CREATE" do
      let (:order) { create(:order, importer: create(:company, importer: true)) }
      let (:user) { create(:user, company: order.importer, order_view: true) }
      let! (:subscription) { create(:event_subscription, user: user, event_type: 'ORDER_COMMENT_CREATE', email: true) }

      before do
        allow(master_setup).to receive(:order_enabled).and_return true
      end

      it "finds subscriptions who can view parent object" do
        c = order.comments.create!(user_id: create(:user).id, body: 'abc')

        # this is for a user who can't view the order
        create(:event_subscription, event_type: 'ORDER_COMMENT_CREATE', email: true)

        # this is for a user who hasn't subscribed to email
        create(:event_subscription, user: create(:user, company: order.importer, order_view: true), event_type: 'ORDER_COMMENT_CREATE', email: false)

        s = described_class.subscriptions_for_event 'ORDER_COMMENT_CREATE', 'email', object_id: c.id
        expect(s.to_a).to eq [subscription]
      end

      it "allows passing the object" do
        c = order.comments.create!(user: user, body: 'abc')
        s = described_class.subscriptions_for_event 'ORDER_COMMENT_CREATE', 'email', object: c
        expect(s.to_a).to eq [subscription]
      end

      it "doesn't find subscriptions associated with a disabled user" do
        user.disabled = true
        user.save!

        c = order.comments.create!(user: user, body: 'abc')
        expect(described_class.subscriptions_for_event('ORDER_COMMENT_CREATE', 'email', object_id: c.id)).to be_blank
      end

      it "returns blank array if comment isn't found" do
        create(:event_subscription, user: create(:user, company: order.importer, order_view: true), event_type: 'ORDER_COMMENT_CREATE', email: false)
        expect(described_class.subscriptions_for_event('ORDER_COMMENT_CREATE', 'email', object_id: -1)).to eq []
      end
    end
  end
end
