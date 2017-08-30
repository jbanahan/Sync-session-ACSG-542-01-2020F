require 'spec_helper'

describe Api::V1::ShipmentsController do
  before(:each) do
    MasterSetup.get.update_attributes(shipment_enabled:true)
    @u = Factory(:master_user,shipment_edit:true,shipment_view:true,order_view:true,product_view:true)
    allow_api_access @u
  end

  describe "index" do
    it "should find shipments" do
      Factory(:shipment,reference:'123')
      Factory(:shipment,reference:'ABC')
      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['results'].collect{|r| r['shp_ref']}).to eq ['123','ABC']
    end

    it "should limit fields returned" do
      s1 = Factory(:shipment,reference:'123',mode:'Air',master_bill_of_lading:'MBOL')
      get :index, fields:'shp_ref,shp_mode', shipment_lines:true, booking_lines:true
      expect(response).to be_success
      j = JSON.parse(response.body)['results']
      j.first.delete 'permissions' #not testing permissions hash
      expect(j).to eq [{'id'=>s1.id,'shp_ref'=>'123','shp_mode'=>'Air','lines'=>[],'booking_lines'=>[]}]
    end
  end

  describe "show" do
    it "should render shipment" do
      s = Factory(:shipment,reference:'123',mode:'Air',importer_reference:'DEF')
      get :show, id: s.id
      expect(response).to be_success
      j = JSON.parse response.body
      sj = j['shipment']
      expect(sj['shp_ref']).to eq '123'
      expect(sj['shp_mode']).to eq 'Air'
      expect(sj['shp_importer_reference']).to eq 'DEF'
    end
    it "should append custom_view to shipment if not nil" do
      allow(OpenChain::CustomHandler::CustomViewSelector).to receive(:shipment_view).and_return 'abc'
      s = Factory(:shipment)
      get :show, id: s.id
      j = JSON.parse response.body
      expect(j['shipment']['custom_view']).to eq 'abc'
    end
    it "should render permissions" do
      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return false
      allow_any_instance_of(Shipment).to receive(:can_view?).and_return true
      allow_any_instance_of(Shipment).to receive(:can_attach?).and_return true
      allow_any_instance_of(Shipment).to receive(:can_comment?).and_return false
      s = Factory(:shipment)
      get :show, id: s.id
      j = JSON.parse response.body
      pj = j['shipment']['permissions']
      expect(pj['can_edit']).to eq false
      expect(pj['can_view']).to eq true
      expect(pj['can_attach']).to eq true
      expect(pj['can_comment']).to eq false
      expect(pj['can_edit_booking']).to eq false
    end

    it "should render without lines" do
      sl = Factory(:shipment_line)
      get :show, id: sl.shipment_id.to_s
      j = JSON.parse response.body
      expect(j['shipment']['lines']).to be_nil
      expect(j['shipment']['booking_lines']).to be_nil
      expect(j['shipment']['id']).to eq sl.shipment_id
    end

    it "should render summary section" do
      ol1 = Factory(:order_line)
      ol2 = Factory(:order_line,order: ol1.order)
      sl1 = Factory(:shipment_line,quantity:1100,product:ol1.product)
      sl1.linked_order_line_id = ol1.id
      sl2 = Factory(:shipment_line,shipment:sl1.shipment,quantity:25,product:ol2.product)
      sl2.linked_order_line_id = ol2.id
      bl1 = Factory(:booking_line,shipment:sl1.shipment,quantity:600,product:ol1.product,order:ol1.order)
      bl2 = Factory(:booking_line,shipment:sl1.shipment,quantity:50,order_line:ol1)
      [sl1,sl2,bl1,bl2].each {|s| s.update_attributes(updated_at:Time.now)}

      get :show, id: sl1.shipment_id.to_s, summary: 'true'
      j = JSON.parse response.body
      expect(j['shipment']['id']).to eq sl1.shipment_id
      expected_summary = {
          'booked_line_count'=>'2',
          'booked_piece_count'=>'650',
          'booked_order_count'=>'1',
          'booked_product_count'=>'1',
          'line_count'=>'2',
          'piece_count'=>'1,125',
          'order_count'=>'1',
          'product_count'=>'2'
      }
      expect(j['shipment']['summary']).to eq expected_summary
    end

    it "should convert numbers to numeric" do
      sl = Factory(:shipment_line,quantity:10)
      get :show, id: sl.shipment_id, shipment_lines: true
      j = JSON.parse response.body
      sln = j['shipment']['lines'].first
      expect(sln['shpln_shipped_qty']).to eq 10
    end
    it "should render custom values" do
      cd = Factory(:custom_definition,module_type:'Shipment',data_type:'string')
      s = Factory(:shipment)
      s.update_custom_value! cd, 'myval'
      get :show, id: s.id
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['shipment']["*cf_#{cd.id}"]).to eq 'myval'
    end
    it "should render shipment lines" do
      sl = Factory(:shipment_line,line_number:5,quantity:10)
      get :show, id: sl.shipment_id, shipment_lines: true
      expect(response).to be_success
      j = JSON.parse response.body
      slj = j['shipment']['lines'].first
      expect(slj['id']).to eq sl.id
      expect(slj['shpln_line_number']).to eq 5
      expect(slj['shpln_shipped_qty']).to eq 10.0
    end
    it "should render booking lines" do
      sl = Factory(:booking_line,line_number:5,quantity:10)
      get :show, id: sl.shipment_id, booking_lines: true
      expect(response).to be_success
      j = JSON.parse response.body
      slj = j['shipment']['booking_lines'].first
      expect(slj['id']).to eq sl.id
      expect(slj['bkln_line_number']).to eq 5
      expect(slj['bkln_quantity']).to eq 10.0
    end
    it "should render optional order lines" do
      ol = Factory(:order_line,quantity:20,currency:'USD')
      ol.order.update_attributes(customer_order_number:'C123',order_number:'123')
      sl = Factory(:shipment_line,quantity:10,product:ol.product)
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
    it "should render shipment containers" do
      c = Factory(:container,entry:nil,shipment:Factory(:shipment),
        container_number:'CN1234')
      sl = Factory(:shipment_line,shipment:c.shipment,container:c)
      get :show, id: sl.shipment_id, shipment_lines: true
      expect(response).to be_success
      j = JSON.parse response.body
      slc = j['shipment']['containers'].first
      expect(slc['con_container_number']).to eq 'CN1234'
      expect(j['shipment']['lines'][0]['shpln_container_uid']).to eq c.id
    end
    it "should optionally render carton sets" do
      cs = Factory(:carton_set,starting_carton:1000)
      Factory(:shipment_line,shipment:cs.shipment,carton_set:cs)
      get :show, id: cs.shipment_id, shipment_lines: true, include: 'carton_sets'
      expect(response).to be_success
      j = JSON.parse response.body
      slc = j['shipment']['carton_sets'].first
      expect(slc['cs_starting_carton']).to eq 1000
      expect(j['shipment']['lines'][0]['shpln_carton_set_uid']).to eq cs.id
    end
    it "should render comments" do
      s = Factory(:shipment,reference:'123',mode:'Air',importer_reference:'DEF')
      s.comments.create! user: @u, subject: "Subject", body: "Comment Body"
      get :show, id: s.id, include: "comments"

      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['shipment']['comments'].size).to eq 1
      expect(j['shipment']['comments'].first['subject']).to eq "Subject"
      expect(j['shipment']['comments'].first['body']).to eq "Comment Body"
    end
  end
  describe "request booking" do
    before :each do
      @s = double("shipment")
      expect(Shipment).to receive(:find).with('1').and_return @s
    end
    it "should error if user cannot request booking" do
      expect(@s).to receive(:can_request_booking?).with(@u).and_return false
      expect(@s).not_to receive(:request_booking!)
      expect(@s).not_to receive(:async_request_booking!)
      post :request_booking, id: '1'
      expect(response.status).to eq 403
    end
    it "should request booking" do
      expect(@s).to receive(:can_request_booking?).with(@u).and_return true
      expect(@s).to receive(:async_request_booking!).with(@u)
      post :request_booking, id: '1'
      expect(response).to be_success
    end
  end
  describe "approve booking" do
    before :each do
      @s = double("shipment")
      expect(Shipment).to receive(:find).with('1').and_return @s
    end
    it "should error if user cannot approve booking" do
      expect(@s).to receive(:can_approve_booking?).with(@u).and_return false
      expect(@s).not_to receive(:approve_booking!)
      expect(@s).not_to receive(:async_approve_booking!)
      post :approve_booking, id: '1'
      expect(response.status).to eq 403
    end
    it "should approve booking" do
      expect(@s).to receive(:can_approve_booking?).with(@u).and_return true
      expect(@s).to receive(:async_approve_booking!).with(@u)
      post :approve_booking, id: '1'
      expect(response).to be_success
    end
  end
  describe "confirm booking" do
    before :each do
      @s = double("shipment")
      expect(Shipment).to receive(:find).with('1').and_return @s
    end
    it "should error if user cannot confirm booking" do
      expect(@s).to receive(:can_confirm_booking?).with(@u).and_return false
      expect(@s).not_to receive(:confirm_booking!)
      expect(@s).not_to receive(:async_confirm_booking!)
      post :confirm_booking, id: '1'
      expect(response.status).to eq 403
    end
    it "should confirm booking" do
      expect(@s).to receive(:can_confirm_booking?).with(@u).and_return true
      expect(@s).to receive(:async_confirm_booking!).with(@u)
      post :confirm_booking, id: '1'
      expect(response).to be_success
    end
  end
  describe "revise booking" do
    before :each do
      @s = double("shipment")
      expect(Shipment).to receive(:find).with('1').and_return @s
    end
    it "should call async_revise_booking" do
      expect(@s).to receive(:can_revise_booking?).with(@u).and_return true
      expect(@s).to receive(:async_revise_booking!).with(@u)
      post :revise_booking, id: 1
      expect(response).to be_success
    end
    it "should fail if user cannot approve booking" do
      expect(@s).to receive(:can_revise_booking?).with(@u).and_return false
      expect(@s).not_to receive(:revise_booking!)
      expect(@s).not_to receive(:async_revise_booking!)
      post :revise_booking, id: '1'
      expect(response.status).to eq 403
    end
  end
  describe "send_shipment_instructions" do
    let :shipment do
      s = double('shipment')
      allow(Shipment).to receive(:find).with('1').and_return s
      s
    end
    it "should call async_send_shipment_instructions" do
      expect(shipment).to receive(:can_send_shipment_instructions?).with(@u).and_return true
      expect(shipment).to receive(:async_send_shipment_instructions!).with(@u)
      post :send_shipment_instructions, id: 1
      expect(response).to be_success
    end
    it "should fail if user cannot send" do
      expect(shipment).to receive(:can_send_shipment_instructions?).with(@u).and_return false
      expect(shipment).to_not receive(:async_send_shipment_instructions!)
      post :send_shipment_instructions, id: 1
      expect(response).to_not be_success
    end
  end
  describe "cancel" do
    before :each do
      @s = double("shipment")
      expect(Shipment).to receive(:find).with('1').and_return @s
    end
    it "should call async_cancel_booking" do
      expect(@s).to receive(:can_cancel?).with(@u).and_return true
      expect(@s).to receive(:async_cancel_shipment!).with(@u)
      post :cancel, id: 1
      expect(response).to be_success
    end
    it "should fail if user cannot cancel" do
      expect(@s).to receive(:can_cancel?).with(@u).and_return false
      expect(@s).not_to receive(:async_cancel_shipment!)
      expect(@s).not_to receive(:cancel_shipment!)
      post :cancel, id: 1
      expect(response.status).to eq 403
    end
  end
  describe "uncancel" do
    before :each do
      @s = double("shipment")
      expect(Shipment).to receive(:find).with('1').and_return @s
    end
    it "should call async_uncancel_booking" do
      expect(@s).to receive(:can_uncancel?).with(@u).and_return true
      expect(@s).to receive(:async_uncancel_shipment!).with(@u)
      post :uncancel, id: 1
      expect(response).to be_success
    end
    it "should fail if user cannot uncancel" do
      expect(@s).to receive(:can_uncancel?).with(@u).and_return false
      expect(@s).not_to receive(:async_uncancel_shipment!)
      expect(@s).not_to receive(:uncancel_shipment!)
      post :uncancel, id: 1
      expect(response.status).to eq 403
    end
  end
  describe "process_tradecard_pack_manifest" do
    before :each do
      @s = Factory(:shipment)
      @att = Factory(:attachment,attachable:@s)
    end
    it "should fail if user cannot edit shipment" do
      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return false
      expect {post :process_tradecard_pack_manifest, {'attachment_id'=>@att.id,'id'=>@s.id}}.to_not change(AttachmentProcessJob,:count)
      expect(response.status).to eq 403
    end
    it "should fail if attachment is not attached to this shipment" do
      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return true
      a2 = Factory(:attachment)
      expect {post :process_tradecard_pack_manifest, {'attachment_id'=>a2.id,'id'=>@s.id}}.to_not change(AttachmentProcessJob,:count)
      expect(response.status).to eq 400
      expect(JSON.parse(response.body)['errors']).to eq ['Attachment not linked to Shipment.']
    end
    it "should fail if AttachmentProcessJob already exists" do
      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return true
      @s.attachment_process_jobs.create!(attachment_id:@att.id,job_name:'Tradecard Pack Manifest',user_id:@u.id,start_at:1.minute.ago)
      expect {post :process_tradecard_pack_manifest, {'attachment_id'=>@att.id,'id'=>@s.id}}.to_not change(AttachmentProcessJob,:count)
      expect(response.status).to eq 400
      expect(JSON.parse(response.body)['errors']).to eq ['This manifest has already been submitted for processing.']
    end
    it "should process job" do
      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return true
      expect_any_instance_of(AttachmentProcessJob).to receive(:process)
      expect {post :process_tradecard_pack_manifest, {'attachment_id'=>@att.id,'id'=>@s.id}}.to change(AttachmentProcessJob,:count).from(0).to(1)
      expect(response).to be_success
      expect(JSON.parse(response.body)['shipment']).to_not be_nil
      aj = AttachmentProcessJob.first
      expect(aj.attachment).to eq @att
      expect(aj.attachable).to eq @s
      expect(aj.user).to eq @u
      expect(aj.start_at).to_not be_nil
      expect(aj.job_name).to eq 'Tradecard Pack Manifest'
    end
  end
  describe "create" do
    before(:each) do
      @ven = Factory(:company,vendor:true,system_code:'VC')
      @imp = Factory(:company,importer:true,system_code:'IMP')
      @product = Factory(:product,unique_identifier:'PUID1')
      @ven.products_as_vendor << @product
      @s_hash = {'shipment'=>{'shp_ref'=>'MYREF',
        'shp_mode'=>'Sea',
        'shp_ven_syscode'=>'VC',
        'shp_imp_syscode'=>'IMP'
        }}
    end
    it "should save" do
      expect {post :create, @s_hash}.to change(Shipment,:count).from(0).to(1)
      expect(response).to be_success
      s = Shipment.first
      j = JSON.parse(response.body)['shipment']
      expect(j['id']).to eq s.id
      expect(s.reference).to eq 'MYREF'
      expect(j['shp_ref']).to eq 'MYREF'
      expect(s.vendor).to eq @ven
      expect(s.importer).to eq @imp
    end
    it "should save lines without containers" do
      @s_hash['shipment']['lines'] = [
        {'shpln_line_number'=>'1',
          'shpln_shipped_qty'=>'104',
          'shpln_puid'=>@product.unique_identifier
        },
        {'shpln_line_number'=>'2',
          'shpln_shipped_qty'=>'10',
          'shpln_puid'=>@product.unique_identifier
        }
      ]
      expect {post :create, @s_hash}.to change(Shipment,:count).from(0).to(1)
      expect(response).to be_success
      s = Shipment.first
      j = JSON.parse(response.body)['shipment']['lines']
      expect(j.size).to eq 2
      first_line = s.shipment_lines.first
      expect(j[0]['shpln_line_number']).to eq 1
      expect(j[0]['id']).to eq first_line.id
      expect(first_line.quantity).to eq 104
      expect(first_line.product).to eq @product

      second_line = s.shipment_lines.last
      expect(j[1]['id']).to eq second_line.id
      expect(second_line.quantity).to eq 10
      expect(second_line.product).to eq @product

    end
    it "should save containers" do
      @s_hash['shipment']['containers'] = [
        {'con_container_number'=>'CNUM','con_container_size'=>'40'},
        {'con_container_number'=>'CNUM2','con_container_size'=>'20'}
      ]
      expect {post :create, @s_hash}.to change(Shipment,:count).from(0).to(1)
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
    it "should save carton_sets" do
      @s_hash['shipment']['carton_sets'] = [
        {'cs_starting_carton'=>1,'cs_length'=>10},
        {'cs_starting_carton'=>2,'cs_carton_qty'=>50}
      ]
      @s_hash['include'] = 'carton_sets'
      expect {post :create, @s_hash}.to change(CartonSet,:count).from(0).to(2)
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
    it "should not save if user doesn't have permission" do
      allow_any_instance_of(Shipment).to receive(:can_edit?).and_return false
      expect {post :create, @s_hash}.to_not change(Shipment,:count)
      expect(response.status).to eq 403
    end
    context "order_lines" do
      before :each do
        @o_line = Factory(:order_line, product:@product, quantity:1000,order:Factory(:order,importer:@imp))
        @s_hash['shipment']['lines'] = [
          {'shpln_line_number'=>'1',
            'shpln_shipped_qty'=>'104',
            'shpln_puid'=>@product.unique_identifier,
            'linked_order_line_id'=>@o_line.id
          }]
      end
      it "should link order line to shipment line" do
        expect {post :create, @s_hash}.to change(Shipment,:count).from(0).to(1)
        expect(response).to be_success
        s = Shipment.first.shipment_lines.first
        expect(s.order_lines.to_a).to eq [@o_line]
      end
      it "should not allow linking an order if the user cannot view the order" do
        allow_any_instance_of(OrderLine).to receive(:can_view?).and_return false
        expect {post :create, @s_hash}.to_not change(Shipment,:count)
        expect(response.status).to eq 400
      end
      it "should not link order line if products are different" do
        @o_line.update_attributes(product_id:Factory(:product).id)
        expect {post :create, @s_hash}.to_not change(Shipment,:count)
        expect(response.status).to eq 400
      end
    end
    it "should not allow linking products that the user cannot view" do
      allow_any_instance_of(Product).to receive(:can_view?).and_return false
      @s_hash['shipment']['lines'] = [
        {'shpln_line_number'=>'1',
          'shpln_shipped_qty'=>'104',
          'shpln_puid'=>@product.unique_identifier,
        }]
      expect {post :create, @s_hash}.to_not change(Shipment,:count)
      expect(response.status).to eq 400
    end
  end
  describe "update" do
    before :each do
      @ven = Factory(:company,vendor:true,system_code:'VC')
      @imp = Factory(:company,importer:true,system_code:'IMP')
      @product = Factory(:product,unique_identifier:'PUID1')
      @ven.products_as_vendor << @product
      @shipment = Factory(:shipment,importer:@imp,mode:'Air')
      @s_hash = {
        'id'=>@shipment.id,
        'shp_ref'=>'MYREF',
        'shp_mode'=>'Sea',
        'shp_ven_syscode'=>'VC',
        }
    end

    it "should update shipment" do
      put :update, id: @shipment.id, shipment: @s_hash
      expect(response).to be_success
      @shipment.reload
      expect(@shipment.mode).to eq 'Sea'
    end

    it "should update shipment line" do
      sl = Factory(:shipment_line,shipment:@shipment,product:@product,quantity:100,line_number:1)
      @s_hash['lines'] = [{shpln_line_number:1,shpln_shipped_qty:24}]
      put :update, id: @shipment.id, shipment: @s_hash
      expect(response).to be_success
      sl.reload
      expect(sl.quantity).to eq 24
    end

    it "should update booking line" do
      sl = Factory(:booking_line,shipment:@shipment,product:@product,quantity:100,line_number:1)
      @s_hash['booking_lines'] = [{bkln_line_number:1,bkln_quantity:24}]
      put :update, id: @shipment.id, shipment: @s_hash
      expect(response).to be_success
      sl.reload
      expect(sl.quantity).to eq 24
    end

    it "should not allow new lines if !can_add_remove_lines?" do
      allow_any_instance_of(Shipment).to receive(:can_add_remove_shipment_lines?).and_return false
      @s_hash['lines'] = [
        { 'shpln_shipped_qty'=>'104',
          'shpln_puid'=>@product.unique_identifier
        }
      ]
      expect {put :update, id: @shipment.id, shipment: @s_hash}.to_not change(ShipmentLine,:count)
      expect(response.status).to eq 400
    end
    it "should not allow lines to be deleted if !can_add_remove_lines?" do
      allow_any_instance_of(Shipment).to receive(:can_add_remove_shipment_lines?).and_return false
      sl = Factory(:shipment_line,shipment:@shipment)
      @s_hash['lines'] = [
        { 'id'=>sl.id,
          '_destroy' => 'true'
        }
      ]
      expect {put :update, id: @shipment.id, shipment: @s_hash}.to_not change(ShipmentLine,:count)
      expect(response.status).to eq 400
    end
    it "should update container" do
      con = Factory(:container,entry:nil,shipment:@shipment,container_number:'CNOLD')
      @s_hash['containers'] = [{'id'=>con.id,'con_container_number'=>'CNUM','con_container_size'=>'40'}]
      put :update, id: @shipment.id, shipment: @s_hash
      expect(response).to be_success
      con.reload
      expect(con.container_number).to eq 'CNUM'
    end
    it "should allow lines to be deleted" do
      sl = Factory(:shipment_line,shipment:@shipment,product:@product,quantity:100,line_number:1)
      @s_hash['lines'] = [{shpln_line_number:1,_destroy:true}]
      put :update, id: @shipment.id, shipment: @s_hash
      expect(response).to be_success
      expect(ShipmentLine.find_by_id(sl.id)).to be_nil
    end
    it "should allow containers to be deleted" do
      con = Factory(:container,entry:nil,shipment:@shipment,container_number:'CNOLD')
      @s_hash['containers'] = [{'id'=>con.id,'_destroy'=>true}]
      put :update, id: @shipment.id, shipment: @s_hash
      expect(response).to be_success
      expect(Container.find_by_id(con.id)).to be_nil
    end
    it "should not allow containers to be deleted if they have lines" do
      con = Factory(:container,entry:nil,shipment:@shipment,container_number:'CNOLD')
      Factory(:shipment_line,shipment:@shipment,product:@product,quantity:100,line_number:1,container:con)
      @s_hash['containers'] = [{'id'=>con.id,'_destroy'=>true}]
      put :update, id: @shipment.id, shipment: @s_hash
      expect(response.status).to eq 400
      expect(Container.find_by_id(con.id)).to_not be_nil
    end
    it "should allow containers to be deleted if associated shipment lines are going to be deleted too" do
      con = Factory(:container,entry:nil,shipment:@shipment,container_number:'CNOLD')
      sl = Factory(:shipment_line,shipment:@shipment,product:@product,quantity:100,line_number:1,container:con)
      @s_hash['containers'] = [{'id'=>con.id,'_destroy'=>true}]
      @s_hash['lines'] = [{'id'=>sl.id,'_destroy'=>true}]
      expect{put :update, id: @shipment.id, shipment: @s_hash}.to change(Container,:count).from(1).to(0)
      expect(response).to be_success
    end

    context "with booking lines" do

      let (:order_line) { Factory(:order_line, product:@product, quantity:1000,order:Factory(:order,importer:@imp)) }
      let (:shipment_data) {
        {'id'=>@shipment.id,
         'booking_lines' => [
           'bkln_order_line_id' => order_line.id,
           'bkln_cbms' => 10,
           'bkln_carton_qty' => 1
         ]
        }
      }

      it "creates booking lines" do
        put :update, id: @shipment.id, shipment: shipment_data
        expect(response).to be_success
        @shipment.reload
        expect(@shipment.booking_lines.length).to eq 1
        line = @shipment.booking_lines.first
        expect(line.order_line).to eq order_line
        expect(line.line_number).to eq 1
        expect(line.cbms).to eq 10
        expect(line.carton_qty).to eq 1
      end
    end

  end
  describe "available_orders" do
    it "should return all orders available from shipment.available_orders" do
      imp = Company.new(name:'IMPORTERNAME')
      vend = Company.new(name:'VENDORNAME')
      o1 = Order.new(importer:imp,vendor:vend,order_date:Date.new(2014,1,1),mode:'Air',order_number:'ONUM',customer_order_number:'CNUM')
      o1.id = 99
      o2 = Order.new(importer:imp,vendor:vend,order_date:Date.new(2014,1,1),mode:'Air',order_number:'ONUM2',customer_order_number:'CNUM2')
      o2.id = 100
      ar_object = double("ShipmentRelation")
      expect_any_instance_of(Shipment).to receive(:available_orders).with(@u).and_return ar_object
      expect(ar_object).to receive(:order).with("customer_order_number").and_return ar_object
      expect(ar_object).to receive(:limit).with(25).and_return ar_object
      expect(ar_object).to receive(:each).and_yield(o1).and_yield(o2)
      allow_any_instance_of(Shipment).to receive(:can_view?).and_return true
      s = Factory(:shipment)
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
    before :each do
      allow_any_instance_of(Shipment).to receive(:can_view?).and_return true
      @shipment = Factory(:shipment)
      @o1 = Factory :order,order_number:'ONUM',customer_order_number:'CNUM'
      @o2 = Factory :order,order_number:'ONUM2',customer_order_number:'CNUM2'

      Factory :booking_line, shipment_id:@shipment.id, order_id:@o1.id
      Factory :booking_line, shipment_id:@shipment.id, order_id:@o2.id
    end

    it "returns orders that have been booked at the order_id level" do
      get :booked_orders, id:@shipment.id
      expect(response).to be_success
      result = JSON.parse(response.body)['booked_orders']
      lines_result = JSON.parse(response.body)['lines_available']
      expect(result.size).to eq 2
      expect(result[0]['id']).to eq @o1.id
      expect(result[0]['ord_ord_num']).to eq @o1.order_number
      expect(result[0]['ord_cust_ord_no']).to eq @o1.customer_order_number
      expect(result[1]['id']).to eq @o2.id
      expect(result[1]['ord_ord_num']).to eq @o2.order_number
      expect(result[1]['ord_cust_ord_no']).to eq @o2.customer_order_number
      expect(lines_result).to be false
    end

    it "lines_available is true if any lines are booked at the order_line_id level" do
      Factory :booking_line, shipment_id:@shipment.id, order_line_id:99

      get :booked_orders, id:@shipment.id
      expect(response).to be_success
      result = JSON.parse(response.body)['lines_available']
      expect(result).to be true
    end
  end
  describe "available_lines" do
    it "returns booking_lines with an order_line_id, in a format that mocks the linked order_line" do
      allow_any_instance_of(Shipment).to receive(:can_view?).and_return true
      shipment = Factory(:shipment)
      order = Factory :order, order_number:'ONUM',customer_order_number:'CNUM'
      prod1 = Factory :product
      oline1 = Factory :order_line, order_id:order.id, line_number:1, sku:'SKU', product_id:prod1.id
      bline1 = Factory :booking_line, shipment_id:shipment.id, order_line_id:oline1.id, line_number:5

      get :available_lines, id:shipment.id
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
    before :each do
      @order_1 = Factory(:order,importer:@u.company,vendor:@u.company,approval_status:'Accepted', customer_order_number: "CNUM", order_number: "ORDERNUM")
      @order_2 = Factory(:order,importer:@u.company,vendor:@u.company,approval_status:'Accepted', customer_order_number: "CNO#")
      @s = Factory(:shipment, importer: @u.company, vendor: @u.company)
    end

    it "autocompletes order numbers that are available to utilize" do
      # Just return all orders...all we care about is that Shipment.available_orders is used
      expect_any_instance_of(Shipment).to receive(:available_orders).with(@u).and_return Order.scoped

      get :autocomplete_order, id: @s.id, n: "CNUM"

      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r.size).to eq 1
      expect(r.first).to eq( {"order_number"=>@order_1.customer_order_number, "id"=>@order_1.id} )
    end

    it "autocompletes using order_number" do
      # Just return all orders...all we care about is that Shipment.available_orders is used
      expect_any_instance_of(Shipment).to receive(:available_orders).with(@u).and_return Order.scoped

      get :autocomplete_order, id: @s.id, n: "ORDER"
      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r.size).to eq 1
      # Note the use of order_number below, this also checks that the field that was matched on
      # is used as the title in the json response
      expect(r.first).to eq( {"order_number"=>@order_1.order_number, "id"=>@order_1.id} )
    end

    it "prefers customer order number if both order number and customer order number match" do
      # Just return all orders...all we care about is that Shipment.available_orders is used
      expect_any_instance_of(Shipment).to receive(:available_orders).with(@u).and_return Order.scoped

      get :autocomplete_order, id: @s.id, n: "NUM"
      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r.size).to eq 1
      # Note the use of order_number below, this also checks that the field that was matched on
      # is used as the title in the json response
      expect(r.first).to eq( {"order_number"=>@order_1.customer_order_number, "id"=>@order_1.id} )
    end

    it "returns blank if no autcomplete text is sent" do
       expect_any_instance_of(Shipment).not_to receive(:available_orders)

       get :autocomplete_order, id: @s.id, n: " "

      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r.size).to eq 0
    end
  end

  describe "autocomplete_products" do
    before :each do
      @product1 = Factory(:product, importer: @u.company, unique_identifier: "Prod1")
      @product2 = Factory(:product, importer: @u.company, unique_identifier: "Prod2")
      @s = Factory(:shipment, importer: @u.company, vendor: @u.company)
    end

    it "autocompletes products that are available to utilize" do
      # Just return all orders...all we care about is that Shipment.available_orders is used
      expect_any_instance_of(Shipment).to receive(:available_products).with(@u).and_return Product.scoped

      get :autocomplete_product, id: @s.id, n: "Prod1"

      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r.size).to eq 1
      expect(r.first).to eq( {"unique_identifier"=>@product1.unique_identifier, "id"=>@product1.id} )
    end

    it "returns blank if no autcomplete text is sent" do
      expect_any_instance_of(Shipment).not_to receive(:available_products)

      get :autocomplete_product, id: @s.id, n: " "

      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r.size).to eq 0
    end
  end

  describe "autocomplete_address" do
    before :each do
      @u = Factory(:user, shipment_edit:true,shipment_view:true,order_view:true,product_view:true)
      @importer = Factory(:importer)
      @s = Factory(:shipment, importer: @importer)
      @u.company.linked_companies << @importer
      allow_any_instance_of(Shipment).to receive(:can_view?).with(@u).and_return true
      allow_api_access @u
    end

    it "returns address matching by name linked to the importer" do
      address = Factory(:full_address, name: "Company 1", company: @importer, in_address_book: true)

      get :autocomplete_address, id: @s.id, n: "ny"
      r = JSON.parse(response.body)
      expect(r.size).to eq 1
      expect(r.first).to eq( {"name"=>address.name, "full_address" => address.full_address, "id"=>address.id} )
    end

    it "does not return address linked to companies user can't view" do
      @u.company.linked_companies.delete_all

      address = Factory(:full_address, name: "Company 1", company: @importer, in_address_book: true)

      get :autocomplete_address, id: @s.id, n: "ny"
      r = JSON.parse(response.body)
      expect(r.size).to eq 0
    end

    it "does not return address not saved to address book" do
      address = Factory(:full_address, name: "Company 1", company: @importer, in_address_book: false)
      get :autocomplete_address, id: @s.id, n: "ny"
      r = JSON.parse(response.body)
      expect(r.size).to eq 0
    end
  end

  describe "create_address" do
    before :each do
      @importer = Factory(:importer)
      @s = Factory(:shipment, importer: @importer)
    end

    it "creates an address associated with the importer" do
      c = Factory(:country)
      address = {name: "Address", line_1: "Line 1", city: "City", state: "ST", postal_code: "1234N", country_id: c.id, in_address_book: true}

      post :create_address, id: @s.id, address: address
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
      expect(r["company_id"]).to eq @importer.id
    end

    it "fails if user can't view" do
      expect_any_instance_of(Shipment).to receive(:can_view?).and_return false

      post :create_address, id: @s.id, address: {}
      expect(response.status).to eq 404
    end
  end

  describe "shipment_lines" do
    before :each do
      @line1 = Factory(:shipment_line)
      @shipment = @line1.shipment
      @line2 = Factory(:shipment_line, shipment: @shipment)
    end

    it "returns shell shipment with only shipment lines" do
      get :shipment_lines, id: @shipment.id
      expect(response).to be_success

      r = JSON.parse(response.body)
      expect(r['shipment']['lines'].length).to eq 2
      expect(r['shipment']['lines'].first['id']).to eq @line1.id
      expect(r['shipment']['lines'].first['shpln_line_number']).to eq @line1.line_number
      expect(r['shipment']['lines'].first['order_lines']).to be_nil

      expect(r['shipment']['lines'].second['id']).to eq @line2.id
      expect(r['shipment']['lines'].second['shpln_line_number']).to eq @line2.line_number
    end

    it "returns order information if requested" do
      ol1 = Factory(:order_line)
      @line1.update_attributes! product: ol1.product

      PieceSet.create! order_line: ol1, shipment_line: @line1, quantity: 1100

      get :shipment_lines, id: @shipment.id, include: "order_lines"
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
      get :shipment_lines, id: @shipment.id, include: "order_lines"
      expect(response.status).to eq 404
    end
  end

  describe "booking_lines" do
    before :each do
      @line1 = Factory(:booking_line)
      @shipment = @line1.shipment
      @line2 = Factory(:booking_line, shipment: @shipment)
    end

    it "returns shell shipment with only shipment lines" do
      get :booking_lines, id: @shipment.id
      expect(response).to be_success

      r = JSON.parse(response.body)

      expect(r['shipment']['booking_lines'].length).to eq 2
      expect(r['shipment']['booking_lines'].first['id']).to eq @line1.id
      expect(r['shipment']['booking_lines'].first['bkln_line_number']).to eq @line1.line_number
      expect(r['shipment']['booking_lines'].first['order_lines']).to be_nil

      expect(r['shipment']['booking_lines'].second['id']).to eq @line2.id
      expect(r['shipment']['booking_lines'].second['bkln_line_number']).to eq @line2.line_number
    end

    it "fails if user can't access the shipment" do
      expect_any_instance_of(Shipment).to receive(:can_view?).and_return false
      get :booking_lines, id: @shipment.id
      expect(response.status).to eq 404
    end
  end

  context 'order booking' do
    let :booking_callback do
      order_booking = Class.new do
        def self.can_book? user
          return true
        end
        def self.book_from_order_hook ship_hash, order, booking_lines
          ship_hash[:shp_master_bill_of_lading] = 'mbol'
        end
        def self.can_request_booking?(shipment, user); true; end
        def self.can_revise_booking?(shipment, user); true; end
        def self.can_edit_booking?(shipment, user); true; end
      end
      OpenChain::OrderBookingRegistry.register order_booking
      order_booking
    end
    let :importer do
      Factory(:company,importer:true)
    end
    let :vendor do
      Factory(:company,vendor:true)
    end
    let :shipment do
      Factory(:shipment,importer:importer,vendor:vendor,ship_from:order.ship_from)
    end
    let :order do
      Factory(:order,importer:importer,vendor:vendor,ship_from:Factory(:address,company:vendor))
    end
    let :product do
      Factory(:product)
    end
    let :order_line do
      Factory(:order_line,order:order,quantity:100,variant:Factory(:variant,product:product),product:product)
    end

    describe "#create_booking_from_order" do
      before :each do
        allow_any_instance_of(Order).to receive(:can_book?).and_return true
      end
      it 'should create booking' do
        booking_callback
        expect(Shipment).to receive(:generate_reference).and_return '12345678'

        expect{post :create_booking_from_order, order_id: order_line.order_id.to_s}.to change(Shipment,:count).from(0).to(1)

        o = order_line.order
        expect(response).to be_success
        s = Shipment.first
        expect(s.reference).to eq '12345678'
        expect(s.importer).to eq importer
        expect(s.vendor).to eq vendor
        expect(s.booking_lines.count).to eq 1
        expect(s.ship_from).to eq o.ship_from
        expect(s.master_bill_of_lading).to eq 'mbol' #proves callback was run
        bl = s.booking_lines.first
        expect(bl.order_line).to eq order_line
        expect(bl.quantity).to eq 100
      end
      it 'should fail if user cannot edit shipment' do
        expect_any_instance_of(Shipment).to receive(:can_edit?).and_return false
        allow(Shipment).to receive(:generate_reference).and_return '12345678'

        expect{post :create_booking_from_order, order_id: order_line.order_id.to_s}.to_not change(Shipment,:count)

        expect(response).to_not be_success
      end
      it 'should fail if user cannot view order' do
        expect_any_instance_of(Order).to receive(:can_view?).and_return false
        allow(Shipment).to receive(:generate_reference).and_return '12345678'

        expect{post :create_booking_from_order, order_id: order_line.order_id.to_s}.to_not change(Shipment,:count)

        expect(response).to_not be_success
      end
      it 'should fail if user cannot book order' do
        expect_any_instance_of(Order).to receive(:can_book?).and_return false
        allow(Shipment).to receive(:generate_reference).and_return '12345678'

        expect{post :create_booking_from_order, order_id: order_line.order_id.to_s}.to_not change(Shipment,:count)

        expect(response).to_not be_success
      end
    end

    describe '#book_order' do
      before :each do
        allow_any_instance_of(Order).to receive(:can_book?).and_return true
      end
      it 'should add order to booking' do
        booking_callback
        s = shipment
        ol = order_line

        expect{put :book_order, id: s.id.to_s, order_id: order_line.order_id.to_s}.to change(BookingLine,:count).from(0).to(1)

        expect(response).to be_success
        s.reload
        expect(s.master_bill_of_lading).to eq 'mbol' #proves callback was run
        expect(s.booking_lines.count).to eq 1
        bl = s.booking_lines.first
        expect(bl.order_line).to eq ol
        expect(bl.quantity).to eq 100
        expect(bl.variant).to eq ol.variant
      end
      it 'should fail if user cannot book order' do
        expect_any_instance_of(Order).to receive(:can_book?).and_return false

        expect{put :book_order, id: shipment.id.to_s, order_id: order_line.order_id.to_s}.to_not change(BookingLine,:count)

        expect(response).to_not be_success
      end
      it 'should fail if order ship from is different than shipment ship from' do
        order.update_attributes(ship_from_id:Factory(:address,company:vendor))

        expect{put :book_order, id: shipment.id.to_s, order_id: order_line.order_id.to_s}.to_not change(BookingLine,:count)

        expect(response).to_not be_success
      end
      it 'should fail if user cannot view order' do
        expect_any_instance_of(Order).to receive(:can_view?).and_return false

        expect{put :book_order, id: shipment.id.to_s, order_id: order_line.order_id.to_s}.to_not change(BookingLine,:count)

        expect(response).to_not be_success
      end
      it 'should fail if user cannot edit shipment' do
        expect_any_instance_of(Shipment).to receive(:can_edit?).and_return false

        expect{put :book_order, id: shipment.id.to_s, order_id: order_line.order_id.to_s}.to_not change(BookingLine,:count)

        expect(response).to_not be_success
      end
      it 'should fail if shipment has different importer as order' do
        order_line.order.update_attributes(importer_id:Factory(:company,importer:true).id)

        expect{put :book_order, id: shipment.id.to_s, order_id: order_line.order_id.to_s}.to_not change(BookingLine,:count)

        expect(response).to_not be_success
        expect(response.body).to match(/importer must/)
      end
      it 'should fail if shipment has different vendor than order' do
        order_line.order.update_attributes(vendor_id:Factory(:company,vendor:true).id)

        expect{put :book_order, id: shipment.id.to_s, order_id: order_line.order_id.to_s}.to_not change(BookingLine,:count)

        expect(response).to_not be_success
        expect(response.body).to match(/vendor must/)
      end
    end
  end

  describe "open_bookings" do
    let (:vendor) { Factory(:vendor) }
    let (:importer) { Factory(:importer) }
    let! (:shipment) { Factory(:shipment, vendor: vendor, importer: importer) }

    context "with order_id parameter" do
      let! (:order) { Factory(:order, importer: importer, vendor:vendor) }

      it "returns bookings user can see where the importer and vendor match the given order's ids" do
        get "open_bookings", order_id: order.id

        expect(response).to be_success
        json = JSON.parse(response.body)
        expect(json["results"].length).to eq 1
        expect(json["results"].first["id"]).to eq shipment.id
      end

      it "does not return results if importer is different than order" do
        shipment.update_attributes! importer_id: Factory(:importer).id

        get "open_bookings", order_id: order.id
        expect(JSON.parse(response.body)["results"].length).to eq 0
      end

      it "does not return results if vendor is different than order" do
        shipment.update_attributes! vendor_id: Factory(:vendor).id

        get "open_bookings", order_id: order.id
        expect(JSON.parse(response.body)["results"].length).to eq 0
      end
    end

    it "limits bookings to linked importer accounts if user is not a vendor or an importer" do
      @u.company = Factory(:master_company)
      @u.company.linked_companies << importer
      @u.save!

      get "open_bookings"

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["results"].length).to eq 1
      expect(json["results"].first["id"]).to eq shipment.id
    end
    
    it "limits bookings by vendor id if user is a vendor" do
      @u.company.vendor = true
      @u.company.save!

      shipment.update_attributes! vendor_id: Factory(:vendor).id

      get "open_bookings"
      expect(JSON.parse(response.body)["results"].length).to eq 0
    end

    it "limits bookings by importer id if user is an importer" do
      @u.company.importer = true
      @u.company.save!

      shipment.update_attributes! importer_id: Factory(:vendor).id

      get "open_bookings"
      expect(JSON.parse(response.body)["results"].length).to eq 0
    end

    it "limits fields returned" do
      @u.company = Factory(:master_company)
      @u.company.linked_companies << importer
      @u.save!
      get "open_bookings", fields: "shp_ref"

      hash = JSON.parse(response.body)["results"].first
      # Rip out permissions, we want to make sure the other shipment fields were limited by the fields parameter
      hash.delete 'permissions'
      expect(hash).to eq({"id" => shipment.id, "shp_ref" => shipment.reference})
    end

    it "does not return shipments that have shipment instructions" do
      shipment.update_attributes! shipment_instructions_sent_date: Time.zone.now
      @u.company = Factory(:master_company)
      @u.company.linked_companies << importer
      @u.save!
      get "open_bookings", fields: "shp_ref"

      expect(JSON.parse(response.body)["results"].length).to eq 0
    end

    context "with booking registry method" do
      let!(:order_booking_registry) {
        order_booking = Class.new {
          def self.can_book?(user); true; end
          def self.open_bookings_hook user, shipments_query, order
            shipments_query.where(mode: "Ocean")
          end
          def self.can_request_booking?(shipment, user); true; end
          def self.can_revise_booking?(shipment, user); true; end
          def self.can_edit_booking?(shipment, user); true; end
        }

        OpenChain::OrderBookingRegistry.register order_booking
        order_booking
      }

      it "uses an order booking registry" do
        @u.company = Factory(:master_company)
        @u.company.linked_companies << importer
        @u.save!

        get "open_bookings"

        # This result should be blank because we're limiting bookings to only ocean ones.
        expect(JSON.parse(response.body)["results"].length).to eq 0
      end

      it "uses an order booking registry" do
        shipment.update_attributes! mode: "Ocean", shipment_instructions_sent_date: Time.zone.now
        @u.company = Factory(:master_company)
        @u.company.linked_companies << importer
        @u.save!

        get "open_bookings"

        # This result should be blank because we're limiting bookings to only ocean ones.
        expect(JSON.parse(response.body)["results"].length).to eq 1
      end
    end
  end
end
