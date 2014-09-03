require 'spec_helper'

describe Api::V1::ShipmentsController do
  before(:each) do
    MasterSetup.get.update_attributes(shipment_enabled:true)
    @u = Factory(:master_user,shipment_edit:true,shipment_view:true,order_view:true,product_view:true)
    allow_api_access @u
  end

  describe "index" do
    it "should find shipments" do
      s1 = Factory(:shipment,reference:'123')
      s2 = Factory(:shipment,reference:'ABC')
      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['results'].collect{|r| r['shp_ref']}).to eq ['123','ABC']
    end

    it "should limit fields returned" do
      s1 = Factory(:shipment,reference:'123',mode:'Air',master_bill_of_lading:'MBOL')
      get :index, fields:'shp_ref,shp_mode'
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['results']).to eq [{'id'=>s1.id,'shp_ref'=>'123','shp_mode'=>'Air',"permissions"=>{"can_edit"=>true, "can_view"=>true, "can_attach"=>false, "can_comment"=>false}}]
    end
  end

  describe "show" do
    it "should render shipment" do
      s = Factory(:shipment,reference:'123',mode:'Air')
      get :show, id: s.id
      expect(response).to be_success
      j = JSON.parse response.body
      sj = j['shipment']
      expect(sj['shp_ref']).to eq '123'
      expect(sj['shp_mode']).to eq 'Air'
    end
    it "should render permissions" do
      Shipment.any_instance.stub(:can_edit?).and_return false
      Shipment.any_instance.stub(:can_view?).and_return true
      Shipment.any_instance.stub(:can_attach?).and_return true
      Shipment.any_instance.stub(:can_comment?).and_return false
      s = Factory(:shipment)
      get :show, id: s.id
      j = JSON.parse response.body
      pj = j['shipment']['permissions']
      expect(pj['can_edit']).to eq false
      expect(pj['can_view']).to eq true
      expect(pj['can_attach']).to eq true
      expect(pj['can_comment']).to eq false
    end
    it "should convert numbers to numeric" do
      sl = Factory(:shipment_line,quantity:10)
      get :show, id: sl.shipment_id
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
      get :show, id: sl.shipment_id
      expect(response).to be_success
      j = JSON.parse response.body
      slj = j['shipment']['lines'].first
      expect(slj['id']).to eq sl.id
      expect(slj['shpln_line_number']).to eq 5
      expect(slj['shpln_shipped_qty']).to eq 10.0
    end
    it "should render optional order lines" do
      ol = Factory(:order_line,quantity:20,currency:'USD')
      ol.order.update_attributes(customer_order_number:'C123',order_number:'123')
      sl = Factory(:shipment_line,quantity:10,product:ol.product)
      sl.linked_order_line_id = ol.id
      sl.save!
      get :show, id: sl.shipment_id, include: 'order_lines'
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
      get :show, id: sl.shipment_id
      expect(response).to be_success
      j = JSON.parse response.body
      slc = j['shipment']['containers'].first
      expect(slc['con_container_number']).to eq 'CN1234'
      expect(j['shipment']['lines'][0]['shpln_container_uid']).to eq c.id
    end
    it "should optionally render carton sets" do
      cs = Factory(:carton_set,starting_carton:1000)
      sl = Factory(:shipment_line,shipment:cs.shipment,carton_set:cs)
      get :show, id: cs.shipment_id, include: 'carton_sets'
      expect(response).to be_success
      j = JSON.parse response.body
      slc = j['shipment']['carton_sets'].first
      expect(slc['cs_starting_carton']).to eq 1000
      expect(j['shipment']['lines'][0]['shpln_carton_set_uid']).to eq cs.id
    end
  end
  describe "process_tradecard_pack_manifest" do
    before :each do
      @s = Factory(:shipment)
      @att = Factory(:attachment,attachable:@s)
    end
    it "should fail if user cannot edit shipment" do
      Shipment.any_instance.stub(:can_edit?).and_return false
      expect {post :process_tradecard_pack_manifest, {'attachment_id'=>@att.id,'id'=>@s.id}}.to_not change(AttachmentProcessJob,:count)
      expect(response.status).to eq 403
    end
    it "should fail if attachment is not attached to this shipment" do
      Shipment.any_instance.stub(:can_edit?).and_return true
      a2 = Factory(:attachment)
      expect {post :process_tradecard_pack_manifest, {'attachment_id'=>a2.id,'id'=>@s.id}}.to_not change(AttachmentProcessJob,:count)
      expect(response.status).to eq 400
      expect(JSON.parse(response.body)['errors']).to eq ['Attachment not linked to Shipment.']
    end
    it "should fail if AttachmentProcessJob already exists" do
      Shipment.any_instance.stub(:can_edit?).and_return true
      @s.attachment_process_jobs.create!(attachment_id:@att.id,job_name:'Tradecard Pack Manifest',user_id:@u.id,start_at:1.minute.ago)
      expect {post :process_tradecard_pack_manifest, {'attachment_id'=>@att.id,'id'=>@s.id}}.to_not change(AttachmentProcessJob,:count)
      expect(response.status).to eq 400
      expect(JSON.parse(response.body)['errors']).to eq ['This manifest has already been submitted for processing.']
    end
    it "should process job" do
      Shipment.any_instance.stub(:can_edit?).and_return true
      AttachmentProcessJob.any_instance.should_receive(:process)
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
      @product = Factory(:product,vendor:@ven,unique_identifier:'PUID1')
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
      Shipment.any_instance.stub(:can_edit?).and_return false
      expect {post :create, @s_hash}.to_not change(Shipment,:count)
      expect(response.status).to eq 403
    end
    context :order_lines do
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
        OrderLine.any_instance.stub(:can_view?).and_return false
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
      Product.any_instance.stub(:can_view?).and_return false
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
      @product = Factory(:product,vendor:@ven,unique_identifier:'PUID1')
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
      sl = Factory(:shipment_line,shipment:@shipment,product:@product,quantity:100,line_number:1,container:con)
      @s_hash['containers'] = [{'id'=>con.id,'_destroy'=>true}]
      put :update, id: @shipment.id, shipment: @s_hash
      expect(response.status).to eq 400
      expect(Container.find_by_id(con.id)).to_not be_nil
    end
    it "should error if locked line is update"
  end
  describe "available_orders" do
    it "should return all orders available from shipment.available_orders" do
      imp = Company.new(name:'IMPORTERNAME')
      vend = Company.new(name:'VENDORNAME')
      o1 = Order.new(importer:imp,vendor:vend,order_date:Date.new(2014,1,1),mode:'Air',order_number:'ONUM',customer_order_number:'CNUM')
      o1.id = 99
      o2 = Order.new(importer:imp,vendor:vend,order_date:Date.new(2014,1,1),mode:'Air',order_number:'ONUM2',customer_order_number:'CNUM2')
      o2.id = 100
      Shipment.any_instance.stub_chain(:available_orders,:order).and_return [o1,o2]
      Shipment.any_instance.stub(:can_view?).and_return true
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
end