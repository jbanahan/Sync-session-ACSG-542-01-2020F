describe OpenChain::BulkAction::BulkSendToTest do

  describe "act" do
    before :each do
      @ord = Factory(:order, last_file_bucket:'the_bucket', last_file_path:'the_path')
      @u = Factory(:user, order_view:true)
    end

    it "sends integration file to test" do
      allow_any_instance_of(Order).to receive(:can_view?).and_return true
      expect(Order).to receive(:send_integration_file_to_test).with('the_bucket', 'the_path')

      described_class.act @u, @ord.id, {'module_type' => 'Order'}, nil, nil
    end

    it "does not send file if integration file can't be found" do
      @ord.update_attributes! last_file_path:'bad_file'
      allow_any_instance_of(Order).to receive(:can_view?).and_return true
      expect(Order).not_to receive(:send_integration_file_to_test).with('the_bucket', 'the_path')

      described_class.act @u, @ord.id, {'module_type' => 'Order'}, nil, nil
    end

    it "does not send file if it doesn't have path set" do
      @ord.update_attributes! last_file_path:nil
      allow_any_instance_of(Order).to receive(:can_view?).and_return true
      expect(Order).not_to receive(:send_integration_file_to_test).with('the_bucket', 'the_path')

      described_class.act @u, @ord.id, {'module_type' => 'Order'}, nil, nil
    end

    it "does not send file if it doesn't have bucket set" do
      @ord.update_attributes! last_file_bucket:nil
      allow_any_instance_of(Order).to receive(:can_view?).and_return true
      expect(Order).not_to receive(:send_integration_file_to_test).with('the_bucket', 'the_path')

      described_class.act @u, @ord.id, {'module_type' => 'Order'}, nil, nil
    end

    it "does not send file if object doesn't support this behavior" do
      company = Factory(:company)

      allow_any_instance_of(Company).to receive(:can_view?).and_return true
      expect(Company).not_to receive(:send_integration_file_to_test).with('the_bucket', 'the_path')

      described_class.act @u, company.id, {'module_type' => 'Company'}, nil, nil
    end

    it "does not send file if user doesn't have view permission for the record" do
      allow_any_instance_of(Order).to receive(:can_view?).and_return false
      expect(Order).not_to receive(:send_integration_file_to_test).with('the_bucket', 'the_path')

      described_class.act @u, @ord.id, {'module_type' => 'Order'}, nil, nil
    end

    it "throws an error when record not found" do
      expect(Order).not_to receive(:send_integration_file_to_test).with('the_bucket', 'the_path')

      expect { described_class.act @u, -555, {'module_type' => 'Order'}, nil, nil }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "throws an error when module_type is not provided" do
      expect { described_class.act @u, @ord.id, {}, nil, nil }.to raise_error(NoMethodError)
    end
  end
end