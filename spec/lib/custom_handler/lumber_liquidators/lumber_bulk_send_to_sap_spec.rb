describe OpenChain::CustomHandler::LumberLiquidators::BulkSendToSap do
  describe 'act' do
    before :each do
      @ord = Factory(:order)
      @user = Factory(:master_user,order_view:true)
      @cdefs = described_class.prep_custom_definitions [:ord_manual_send_to_sap_date]
    end
    it "should FTP file to SAP" do
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator).to receive(:send_order).with(@ord, force_send:true).and_return("Success")

      described_class.act @user, @ord.id, nil, nil, nil

      # Ensure the date set in the custom date field is within a couple of seconds of the current date/time.
      expect(@ord.custom_value(@cdefs[:ord_manual_send_to_sap_date])).to be_within(2).of(Time.zone.now)

      snapshots = @ord.entity_snapshots
      expect(snapshots.length).to eq 1
      expect(snapshots.first.context).to eq "Manual SAP Send"
    end
    it "handles bad order control numbers" do
      expect{ described_class.act @user, -500, nil, nil, nil }.to raise_error(ActiveRecord::RecordNotFound)
    end
    it "handles permission errors" do
      @user.order_view = false
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator).to_not receive(:send_order)
      described_class.act @user, @ord.id, nil, nil, nil
    end
  end
end
