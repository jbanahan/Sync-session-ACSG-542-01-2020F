require 'spec_helper'

describe OpenChain::Events::EntryEvents::LandedCostReportAttacherListener do

  describe :accepts? do
    context "J JILL Logic" do
      before :each do
        @entry = Factory(:entry, :customer_number => "JILL")
        @broker_invoice = Factory(:broker_invoice, :entry => @entry)
        @broker_invoice_line = Factory(:broker_invoice_line, :broker_invoice => @broker_invoice, :charge_code => "0600")
      end

      context "www-vfitrack-net system code" do
        before :each do
          ms = double("MasterSetup")
          ms.stub(:system_code).and_return "www-vfitrack-net"
          MasterSetup.stub(:get).and_return ms
        end

        it "should accept a J JILL entry with a Broker Invoice containing a charge code of '0600'" do
          described_class.new.accepts?(nil, @entry).should be_true
        end 

        it "should not accept non-JJILL entries with 0600 code" do
          @entry.update_attributes :customer_number => "Blargh!!"
          described_class.new.accepts?(nil, @entry).should be_false
        end

        it "should not accept JJILL entries without a 0600 code" do
          @broker_invoice_line.update_attributes :charge_code => "1234"
          described_class.new.accepts?(nil, @entry).should be_false
        end

        it "accepts JJILL entries with internal charge code lines" do
          DataCrossReference.create! key: '1234', value: '', cross_reference_type: DataCrossReference::ALLIANCE_FREIGHT_CHARGE_CODE
          @broker_invoice_line.update_attributes :charge_code => "1234"
          described_class.new.accepts?(nil, @entry).should be_true
        end
      end

      it "does not accept when run from non-vfitrack system" do
        described_class.new.accepts?(nil, @entry).should be_false
      end
    end
  end

  context :using_checksum do 
    before :each do
      @landed_cost_data = {
        entries: [
          {
            broker_reference: "Broker Ref",
            commercial_invoices: [
              {
                invoice_number: "INV #1",
                commercial_invoice_lines: [
                  {
                    po_number: "PO #1",
                    part_number: "Part #1",
                    quantity: BigDecimal.new(1),
                    per_unit: {
                      entered_value: BigDecimal.new("1.20"), 
                      duty: BigDecimal.new("3.20"), 
                      fee: BigDecimal.new("4.20"),
                      international_freight: BigDecimal.new("5.20"), 
                      inland_freight: BigDecimal.new("6.20"), 
                      brokerage: BigDecimal.new("7.20"), 
                      other: BigDecimal.new("8.20")
                    }
                  },
                  {
                    po_number: "PO #2",
                    part_number: "Part #2",
                    quantity: BigDecimal.new(2),
                    per_unit: {
                      entered_value: BigDecimal.new("1.20"), 
                      duty: BigDecimal.new("3.20"), 
                      fee: BigDecimal.new("4.20"),
                      international_freight: BigDecimal.new("5.20"), 
                      inland_freight: BigDecimal.new("6.20"), 
                      brokerage: BigDecimal.new("7.20"), 
                      other: BigDecimal.new("8.20")
                    }
                  }
                ]
              },
              {
                invoice_number: "INV #2",
                commercial_invoice_lines: [
                  {
                    po_number: "PO #3",
                    part_number: "Part #3",
                    quantity: BigDecimal.new(3),
                    per_unit: {
                      entered_value: BigDecimal.new("1.20"), 
                      duty: BigDecimal.new("3.20"), 
                      fee: BigDecimal.new("4.20"),
                      international_freight: BigDecimal.new("5.20"), 
                      inland_freight: BigDecimal.new("6.20"), 
                      brokerage: BigDecimal.new("7.20"), 
                      other: BigDecimal.new("8.20")
                    }
                  },
                  {
                    po_number: "PO #4",
                    part_number: "Part #4",
                    quantity: BigDecimal.new(4),
                    per_unit: {
                      entered_value: BigDecimal.new("1.20"), 
                      duty: BigDecimal.new("3.20"), 
                      fee: BigDecimal.new("4.20"),
                      international_freight: BigDecimal.new("5.20"), 
                      inland_freight: BigDecimal.new("6.20"), 
                      brokerage: BigDecimal.new("7.20"), 
                      other: BigDecimal.new("8.20")
                    }
                  }
                ]
              }
            ]
          }
        ]
      }
    end
    
    describe :receive do
      before :each do
        @e = Factory(:entry)
      end

      it "should generate a report and create an entry attachment" do
        OpenChain::Report::LandedCostDataGenerator.any_instance.should_receive(:landed_cost_data_for_entry).with(@e).and_return @landed_cost_data
        LocalLandedCostsController.any_instance.should_receive(:show_landed_cost_data).with(@landed_cost_data).and_return "Landed Cost Report"
        attachment = double("attachment")
        Attachment.should_receive(:delay).and_return attachment
        attachment.should_receive(:push_to_google_drive).with "JJill Landed Cost", kind_of(Numeric)

        entry = described_class.new.receive nil, @e
        entry.id.should == @e.id

        entry.attachments.should have(1).item
        a = entry.attachments.first
        a.attached_file_name.should == "Landed Cost - #{@e.broker_reference}.html"
        a.attachment_type.should == "Landed Cost Report"
      end

      it "should replace any existing landed cost reports with the new one" do
        # Saving without a checksum will ensure the new report is attached (since the checksum won't match)
        att = @e.attachments.build
        att.attachment_type = "Landed Cost Report"
        att.save!
        @e.attachments.reload

        OpenChain::Report::LandedCostDataGenerator.any_instance.should_receive(:landed_cost_data_for_entry).with(@e).and_return @landed_cost_data
        LocalLandedCostsController.any_instance.should_receive(:show_landed_cost_data).with(@landed_cost_data).and_return "Landed Cost Report"
        attachment = double("attachment")
        Attachment.should_receive(:delay).and_return attachment
        attachment.should_receive(:push_to_google_drive).with "JJill Landed Cost", kind_of(Numeric)
        
        entry = described_class.new.receive nil, @e
        entry.id.should == @e.id

        entry.attachments.should have(1).item
      end

      it "should not update the attachment if the checksum is the same" do
        c = described_class.new
        att = @e.attachments.build
        att.attachment_type = "Landed Cost Report"
        att.checksum = c.calculate_landed_cost_checksum @landed_cost_data
        att.save!
        @e.attachments.reload

        OpenChain::Report::LandedCostDataGenerator.any_instance.should_receive(:landed_cost_data_for_entry).with(@e).and_return @landed_cost_data
        entry = c.receive nil, @e

        entry.attachments.should have(1).item
        entry.attachments.first.id.should eq att.id
      end
    end

    describe :calculate_landed_cost_checksum do
      it "should generate the same checksum for identical sets of landed cost data" do
        checksum = described_class.new.calculate_landed_cost_checksum @landed_cost_data
        checksum.should eq described_class.new.calculate_landed_cost_checksum @landed_cost_data
      end

      it "should not take invoice ordering into account when calculating checksums" do
        checksum = described_class.new.calculate_landed_cost_checksum @landed_cost_data

        # Just change the order of the invoices
        @landed_cost_data[:entries][0][:commercial_invoices] << @landed_cost_data[:entries][0][:commercial_invoices][0]
        @landed_cost_data[:entries][0][:commercial_invoices] = @landed_cost_data[:entries][0][:commercial_invoices].drop 1

        checksum.should eq described_class.new.calculate_landed_cost_checksum @landed_cost_data
      end

      it "should not take invoice line ordering into account when calculating checksums" do
        checksum = described_class.new.calculate_landed_cost_checksum @landed_cost_data
        @landed_cost_data[:entries][0][:commercial_invoices][0][:commercial_invoice_lines] << @landed_cost_data[:entries][0][:commercial_invoices][0][:commercial_invoice_lines][0]
        @landed_cost_data[:entries][0][:commercial_invoices][0][:commercial_invoice_lines] = @landed_cost_data[:entries][0][:commercial_invoices][0][:commercial_invoice_lines].drop 1
        checksum.should eq described_class.new.calculate_landed_cost_checksum @landed_cost_data
      end

      it "should generate different checksum if broker reference is different" do
        checksum = described_class.new.calculate_landed_cost_checksum @landed_cost_data
        @landed_cost_data[:entries][0][:broker_reference] = "Changed"
        checksum.should_not eq described_class.new.calculate_landed_cost_checksum @landed_cost_data
      end

      it "should generate different checksum if entered value changes" do
        checksum = described_class.new.calculate_landed_cost_checksum @landed_cost_data
        @landed_cost_data[:entries][0][:commercial_invoices][0][:commercial_invoice_lines][0][:per_unit][:entered_value] = BigDecimal.new("100")
        checksum.should_not eq described_class.new.calculate_landed_cost_checksum @landed_cost_data
      end

      it "should generate different checksum if duty changes" do
        checksum = described_class.new.calculate_landed_cost_checksum @landed_cost_data
        @landed_cost_data[:entries][0][:commercial_invoices][0][:commercial_invoice_lines][0][:per_unit][:duty] = BigDecimal.new("100")
        checksum.should_not eq described_class.new.calculate_landed_cost_checksum @landed_cost_data
      end

      it "should generate different checksum if fee changes" do
        checksum = described_class.new.calculate_landed_cost_checksum @landed_cost_data
        @landed_cost_data[:entries][0][:commercial_invoices][0][:commercial_invoice_lines][0][:per_unit][:fee] = BigDecimal.new("100")
        checksum.should_not eq described_class.new.calculate_landed_cost_checksum @landed_cost_data
      end

      it "should generate different checksum if int'l freight changes" do
        checksum = described_class.new.calculate_landed_cost_checksum @landed_cost_data
        @landed_cost_data[:entries][0][:commercial_invoices][0][:commercial_invoice_lines][0][:per_unit][:international_freight] = BigDecimal.new("100")
        checksum.should_not eq described_class.new.calculate_landed_cost_checksum @landed_cost_data
      end

      it "should generate different checksum if inland freight changes" do
        checksum = described_class.new.calculate_landed_cost_checksum @landed_cost_data
        @landed_cost_data[:entries][0][:commercial_invoices][0][:commercial_invoice_lines][0][:per_unit][:inland_freight] = BigDecimal.new("100")
        checksum.should_not eq described_class.new.calculate_landed_cost_checksum @landed_cost_data
      end

      it "should generate different checksum if brokerage changes" do
        checksum = described_class.new.calculate_landed_cost_checksum @landed_cost_data
        @landed_cost_data[:entries][0][:commercial_invoices][0][:commercial_invoice_lines][0][:per_unit][:brokerage] = BigDecimal.new("100")
        checksum.should_not eq described_class.new.calculate_landed_cost_checksum @landed_cost_data
      end

      it "should generate different checksum if other changes" do
        checksum = described_class.new.calculate_landed_cost_checksum @landed_cost_data
        @landed_cost_data[:entries][0][:commercial_invoices][0][:commercial_invoice_lines][0][:per_unit][:other] = BigDecimal.new("100")
        checksum.should_not eq described_class.new.calculate_landed_cost_checksum @landed_cost_data
      end
    end
  end
end