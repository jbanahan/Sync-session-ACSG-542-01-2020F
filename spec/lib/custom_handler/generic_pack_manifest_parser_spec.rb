require 'spec_helper'
require Rails.root.join('spec/fixtures/files/standard_booking_form')

describe OpenChain::CustomHandler::GenericPackManifestParser do

  let(:shipment) { FactoryGirl.create(:shipment) }
  let(:user) { FactoryGirl.create(:master_user, shipment_edit: true, shipment_view: true) }

  before do
    # @user = double :user
    # @user.stub(:view_shipments?).and_return true
    # @user.stub(:edit_shipments?).and_return true
  end

  it 'parses it' do
    result = described_class.new.process_rows shipment, FORM_ARRAY, user
    expect(result).to be_present
    expect(shipment.booking_lines.length).to eq 3
  end
end
