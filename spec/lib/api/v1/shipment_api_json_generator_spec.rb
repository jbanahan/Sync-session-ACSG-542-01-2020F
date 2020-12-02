describe OpenChain::Api::V1::ShipmentApiJsonGenerator do

  let (:user) { create(:user) }
  let (:params) { {} }
  let (:shipment) { Shipment.new }

  before :each do
    allow(subject).to receive(:current_user).and_return user
    allow(subject).to receive(:params).and_return params
  end

  # Almost all of the code in the class being tested was lifted directly
  # from the Api::V1::ShipmentsController.  As such, it's still mostly tested there.
  # I don't have the availability at the moment to do a full re-implementation of the
  # those tests here...so for the moment, only new things are unit tested.
  describe "obj_to_json_hash" do

    it "calls through to the custom api response registry" do
      expect(OpenChain::Registries::CustomizedApiResponseRegistry).to receive(:customize_shipment_response).with(shipment, user, hash_including(id: nil), params)
      subject.obj_to_json_hash shipment
    end
  end
end