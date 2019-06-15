describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderAcceptance do

  subject { described_class }

  describe 'can_be_accepted?' do
    let! (:cdefs) {
      subject.prep_custom_definitions([:ord_country_of_origin])
    }

    let! (:order) { 
      o = Factory(:order,fob_point:'Shanghai',terms_of_sale:'FOB',ship_from:Factory(:address))
      o.update_custom_value! cdefs[:ord_country_of_origin],'CN'
      o
    }

    it "passes if fields are populated" do
      expect(subject.can_be_accepted?(order)).to eq true
    end
    
    it "fails if FOB Point is empty" do
      order.update_attributes(fob_point:nil)
      expect(subject.can_be_accepted?(order)).to eq false
    end

    it "fails if INCO terms are empty" do
      order.update_attributes(terms_of_sale:nil)
      expect(subject.can_be_accepted?(order)).to eq false
    end

    it "fails if country of origin is empty" do
      order.update_custom_value!(cdefs[:ord_country_of_origin],'')
      expect(subject.can_be_accepted?(order)).to eq false
    end
  end

  describe "can_accept?" do
    let (:user) { Factory(:user) }
    let (:order) { Factory(:order)}

    it "returns true if user is an admin" do
      u = User.new
      u.admin = true
      expect(subject.can_accept? Order.new(), u).to eq true
    end

    context "with non-admin user" do

      context "in ORDERACCEPT group" do
        let! (:group) {
          g = Group.use_system_group("ORDERACCEPT")
          user.groups << g
          g
        }

        it "rejects non-admin users that are not the vendor or agent" do
          expect(subject.can_accept? order, user).to eq false
        end

        it "accepts user that is the vendor" do
          order.vendor = user.company
          expect(subject.can_accept? order, user).to eq true
        end

        it "accepts user that is the vendor" do
          order.agent = user.company
          expect(subject.can_accept? order, user).to eq true
        end
      end

      context "not in ORDERACCEPT group" do
        it "rejects user that is the vendor but not in group" do
          order.vendor = user.company
          expect(subject.can_accept? order, user).to eq false
        end

        it "rejects user that is the vendor but not in group" do
          order.agent = user.company
          expect(subject.can_accept? order, user).to eq false
        end
      end
    end
  end
end
