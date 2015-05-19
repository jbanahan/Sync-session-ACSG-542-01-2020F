require 'spec_helper'

describe OpenChain::CustomHandler::GenericPackManifestParser do

  let(:file) { File.open(Rails.root.join 'spec/fixtures/files/Standardized Booking Form (SO).xls') }
  let(:user) { FactoryGirl.create(:user) }
  let(:shipment) { FactoryGirl.create(:shipment) }
  let(:attachment) { double :attachment }

  before do
    attachment.stub(:attached).and_return file
  end

  it 'finds the file' do
    expect(file).not_to be_nil
  end

  it 'parses it' do
    result = described_class.process_attachment shipment, attachment, user
    expect(result).to be_present?
  end
end
