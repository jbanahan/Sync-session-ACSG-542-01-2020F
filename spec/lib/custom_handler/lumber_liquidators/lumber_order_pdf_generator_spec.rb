describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator do
  let(:cdefs) { subject.instance_variable_get("@cdefs") }

  describe '#create!' do
    let(:order) { create(:order, order_number:'ABC', vendor: create(:vendor), order_date: Date.new(2016, 3, 15)) }
    let(:purchasing_contact) {
      order.vendor.update_custom_value! cdefs[:cmp_purchasing_contact_email], "me@there.com"
      "me@there.com"
    }

    before :each do
      cdefs
      stub_master_setup_request_host
    end

    it 'should create pdf and attach to order' do
      Timecop.freeze(Time.now) do
        described_class.create! order, create(:master_user)
        order.reload
        expect(order.attachments.size).to eq 1

        att = order.attachments.first
        expect(att.attachment_type).to eq 'Order Printout'
        expect(att.attached_file_name).to eq "order_ABC_#{Time.now.strftime('%Y%m%d%H%M%S%L')}.pdf"
        expect(ActionMailer::Base.deliveries.size).to eq 0
      end
    end

    it "sends email to Purchasing Contact Email" do
      contact = purchasing_contact
      described_class.create! order, create(:master_user)

      expect(ActionMailer::Base.deliveries.size).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq [contact]
      expect(m.subject).to eq "Lumber Liquidators PO ABC - NEW"
      expect(m.body.raw_source).to include "You have received the attached purchase order from Lumber Liquidators.  If you have a VFI Track account, you may access the order at <a href=\"https://localhost:3000\">https://localhost:3000</a>"
    end

    it "sends email to Purchasing Content email notifying of updated po" do
      contact = purchasing_contact
      order.attachments.create! attachment_type: 'Order Printout'
      described_class.create! order, create(:master_user)

      expect(ActionMailer::Base.deliveries.size).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq [contact]
      expect(m.subject).to eq "Lumber Liquidators PO ABC - UPDATE"
    end
  end

  describe "carb_statement" do
    let(:ord) { create(:order, order_date: Date.new(2017, 8, 31)) }

    it "returns pre-8/31/17 (inclusive) message" do
      expect(described_class.carb_statement ord).to eq "All Composite Wood Products contained in finished goods must be compliant to California 93120 Phase 2 for formaldehyde."
    end

    it "returns post-8/31/17 message" do
      ord.update_attributes(order_date: Date.new(2017, 9, 1))
      expect(described_class.carb_statement ord).to eq "All Composite Wood Products contained in finished goods must be TSCA Title VI Compliant and must be compliant with California Phase 2 formaldehyde emission standards (17 CCR 93120.2)"
    end

    it "uses 'created_at' if order date is blank" do
      ord.update_attributes(order_date: nil)
      expect(ord).to receive(:created_at).and_return Date.new(2017, 8, 31)
      expect(described_class.carb_statement ord).to eq "All Composite Wood Products contained in finished goods must be compliant to California 93120 Phase 2 for formaldehyde."
    end
  end

  describe "lacey_statement" do
    let(:ord) { create(:order, order_date: Date.new(2018, 7, 30)) }
    let(:statement) { "All U.S. Domestic and Imported products must be compliant with all applicable laws, including, without limitation and to the extent applicable, the U.S. Lacey Act (16 U.S.C. §§ 3371–3378)" }

    it "returns nil if order is before 8/1/18" do
      expect(described_class.lacey_statement ord).to be_nil
    end

    it "returns message if order is on or after 8/1/18" do
      ord.update_attributes! order_date: Date.new(2018, 8, 1)
      expect(described_class.lacey_statement ord).to eq statement
    end

    it "uses 'created_at' if order date is blank" do
      ord.update_attributes! order_date: nil
      expect(ord).to receive(:created_at).and_return Date.new(2018, 8, 2)
      expect(described_class.lacey_statement ord).to eq statement
    end
  end

  ##########################
  # NOT TESTING #render method
  # which should be tested manually when modifying PDF generation
  ##########################
end
