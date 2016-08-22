require 'spec_helper'

describe SchedulableReportResult do

  describe "run_schedulable" do
    let (:user) { Factory(:user) }
    let (:report_class) { "OpenChain::Report::KewillCurrencyRatesReport"}
    let (:valid_options) {
      {'username' => user.username, 'report_class' => report_class, 'report_name' => "Testing"}
    }

    it "runs a report via the schedule interface" do
      expect(OpenChain::Report::KewillCurrencyRatesReport).to receive(:permission?).with(user).and_return true
      report_settings = {settings: {'test'=>'testing'}, friendly_settings: ["Testing"]}
      expect(OpenChain::Report::KewillCurrencyRatesReport).to receive(:schedulable_settings).with(user, "Testing", valid_options).and_return report_settings

      expect(described_class).to receive(:run_report!).with "Testing", user, report_class.constantize, (valid_options.merge report_settings).with_indifferent_access
      described_class.run_schedulable valid_options
    end

    it "merges settings from the report's schedulable interface with settings from the schedule setup" do
      # The test1 value in valid_options should override the test1 value from report_settings
      valid_options['settings'] = {"test1" => "test1", "test2" => "test2"}
      # Make sure the friendly settings is having unique called on it, so use value that is the same in both the report_settings and the valid_options
      valid_options['friendly_settings'] = ["Testing", "Friendly Settings"]

      expect(OpenChain::Report::KewillCurrencyRatesReport).to receive(:permission?).with(user).and_return true
      report_settings = {settings: {"test1" => "test",'test'=>'testing'}, friendly_settings: ["Testing", "Testing 2"]}
      expect(OpenChain::Report::KewillCurrencyRatesReport).to receive(:schedulable_settings).with(user, "Testing", valid_options).and_return report_settings

      expected_hash = valid_options.clone
      expected_hash[:settings] = {"test1" => "test1", "test" => "testing", "test2" => "test2"}
      expected_hash[:friendly_settings] = ["Testing", "Friendly Settings", "Testing 2"]

      expect(described_class).to receive(:run_report!).with "Testing", user, report_class.constantize, expected_hash.with_indifferent_access
      described_class.run_schedulable valid_options
    end

    it "raises an error if a username is not given in settings" do
      valid_options.delete 'username'
      expect { described_class.run_schedulable valid_options }.to raise_error "username option must be set and point to an existing user."
    end

    it "raises an error if username does not point to a valid user" do
      valid_options['username'] = 'notauser'
      expect { described_class.run_schedulable valid_options }.to raise_error "username option must be set and point to an existing user."
    end

    it "raises an error if report_name is not given in settings" do
      valid_options.delete 'report_name'
      expect { described_class.run_schedulable valid_options }.to raise_error "report_name option must be set."
    end

    it "raises an error if report class is not given in settings" do
      valid_options.delete 'report_class'
      expect { described_class.run_schedulable valid_options }.to raise_error "report_class option must be set to a valid report class."
    end

    it "raises an error if report_class points to an un-instantiable class" do
      valid_options['report_class'] = "NotAnActualClass"
      expect { described_class.run_schedulable valid_options }.to raise_error "report_class option must be set to a valid report class."
    end

    it "raises an error if report_class implements permission? and returns false" do
      expect(OpenChain::Report::KewillCurrencyRatesReport).to receive(:permission?).with(user).and_return false
      expect { described_class.run_schedulable valid_options }.to raise_error "User #{user.username} does not have permission to run this scheduled report."
    end

    it "raises an error if report_class implements can_view? and returns false" do
      expect(OpenChain::Report::KewillCurrencyRatesReport).to receive(:permission?).with(user).and_return true
      expect(OpenChain::Report::KewillCurrencyRatesReport).to receive(:can_view?).with(user).and_return false

      expect { described_class.run_schedulable valid_options }.to raise_error "User #{user.username} does not have permission to run this scheduled report."
    end

    it "raises an error if report_class does not respond to run_report" do
      valid_options['report_class'] = "String"
      expect { described_class.run_schedulable valid_options }.to raise_error "report_class String must implement the run_report method."
    end
  end
end