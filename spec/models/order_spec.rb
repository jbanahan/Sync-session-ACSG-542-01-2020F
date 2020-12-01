describe Order do
  describe 'display_order_number' do
    it "shows order_number if no customer order number" do
      expect(described_class.new(order_number: 'abc').display_order_number).to eq 'abc'
    end

    it "shows customer order number" do
      expect(described_class.new(order_number: 'abc', customer_order_number: 'def').display_order_number).to eq 'def'
    end
  end

  describe 'post_create_logic' do
    let(:user) { FactoryBot(:master_user) }
    let(:order) { FactoryBot(:order) }

    it 'runs' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_create, order)
      expect(order).to receive(:create_snapshot_with_async_option).with(false, user)
      order.post_create_logic!(user)
    end

    it 'runs async' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_create, order)
      expect(order).to receive(:create_snapshot_with_async_option).with(true, user)
      order.post_create_logic!(user, true)
    end

    it 'runs async method' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_create, order)
      expect(order).to receive(:create_snapshot_with_async_option).with(true, user)
      order.async_post_create_logic!(user)
    end
  end

  describe 'post_update_logic' do
    let(:user) { FactoryBot(:master_user) }
    let(:order) { FactoryBot(:order) }

    it 'runs' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_update, order)
      expect(order).to receive(:create_snapshot_with_async_option).with(false, user)
      order.post_update_logic!(user)
    end

    it 'runs async' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_update, order)
      expect(order).to receive(:create_snapshot_with_async_option).with(true, user)
      order.post_update_logic!(user, true)
    end

    it 'runs async method' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_update, order)
      expect(order).to receive(:create_snapshot_with_async_option).with(true, user)
      order.async_post_update_logic!(user)
    end
  end

  describe 'can_book?' do
    it "proxies call to booking registry" do
      order = described_class.new
      user = User.new
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:can_book?).with(order, user).and_return true
      expect(order.can_book?(user)).to eq true
    end
  end

  describe 'accept' do
    let(:order) { FactoryBot(:order) }
    let(:user) { FactoryBot(:user, company: FactoryBot(:company, vendor: true)) }

    it 'accepts' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_accept, order)
      expect(order).to receive(:create_snapshot_with_async_option).with false, user
      order.accept! user
      order.reload
      expect(order.approval_status).to eq 'Accepted'
      expect(order.accepted_by).to eq user
      expect(order.accepted_at).not_to be_nil
    end

    it 'accepts async' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_accept, order)
      expect(order).to receive(:create_snapshot_with_async_option).with true, user
      order.async_accept! user
      order.reload
      expect(order.approval_status).to eq 'Accepted'
      expect(order.accepted_by).to eq user
      expect(order.accepted_at).not_to be_nil
    end
  end

  describe 'can_be_accepted?' do
    it "defers to OrderAcceptanceRegistry" do
      o = described_class.new
      expect(OpenChain::Registries::OrderAcceptanceRegistry).to receive(:can_be_accepted?).with(o).and_return true
      expect(o.can_be_accepted?).to eq true
    end
  end

  describe 'unaccept' do
    let(:user) { FactoryBot(:user, company: FactoryBot(:company, vendor: true)) }
    let(:order) { FactoryBot(:order, approval_status: 'Approved', accepted_by: user, accepted_at: Time.zone.now) }

    it 'unaccepts' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_unaccept, order)
      expect(order).to receive(:create_snapshot_with_async_option).with false, user
      order.unaccept! user
      order.reload
      expect(order.approval_status).to be_nil
      expect(order.accepted_by).to be_nil
      expect(order.accepted_at).to be_nil
    end

    it 'unaccepts async' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_unaccept, order)
      expect(order).to receive(:create_snapshot_with_async_option).with true, user
      order.async_unaccept! user
      order.reload
      expect(order.approval_status).to be_nil
      expect(order.accepted_by).to be_nil
      expect(order.accepted_at).to be_nil
    end
  end

  describe 'can_accept' do
    it "defers to OrderAcceptanceRegistry" do
      o = described_class.new
      u = User.new
      expect(OpenChain::Registries::OrderAcceptanceRegistry).to receive(:can_accept?).with(o, u).and_return true
      expect(o.can_accept?(u)).to eq true
    end
  end

  describe 'close' do
    let(:time) { Time.zone.now }
    let(:order) { FactoryBot(:order) }
    let(:user) { FactoryBot(:user) }

    before do
      allow(Time).to receive(:now).and_return time
    end

    it 'closes' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_close, order)
      order.close! user
      order.reload
      expect(order.closed_at.to_i).to eq time.to_i
      expect(order.closed_by).to eq user
      expect(order.entity_snapshots.count).to eq 1
    end

    it 'closes async' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_close, order)
      order.async_close! user
      expect(order.closed_at).to eq time
      expect(order.closed_by).to eq user
      expect(order.entity_snapshots.count).to eq 1
    end
  end

  describe 'reopen' do
    let(:user) { FactoryBot(:user) }
    let(:order) { FactoryBot(:order, closed_at: Time.zone.now, closed_by: user) }

    it 'reopens' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_reopen, order)
      order.reopen! user
      order.reload
      expect(order.closed_at).to be_nil
      expect(order.closed_by).to be_nil
      expect(order.entity_snapshots.count).to eq 1
    end

    it 'reopens async' do
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_reopen, order)
      order.async_reopen! user
      expect(order.closed_at).to be_nil
      expect(order.closed_by).to be_nil
      expect(order.entity_snapshots.count).to eq 1
    end
  end

  describe 'can_close?' do
    let(:order) { FactoryBot(:order, importer: FactoryBot(:company, importer: true)) }

    it "allows a user to close an order if the user can edit orders and is from importer" do
      u = FactoryBot(:user, order_edit: true, company: order.importer)
      expect(order.can_close?(u)).to be_truthy
    end

    it "allows a user to close an order if the user can edit orders and is from master" do
      u = FactoryBot(:master_user, order_edit: true)
      expect(order.can_close?(u)).to be_truthy
    end

    it "does not allow a user to close an order if the user can edit orders and is from vendor" do
      u = FactoryBot(:user, order_edit: true)
      order.update(vendor_id: u.company_id)
      expect(order.can_close?(u)).to be_falsey
    end

    it "does not allow a user to close an order if the user cannot edit orders" do
      u = FactoryBot(:user, order_edit: false, company: order.importer)
      expect(order.can_close?(u)).to be_falsey
    end
  end

  describe 'linkable attachments' do
    it 'has linkable attachments' do
      o = FactoryBot(:order, order_number: 'ordn')
      linkable = FactoryBot(:linkable_attachment, model_field_uid: 'ord_ord_num', value: 'ordn')
      LinkedAttachment.create(linkable_attachment_id: linkable.id, attachable: o)
      o.reload
      expect(o.linkable_attachments.first).to eq(linkable)
    end
  end

  describe 'all attachments' do
    let(:order) { FactoryBot(:order) }

    it 'returns all_attachments when only regular attachments' do
      a = order.attachments.create!
      all = order.all_attachments
      expect(all.size).to eq(1)
      expect(all.first).to eq(a)
    end

    it 'returns all_attachments when only linked attachents' do
      linkable = FactoryBot(:linkable_attachment, model_field_uid: 'ord_ord_num', value: order.order_number)
      a = linkable.build_attachment
      a.save!
      order.linked_attachments.create!(linkable_attachment_id: linkable.id)
      all = order.all_attachments
      expect(all.size).to eq(1)
      expect(all.first).to eq(a)
    end

    it 'returns all_attachments when both attachments' do
      a = order.attachments.create!
      linkable = FactoryBot(:linkable_attachment, model_field_uid: 'ord_ord_num', value: order.order_number)
      linkable_a = linkable.build_attachment
      linkable_a.save!
      order.linked_attachments.create!(linkable_attachment_id: linkable.id)
      all = order.all_attachments
      expect(all.size).to eq(2)
      expect(all).to include(a)
      expect(all).to include(linkable_a)
    end

    it 'returns empty array when no attachments' do
      expect(order.all_attachments).to be_empty
    end
  end

  describe "create_unique_po_number" do
    it "uses importer identifier in po number" do
      o = described_class.new customer_order_number: "PO",
                              importer: Company.new(system_code: "SYS_CODE",
                                                    alliance_customer_number: "ALL_CODE",
                                                    fenix_customer_number: "FEN_CODE")

      expect(o.create_unique_po_number).to eq "SYS_CODE-PO"
    end

    it "uses importer kewill code after sys code" do
      o = described_class.new customer_order_number: "PO", importer: with_customs_management_id(FactoryBot(:importer), "ALL_CODE")
      expect(o.create_unique_po_number).to eq "ALL_CODE-PO"
    end

    it "uses fenix code after kewill code" do
      o = described_class.new customer_order_number: "PO", importer: with_fenix_id(FactoryBot(:importer), "FEN_CODE")
      expect(o.create_unique_po_number).to eq "FEN_CODE-PO"
    end

    it "uses vendor sys code" do
      o = described_class.new customer_order_number: "PO", vendor: Company.new(system_code: "SYS_CODE")
      expect(o.create_unique_po_number).to eq "SYS_CODE-PO"
    end
  end

  describe "can_view?" do
    let(:selling_agent) { FactoryBot(:company, selling_agent: true) }
    let(:user) { FactoryBot(:user, company: selling_agent) }
    let(:order) { described_class.new }

    context "selling agent" do
      before do
        order.selling_agent = selling_agent
        allow(user).to receive(:view_orders?).and_return true
      end

      it "allows a user to view orders if linked company is selling agent" do
        order.selling_agent = FactoryBot(:company, selling_agent: true)

        user.company.linked_company_ids = [order.selling_agent.id]
        expect(order.can_view?(user)).to be_truthy
      end

      it "allows a selling agent to view their orders" do
        selling_agent = FactoryBot(:company, selling_agent: true)
        order.selling_agent = selling_agent
        u = FactoryBot(:user, company: selling_agent)
        allow(u).to receive(:view_orders?).and_return true

        expect(order.can_view?(u)).to be_truthy
      end
    end

    context "importer" do
      let(:importer) { FactoryBot(:company, importer: true) }
      let(:user) { FactoryBot(:user, company: importer) }

      before do
        order.importer = importer
        allow(user).to receive(:view_orders?).and_return true
      end

      it "allows an importer to view their orders" do
        expect(order.can_view?(user)).to be_truthy
      end

      it "allows user to view if linked company is order importer" do
        order.importer = FactoryBot(:company, importer: true)

        user.company.linked_company_ids = [order.importer.id]
        expect(order.can_view?(user)).to be_truthy
      end

      it "allows user to view if linked company is order vendor" do
        order.vendor = FactoryBot(:company, vendor: true)

        user.company.linked_company_ids = [order.vendor.id]
        expect(order.can_view?(user)).to be_truthy
      end

      it "allows a vendor to view their orders" do
        vendor = FactoryBot(:company, vendor: true)
        order.vendor = vendor
        u = FactoryBot(:user, company: vendor)
        allow(u).to receive(:view_orders?).and_return true

        expect(order.can_view?(u)).to be_truthy
      end
    end

    context "vendor" do
      let(:vendor) { FactoryBot(:company, vendor: true) }
      let(:user) { FactoryBot(:user, company: vendor) }

      before do
        order.vendor = vendor
        allow(user).to receive(:view_orders?).and_return true
      end

      it "allows a vendor to view their orders" do
        expect(order.can_view?(user)).to be_truthy
      end

      it "allows user to view if linked company is order vendor" do
        order.vendor = FactoryBot(:company, vendor: true)

        user.company.linked_company_ids = [order.vendor.id]
        expect(order.can_view?(user)).to be_truthy
      end
    end

    context "factory" do
      let(:factory) { FactoryBot(:company, factory: true) }
      let(:user) { FactoryBot(:user, company: factory) }

      before do
        order.factory = factory
        allow(user).to receive(:view_orders?).and_return true
      end

      it "allows a factory to view their orders" do
        expect(order.can_view?(user)).to be_truthy
      end
    end
  end

  describe "compose_po_number" do
    it "assembles a po number" do
      expect(described_class.compose_po_number("A", "b")).to eq "A-b"
    end
  end

  describe "shipping?" do
    it "shows PO as shipping if any line has a piece set associated with a shipment" do
      order = FactoryBot(:order_line).order
      sl = FactoryBot(:shipment_line, product: order.order_lines.first.product)
      PieceSet.create! order_line: order.order_lines.first, shipment_line: sl, quantity: 1

      expect(order.shipping?).to be_truthy
    end

    it "does not show PO as shipping if there is no piece set associated w/ a shipment" do
      order = FactoryBot(:order_line).order
      PieceSet.create! order_line: order.order_lines.first, quantity: 1
      expect(order.shipping?).to be_falsey
    end
  end

  describe "mark_order_as_accepted" do
    it "marks the order" do
      o = described_class.new
      o.mark_order_as_accepted
      expect(o.approval_status).to eq "Accepted"
    end
  end

  describe "associate_vendor_and_products!" do
    it "creates assignments for records where they don't already exist" do
      expect_any_instance_of(ProductVendorAssignment).to receive(:create_snapshot).once
      ol = FactoryBot(:order_line)
      ol2 = FactoryBot(:order_line, order: ol.order)

      expect(ol.order.vendor).not_to be_nil

      associated_product = ol.product
      FactoryBot(:product_vendor_assignment, vendor: ol.order.vendor, product: associated_product)

      expect {ol.order.associate_vendor_and_products!(FactoryBot(:user))}.to change(ProductVendorAssignment, :count).from(1).to(2)

      pva = ProductVendorAssignment.last
      expect(pva.vendor).to eq ol.order.vendor
      expect(pva.product).to eq ol2.product
    end
  end

  describe '#available_tpp_survey_responses' do
    let :clean_survey_response do
      destination = FactoryBot(:country, iso_code: 'US')
      mc = FactoryBot(:master_company)
      ship_to = FactoryBot(:address, company: mc, country: destination)
      u = FactoryBot(:vendor_user)
      vendor = u.company
      o = FactoryBot(:order, vendor: vendor)
      FactoryBot(:order_line, order: o, ship_to: ship_to)

      tpp = FactoryBot(:trade_preference_program, destination_country: destination)

      survey = FactoryBot(:survey, trade_preference_program: tpp, expiration_days: 365)
      sr = survey.generate_response!(u)
      sr.submitted_date = 1.day.ago
      sr.save!
      [o, sr]
    end

    it 'finds responses' do
      o, sr = clean_survey_response
      expect(o.available_tpp_survey_responses.to_a).to eq [sr]
    end

    it 'only includes responses that are submitted' do
      o, sr = clean_survey_response
      sr.submitted_date = nil
      sr.save!
      expect(o.available_tpp_survey_responses.to_a).to eq []
    end

    it 'only includes responses where the responder is from the vendor company' do
      o = clean_survey_response.first
      o.vendor = FactoryBot(:vendor)
      o.save!
      expect(o.available_tpp_survey_responses.to_a).to eq []
    end

    it 'only includes responses that are for a ship to country that is included in order' do
      o = clean_survey_response.first
      st = o.order_lines.first.ship_to
      st.country = FactoryBot(:country)
      st.save!
      expect(o.available_tpp_survey_responses.to_a).to eq []
    end

    it 'only includes responses that are not expired' do
      o, sr = clean_survey_response
      sr.email_sent_date = 2.years.ago
      sr.save!
      expect(o.available_tpp_survey_responses.to_a).to eq []
    end
  end

  describe "booked?" do
    let (:order) { FactoryBot(:order) }
    let (:product) { FactoryBot(:product) }
    let! (:booking_line) { FactoryBot(:booking_line, order: order, product: product) }

    it "indicates booked as true if an order id is listed on a booking line" do
      expect(order.booked?).to eq true
    end

    it "indicates booked as false if an order is not on a booking line" do
      booking_line.destroy
      expect(order.booked?).to eq false
    end
  end

  describe "booked_qty" do
    let (:order) { FactoryBot(:order) }
    let (:product) { FactoryBot(:product) }
    let! (:booking_line_1) { FactoryBot(:booking_line, order: order, product: product, quantity: 10) }
    let! (:booking_line_2) { FactoryBot(:booking_line, order: order, product: product, quantity: 15) }

    it "finds sum of quantity of all booking lines" do
      expect(order.booked_qty).to eq 25
    end

    it "handles booking lines w/ null quantities" do
      booking_line_1.update! quantity: nil
      expect(order.booked_qty).to eq 15
    end

    it "returns 0 if no lines are booked" do
      booking_line_1.destroy
      booking_line_2.destroy
      expect(order.booked_qty).to eq 0
    end
  end

  describe "related_bookings" do
    it "returns booked shipments associated with order" do
      o = FactoryBot(:order)
      s1 = FactoryBot(:shipment, reference: "ref")
      ol1 = FactoryBot(:order_line, order: o)
      FactoryBot(:booking_line, shipment: s1, order_line: ol1)
      s2 = FactoryBot(:shipment, reference: "ref2")
      ol2 = FactoryBot(:order_line, order: o)
      FactoryBot(:booking_line, shipment: s2, order_line: ol2)

      expect(o.related_bookings).to eq Set.new([s1, s2])
    end
  end
end
