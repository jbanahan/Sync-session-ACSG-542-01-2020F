require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberDhlOrderPushReport do

  def expect_no_results tempfile
    @tempfile = tempfile
    tempfile = described_class.run_report user
    wb = Spreadsheet.open @tempfile.path
    sheet = wb.worksheet "DHL PO Push"
    expect(sheet.rows.length).to eq 1
  end

  describe "run_report" do
    before :all do
      @cdefs = described_class.prep_custom_definitions [:ord_country_of_origin, :ord_dhl_push_date]
    end

    after :all do
      CustomDefinition.delete_all
    end

    let (:vendor) { Factory(:company, name: "Vendor Name", vendor: true) }
    let (:order) { 
      order = Factory(:order, approval_status: "Approved", vendor: vendor) 
      order.business_validation_results.create! state: "Pass"
      order
    }
    let (:user) { Factory(:user, time_zone: "America/New_York") }

    after :each do 
      @tempfile.close! if @tempfile && !@tempfile.closed?
    end

    before :each do
      order
    end

    context "with valid country setup" do
      before :each do
        order.update_custom_value! @cdefs[:ord_country_of_origin], "PE"
      end

      it "returns results" do
        Timecop.freeze(Time.zone.parse("2016-04-04 12:00")) do   
          @tempfile = described_class.run_report user
        end

        expect(@tempfile.original_filename).to eq "DHL PO Push 04-04-16.xls"
        
        wb = Spreadsheet.open @tempfile.path
        sheet = wb.worksheet "DHL PO Push"
        expect(sheet).not_to be_nil
        expect(sheet.row(0)).to eq ["Order Number", "Vendor Name"]
        expect(sheet.row(1)).to eq [order.order_number.to_s, vendor.name]

        order.reload
        expect(order.custom_value(@cdefs[:ord_dhl_push_date])).to eq Date.new(2016, 4, 4)
        expect(order.entity_snapshots.length).to eq 1
      end

      it "does not return results if business rules don't pass" do
        order.business_validation_results.first.update_attributes! state: "Fail"
        expect_no_results(described_class.run_report user)
      end

      it "does not return results for orders that already have push date set" do
        order.update_custom_value! @cdefs[:ord_dhl_push_date], Time.zone.now.to_date
        expect_no_results(described_class.run_report user)
      end

      it "does not return results for non-approved orders" do
        order.update_attributes! approval_status: ""
        expect_no_results(described_class.run_report user)
      end

      it "does not return results for closed orders" do
        order.update_attributes! closed_at: Time.zone.now
        expect_no_results(described_class.run_report user)
      end
    end
    

    context "with valid country of origin" do
      ['BO', 'BR', 'PE', 'PY'].each do |country|
        it "returns results" do
          order.update_custom_value! @cdefs[:ord_country_of_origin], country
          @tempfile = described_class.run_report user
          wb = Spreadsheet.open @tempfile.path
          sheet = wb.worksheet "DHL PO Push"
          expect(sheet.row(1)).to eq [order.order_number.to_s, vendor.name]
        end
      end
    end

    it "does not return results for other countries" do
      order.update_custom_value! @cdefs[:ord_country_of_origin], "US"
      expect_no_results(described_class.run_report user)
    end
  end

  describe "permission?" do
    let (:logistics_user) {
      group = Group.use_system_group 'LOGISTICS'
      user = Factory(:user)
      user.groups << group
      user
    }

    context "with ll system code" do
      before :each do
        ms = double("MasterSetup")
        MasterSetup.stub(:get).and_return ms
        ms.stub(:system_code).and_return "ll"
      end

      it "does not allow access to users not in LOGISTICS group" do
        expect(described_class.permission? User.new).to be_false
      end

      it "allows access to users in the logistics group" do
        expect(described_class.permission? logistics_user).to be_true
      end
    end
    
    it "does not allow non-ll system access" do
      expect(described_class.permission? logistics_user).to be_false
    end
  end
end