describe Shipment do
  let :order_booking do
    obr = Class.new do
      def self.can_book?(_ord, _user);
        true;
      end

      def self.can_request_booking?(_ord, _user);
        true;
      end

      def self.can_revise_booking?(_ord, _user);
        true;
      end

      def self.can_edit_booking?(_shipment, _user);
        true;
      end

      def self.can_cancel?(_shipment, _user);
        true;
      end

      def self.can_uncancel?(_shipment, _user);
        true;
      end
    end
    OpenChain::Registries::OrderBookingRegistry.register obr
    OpenChain::Registries::ShipmentRegistry.register obr
    obr
  end

  describe '#generate_reference' do
    it 'generates random reference number' do
      expect(described_class.generate_reference).to match(/^[0-9A-F]{8}$/)
    end

    it 'tries again if reference is taken' do
      expect(SecureRandom).to receive(:hex).and_return('01234567', '87654321')
      create(:shipment, reference: '01234567')
      expect(described_class.generate_reference).to eq '87654321'
    end
  end

  describe "can_view?" do
    it "does not allow view if user not master and not linked to importer (even if the company is one of the other parties)" do
      imp = create(:company, importer: true)
      c = create(:company, vendor: true)
      s = create(:shipment, vendor: c, importer: imp)
      u = create(:user, shipment_view: true, company: c)
      expect(s.can_view?(u)).to be_falsey
    end

    it "allows view if user from importer company" do
      imp = create(:company, importer: true)
      u = create(:user, shipment_view: true, company: imp)
      s = create(:shipment, importer: imp)
      expect(s.can_view?(u)).to be_truthy
    end

    it "allows view if user from forwarder company" do
      fwd = create(:company, forwarder: true)
      imp = create(:company, importer: true)
      imp.linked_companies << fwd
      u = create(:user, shipment_view: true, company: fwd)
      s = create(:shipment, importer: imp, forwarder: fwd)
      expect(s.can_view?(u)).to be_truthy
    end
  end

  describe "search_secure" do
    let!(:master_only) { create(:shipment) }

    it "allows vendor who is linked to shipment" do
      u = create(:user)
      s = create(:shipment, vendor: u.company)
      expect(described_class.search_secure(u, described_class).to_a).to eq [s]
    end

    it "allows importer who is linked to shipment" do
      u = create(:user)
      s = create(:shipment, importer: u.company)
      expect(described_class.search_secure(u, described_class).to_a).to eq [s]
    end

    it "allows agent who is linked to vendor on shipment" do
      u = create(:user)
      v = create(:company)
      v.linked_companies << u.company
      s = create(:shipment, vendor: v)
      expect(described_class.search_secure(u, described_class).to_a).to eq [s]
    end

    it "allows master user" do
      u = create(:master_user)
      expect(described_class.search_secure(u, described_class).to_a).to eq [master_only]
    end

    it "allows carrier who is linked to shipment" do
      u = create(:user)
      s = create(:shipment, carrier: u.company)
      expect(described_class.search_secure(u, described_class).to_a).to eq [s]
    end

    it "allows forwarder who is linked to shipment" do
      u = create(:user)
      s = create(:shipment, forwarder: u.company)
      expect(described_class.search_secure(u, described_class).to_a).to eq [s]
    end

    it "does not allow non linked user" do
      u = create(:user)
      expect(described_class.search_secure(u, described_class).to_a).to be_empty
    end
  end

  describe "can_cancel?" do
    it "calls registry method" do
      u = create(:user)
      s = create(:shipment)
      expect(OpenChain::Registries::ShipmentRegistry).to receive(:can_cancel?).with(s, u).and_return true
      s.can_cancel? u
    end
  end

  describe "cancel_shipment!" do
    let (:user) { create(:user) }
    let (:shipment) { create(:shipment) }

    it "sets cancel fields" do
      expect(shipment).to receive(:create_snapshot_with_async_option).with false, user, nil, nil
      expect(OpenChain::EventPublisher).to receive(:publish).with(:shipment_cancel, shipment)
      expect(OpenChain::Registries::ShipmentRegistry).to receive(:cancel_shipment_hook).with(shipment, user)
      now = Time.zone.parse("2018-09-10 12:00")
      Timecop.freeze(now) { shipment.cancel_shipment! user }

      shipment.reload
      expect(shipment.canceled_date).to eq now
      expect(shipment.canceled_by).to eq user
    end

    it "sets canceled_order_line_id for linked orders and remove shipment_line_id from piece_sets" do
      expect(shipment).to receive(:create_snapshot_with_async_option)
      expect(OpenChain::EventPublisher).to receive(:publish).with(:shipment_cancel, shipment)
      expect(OpenChain::Registries::ShipmentRegistry).to receive(:cancel_shipment_hook).with(shipment, user)
      p = create(:product)
      ol = create(:order_line, product: p, quantity: 100)
      sl1 = shipment.shipment_lines.build(quantity: 5)
      sl2 = shipment.shipment_lines.build(quantity: 10)
      [sl1, sl2].each do |sl|
        sl.product = p
        sl.linked_order_line_id = ol.id
        sl.save!
      end
      # merge the two piece sets but don't delete so we don't have to check if they're linked
      # to other things
      expect {shipment.cancel_shipment!(user)}.to change(PieceSet, :count).from(2).to(0)
      [sl1, sl2].each do |sl|
        sl.reload
        expect(sl.canceled_order_line).to eq ol
      end
    end

    it "allows passing snapshot context and canceled date" do
      expect(shipment).to receive(:create_snapshot_with_async_option).with true, user, nil, "context"
      shipment.cancel_shipment! user, async_snapshot: true, canceled_date: Time.zone.parse("2018-09-10 12:00"), snapshot_context: "context"

      shipment.reload
      expect(shipment.canceled_date).to eq Time.zone.parse("2018-09-10 12:00")
      expect(shipment.canceled_by).to eq user
    end
  end

  describe "can_uncancel?" do
    it "calls registry method" do
      u = create(:user)
      s = create(:shipment)
      expect(OpenChain::Registries::ShipmentRegistry).to receive(:can_uncancel?).with(s, u).and_return true
      s.can_uncancel? u
    end
  end

  describe "uncancel_shipment!" do
    it "removes cancellation" do
      u = create(:user)
      s = create(:shipment, canceled_by: u, canceled_date: Time.zone.now, cancel_requested_at: Time.zone.now, cancel_requested_by: u)
      expect(s).to receive(:create_snapshot_with_async_option).with false, u
      s.uncancel_shipment! u
      s.reload
      expect(s.canceled_by).to be_nil
      expect(s.canceled_date).to be_nil
      expect(s.cancel_requested_at).to be_nil
      expect(s.cancel_requested_by).to be_nil
    end

    it "restores cancelled order line links" do
      u = create(:user)
      s = create(:shipment)
      expect(s).to receive(:create_snapshot_with_async_option).with false, u
      p = create(:product)
      ol = create(:order_line, product: p, quantity: 100)
      sl1 = s.shipment_lines.build(quantity: 5)
      sl2 = s.shipment_lines.build(quantity: 10)
      [sl1, sl2].each do |sl|
        sl.product = p
        sl.canceled_order_line_id = ol.id
        sl.save!
      end
      # merge the two piece sets but don't delete so we don't have to check if they're linked
      # to other things
      expect {s.uncancel_shipment!(u)}.to change(PieceSet.where(order_line_id: ol.id), :count).from(0).to(2)
      [sl1, sl2].each do |sl|
        sl.reload
        expect(sl.order_lines.to_a).to eq [ol]
      end
    end
  end

  describe '#request_cancel' do
    let (:shipment) { create(:shipment) }
    let (:user) { create(:user) }

    it "calls hook" do
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:post_request_cancel_hook).with(shipment, user)
      expect(shipment).to receive(:create_snapshot_with_async_option).with(false, user)
      now = Time.zone.now
      Timecop.freeze(now) { shipment.request_cancel! user }

      expect(shipment.cancel_requested_by).to eq user
      expect(shipment.cancel_requested_at).to eq now
    end
  end

  describe "request booking" do
    it "sets booking fields" do
      u = User.new
      s = described_class.new
      expect(s).to receive(:save!)
      expect(s).to receive(:create_snapshot_with_async_option).with false, u
      expect(OpenChain::EventPublisher).to receive(:publish).with(:shipment_booking_request, s)
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:request_booking_hook).with(s, u)
      s.request_booking! u
      expect(s.booking_received_date).not_to be_nil
      expect(s.booking_requested_by).to eq u
      expect(s.booking_request_count).to eq 1
    end
  end

  describe "can_request_booking?" do
    it "defers to order booking registry" do
      s = described_class.new
      u = instance_double(User)
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:can_request_booking?).with(s, u).and_return true
      expect(s.can_request_booking?(u)).to be true
    end
  end

  describe "can_approve_booking?" do
    it "allows approval for importer user who can edit shipment" do
      u = create(:user, shipment_edit: true, company: create(:company, importer: true))
      s = described_class.new(booking_received_date: Time.zone.now)
      s.importer = u.company
      allow(s).to receive(:can_edit?).and_return true
      expect(s.can_approve_booking?(u)).to be_truthy
    end

    it "allows approval for master user who can edit shipment" do
      u = create(:master_user, shipment_edit: true)
      s = described_class.new(booking_received_date: Time.zone.now)
      expect(s).to receive(:can_edit?).with(u).and_return true
      expect(s.can_approve_booking?(u)).to be_truthy
    end

    it "does not allow approval for user who cannot edit shipment" do
      u = create(:master_user, shipment_edit: true)
      s = described_class.new(booking_received_date: Time.zone.now)
      expect(s).to receive(:can_edit?).with(u).and_return false
      expect(s.can_approve_booking?(u)).to be_falsey
    end

    it "does not allow approval for user from a different associated company" do
      u = create(:user, shipment_edit: true, company: create(:company, importer: true))
      s = described_class.new(booking_received_date: Time.zone.now)
      s.vendor = u.company
      allow(s).to receive(:can_edit?).and_return true
      expect(s.can_approve_booking?(u)).to be_falsey
    end

    it "does not allow approval when booking not received" do
      u = create(:master_user, shipment_edit: true)
      s = described_class.new(booking_received_date: nil)
      allow(s).to receive(:can_edit?).and_return true
      expect(s.can_approve_booking?(u)).to be_falsey
    end

    it "does not allow if booking has been confirmed" do
      u = create(:master_user, shipment_edit: true)
      s = described_class.new(booking_received_date: Time.zone.now, booking_confirmed_date: Time.zone.now)
      allow(s).to receive(:can_edit?).and_return true # make sure we're not testing the wrong thing
      expect(s.can_approve_booking?(u)).to be_falsey
    end
  end

  describe "approve_booking!" do
    it "sets booking_approved_date and booking_approved_by" do
      u = create(:user)
      s = create(:shipment)
      expect(s).to receive(:create_snapshot_with_async_option).with false, u
      expect(OpenChain::EventPublisher).to receive(:publish).with(:shipment_booking_approve, s)
      s.approve_booking! u
      s.reload
      expect(s.booking_approved_date).not_to be_nil
      expect(s.booking_approved_by).to eq u
    end
  end

  describe "can_confirm_booking?" do
    it "allows confirmation for carrier user who can edit shipment" do
      u = create(:user, shipment_edit: true, company: create(:company, carrier: true))
      s = described_class.new(booking_received_date: Time.zone.now)
      allow(s).to receive(:can_edit?).and_return true
      s.carrier = u.company
      expect(s.can_confirm_booking?(u)).to be_truthy
    end

    it "allows confirmation for master user who can edit shipment" do
      u = create(:master_user, shipment_edit: true)
      s = described_class.new(booking_received_date: Time.zone.now)
      expect(s).to receive(:can_edit?).with(u).and_return true
      expect(s.can_confirm_booking?(u)).to be_truthy
    end

    it "does not allow confirmation for user who cannot edit shipment" do
      u = create(:master_user, shipment_edit: false)
      s = described_class.new(booking_received_date: Time.zone.now)
      expect(s).to receive(:can_edit?).with(u).and_return false
      expect(s.can_confirm_booking?(u)).to be_falsey
    end

    it "does not allow confirmation for user who can edit shipment but isn't carrier or master" do
      u = create(:user, shipment_edit: true, company: create(:company, vendor: true))
      s = described_class.new(booking_received_date: Time.zone.now)
      allow(s).to receive(:can_edit?).and_return true
      s.vendor = u.company
      expect(s.can_confirm_booking?(u)).to be_falsey
    end

    it "does not allow confirmation when booking has not been received" do
      u = create(:master_user, shipment_edit: true)
      s = described_class.new(booking_received_date: nil)
      allow(s).to receive(:can_edit?).and_return true
      expect(s.can_confirm_booking?(u)).to be_falsey
    end

    it "does not allow if booking already confiremd" do
      u = create(:master_user, shipment_edit: true)
      s = described_class.new(booking_received_date: Time.zone.now, booking_confirmed_date: Time.zone.now)
      allow(s).to receive(:can_edit?).and_return true # make sure we're not accidentally testing the wrong thing
      expect(s.can_confirm_booking?(u)).to be_falsey
    end
  end

  describe "confirm booking" do
    let (:user) { create(:user) }
    let (:shipment) do
      s = create(:shipment)
      create(:shipment_line, shipment: s, quantity: 50)
      create(:shipment_line, shipment: s, quantity: 100)

      s
    end

    it "sets booking confirmed date and booking confirmed by and booked quantity" do
      expect(shipment).to receive(:create_snapshot_with_async_option).with false, user
      expect(OpenChain::EventPublisher).to receive(:publish).with(:shipment_booking_confirm, shipment)
      shipment.confirm_booking! user
      shipment.reload
      expect(shipment.booking_confirmed_date).not_to be_nil
      expect(shipment.booking_confirmed_by).to eq user
      expect(shipment.booked_quantity).to eq 150
    end

    it "utilizes booking lines by default to calculate booked quantity" do
      shipment.booking_lines << BookingLine.new(line_number: 1, quantity: 100, product: shipment.shipment_lines.first.product)
      shipment.booking_lines << BookingLine.new(line_number: 2, quantity: 100, product: shipment.shipment_lines.first.product)

      shipment.confirm_booking! user
      expect(shipment.booked_quantity).to eq 200
    end
  end

  describe "can_revise_booking?" do
    it "defers to booking registry" do
      user = User.new
      shipment = described_class.new
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:can_revise_booking?).with(shipment, user).and_return true
      expect(shipment.can_revise_booking?(user)).to eq true
    end
  end

  describe "revise booking" do
    it "removes received, requested, approved and confirmed date and 'by' fields" do
      u = create(:user)
      original_receive = Time.zone.now
      s = create(:shipment, booking_approved_by: u, booking_requested_by: u, booking_confirmed_by: u,
                             booking_received_date: original_receive, booking_approved_date: Time.zone.now,
                             booking_confirmed_date: Time.zone.now, booking_request_count: 1)
      expect(s).to receive(:create_snapshot_with_async_option).with(false, u)
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:revise_booking_hook).with(s, u)
      now = Time.zone.now
      Timecop.freeze(now) { s.revise_booking! u }
      s.reload
      expect(s.booking_approved_by).to be_nil
      expect(s.booking_approved_date).to be_nil
      expect(s.booking_confirmed_by).to be_nil
      expect(s.booking_confirmed_date).to be_nil
      expect(s.booking_received_date.to_i).to eq original_receive.to_i
      expect(s.booking_requested_by).to eq u
      expect(s.booking_revised_date.to_i).to eq now.to_i
      expect(s.booking_request_count).to eq 2
    end
  end

  context 'shipment instructions' do
    describe '#can_send_shipment_instructions?' do
      let :shipment_without_lines do
        s = described_class.new(vendor: Company.new, booking_received_date: Time.zone.now)
        allow(s).to receive(:can_edit?).and_return true
        s
      end
      let :shipment do
        shipment_without_lines.shipment_lines.build(line_number: 1)
        shipment_without_lines
      end
      let :user do
        u = User.new
        u.company = shipment_without_lines.vendor
        u
      end

      it "allows if user is from vendor and booking has been sent and shipment lines exist and user can edit" do
        expect(shipment.can_send_shipment_instructions?(user)).to be_truthy
      end

      it "does not allow if user cannot edit" do
        expect(shipment).to receive(:can_edit?).with(user).and_return false
        expect(shipment.can_send_shipment_instructions?(user)).to be_falsey
      end

      it "does not allow if shipment does not have lines" do
        expect(shipment_without_lines.can_send_shipment_instructions?(user)).to be_falsey
      end

      it "does not allow if user is not from vendor" do
        user.company = Company.new
        expect(shipment.can_send_shipment_instructions?(user)).to be_falsey
      end

      it "does not allow if booking has not been sent" do
        shipment.booking_received_date = nil
        expect(shipment.can_send_shipment_instructions?(user)).to be_falsey
      end

      it "does not allow if shipment is canceled" do
        shipment.canceled_date = Time.zone.now
        expect(shipment.can_send_shipment_instructions?(user)).to be_falsey
      end
    end

    describe '#send_shipment_instructions!' do
      it "sets shipment instructions fields, publish event, and create snapshot" do
        s = create(:shipment)
        u = create(:user)
        expect(OpenChain::EventPublisher).to receive(:publish).with(:shipment_instructions_send, s)
        expect(s).to receive(:create_snapshot_with_async_option).with(false, u)

        s.send_shipment_instructions! u

        s.reload
        expect(s.shipment_instructions_sent_date).not_to be_nil
        expect(s.shipment_instructions_sent_by).to eq u
      end
    end
  end

  describe "can_add_remove_booking_lines?" do
    it "allows adding lines if user can edit" do
      u = instance_double('user')
      s = described_class.new
      expect(s).to receive(:can_edit?).with(u).and_return true
      expect(s.can_add_remove_booking_lines?(u)).to be_truthy
    end

    it "does not allow adding lines if user cannot edit" do
      u = instance_double('user')
      s = described_class.new
      expect(s).to receive(:can_edit?).with(u).and_return false
      expect(s.can_add_remove_booking_lines?(u)).to be_falsey
    end

    context "editable shipment" do
      let(:shipment) do
        s = described_class.new
        # stub can edit to make sure we're allowing anyone/anything to edit
        allow(s).to receive(:can_edit?).and_return true
        s
      end

      let(:user) { instance_double("user") }

      it "allows adding booking lines if booking is approved" do
        s = shipment.tap {|shp| shp.booking_approved_date = Time.zone.now }
        expect(s.can_add_remove_booking_lines?(user)).to be_truthy
      end

      it "allows adding lines if booking is confirmed" do
        s = shipment.tap {|shp| shp.booking_confirmed_date = Time.zone.now }
        expect(s.can_add_remove_booking_lines?(user)).to be_truthy
      end

      it "disallows adding lines if shipment has actual shipment lines on it" do
        s = shipment.tap {|shp| shp.shipment_lines.build }
        expect(s.can_add_remove_booking_lines?(user)).to be_falsey
      end
    end
  end

  describe "can_add_remove_shipment_lines?" do
    it "allows adding lines if user can edit" do
      u = instance_double('user')
      s = described_class.new
      expect(s).to receive(:can_edit?).with(u).and_return true
      expect(s.can_add_remove_shipment_lines?(u)).to be_truthy
    end

    it "disallows adding lines if user cannot edit" do
      u = instance_double('user')
      s = described_class.new
      expect(s).to receive(:can_edit?).with(u).and_return false
      expect(s.can_add_remove_shipment_lines?(u)).to be_falsey
    end
  end

  describe "available_orders" do
    it "finds nothing if importer not set" do
      expect(described_class.new.available_orders(User.new)).to be_empty
    end

    context "with_data" do
      let(:imp) { create(:company, importer: true) }
      let(:vendor_1) { create(:company, vendor: true) }
      let(:vendor_2) { create(:company, vendor: true) }
      let!(:order_1) { create(:order, importer: imp, vendor: vendor_1, approval_status: 'Accepted') }
      let!(:order_2) { create(:order, importer: imp, vendor: vendor_2, approval_status: 'Accepted') }
      let(:s) { described_class.new(importer_id: imp.id) }

      before do
        create(:order, importer: create(:company, importer: true), vendor: vendor_1, approval_status: 'Accepted')
      end

      it "finds all orders with approval_status == Accepted where user is importer if vendor isn't set" do
        # don't find because not accepted
        create(:order, importer: imp, vendor: vendor_1)
        u = create(:user, company: imp, order_view: true)
        expect(s.available_orders(u).to_a).to eq [order_1, order_2]
      end

      it "finds all orders for vendor with approval_status == Accepted user is importer" do
        u = create(:user, company: vendor_1, order_view: true)
        expect(s.available_orders(u).to_a).to eq [order_1]
      end

      it "finds all orders where shipment.vendor == order.vendor and approval_status == Accepted if vendor is set" do
        u = create(:user, company: imp, order_view: true)
        s.vendor_id = vendor_1.id
        expect(s.available_orders(u).to_a).to eq [order_1]
      end

      it "does not show orders that the user cannot see" do
        u = create(:user, company: vendor_1, order_view: true)
        s.vendor_id = vendor_2.id
        expect(s.available_orders(u).to_a).to be_empty
      end

      it "does not find closed orders" do
        order_2.update(closed_at: Time.zone.now)
        u = create(:user, company: imp, order_view: true)
        expect(s.available_orders(u).to_a).to eq [order_1]
      end
    end

  end

  describe "commercial_invoices" do
    it "finds linked invoices" do
      sl_1 = create(:shipment_line, quantity: 10)
      ol_1 = create(:order_line, product: sl_1.product, order: create(:order, vendor: sl_1.shipment.vendor), quantity: 10, price_per_unit: 3)
      cl_1 = create(:commercial_invoice_line, commercial_invoice: create(:commercial_invoice, invoice_number: "IN1"), quantity: 10)
      sl_2 = create(:shipment_line, quantity: 11, shipment: sl_1.shipment, product: sl_1.product)
      ol_2 = create(:order_line, product: sl_2.product, order: create(:order, vendor: sl_2.shipment.vendor), quantity: 11, price_per_unit: 2)
      cl_2 = create(:commercial_invoice_line, commercial_invoice: create(:commercial_invoice, invoice_number: "IN2"), quantity: 11)
      PieceSet.create!(shipment_line_id: sl_1.id, order_line_id: ol_1.id, commercial_invoice_line_id: cl_1.id, quantity: 10)
      PieceSet.create!(shipment_line_id: sl_2.id, order_line_id: ol_2.id, commercial_invoice_line_id: cl_2.id, quantity: 11)

      s = described_class.find(sl_1.shipment.id)

      expect(s.commercial_invoices.collect(&:invoice_number)).to eq(["IN1", "IN2"])
    end

    it "only returns unique invoices" do
      sl_1 = create(:shipment_line, quantity: 10)
      ol_1 = create(:order_line, product: sl_1.product, order: create(:order, vendor: sl_1.shipment.vendor), quantity: 10, price_per_unit: 3)
      cl_1 = create(:commercial_invoice_line, commercial_invoice: create(:commercial_invoice, invoice_number: "IN1"), quantity: 10)
      sl_2 = create(:shipment_line, quantity: 11, shipment: sl_1.shipment, product: sl_1.product)
      ol_2 = create(:order_line, product: sl_2.product, order: create(:order, vendor: sl_2.shipment.vendor), quantity: 11, price_per_unit: 2)
      cl_2 = create(:commercial_invoice_line, commercial_invoice: cl_1.commercial_invoice, quantity: 11)
      PieceSet.create!(shipment_line_id: sl_1.id, order_line_id: ol_1.id, commercial_invoice_line_id: cl_1.id, quantity: 10)
      PieceSet.create!(shipment_line_id: sl_2.id, order_line_id: ol_2.id, commercial_invoice_line_id: cl_2.id, quantity: 11)

      sl_1.reload
      ci = sl_1.shipment.commercial_invoices
      # need to to_a call below because of bug: https://github.com/rails/rails/issues/5554
      expect(ci.to_a.size).to eq(1)
      ci.first.invoice_number == "IN1"
    end
  end

  describe 'linkable attachments' do
    it 'has linkable attachments' do
      s = create(:shipment, reference: 'ordn')
      linkable = create(:linkable_attachment, model_field_uid: 'shp_ref', value: 'ordn')
      LinkedAttachment.create(linkable_attachment_id: linkable.id, attachable: s)
      s.reload
      expect(s.linkable_attachments.first).to eq(linkable)
    end
  end

  describe "available_products" do
    let(:imp) { create(:importer) }
    let(:shipment) { create(:shipment, importer: imp) }

    before do
      create(:product, importer: imp)
      create(:product)
    end

    it "limits available products to those sharing importers with the shipment and user's importer company" do
      user = create(:user, company: imp)
      products = shipment.available_products(user).all
      expect(products.size).to eq 1
    end

    it "limits available products to those sharing importers with the shipment and user's linked companies" do
      user = create(:user, company: create(:importer))
      user.company.linked_companies << imp
      products = shipment.available_products(user).all
      expect(products.size).to eq 1
    end
  end

  describe "can_edit_booking?" do
    it "calls through to order registry" do
      user = User.new
      shipment = described_class.new
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:can_edit_booking?).with(shipment, user).and_return true
      expect(shipment.can_edit_booking?(user)).to eq true
    end
  end

  describe "get_requested_equipment_pieces" do
    it "splits 2 value fields (normal case)" do
      shp = described_class.new
      shp.requested_equipment = " 5 ABCD\n   \n7 EFGH  "
      pieces = shp.requested_equipment_pieces
      expect(pieces).not_to be_nil
      expect(pieces.length).to eq(2)
      expect(pieces[0].length).to eq(2)
      expect(pieces[0][0]).to eq('5')
      expect(pieces[0][1]).to eq('ABCD')
      expect(pieces[1].length).to eq(2)
      expect(pieces[1][0]).to eq('7')
      expect(pieces[1][1]).to eq('EFGH')
    end

    it "handles nil value" do
      shp = described_class.new
      shp.requested_equipment = nil
      pieces = shp.requested_equipment_pieces
      expect(pieces).not_to be_nil
      expect(pieces.length).to eq(0)
    end

    it "handles blank value" do
      shp = described_class.new
      shp.requested_equipment = '    '
      pieces = shp.requested_equipment_pieces
      expect(pieces).not_to be_nil
      expect(pieces.length).to eq(0)
    end

    it "handles non-standard value" do
      shp = described_class.new
      shp.requested_equipment = "4 2 ABCD"
      expect { shp.requested_equipment_pieces }.to raise_error("Bad requested equipment field, expected each line to have number and type like \"3 40HC\", got 4 2 ABCD.")
    end
  end

  describe "normalized_booking_mode" do
    let(:s) { create(:shipment, booking_mode: "Ocean - FCL")}

    it "strips everything after the first whitespace" do
      expect(s.normalized_booking_mode).to eq "OCEAN"
    end

    it "returns nil if booking_mode blank" do
      s.update! booking_mode: nil
      expect(s.normalized_booking_mode).to be_nil
      s.update! booking_mode: ""
      expect(s.normalized_booking_mode).to be_nil
    end

    it "returns nil if booking_mode doesn't contain letters" do
      s.update! booking_mode: "$@#!"
      expect(s.normalized_booking_mode).to be_nil
    end
  end
end
