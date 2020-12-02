describe Api::V1::ShipmentsController do

  let! (:master_setup) do
    ms = stub_master_setup
    allow(ms).to receive(:shipment_enabled).and_return true
    allow(ms).to receive(:order_enabled).and_return true
    ms
  end

  let(:user) { create(:master_user, shipment_edit: true, shipment_view: true, order_view: true, product_view: true) }

  before do
    allow_api_access user
  end

  describe "index" do
    it "finds shipments" do
      create(:shipment, reference: '123')
      create(:shipment, reference: 'ABC')
      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['results'].collect {|r| r['shp_ref']}).to eq ['123', 'ABC']
    end

    it "limits fields returned" do
      s1 = create(:shipment, reference: '123', mode: 'Air', master_bill_of_lading: 'MBOL')
      get :index, fields: 'shp_ref,shp_mode', shipment_lines: true, booking_lines: true
      expect(response).to be_success
      j = JSON.parse(response.body)['results']
      j.first.delete 'permissions' # not testing permissions hash
      expect(j).to eq [{'id' => s1.id, 'shp_ref' => '123', 'shp_mode' => 'Air', 'lines' => [], 'booking_lines' => [], 'screen_settings' => {}}]
    end
  end

  describe "show" do
    it "renders shipment" do
      s = create(:shipment, reference: '123', mode: 'Air', importer_reference: 'DEF')
      get :show, id: s.id
      expect(response).to be_success
      j = JSON.parse response.body
      sj = j['shipment']
      expect(sj['shp_ref']).to eq '123'
      expect(sj['shp_mode']).to eq 'Air'
      expect(sj['shp_importer_reference']).to eq 'DEF'
    end

    it "appends custom_view to shipment if not nil" do
      allow(OpenChain::CustomHandler::CustomViewSelector).to receive(:shipment_view).and_return 'abc'
      s = create(:shipment)
      get :show, id: s.id
      j = JSON.parse response.body
      expect(j['shipment']['custom_view']).to eq 'abc'
    end

    it "renders permissions" do
      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return false
      allow_any_instance_of(Shipment).to receive(:can_view?).and_return true
      allow_any_instance_of(Shipment).to receive(:can_attach?).and_return true
      allow_any_instance_of(Shipment).to receive(:can_comment?).and_return false
      allow_any_instance_of(Shipment).to receive(:can_edit_booking?).and_return false
      s = create(:shipment)
      get :show, id: s.id
      j = JSON.parse response.body
      pj = j['shipment']['permissions']
      expect(pj['can_edit']).to eq false
      expect(pj['can_view']).to eq true
      expect(pj['can_attach']).to eq true
      expect(pj['can_comment']).to eq false
      expect(pj['can_edit_booking']).to eq false
    end

    it "renders without lines" do
      sl = create(:shipment_line)
      get :show, id: sl.shipment_id.to_s
      j = JSON.parse response.body
      expect(j['shipment']['lines']).to be_nil
      expect(j['shipment']['booking_lines']).to be_nil
      expect(j['shipment']['id']).to eq sl.shipment_id
    end

    it "renders summary section" do
      ol1 = create(:order_line)
      ol2 = create(:order_line, order: ol1.order)
      sl1 = create(:shipment_line, quantity: 1100, product: ol1.product)
      sl1.linked_order_line_id = ol1.id
      sl2 = create(:shipment_line, shipment: sl1.shipment, quantity: 25, product: ol2.product)
      sl2.linked_order_line_id = ol2.id
      bl1 = create(:booking_line, shipment: sl1.shipment, quantity: 600, product: ol1.product, order: ol1.order)
      bl2 = create(:booking_line, shipment: sl1.shipment, quantity: 50, order_line: ol1)
      [sl1, sl2, bl1, bl2].each {|s| s.update(updated_at: Time.zone.now)}

      get :show, id: sl1.shipment_id.to_s, summary: 'true'
      j = JSON.parse response.body
      expect(j['shipment']['id']).to eq sl1.shipment_id
      expected_summary = {
        'booked_line_count' => '2',
        'booked_piece_count' => '650',
        'booked_order_count' => '1',
        'booked_product_count' => '1',
        'line_count' => '2',
        'piece_count' => '1,125',
        'order_count' => '1',
        'product_count' => '2'
      }
      expect(j['shipment']['summary']).to eq expected_summary
    end

    it "converts numbers to numeric" do
      sl = create(:shipment_line, quantity: 10)
      get :show, id: sl.shipment_id, shipment_lines: true
      j = JSON.parse response.body
      sln = j['shipment']['lines'].first
      expect(sln['shpln_shipped_qty']).to eq 10
    end

    it "renders custom values" do
      cd = create(:custom_definition, module_type: 'Shipment', data_type: 'string')
      s = create(:shipment)
      s.update_custom_value! cd, 'myval'
      get :show, id: s.id
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['shipment']["*cf_#{cd.id}"]).to eq 'myval'
    end

    it "renders shipment lines" do
      sl = create(:shipment_line, line_number: 5, quantity: 10)
      get :show, id: sl.shipment_id, shipment_lines: true
      expect(response).to be_success
      j = JSON.parse response.body
      slj = j['shipment']['lines'].first
      expect(slj['id']).to eq sl.id
      expect(slj['shpln_line_number']).to eq 5
      expect(slj['shpln_shipped_qty']).to eq 10.0
    end

    it "renders booking lines" do
      sl = create(:booking_line, line_number: 5, quantity: 10)
      get :show, id: sl.shipment_id, booking_lines: true
      expect(response).to be_success
      j = JSON.parse response.body
      slj = j['shipment']['booking_lines'].first
      expect(slj['id']).to eq sl.id
      expect(slj['bkln_line_number']).to eq 5
      expect(slj['bkln_quantity']).to eq 10.0
    end

    it "renders optional order lines" do
      ol = create(:order_line, quantity: 20, currency: 'USD')
      ol.order.update(customer_order_number: 'C123', order_number: '123')
      sl = create(:shipment_line, quantity: 10, product: ol.product)
      sl.linked_order_line_id = ol.id
      sl.save!
      get :show, id: sl.shipment_id, shipment_lines: true, include: 'order_lines'
      expect(response).to be_success
      j = JSON.parse response.body
      slj = j['shipment']['lines'].first
      olj = slj['order_lines'].first
      expect(slj['id']).to eq sl.id
      expect(olj['ordln_currency']).to eq 'USD'
      expect(olj['allocated_quantity']).to eq '10.0'
      expect(olj['ord_ord_num']).to eq ol.order.order_number
      expect(olj['ord_cust_ord_no']).to eq ol.order.customer_order_number
    end

    it "renders shipment containers" do
      c = create(:container, entry: nil, shipment: create(:shipment),
                              container_number: 'CN1234')
      sl = create(:shipment_line, shipment: c.shipment, container: c)
      get :show, id: sl.shipment_id, shipment_lines: true, include: "containers"
      expect(response).to be_success
      j = JSON.parse response.body
      slc = j['shipment']['containers'].first
      expect(slc['con_container_number']).to eq 'CN1234'
      expect(j['shipment']['lines'][0]['shpln_container_uid']).to eq c.id
    end

    it "optionallies render carton sets" do
      cs = create(:carton_set, starting_carton: 1000)
      create(:shipment_line, shipment: cs.shipment, carton_set: cs)
      get :show, id: cs.shipment_id, shipment_lines: true, include: 'carton_sets'
      expect(response).to be_success
      j = JSON.parse response.body
      slc = j['shipment']['carton_sets'].first
      expect(slc['cs_starting_carton']).to eq 1000
      expect(j['shipment']['lines'][0]['shpln_carton_set_uid']).to eq cs.id
    end

    it "renders comments" do
      s = create(:shipment, reference: '123', mode: 'Air', importer_reference: 'DEF')
      s.comments.create! user: user, subject: "Subject", body: "Comment Body"
      get :show, id: s.id, include: "comments"

      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['shipment']['comments'].size).to eq 1
      expect(j['shipment']['comments'].first['subject']).to eq "Subject"
      expect(j['shipment']['comments'].first['body']).to eq "Comment Body"
    end

    it "renders importer-specific view settings" do
      s = create(:shipment, reference: "123", importer: create(:company, system_code: "ACME"))
      KeyJsonItem.shipment_settings("ACME").first_or_create!(json_data: {"percentage_field" => "by product"}.to_json)
      get :show, id: s.id

      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['shipment']['screen_settings']).to eq({"percentage_field" => "by product"})
    end
  end

  describe "request booking" do
    let(:shipment) { instance_double("shipment") }

    it "errors if user cannot request booking" do
      expect(Shipment).to receive(:find).with('1').and_return shipment
      expect(shipment).to receive(:can_request_booking?).with(user).and_return false
      expect(shipment).not_to receive(:request_booking!)
      expect(shipment).not_to receive(:async_request_booking!)
      post :request_booking, id: '1'
      expect(response.status).to eq 403
    end

    it "requests booking" do
      expect(Shipment).to receive(:find).with('1').and_return shipment
      expect(shipment).to receive(:can_request_booking?).with(user).and_return true
      expect(shipment).to receive(:async_request_booking!).with(user)
      post :request_booking, id: '1'
      expect(response).to be_success
    end
  end

  describe "approve booking" do
    let(:shipment) { instance_double('shipment') }

    it "errors if user cannot approve booking" do
      expect(Shipment).to receive(:find).with('1').and_return shipment
      expect(shipment).to receive(:can_approve_booking?).with(user).and_return false
      expect(shipment).not_to receive(:approve_booking!)
      expect(shipment).not_to receive(:async_approve_booking!)
      post :approve_booking, id: '1'
      expect(response.status).to eq 403
    end

    it "approves booking" do
      expect(Shipment).to receive(:find).with('1').and_return shipment
      expect(shipment).to receive(:can_approve_booking?).with(user).and_return true
      expect(shipment).to receive(:async_approve_booking!).with(user)
      post :approve_booking, id: '1'
      expect(response).to be_success
    end
  end

  describe "confirm booking" do
    let(:shipment) { instance_double("shipment") }

    it "errors if user cannot confirm booking" do
      expect(Shipment).to receive(:find).with('1').and_return shipment
      expect(shipment).to receive(:can_confirm_booking?).with(user).and_return false
      expect(shipment).not_to receive(:confirm_booking!)
      expect(shipment).not_to receive(:async_confirm_booking!)
      post :confirm_booking, id: '1'
      expect(response.status).to eq 403
    end

    it "confirms booking" do
      expect(Shipment).to receive(:find).with('1').and_return shipment
      expect(shipment).to receive(:can_confirm_booking?).with(user).and_return true
      expect(shipment).to receive(:async_confirm_booking!).with(user)
      post :confirm_booking, id: '1'
      expect(response).to be_success
    end
  end

  describe "revise booking" do
    let(:shipment) { instance_double("shipment") }

    it "calls async_revise_booking" do
      expect(Shipment).to receive(:find).with('1').and_return shipment
      expect(shipment).to receive(:can_revise_booking?).with(user).and_return true
      expect(shipment).to receive(:async_revise_booking!).with(user)
      post :revise_booking, id: 1
      expect(response).to be_success
    end

    it "fails if user cannot approve booking" do
      expect(Shipment).to receive(:find).with('1').and_return shipment
      expect(shipment).to receive(:can_revise_booking?).with(user).and_return false
      expect(shipment).not_to receive(:revise_booking!)
      expect(shipment).not_to receive(:async_revise_booking!)
      post :revise_booking, id: '1'
      expect(response.status).to eq 403
    end
  end

  describe "send_shipment_instructions" do
    let :shipment do
      s = instance_double('shipment')
      allow(Shipment).to receive(:find).with('1').and_return s
      s
    end

    it "calls async_send_shipment_instructions" do
      expect(shipment).to receive(:can_send_shipment_instructions?).with(user).and_return true
      expect(shipment).to receive(:async_send_shipment_instructions!).with(user)
      post :send_shipment_instructions, id: 1
      expect(response).to be_success
    end

    it "fails if user cannot send" do
      expect(shipment).to receive(:can_send_shipment_instructions?).with(user).and_return false
      expect(shipment).not_to receive(:async_send_shipment_instructions!)
      post :send_shipment_instructions, id: 1
      expect(response).not_to be_success
    end
  end

  describe "cancel" do
    let(:shipment) { instance_double("shipment") }

    it "calls async_cancel_booking" do
      expect(Shipment).to receive(:find).with('1').and_return shipment
      expect(shipment).to receive(:can_cancel?).with(user).and_return true
      expect(shipment).to receive(:async_cancel_shipment!).with(user)
      post :cancel, id: 1
      expect(response).to be_success
    end

    it "fails if user cannot cancel" do
      expect(Shipment).to receive(:find).with('1').and_return shipment
      expect(shipment).to receive(:can_cancel?).with(user).and_return false
      expect(shipment).not_to receive(:async_cancel_shipment!)
      expect(shipment).not_to receive(:cancel_shipment!)
      post :cancel, id: 1
      expect(response.status).to eq 403
    end
  end

  describe "uncancel" do
    let(:shipment) { instance_double('shipment') }

    it "calls async_uncancel_booking" do
      expect(Shipment).to receive(:find).with('1').and_return shipment
      expect(shipment).to receive(:can_uncancel?).with(user).and_return true
      expect(shipment).to receive(:async_uncancel_shipment!).with(user)
      post :uncancel, id: 1
      expect(response).to be_success
    end

    it "fails if user cannot uncancel" do
      expect(Shipment).to receive(:find).with('1').and_return shipment
      expect(shipment).to receive(:can_uncancel?).with(user).and_return false
      expect(shipment).not_to receive(:async_uncancel_shipment!)
      expect(shipment).not_to receive(:uncancel_shipment!)
      post :uncancel, id: 1
      expect(response.status).to eq 403
    end
  end

  describe "process_tradecard_pack_manifest" do
    let(:shipment) { create(:shipment, reference: "ref num") }
    let!(:att) { create(:attachment, attachable: shipment, attached_file_name: "attached.txt") }

    it "fails if user cannot edit shipment" do
      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return false
      expect {post :process_tradecard_pack_manifest, {'attachment_ids' => [att.id], 'id' => shipment.id}}.not_to change(AttachmentProcessJob, :count)
      expect(response.status).to eq 403
    end

    it "fails if attachment is not attached to this shipment" do
      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return true
      a2 = create(:attachment, attached_file_name: "not attached.txt")
      a3 = create(:attachment, attached_file_name: "also not attached.txt")
      expect {post :process_tradecard_pack_manifest, {'attachment_ids' => [a2.id, a3.id], 'id' => shipment.id}}.not_to change(AttachmentProcessJob, :count)
      expect(response.status).to eq 400
      # rubocop:disable Layout/LineLength
      expect(JSON.parse(response.body)['errors']).to eq ['Processing cancelled. The following attachments are not linked to the shipment: not attached.txt, also not attached.txt']
      # rubocop:enable Layout/LineLength
    end

    it "fails if AttachmentProcessJob already exists and doesn't have an error" do
      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return true
      apj = shipment.attachment_process_jobs.create!(attachment_id: att.id, job_name: 'Tradecard Pack Manifest', user_id: user.id, start_at: 1.minute.ago)
      expect {post :process_tradecard_pack_manifest, {'attachment_ids' => [att.id], 'id' => shipment.id}}.not_to change(AttachmentProcessJob, :count)
      expect(response.status).to eq 400
      expect(JSON.parse(response.body)['errors']).to eq ['Processing cancelled. The following attachments have already been submitted: attached.txt']
      expect(apj.error_message).to be_nil
    end

    it "processes single job" do
      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return true
      expect_any_instance_of(AttachmentProcessJob).to receive(:process)
      expect {post :process_tradecard_pack_manifest, {'attachment_ids' => [att.id], 'id' => shipment.id}}.to change(AttachmentProcessJob, :count).from(0).to(1)
      expect(response).to be_success
      resp = JSON.parse(response.body)
      expect(resp['shipment']).not_to be_nil
      expect(resp['notices']).to be_nil
      aj = AttachmentProcessJob.first
      expect(aj.attachment).to eq att
      expect(aj.attachable).to eq shipment
      expect(aj.user).to eq user
      expect(aj.start_at).not_to be_nil
      expect(aj.job_name).to eq 'Tradecard Pack Manifest'
      expect(user.messages).to be_empty
    end

    it "processes multiple jobs", :disable_delayed_jobs do
      att_2 = create(:attachment, attachable: shipment, attached_file_name: "attached2.txt")

      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return true
      allow_any_instance_of(AttachmentProcessJob).to receive(:process)

      expect {post :process_tradecard_pack_manifest, {'attachment_ids' => [att.id, att_2.id], 'id' => shipment.id}}.to change(AttachmentProcessJob, :count).from(0).to(2)
      expect(response).to be_success
      resp = JSON.parse(response.body)
      expect(resp['shipment']).not_to be_nil
      expect(resp['notices']).to eq ["Worksheets have been submitted for processing. You'll receive a system message when they finish."]

      aj_1, aj_2 = AttachmentProcessJob.all
      expect(aj_1.attachment).to eq att
      expect(aj_1.attachable).to eq shipment
      expect(aj_1.user).to eq user
      expect(aj_1.start_at).not_to be_nil
      expect(aj_1.job_name).to eq 'Tradecard Pack Manifest'
      expect(aj_2.start_at).not_to be_nil
      expect(aj_2.attachment).to eq att_2
      msg = user.messages.first
      expect(msg.subject).to eq "Shipment ref num worksheet upload completed."
      expect(msg.body).to eq "All worksheets processed successfully."
    end

    it "assigns timestamp before being queued" do
      # DelayedJob prevents processing from taking place.
      # Ensures that submitted but unprocessed worksheets can't be resubmitted

      att_2 = create(:attachment, attachable: shipment, attached_file_name: "attached2.txt")

      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return true
      post :process_tradecard_pack_manifest, {'attachment_ids' => [att.id, att_2.id], 'id' => shipment.id}
      expect(AttachmentProcessJob.count).to eq 2
      expect(AttachmentProcessJob.pluck(:start_at).all?(&:present?)).to eq true
    end

    context "error reporting" do
      it "logs exception" do
        allow_any_instance_of(Shipment).to receive(:can_edit?).and_return true
        expect_any_instance_of(AttachmentProcessJob).to receive(:process).and_raise "Failed to process!"
        post :process_tradecard_pack_manifest, {'attachment_ids' => [att.id], 'id' => shipment.id}
        expect(JSON.parse(response.body)['errors']).to eq ['Failed to process!']
        expect(AttachmentProcessJob.first.error_message).to eq 'Failed to process!'
      end

      it "clears log on retry if it doesn't contain 'already submitted' error" do
        allow_any_instance_of(Shipment).to receive(:can_edit?).and_return true
        apj = shipment.attachment_process_jobs.create!(attachment_id: att.id,
                                                       error_message: "ERROR",
                                                       job_name: 'Tradecard Pack Manifest',
                                                       user_id: user.id,
                                                       start_at: 1.minute.ago)

        expect_any_instance_of(AttachmentProcessJob).to receive(:process)
        post :process_tradecard_pack_manifest, {'attachment_ids' => [att.id], 'id' => shipment.id}
        apj.reload
        expect(apj.error_message).to be_nil
      end

      it "notifies user of exceptions for multiple jobs", :disable_delayed_jobs do
        allow_any_instance_of(Shipment).to receive(:can_edit?).and_return true
        att_2 = create(:attachment, attachable: shipment, attached_file_name: "attached2.txt")
        bad_attachment = Attachment.first
        counter = 0

        allow_any_instance_of(AttachmentProcessJob).to receive(:process) do |apj|
          counter += 1
          raise "Failed to process!" if apj.attachment == bad_attachment
        end

        post :process_tradecard_pack_manifest, {'attachment_ids' => [att.id, att_2.id], 'id' => shipment.id}
        expect(counter).to eq 2 # The exception didn't prevent the second file from processing
        expect(user.messages.count).to eq 1
        msg = user.messages.first
        expect(msg.subject).to eq "Shipment ref num worksheet upload completed with errors."
        expect(msg.body).to eq "The following worksheets could not be processed *** #{bad_attachment.attached_file_name}: Failed to process!"
      end
    end
  end

  describe "create" do
    let(:shipment_hash) do
      {'shipment' => {'shp_ref' => 'MYREF',
                      'shp_mode' => 'Sea',
                      'shp_ven_syscode' => 'VC',
                      'shp_imp_syscode' => 'IMP'}}
    end

    let!(:ven) { create(:company, vendor: true, system_code: 'VC') }
    let!(:imp) { create(:company, importer: true, system_code: 'IMP') }
    let!(:product) { create(:product, unique_identifier: 'PUID1') }

    before do
      ven.products_as_vendor << product
    end

    it "saves" do
      expect {post :create, shipment_hash}.to change(Shipment, :count).from(0).to(1)
      expect(response).to be_success
      s = Shipment.first
      j = JSON.parse(response.body)['shipment']
      expect(j['id']).to eq s.id
      expect(s.reference).to eq 'MYREF'
      expect(j['shp_ref']).to eq 'MYREF'
      expect(s.vendor).to eq ven
      expect(s.importer).to eq imp
    end

    it "saves lines without containers" do
      shipment_hash['shipment']['lines'] = [
        {'shpln_line_number' => '1',
         'shpln_shipped_qty' => '104',
         'shpln_puid' => product.unique_identifier},
        {'shpln_line_number' => '2',
         'shpln_shipped_qty' => '10',
         'shpln_puid' => product.unique_identifier}
      ]
      expect {post :create, shipment_hash}.to change(Shipment, :count).from(0).to(1)
      expect(response).to be_success
      s = Shipment.first
      j = JSON.parse(response.body)['shipment']['lines']
      expect(j.size).to eq 2
      first_line = s.shipment_lines.first
      expect(j[0]['shpln_line_number']).to eq 1
      expect(j[0]['id']).to eq first_line.id
      expect(first_line.quantity).to eq 104
      expect(first_line.product).to eq product

      second_line = s.shipment_lines.last
      expect(j[1]['id']).to eq second_line.id
      expect(second_line.quantity).to eq 10
      expect(second_line.product).to eq product

    end

    it "saves containers" do
      shipment_hash['shipment']['containers'] = [
        {'con_container_number' => 'CNUM', 'con_container_size' => '40'},
        {'con_container_number' => 'CNUM2', 'con_container_size' => '20'}
      ]
      shipment_hash["include"] = "containers"
      expect {post :create, shipment_hash}.to change(Shipment, :count).from(0).to(1)
      expect(response).to be_success
      s = Shipment.first
      j = JSON.parse(response.body)['shipment']['containers']
      expect(j.size).to eq 2
      fc = s.containers.first
      sc = s.containers.last
      expect(j[0]['con_container_number']).to eq 'CNUM'
      expect(fc.container_number).to eq 'CNUM'
      expect(fc.container_size).to eq '40'

      expect(j[1]['con_container_number']).to eq 'CNUM2'
      expect(sc.container_number).to eq 'CNUM2'
      expect(sc.container_size).to eq '20'
    end

    it "saves carton_sets" do
      shipment_hash['shipment']['carton_sets'] = [
        {'cs_starting_carton' => 1, 'cs_length' => 10},
        {'cs_starting_carton' => 2, 'cs_carton_qty' => 50}
      ]
      shipment_hash['include'] = 'carton_sets'
      expect {post :create, shipment_hash}.to change(CartonSet, :count).from(0).to(2)
      expect(response).to be_success
      s = Shipment.first
      j = JSON.parse(response.body)['shipment']['carton_sets']
      expect(j.size).to eq 2
      fc = s.carton_sets.first
      sc = s.carton_sets.last
      expect(j[0]['cs_starting_carton']).to eq 1
      expect(j[1]['cs_carton_qty']).to eq 50
      expect(fc.length_cm).to eq 10
      expect(sc.starting_carton).to eq 2
    end

    it "does not save if user doesn't have permission" do
      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return false
      expect {post :create, shipment_hash}.not_to change(Shipment, :count)
      expect(response.status).to eq 403
    end

    context "order_lines" do
      let!(:o_line) { create(:order_line, product: product, quantity: 1000, order: create(:order, importer: imp)) }

      before do
        shipment_hash['shipment']['lines'] = [
          {'shpln_line_number' => '1',
           'shpln_shipped_qty' => '104',
           'shpln_puid' => product.unique_identifier,
           'linked_order_line_id' => o_line.id}]
      end

      it "links order line to shipment line" do
        expect {post :create, shipment_hash}.to change(Shipment, :count).from(0).to(1)
        expect(response).to be_success
        s = Shipment.first.shipment_lines.first
        expect(s.order_lines.to_a).to eq [o_line]
      end

      it "does not allow linking an order if the user cannot view the order" do
        allow_any_instance_of(OrderLine).to receive(:can_view?).and_return false
        expect {post :create, shipment_hash}.not_to change(Shipment, :count)
        expect(response.status).to eq 400
      end

      it "does not link order line if products are different" do
        o_line.update(product_id: create(:product).id)
        expect {post :create, shipment_hash}.not_to change(Shipment, :count)
        expect(response.status).to eq 400
      end
    end

    it "does not allow linking products that the user cannot view" do
      allow_any_instance_of(Product).to receive(:can_view?).and_return false
      shipment_hash['shipment']['lines'] = [
        {'shpln_line_number' => '1',
         'shpln_shipped_qty' => '104',
         'shpln_puid' => product.unique_identifier}]
      expect {post :create, shipment_hash}.not_to change(Shipment, :count)
      expect(response.status).to eq 400
    end
  end

  describe "update" do
    let(:imp) { create(:company, importer: true, system_code: 'IMP') }
    let(:shipment) { create(:shipment, importer: imp, mode: 'Air') }
    let!(:ven) { create(:company, vendor: true, system_code: 'VC') }
    let(:product) { create(:product, unique_identifier: 'PUID1') }

    let(:shipment_hash) do
      {
        'id' => shipment.id,
        'shp_ref' => 'MYREF',
        'shp_mode' => 'Sea',
        'shp_ven_syscode' => 'VC'
      }
    end

    before do
      ven.products_as_vendor << product
    end

    it "updates shipment" do
      put :update, id: shipment.id, shipment: shipment_hash
      expect(response).to be_success
      shipment.reload
      expect(shipment.mode).to eq 'Sea'
    end

    it "updates shipment line" do
      sl = create(:shipment_line, shipment: shipment, product: product, quantity: 100, line_number: 1)
      shipment_hash['lines'] = [{shpln_line_number: 1, shpln_shipped_qty: 24}]
      put :update, id: shipment.id, shipment: shipment_hash
      expect(response).to be_success
      sl.reload
      expect(sl.quantity).to eq 24
    end

    it "does not allow new lines if !can_add_remove_lines?" do
      allow_any_instance_of(Shipment).to receive(:can_add_remove_shipment_lines?).and_return false
      shipment_hash['lines'] = [
        { 'shpln_shipped_qty' => '104',
          'shpln_puid' => product.unique_identifier}
      ]
      expect {put :update, id: shipment.id, shipment: shipment_hash}.not_to change(ShipmentLine, :count)
      expect(response.status).to eq 400
    end

    it "does not allow lines to be deleted if !can_add_remove_lines?" do
      allow_any_instance_of(Shipment).to receive(:can_add_remove_shipment_lines?).and_return false
      sl = create(:shipment_line, shipment: shipment)
      shipment_hash['lines'] = [
        { 'id' => sl.id,
          '_destroy' => 'true'}
      ]
      expect {put :update, id: shipment.id, shipment: shipment_hash}.not_to change(ShipmentLine, :count)
      expect(response.status).to eq 400
    end

    it "updates container" do
      con = create(:container, entry: nil, shipment: shipment, container_number: 'CNOLD')
      shipment_hash['containers'] = [{'id' => con.id, 'con_container_number' => 'CNUM', 'con_container_size' => '40'}]
      put :update, id: shipment.id, shipment: shipment_hash
      expect(response).to be_success
      con.reload
      expect(con.container_number).to eq 'CNUM'
    end

    it "allows lines to be deleted" do
      sl = create(:shipment_line, shipment: shipment, product: product, quantity: 100, line_number: 1)
      shipment_hash['lines'] = [{shpln_line_number: 1, _destroy: true}]
      put :update, id: shipment.id, shipment: shipment_hash
      expect(response).to be_success
      expect(ShipmentLine.find_by(id: sl.id)).to be_nil
    end

    it "allows containers to be deleted" do
      con = create(:container, entry: nil, shipment: shipment, container_number: 'CNOLD')
      shipment_hash['containers'] = [{'id' => con.id, '_destroy' => true}]
      put :update, id: shipment.id, shipment: shipment_hash
      expect(response).to be_success
      expect(Container.find_by(id: con.id)).to be_nil
    end

    it "does not allow containers to be deleted if they have lines" do
      con = create(:container, entry: nil, shipment: shipment, container_number: 'CNOLD')
      create(:shipment_line, shipment: shipment, product: product, quantity: 100, line_number: 1, container: con)
      shipment_hash['containers'] = [{'id' => con.id, '_destroy' => true}]
      put :update, id: shipment.id, shipment: shipment_hash
      expect(response.status).to eq 400
      expect(Container.find_by(id: con.id)).not_to be_nil
    end

    it "allows containers to be deleted if associated shipment lines are going to be deleted too" do
      con = create(:container, entry: nil, shipment: shipment, container_number: 'CNOLD')
      sl = create(:shipment_line, shipment: shipment, product: product, quantity: 100, line_number: 1, container: con)
      shipment_hash['containers'] = [{'id' => con.id, '_destroy' => true}]
      shipment_hash['lines'] = [{'id' => sl.id, '_destroy' => true}]
      expect {put :update, id: shipment.id, shipment: shipment_hash}.to change(Container, :count).from(1).to(0)
      expect(response).to be_success
    end

    context "with booking lines" do

      let (:order_line) { create(:order_line, product: product, quantity: 1000, order: create(:order, importer: imp)) }

      let (:shipment_data) do
        {'id' => shipment.id,
         'booking_lines' => [
           'bkln_order_line_id' => order_line.id,
           'bkln_cbms' => 10,
           'bkln_carton_qty' => 1
         ]}
      end

      it "updates booking line" do
        sl = create(:booking_line, shipment: shipment, product: product, quantity: 100, line_number: 1)
        shipment_data['booking_lines'].first.merge!({'bkln_line_number' => 1, 'bkln_quantity' => 24})
        put :update, id: shipment.id, shipment: shipment_data
        expect(response).to be_success
        sl.reload
        expect(sl.quantity).to eq 24
      end

      it "creates booking lines" do
        put :update, id: shipment.id, shipment: shipment_data
        expect(response).to be_success
        shipment.reload
        expect(shipment.booking_lines.length).to eq 1
        line = shipment.booking_lines.first
        expect(line.order_line).to eq order_line
        expect(line.line_number).to eq 1
        expect(line.cbms).to eq 10
        expect(line.carton_qty).to eq 1
      end

      it "rejects orders belonging to a different importer" do
        order_line.order.update!(importer: create(:company, importer: true, system_code: 'ACME'))
        put :update, id: shipment.id, shipment: shipment_data
        expect(response.status).to eq 400
        expect(JSON.parse(response.body)['errors']).to eq ["Order has different importer from shipment"]
        shipment.reload
        expect(shipment.booking_lines.length).to eq 0
      end

      it "destroys a booking line" do
        line = shipment.booking_lines.create! product_id: product.id, quantity: 100, line_number: 1, order_line_id: order_line.id

        booking_line = shipment_data['booking_lines'].first
        booking_line.clear
        booking_line["_destroy"] = true
        booking_line["id"] = line.id

        put :update, id: shipment.id, shipment: shipment_data

        shipment.reload
        expect(shipment.booking_lines.length).to eq 0
      end
    end

  end

  describe "available_orders" do
    it "returns all orders available from shipment.available_orders" do
      imp = Company.new(name: 'IMPORTERNAME')
      vend = Company.new(name: 'VENDORNAME')
      o1 = Order.new(importer: imp, vendor: vend, order_date: Date.new(2014, 1, 1), mode: 'Air', order_number: 'ONUM', customer_order_number: 'CNUM')
      o1.id = 99
      o2 = Order.new(importer: imp, vendor: vend, order_date: Date.new(2014, 1, 1), mode: 'Air', order_number: 'ONUM2', customer_order_number: 'CNUM2')
      o2.id = 100
      ar_object = instance_double("ShipmentRelation")
      expect_any_instance_of(Shipment).to receive(:available_orders).with(user).and_return ar_object
      expect(ar_object).to receive(:order).with("customer_order_number").and_return ar_object
      expect(ar_object).to receive(:limit).with(25).and_return ar_object
      expect(ar_object).to receive(:each).and_yield(o1).and_yield(o2)
      allow_any_instance_of(Shipment).to receive(:can_view?).and_return true
      s = create(:shipment)
      get :available_orders, id: s.id
      expect(response).to be_success
      r = JSON.parse(response.body)['available_orders']
      expect(r.size).to eq 2
      r0 = r[0]
      expect(r0['id']).to eq 99
      expect(r0['ord_imp_name']).to eq 'IMPORTERNAME'
      expect(r0['ord_ord_num']).to eq 'ONUM'
      expect(r0['ord_cust_ord_no']).to eq 'CNUM'
      expect(r0['ord_mode']).to eq 'Air'
      expect(r0['ord_ord_date']).to eq '2014-01-01'
      expect(r0['ord_ven_name']).to eq 'VENDORNAME'
      expect(r[1]['id']).to eq 100
    end
  end

  describe "booked orders" do
    let(:shipment) { create(:shipment) }
    let!(:order1) { create :order, order_number: 'ONUM', customer_order_number: 'CNUM' }
    let!(:order2) { create :order, order_number: 'ONUM2', customer_order_number: 'CNUM2' }

    before do
      create :booking_line, shipment_id: shipment.id, order_id: order1.id
      create :booking_line, shipment_id: shipment.id, order_id: order2.id
    end

    it "returns orders that have been booked at the order_id level" do
      allow_any_instance_of(Shipment).to receive(:can_view?).and_return true
      get :booked_orders, id: shipment.id
      expect(response).to be_success
      result = JSON.parse(response.body)['booked_orders']
      lines_result = JSON.parse(response.body)['lines_available']
      expect(result.size).to eq 2
      expect(result[0]['id']).to eq order1.id
      expect(result[0]['ord_ord_num']).to eq order1.order_number
      expect(result[0]['ord_cust_ord_no']).to eq order1.customer_order_number
      expect(result[1]['id']).to eq order2.id
      expect(result[1]['ord_ord_num']).to eq order2.order_number
      expect(result[1]['ord_cust_ord_no']).to eq order2.customer_order_number
      expect(lines_result).to be false
    end

    it "lines_available is true if any lines are booked at the order_line_id level" do
      allow_any_instance_of(Shipment).to receive(:can_view?).and_return true
      create :booking_line, shipment_id: shipment.id, order_line_id: 99

      get :booked_orders, id: shipment.id
      expect(response).to be_success
      result = JSON.parse(response.body)['lines_available']
      expect(result).to be true
    end
  end

  describe "available_lines" do
    it "returns booking_lines with an order_line_id, in a format that mocks the linked order_line" do
      allow_any_instance_of(Shipment).to receive(:can_view?).and_return true
      shipment = create(:shipment)
      order = create :order, order_number: 'ONUM', customer_order_number: 'CNUM'
      prod1 = create :product
      oline1 = create :order_line, order_id: order.id, line_number: 1, sku: 'SKU', product_id: prod1.id
      bline1 = create :booking_line, shipment_id: shipment.id, order_line_id: oline1.id, line_number: 5

      get :available_lines, id: shipment.id
      expect(response).to be_success
      result = JSON.parse(response.body)['lines']
      expect(result[0]['id']).to eq oline1.id
      expect(result[0]['ordln_line_number']).to eq bline1.line_number
      expect(result[0]['ordln_puid']).to eq bline1.product_identifier
      expect(result[0]['ordln_sku']).to eq oline1.sku
      expect(result[0]['ordln_ordered_qty']).to eq bline1.quantity.to_s
      expect(result[0]['linked_line_number']).to eq oline1.line_number
      expect(result[0]['linked_cust_ord_no']).to eq order.customer_order_number
    end
  end

  describe "autocomplete_orders" do
    let(:shipment) { create(:shipment, importer: user.company, vendor: user.company) }
    let!(:order_1) { create(:order, importer: user.company, vendor: user.company, approval_status: 'Accepted', customer_order_number: "CNUM", order_number: "ORDERNUM") }

    before do
      create(:order, importer: user.company, vendor: user.company, approval_status: 'Accepted', customer_order_number: "CNO#")
    end

    it "autocompletes order numbers that are available to utilize" do
      # Just return all orders...all we care about is that Shipment.available_orders is used
      expect_any_instance_of(Shipment).to receive(:available_orders).with(user).and_return Order.all

      get :autocomplete_order, id: shipment.id, n: "CNUM"

      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r.size).to eq 1
      expect(r.first).to eq({"order_number" => order_1.customer_order_number, "id" => order_1.id})
    end

    it "autocompletes using order_number" do
      # Just return all orders...all we care about is that Shipment.available_orders is used
      expect_any_instance_of(Shipment).to receive(:available_orders).with(user).and_return Order.all

      get :autocomplete_order, id: shipment.id, n: "ORDER"
      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r.size).to eq 1
      # Note the use of order_number below, this also checks that the field that was matched on
      # is used as the title in the json response
      expect(r.first).to eq({"order_number" => order_1.order_number, "id" => order_1.id})
    end

    it "prefers customer order number if both order number and customer order number match" do
      # Just return all orders...all we care about is that Shipment.available_orders is used
      expect_any_instance_of(Shipment).to receive(:available_orders).with(user).and_return Order.all

      get :autocomplete_order, id: shipment.id, n: "NUM"
      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r.size).to eq 1
      # Note the use of order_number below, this also checks that the field that was matched on
      # is used as the title in the json response
      expect(r.first).to eq({"order_number" => order_1.customer_order_number, "id" => order_1.id})
    end

    it "returns blank if no autcomplete text is sent" do
       expect_any_instance_of(Shipment).not_to receive(:available_orders)

       get :autocomplete_order, id: shipment.id, n: " "

       expect(response).to be_success
       r = JSON.parse(response.body)
       expect(r.size).to eq 0
    end
  end

  describe "autocomplete_products" do
    let(:shipment) { create(:shipment, importer: user.company, vendor: user.company) }
    let!(:product1) { create(:product, importer: user.company, unique_identifier: "Prod1") }
    let(:product2) { create(:product, importer: user.company, unique_identifier: "Prod2") }

    it "autocompletes products that are available to utilize" do
      # Just return all orders...all we care about is that Shipment.available_orders is used
      expect_any_instance_of(Shipment).to receive(:available_products).with(user).and_return Product.all

      get :autocomplete_product, id: shipment.id, n: "Prod1"

      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r.size).to eq 1
      expect(r.first).to eq({"unique_identifier" => product1.unique_identifier, "id" => product1.id})
    end

    it "returns blank if no autcomplete text is sent" do
      expect_any_instance_of(Shipment).not_to receive(:available_products)

      get :autocomplete_product, id: shipment.id, n: " "

      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r.size).to eq 0
    end
  end

  describe "autocomplete_address" do
    let(:user) { create(:user, shipment_edit: true, shipment_view: true, order_view: true, product_view: true) }
    let(:importer) { create(:importer) }
    let(:shipment) { create(:shipment, importer: importer) }

    before do
      user.company.linked_companies << importer
      allow_any_instance_of(Shipment).to receive(:can_view?).with(user).and_return true
      allow_api_access user
    end

    it "returns address matching by name linked to the importer" do
      address = create(:full_address, name: "Company 1", company: importer, in_address_book: true)

      get :autocomplete_address, id: shipment.id, n: "ny"
      r = JSON.parse(response.body)
      expect(r.size).to eq 1
      expect(r.first).to eq({"name" => address.name, "full_address" => address.full_address, "id" => address.id})
    end

    it "does not return address linked to companies user can't view" do
      user.company.linked_companies.delete_all

      create(:full_address, name: "Company 1", company: importer, in_address_book: true)

      get :autocomplete_address, id: shipment.id, n: "ny"
      r = JSON.parse(response.body)
      expect(r.size).to eq 0
    end

    it "does not return address not saved to address book" do
      create(:full_address, name: "Company 1", company: importer, in_address_book: false)
      get :autocomplete_address, id: shipment.id, n: "ny"
      r = JSON.parse(response.body)
      expect(r.size).to eq 0
    end
  end

  describe "create_address" do
    let(:importer) { create(:importer) }
    let(:shipment) { create(:shipment, importer: importer) }

    it "creates an address associated with the importer" do
      c = create(:country)
      address = {name: "Address", line_1: "Line 1", city: "City", state: "ST", postal_code: "1234N", country_id: c.id, in_address_book: true}

      post :create_address, id: shipment.id, address: address
      expect(response).to be_success

      r = JSON.parse(response.body)["address"]
      expect(r).not_to be_nil
      expect(r['name']).to eq "Address"
      expect(r["line_1"]).to eq "Line 1"
      expect(r["city"]).to eq "City"
      expect(r["state"]).to eq "ST"
      expect(r["postal_code"]).to eq "1234N"
      expect(r["country_id"]).to eq c.id
      expect(r["in_address_book"]).to eq true
      expect(r["company_id"]).to eq importer.id
    end

    it "fails if user can't view" do
      expect_any_instance_of(Shipment).to receive(:can_view?).and_return false

      post :create_address, id: shipment.id, address: {}
      expect(response.status).to eq 404
    end
  end

  describe "shipment_lines" do
    let!(:line1) { create(:shipment_line) }
    let(:shipment) { line1.shipment }
    let!(:line2) { create(:shipment_line, shipment: shipment) }

    it "returns shell shipment with only shipment lines" do
      get :shipment_lines, id: shipment.id
      expect(response).to be_success

      r = JSON.parse(response.body)
      expect(r['shipment']['lines'].length).to eq 2
      expect(r['shipment']['lines'].first['id']).to eq line1.id
      expect(r['shipment']['lines'].first['shpln_line_number']).to eq line1.line_number
      expect(r['shipment']['lines'].first['order_lines']).to be_nil

      expect(r['shipment']['lines'].second['id']).to eq line2.id
      expect(r['shipment']['lines'].second['shpln_line_number']).to eq line2.line_number
    end

    it "returns order information if requested" do
      ol1 = create(:order_line)
      line1.update! product: ol1.product

      PieceSet.create! order_line: ol1, shipment_line: line1, quantity: 1100

      get :shipment_lines, id: shipment.id, include: "order_lines"
      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r['shipment']['lines'].length).to eq 2
      expect(r['shipment']['lines'].first['order_lines'].length).to eq 1
      ol = r['shipment']['lines'].first['order_lines'].first
      expect(ol['allocated_quantity']).to eq "1100.0"
      expect(ol['order_id']).to eq ol1.order_id
      expect(ol['ord_ord_num']).to eq ol1.order.order_number.to_s
      expect(ol['ordln_puid']).to eq ol1.product.unique_identifier

      expect(r['shipment']['lines'].second['order_lines'].length).to eq 0
    end

    it "fails if user can't access the shipment" do
      expect_any_instance_of(Shipment).to receive(:can_view?).and_return false
      get :shipment_lines, id: shipment.id, include: "order_lines"
      expect(response.status).to eq 404
    end
  end

  describe "booking_lines" do
    let!(:line1) { create(:booking_line) }
    let(:shipment) { line1.shipment }
    let!(:line2) { create(:booking_line, shipment: shipment) }

    it "returns shell shipment with only shipment lines" do
      get :booking_lines, id: shipment.id
      expect(response).to be_success

      r = JSON.parse(response.body)

      expect(r['shipment']['booking_lines'].length).to eq 2
      expect(r['shipment']['booking_lines'].first['id']).to eq line1.id
      expect(r['shipment']['booking_lines'].first['bkln_line_number']).to eq line1.line_number
      expect(r['shipment']['booking_lines'].first['order_lines']).to be_nil

      expect(r['shipment']['booking_lines'].second['id']).to eq line2.id
      expect(r['shipment']['booking_lines'].second['bkln_line_number']).to eq line2.line_number
    end

    it "fails if user can't access the shipment" do
      expect_any_instance_of(Shipment).to receive(:can_view?).and_return false
      get :booking_lines, id: shipment.id
      expect(response.status).to eq 404
    end
  end

  context 'order booking' do
    let :importer do
      create(:company, importer: true)
    end
    let :vendor do
      create(:company, vendor: true)
    end
    let :shipment do
      create(:shipment, importer: importer, vendor: vendor, ship_from: order.ship_from)
    end
    let :order do
      create(:order, importer: importer, vendor: vendor, ship_from: create(:address, company: vendor))
    end
    let :product do
      create(:product)
    end
    let :order_line do
      create(:order_line, order: order, quantity: 100, variant: create(:variant, product: product), product: product)
    end

    describe "#create_booking_from_order" do
      before do
        allow_any_instance_of(Order).to receive(:can_book?).and_return true
      end

      it 'creates booking' do
        expect(OpenChain::Registries::OrderBookingRegistry).to receive(:book_from_order_hook) do |h, _order, _lines|
          h[:shp_master_bill_of_lading] = "mbol"
        end

        expect(Shipment).to receive(:generate_reference).and_return '12345678'

        expect {post :create_booking_from_order, order_id: order_line.order_id.to_s}.to change(Shipment, :count).from(0).to(1)

        expect(response).to be_success
        s = Shipment.first
        expect(s.reference).to eq '12345678'
        expect(s.importer).to eq importer
        expect(s.vendor).to eq vendor
        expect(s.booking_lines.count).to eq 1
        expect(s.master_bill_of_lading).to eq 'mbol' # proves callback was run
        bl = s.booking_lines.first
        expect(bl.order_line).to eq order_line
        expect(bl.quantity).to eq 100
      end

      it 'fails if user cannot edit shipment' do
        expect_any_instance_of(Shipment).to receive(:can_edit?).and_return false
        allow(Shipment).to receive(:generate_reference).and_return '12345678'

        expect {post :create_booking_from_order, order_id: order_line.order_id.to_s}.not_to change(Shipment, :count)

        expect(response).not_to be_success
      end

      it 'fails if user cannot view order' do
        expect_any_instance_of(Order).to receive(:can_view?).and_return false
        allow(Shipment).to receive(:generate_reference).and_return '12345678'

        expect {post :create_booking_from_order, order_id: order_line.order_id.to_s}.not_to change(Shipment, :count)

        expect(response).not_to be_success
      end

      it 'fails if user cannot book order' do
        expect_any_instance_of(Order).to receive(:can_book?).and_return false
        allow(Shipment).to receive(:generate_reference).and_return '12345678'

        expect {post :create_booking_from_order, order_id: order_line.order_id.to_s}.not_to change(Shipment, :count)

        expect(response).not_to be_success
      end
    end

    describe '#book_order' do
      before do
        allow_any_instance_of(Order).to receive(:can_book?).and_return true
      end

      it 'adds order to booking' do
        expect(OpenChain::Registries::OrderBookingRegistry).to receive(:book_from_order_hook) do |h, _order, _lines|
          h[:shp_master_bill_of_lading] = "mbol"
        end
        s = shipment
        ol = order_line

        expect {put :book_order, id: s.id.to_s, order_id: order_line.order_id.to_s}.to change(BookingLine, :count).from(0).to(1)

        expect(response).to be_success
        s.reload
        expect(s.master_bill_of_lading).to eq 'mbol' # proves callback was run
        expect(s.booking_lines.count).to eq 1
        bl = s.booking_lines.first
        expect(bl.order_line).to eq ol
        expect(bl.quantity).to eq 100
        expect(bl.variant).to eq ol.variant
      end

      it 'fails if user cannot book order' do
        expect_any_instance_of(Order).to receive(:can_book?).and_return false

        expect {put :book_order, id: shipment.id.to_s, order_id: order_line.order_id.to_s}.not_to change(BookingLine, :count)

        expect(response).not_to be_success
      end

      it 'fails if order ship from is different than shipment ship from' do
        order.update(ship_from_id: create(:address, company: vendor))

        expect {put :book_order, id: shipment.id.to_s, order_id: order_line.order_id.to_s}.not_to change(BookingLine, :count)

        expect(response).not_to be_success
      end

      it 'fails if user cannot view order' do
        expect_any_instance_of(Order).to receive(:can_view?).and_return false

        expect {put :book_order, id: shipment.id.to_s, order_id: order_line.order_id.to_s}.not_to change(BookingLine, :count)

        expect(response).not_to be_success
      end

      it 'fails if user cannot edit shipment' do
        expect_any_instance_of(Shipment).to receive(:can_edit?).and_return false

        expect {put :book_order, id: shipment.id.to_s, order_id: order_line.order_id.to_s}.not_to change(BookingLine, :count)

        expect(response).not_to be_success
      end

      it 'fails if shipment has different importer as order' do
        order_line.order.update(importer_id: create(:company, importer: true).id)

        expect {put :book_order, id: shipment.id.to_s, order_id: order_line.order_id.to_s}.not_to change(BookingLine, :count)

        expect(response).not_to be_success
        expect(response.body).to match(/importer must/)
      end

      it 'fails if shipment has different vendor than order' do
        order_line.order.update(vendor_id: create(:company, vendor: true).id)

        expect {put :book_order, id: shipment.id.to_s, order_id: order_line.order_id.to_s}.not_to change(BookingLine, :count)

        expect(response).not_to be_success
        expect(response.body).to match(/vendor must/)
      end
    end
  end

  describe "open_bookings" do
    let (:vendor) { create(:vendor) }
    let (:importer) { create(:importer) }
    let! (:shipment) { create(:shipment, vendor: vendor, importer: importer) }

    context "with order_id parameter" do
      let! (:order) { create(:order, importer: importer, vendor: vendor) }

      it "returns bookings user can see where the importer and vendor match the given order's ids" do
        expect(OpenChain::Registries::OrderBookingRegistry).to receive(:can_book_order_to_shipment?).with(order, shipment).and_return "yes"
        get "open_bookings", order_id: order.id

        expect(response).to be_success
        json = JSON.parse(response.body)
        expect(json["results"].length).to eq 1
        expect(json["results"].first["id"]).to eq shipment.id
        expect(json["results"].first["permissions"]["can_book_order_to_shipment"]).to eq "yes"
      end

      it "does not return results if importer is different than order" do
        shipment.update! importer_id: create(:importer).id

        get "open_bookings", order_id: order.id
        expect(JSON.parse(response.body)["results"].length).to eq 0
      end

      it "does not return results if vendor is different than order" do
        shipment.update! vendor_id: create(:vendor).id

        get "open_bookings", order_id: order.id
        expect(JSON.parse(response.body)["results"].length).to eq 0
      end
    end

    it "limits bookings to linked importer accounts if user is not a vendor or an importer" do
      user.company = create(:master_company)
      user.company.linked_companies << importer
      user.save!

      get "open_bookings"

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["results"].length).to eq 1
      expect(json["results"].first["id"]).to eq shipment.id
    end

    it "limits bookings by vendor id if user is a vendor" do
      user.company.vendor = true
      user.company.save!

      shipment.update! vendor_id: create(:vendor).id

      get "open_bookings"
      expect(JSON.parse(response.body)["results"].length).to eq 0
    end

    it "limits bookings by importer id if user is an importer" do
      user.company.importer = true
      user.company.save!

      shipment.update! importer_id: create(:vendor).id

      get "open_bookings"
      expect(JSON.parse(response.body)["results"].length).to eq 0
    end

    it "limits fields returned" do
      user.company = create(:master_company)
      user.company.linked_companies << importer
      user.save!
      get "open_bookings", fields: "shp_ref"

      hash = JSON.parse(response.body)["results"].first
      # Rip out permissions, we want to make sure the other shipment fields were limited by the fields parameter
      hash.delete 'permissions'
      expect(hash).to eq({"id" => shipment.id, "shp_ref" => shipment.reference, "screen_settings" => {}})
    end

    it "uses order booking registry to add query restrictions to open bookings" do
      # Make sure it's setup with a scenario where a shipment should be found
      user.company = create(:master_company)
      user.company.linked_companies << importer
      user.save!

      hook_user = nil
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:open_bookings_hook) do |user, s, _order|
        hook_user = user
        s.where("shipments.reference != ?", shipment.reference)
      end

      get "open_bookings", fields: "shp_ref"
      expect(hook_user).to eq user
      expect(JSON.parse(response.body)["results"].length).to eq 0
    end
  end
end
