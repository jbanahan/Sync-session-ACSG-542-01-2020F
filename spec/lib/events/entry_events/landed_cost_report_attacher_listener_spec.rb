require 'spec_helper'

describe OpenChain::Events::EntryEvents::LandedCostReportAttacherListener do

  describe :accept? do
    context "J JILL Logic" do
      before :each do
        @entry = Factory(:entry, :customer_name => "JILL")
        @broker_invoice = Factory(:broker_invoice, :entry => @entry)
        @broker_invoice_line = Factory(:broker_invoice_line, :broker_invoice => @broker_invoice, :charge_code => "0600")
      end

      it "should accept a J JILL entry with a Broker Invoice containing a charge code of '0600'" do
        described_class.new.accept?(nil, @entry).should be_true
      end 

      it "should not accept non-JJILL entries with 0600 code" do
        @entry.update_attributes :customer_name => "Blargh!!"
        described_class.new.accept?(nil, @entry).should be_false
      end

      it "should not accept JJILL entries without a 0600 code" do
        @broker_invoice_line.update_attributes :charge_code => "1234"
        described_class.new.accept?(nil, @entry).should be_false
      end
    end
  end

  context :receive do

    before :each do
      @e = Factory(:entry)
    end

    it "should generate a report and create an entry attachment" do
      LocalLandedCostsController.any_instance.should_receive(:show).with(@e.id).and_return "Landed Cost Report"
      entry = described_class.new.receive nil, @e
      entry.id.should == @e.id

      entry.attachments.should have(1).item
      a = entry.attachments.first
      a.attached_file_name.should == "Landed Cost - #{@e.broker_reference}.html"
      a.attachment_type.should == "Landed Cost Report"
    end

    it "should replace any existing landed cost reports with the new one" do
      att = @e.attachments.build
      att.attachment_type = "Landed Cost Report"
      att.save!
      @e.attachments.reload

      LocalLandedCostsController.any_instance.should_receive(:show).with(@e.id).and_return "Landed Cost Report"
      entry = described_class.new.receive nil, @e
      entry.id.should == @e.id

      entry.attachments.should have(1).item
    end
  end
end