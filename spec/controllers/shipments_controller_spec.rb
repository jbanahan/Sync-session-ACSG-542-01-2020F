require 'spec_helper'

describe ShipmentsController do
  let!(:u) { Factory(:user) }
  let(:shipment) { Factory(:shipment, reference: "REFNUM") }
  let(:workbook) { double "workbook" }

  before { sign_in_as u }

  describe "download" do
    it "allows users with edit privileges" do
      expect_any_instance_of(Shipment).to receive(:can_edit?).with(u).and_return true
      expect_any_instance_of(OpenChain::CustomHandler::ShipmentDownloadGenerator).to receive(:generate).with(shipment, u).and_return workbook
      expect_any_instance_of(described_class).to receive(:send_excel_workbook).with(workbook, "REFNUM.xls")
      expect_any_instance_of(described_class).to receive(:render)
    
      get :download, id: shipment.id
      expect(response).to be_success
    end

    it "blocks users without edit privileges" do
      expect_any_instance_of(Shipment).to receive(:can_edit?).with(u).and_return false
      expect_any_instance_of(OpenChain::CustomHandler::ShipmentDownloadGenerator).to_not receive(:generate)

      get :download, id: shipment.id
      expect(response).to redirect_to request.referrer
    end

    it "uses J Jill generator for JILL user" do
      co = Factory(:company, system_code: "JJILL")
      u.company = co; u.save!

      expect_any_instance_of(Shipment).to receive(:can_edit?).with(u).and_return true
      expect_any_instance_of(OpenChain::CustomHandler::JJill::JJillShipmentDownloadGenerator).to receive(:generate).with(shipment, u).and_return workbook
      expect_any_instance_of(described_class).to receive(:send_excel_workbook).with(workbook, "REFNUM.xls")
      expect_any_instance_of(described_class).to receive(:render)
    
      get :download, id: shipment.id
      expect(response).to be_success
    end
  end

end