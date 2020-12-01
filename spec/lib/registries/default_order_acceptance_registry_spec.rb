describe OpenChain::Registries::DefaultOrderAcceptanceRegistry do
  subject { described_class }

  describe "can_be_accepted?" do
    let (:order) { Order.new }

    it "accepts all orders" do
      expect(subject.can_be_accepted? order ).to eq true
    end
  end

  describe "can_accept?" do
    let (:user) { FactoryBot(:user) }
    let (:order) { FactoryBot(:order)}

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