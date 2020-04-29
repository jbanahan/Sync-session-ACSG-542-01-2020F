describe OpenChain::TimedBusinessRuleRunner do
  describe "run_schedulable" do
    let!(:entry) { Factory(:entry) }
    let!(:product) { Factory(:product) }
    let!(:job1) { Factory(:business_validation_scheduled_job, validatable: entry, run_date: DateTime.new(2018, 3, 15)) }
    let!(:job2) { Factory(:business_validation_scheduled_job, validatable: product, run_date: DateTime.new(2018, 3, 10)) }

    it "runs validations for selected objects" do
      expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with(product)
      now = DateTime.new(2018, 3, 11)
      Timecop.freeze(now) do
        expect {described_class.run_schedulable}.to change(BusinessValidationScheduledJob, :count).from(2).to(1)
      end
    end
  end
end
