require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover do
  describe "process" do
    before :each do
      @cdefs = described_class.prep_custom_definitions([:prodven_risk,:ordln_pc_approved_by,:ordln_pc_approved_date,:ordln_qa_approved_by,:ordln_qa_approved_date,:ord_assigned_agent,:ord_inspector_assigned])
    end
    it "should approve lines where risk level is Auto-Flow" do
      u = Factory(:master_user,username:'autoflow')
      p = Factory(:product)
      v = Factory(:company,name:'vendor')
      pva = p.product_vendor_assignments.create!(vendor_id:v.id)
      pva.update_custom_value!(@cdefs[:prodven_risk],'Auto-Flow')
      ord = Factory(:order,vendor:v)
      ol = Factory(:order_line,product:p,order:ord)

      expect(ord).to receive(:create_snapshot).with(u, nil, "System Job: Autoflow Order Approver")

      # create another product with an empty risk assignment. Nothing should happen to this one
      other_product = Factory(:product)
      other_product.product_vendor_assignments.create!(vendor_id:v.id)
      other_ol = Factory(:order_line,product:other_product,order:ord)

      # create another product with low risk assignment and an order line with Auto-Flow approval which should be cmp_legal_approved_date
      low_product = Factory(:product)
      low_product.product_vendor_assignments.create!(vendor_id:v.id).update_custom_value!(@cdefs[:prodven_risk],'Low')
      low_ol = Factory(:order_line,product:low_product,order:ord)

      described_class.process(ord)

      [ol,other_ol,low_ol].each {|line| line.reload}

      expect(ol.get_custom_value(@cdefs[:ordln_pc_approved_by]).value).to eq u.id
      expect(ol.get_custom_value(@cdefs[:ordln_pc_approved_date]).value).to_not be_blank

      expect(other_ol.get_custom_value(@cdefs[:ordln_pc_approved_by]).value).to be_blank
      expect(other_ol.get_custom_value(@cdefs[:ordln_pc_approved_date]).value).to be_blank

      expect(low_ol.get_custom_value(@cdefs[:ordln_pc_approved_by]).value).to be_blank
      expect(low_ol.get_custom_value(@cdefs[:ordln_pc_approved_date]).value).to be_blank
    end

    it "should approve lines where risk level is 'Domestic Low Auto-Flow'" do
      u = Factory(:master_user,username:'autoflow')
      p = Factory(:product)
      v = Factory(:company,name:'vendor')
      pva = p.product_vendor_assignments.create!(vendor_id:v.id)
      pva.update_custom_value!(@cdefs[:prodven_risk],'Domestic Low Auto-Flow')
      ord = Factory(:order,vendor:v)
      ol = Factory(:order_line,product:p,order:ord)

      expect(ord).to receive(:create_snapshot).with(u, nil, "System Job: Autoflow Order Approver")

      # create another product with an empty risk assignment. Nothing should happen to this one
      other_product = Factory(:product)
      other_product.product_vendor_assignments.create!(vendor_id:v.id)
      other_ol = Factory(:order_line,product:other_product,order:ord)

      # create another product with low risk assignment and an order line with Auto-Flow approval which should be cmp_legal_approved_date
      low_product = Factory(:product)
      low_product.product_vendor_assignments.create!(vendor_id:v.id).update_custom_value!(@cdefs[:prodven_risk],'Low')
      low_ol = Factory(:order_line,product:low_product,order:ord)

      described_class.process(ord)

      [ol,other_ol,low_ol].each {|line| line.reload}

      expect(ol.custom_value(@cdefs[:ordln_pc_approved_by])).to eq u.id
      expect(ol.custom_value(@cdefs[:ordln_pc_approved_date])).to_not be_blank

      expect(other_ol.custom_value(@cdefs[:ordln_pc_approved_by])).to be_blank
      expect(other_ol.custom_value(@cdefs[:ordln_pc_approved_date])).to be_blank

      expect(low_ol.custom_value(@cdefs[:ordln_pc_approved_by])).to be_blank
      expect(low_ol.custom_value(@cdefs[:ordln_pc_approved_date])).to be_blank
    end

    it "should auto flow QA if no assigned agent" do
      ol = Factory(:order_line)
      described_class.process(ol.order)
      expect(ol.custom_value(@cdefs[:ordln_qa_approved_by])).to_not be_blank
      expect(ol.custom_value(@cdefs[:ordln_qa_approved_date])).to_not be_blank
    end
    
    it "should auto flow if assigned agent is global sourcing" do
      ['GS-EU','GS-US','GS-CA'].each do |agent|
        ol = Factory(:order_line)
        ol.order.update_custom_value!(@cdefs[:ord_assigned_agent],agent)
        
        described_class.process(ol.order)
        expect(ol.custom_value(@cdefs[:ordln_qa_approved_by])).to_not be_blank
        expect(ol.custom_value(@cdefs[:ordln_qa_approved_date])).to_not be_blank
      end
    end

    it "should not auto flow QA if assigned agent" do
      ol = Factory(:order_line)
      ol.order.update_custom_value!(@cdefs[:ord_assigned_agent],'RO')

      described_class.process(ol.order)

      expect(ol.custom_value(@cdefs[:ordln_qa_approved_by])).to be_blank
      expect(ol.custom_value(@cdefs[:ordln_qa_approved_date])).to be_blank
    end

    it "should create Auto Flow user" do
      p = Factory(:product)
      v = Factory(:company,name:'vendor')
      pva = p.product_vendor_assignments.create!(vendor_id:v.id)
      pva.update_custom_value!(@cdefs[:prodven_risk],'Auto-Flow')
      ord = Factory(:order,vendor:v)
      ol = Factory(:order_line,product:p,order:ord)

      described_class.process(ord)

      expect(User.find(ol.get_custom_value(@cdefs[:ordln_pc_approved_by]).value).username).to eq 'autoflow'
    end

    it "allows disabling the snapshot" do
      Factory(:master_user,username:'autoflow')
      p = Factory(:product)
      v = Factory(:company,name:'vendor')
      pva = p.product_vendor_assignments.create!(vendor_id:v.id)
      pva.update_custom_value!(@cdefs[:prodven_risk],'Auto-Flow')
      ord = Factory(:order,vendor:v)
      Factory(:order_line,product:p,order:ord)

      expect(ord).not_to receive(:create_snapshot)

      expect(described_class.process(ord, entity_snapshot: false)).to eq true
    end
  end
end
