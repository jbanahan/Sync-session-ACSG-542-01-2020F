describe OpenChain::Wto6ChangeResetter do
  describe "reset_fields_if_changed" do
    before(:each) do
      @cr = 50.days.ago
      @p = Factory(:product, name:'myname', created_at:@cr)
      @flds = ['prod_name']
    end
    it "should reset fields if changed" do
      expect(@p).to receive(:wto6_changed_after?).with(@cr).and_return(true)
      described_class.reset_fields_if_changed(@p, 'prod_created_at', ['prod_name'])
      @p.reload
      expect(@p.name).to be_blank
    end
    it "should reset read_only field" do
      cd = Factory(:custom_definition, module_type:'Product', data_type:'string')
      FieldValidatorRule.create!(module_type:'Product', model_field_uid:"*cf_#{cd.id}", read_only:true)
      ModelField.reload

      @p.update_custom_value!(cd, 'abc')
      expect(@p).to receive(:wto6_changed_after?).with(@cr).and_return(true)

      expect(@p.get_custom_value(cd).value).to eq 'abc' # double check that value was set properly

      # do the work
      described_class.reset_fields_if_changed(@p, 'prod_created_at', ["*cf_#{cd.id}"])

      @p.reload
      expect(@p.get_custom_value(cd).value).to be_nil
    end
    it "should not reset fields if not changed" do
      expect(@p).to receive(:wto6_changed_after?).with(@cr).and_return(false)
      described_class.reset_fields_if_changed(@p, 'prod_created_at', ['prod_name'])
      @p.reload
      expect(@p.name).to eq 'myname'
    end
  end
  describe "run_schedulable" do
    it "should get products based on last_started_at" do
      cr = 12.days.ago
      p = Factory(:product, updated_at:6.days.ago, created_at:cr)
      p2 = Factory(:product, updated_at:4.days.ago, created_at:cr)
      d = 5.days.ago

      # this is the expectation
      # need to test the Product call because the reset_field_if_changed stub is clobbered by the SchedulableJob loading the class
      expect_any_instance_of(Product).to receive(:wto6_changed_after?).once

      # have the test actually run the schedulable job since we have the dependency on the last_start_time being
      # passed through to the underlying class
      opts = {'change_date_field'=>'prod_created_at', 'fields_to_reset'=>['prod_name']}
      s = SchedulableJob.new(opts:opts.to_json, run_class:'OpenChain::Wto6ChangeResetter')
      s.last_start_time = d
      s.run
    end
    it "should get all products if run_all option exists" do
      cr = 12.days.ago
      p = Factory(:product, updated_at:6.days.ago, created_at:cr)
      p2 = Factory(:product, updated_at:4.days.ago, created_at:cr)
      d = 5.days.ago

      # this is the expectation
      expect(described_class).to receive(:reset_fields_if_changed).twice

      opts = {'change_date_field'=>'prod_created_at', 'fields_to_reset'=>['prod_name'], 'run_all'=>'true', 'last_start_time'=>10.days.from_now}

      described_class.run_schedulable(opts)
    end
  end
end