require 'spec_helper'

describe OpenChain::CustomHandler::EcellerateShipmentActivityParser do
  def default_row overrides={}
    #only creating relevant fields
    h = {prefix:'House Bill',hbol:'HBOL123',mbol:'MBOL123',ior:'CUSTNUM',etd:Date.new(2014,1,1),atd:Date.new(2014,1,2),
      eta:Date.new(2014,1,3),ata:Date.new(2014,1,4),cargo_ready:Date.new(2014,1,5),
      est_delivery:Date.new(2014,1,6),act_delivery:Date.new(2014,1,7),line_number:1,cartons:'100.000 CTN',quantity:'52.000 EA',part:'12345',po:'POABC'
      }.merge overrides
    r = Array.new 65
    r[0] = h[:prefix]
    r[1] = h[:hbol]
    r[2] = h[:mbol]
    r[5] = h[:ior]
    r[33] = h[:etd]
    r[34] = h[:atd]
    r[35] = h[:eta]
    r[36] = h[:ata]
    r[38] = h[:cargo_ready]
    r[41] = h[:est_delivery]
    r[42] = h[:act_delivery]
    r[43] = h[:line_number]
    r[45] = h[:part]
    r[48] = h[:po]
    r[54] = h[:quantity]
    r[55] = h[:cartons]
    r
  end
  describe :can_view? do
    it "must have ecellerate custom feature" do
      MasterSetup.any_instance.stub(:custom_feature?).and_return false
      User.any_instance.stub(:edit_shipments?).and_return true
      expect(described_class.can_view?(Factory(:master_user))).to be_false
    end
    it "must be from master user" do
      MasterSetup.any_instance.stub(:custom_feature?).and_return true
      User.any_instance.stub(:edit_shipments?).and_return true
      expect(described_class.can_view?(Factory(:user))).to be_false
    end
    it "must be user who can edit shipments" do
      MasterSetup.any_instance.stub(:custom_feature?).and_return true
      User.any_instance.stub(:edit_shipments?).and_return false
      expect(described_class.can_view?(Factory(:master_user))).to be_false
    end
    it "should pass for user who can edit shipments, is master, and has custom feature enabled" do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('ecellerate').and_return true
      User.any_instance.stub(:edit_shipments?).and_return true
      expect(described_class.can_view?(Factory(:master_user))).to be_true
    end
  end
  describe :process do
    it "must allow can_view?" do
      p = described_class.new(double('att'))
      p.should_receive(:can_view?).and_return false
      expect {p.process User.new}.to raise_error "Processing Failed because you cannot view this file."
    end
    it "should call parse" do
      a = double('att')
      xlc = double('xlc')
      p = described_class.new(a)
      p.should_receive(:can_view?).and_return true
      OpenChain::XLClient.should_receive(:new_from_attachable).with(a).and_return(xlc)
      p.should_receive(:parse).with(xlc)
      p.process User.new
    end
  end
  describe :parse do
    def run_parse rows
      a = double(:att)
      x = double(:xl_client)
      stubbed = x.stub(:all_row_values,0)
      rows.each {|row| stubbed = stubbed.and_yield row}
      described_class.new(a).parse x
    end
    before :each do
      @imp = Factory(:company,importer:true,ecellerate_customer_number:'CUSTNUM')
    end
    it "should update existing shipment" do
      s = Factory(:shipment,importer:@imp,house_bill_of_lading:'HBOL123')
      r = default_row
      expect {run_parse [r]}.to_not change(Shipment,:count)
      s.reload
      expect(s.est_departure_date).to eq r[33]
      expect(s.departure_date).to eq r[34]
      expect(s.est_arrival_port_date).to eq r[35]
      expect(s.arrival_port_date).to eq r[36]
      expect(s.cargo_on_hand_date).to eq r[38]
      expect(s.est_delivery_date).to eq r[41]
      expect(s.delivered_date).to eq r[42]

    end

    it "should skip rows that don't start with 'House Bill'" do
      expect {run_parse [default_row(prefix:'OTHER')]}.to_not change(Shipment,:count)
      expect(ActionMailer::Base.deliveries.size).to eq 0
    end
    it "should skip shipments where ecellerate_customer_number not found for importer" do
      r = default_row(ior:'OTHER')
      d = 1.week.ago
      s = Factory(:shipment,importer:@imp,house_bill_of_lading:r[1],updated_at:d)
      expect {run_parse [r]}.to_not change(s,:updated_at)
      expect(ActionMailer::Base.deliveries.size).to eq 0
    end
    it "should email errors for shipments not found when importer is found" do
      r = default_row
      expect {run_parse [r]}.to_not change(Shipment,:count)
      expect(ActionMailer::Base.deliveries.size).to eq 1
      expect(ActionMailer::Base.deliveries.first.body).to match /HBOL123/
    end
  end
end