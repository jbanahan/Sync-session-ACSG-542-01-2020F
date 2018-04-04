require 'spec_helper'

describe ValidationRuleEntryReleased do
  before :each do
    @rule = ValidationRuleEntryReleased.new(rule_attributes_json: {hold_date: 'ent_cbp_hold_date', release_date: 'ent_cbp_hold_release_date'}.to_json)
    @entry = Factory(:entry, entry_number: '1234', importer_id: 555)
  end

  it 'raises an error given an invalid release_date model field' do
    rule = ValidationRuleEntryReleased.new(rule_attributes_json: {hold_date: 'ent_cbp_hold_date', release_date: 'this_is_invalid'}.to_json)
    expect{rule.run_validation(@entry)}.to raise_error("Invalid Release model field value of this_is_invalid used")
  end

  it 'raises an error given an invalid hold_date model_field' do
    rule = ValidationRuleEntryReleased.new(rule_attributes_json: {hold_date: 'this_is_invalid', release_date: 'ent_cbp_hold_release_date'}.to_json)
    expect{rule.run_validation(@entry)}.to raise_error("Invalid Hold model field value of this_is_invalid used")
  end

  it 'handles a timezone option for failures' do
    rule = ValidationRuleEntryReleased.new(rule_attributes_json: {timezone: "America/Chicago", hold_date: 'ent_cbp_hold_date', release_date: 'ent_cbp_hold_release_date'}.to_json)
    Timecop.freeze(Time.zone.now) do
      @entry.cbp_hold_date = Time.zone.now
      @entry.cbp_hold_release_date = nil
      @entry.save
      @entry.reload
      expect(rule.run_validation(@entry)).to eql("Entry #{@entry.entry_number} is on hold. CBP Hold Date is #{Time.zone.now.in_time_zone("America/Chicago").strftime("%Y-%m-%d %H:%M %Z")}")
    end
  end

  it 'fails if hold field is populated and release field is not populated' do
    Timecop.freeze(Time.zone.now) do
      @entry.cbp_hold_date = Time.zone.now
      @entry.cbp_hold_release_date = nil
      @entry.save
      @entry.reload
      expect(@rule.run_validation(@entry)).to eql("Entry #{@entry.entry_number} is on hold. CBP Hold Date is #{Time.zone.now.in_time_zone("America/New_York").strftime("%Y-%m-%d %H:%M %Z")}")
    end
  end

  it 'passes if hold field is not populated' do
    @entry.cbp_hold_date = nil
    @entry.save
    @entry.reload
    expect(@rule.run_validation(@entry)).to be_nil
  end

  it 'passes if release field is populated' do
    @entry.cbp_hold_date = DateTime.now
    @entry.cbp_hold_release_date = DateTime.now
    @entry.save
    @entry.reload
    expect(@rule.run_validation(@entry)).to be_nil
  end
end