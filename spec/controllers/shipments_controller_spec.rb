describe ShipmentsController do
  let!(:u) { create(:user) }
  let(:shipment) { create(:shipment, reference: "REFNUM") }

  before { sign_in_as u }

  # TODO most of this controller is not tested within this spec

  describe "download" do
    it "allows users with edit privileges" do
      expect_any_instance_of(Shipment).to receive(:can_edit?).with(u).and_return true
      expect_any_instance_of(OpenChain::CustomHandler::ShipmentDownloadGenerator).to receive(:generate).with(instance_of(XlsxBuilder), shipment, u)
      expect_any_instance_of(described_class).to receive(:send_builder_data).with(instance_of(XlsxBuilder), "REFNUM")

      get :download, params: { id: shipment.id }, as: :json
      expect(response).to be_success
    end

    it "blocks users without edit privileges" do
      expect_any_instance_of(Shipment).to receive(:can_edit?).with(u).and_return false
      expect_any_instance_of(OpenChain::CustomHandler::ShipmentDownloadGenerator).not_to receive(:generate)

      get :download, id: shipment.id
      expect(response).to redirect_to request.referer
    end

    it "uses J Jill generator for shipments with JJILL importer" do
      co = create(:company, system_code: "JJILL")
      shipment.update! importer_id: co.id

      expect_any_instance_of(Shipment).to receive(:can_edit?).with(u).and_return true
      expect_any_instance_of(OpenChain::CustomHandler::JJill::JJillShipmentDownloadGenerator).to receive(:generate).with(instance_of(XlsxBuilder), shipment, u)
      expect_any_instance_of(described_class).to receive(:send_builder_data).with(instance_of(XlsxBuilder), "REFNUM")

      get :download, params: { id: shipment.id }, as: :json
      expect(response).to be_success
    end
  end

end
