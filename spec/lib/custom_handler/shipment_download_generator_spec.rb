require 'spec_helper'

describe OpenChain::CustomHandler::ShipmentDownloadGenerator do
  before do
    @shipment = Factory :shipment
    @user = Factory :master_user
    @shipment.stub(:can_view?).and_return true
    Factory :container, shipment: @shipment
    Factory :shipment_line, shipment: @shipment
  end

  it "runs without exploding" do
    result = described_class.new(@shipment, @user).generate
    expect(result).not_to be_nil
  end
end