require 'spec_helper'
require Rails.root.join('spec/fixtures/files/standard_booking_form')

describe OpenChain::CustomHandler::GenericPackManifestParser do

  let(:user) { double(:user) }
  let(:shipment) { double(:shipment) }
  let(:attachment) { double :attachment }

  before do
    shipment.stub(:can_edit?).and_return true
  end

  it 'parses it' do
    result = described_class.new.process_rows shipment, FORM_ARRAY, user
    expect(result).to be_present?
  end
end
