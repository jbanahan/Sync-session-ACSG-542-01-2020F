require 'spec_helper'

describe OpenChain::PollingJob do
  class FakePollingJob
    include OpenChain::PollingJob
  end

  subject { FakePollingJob.new }

  describe "poll" do
    it "determines last start time and current time and yields" do
      start_time = nil
      end_time = nil
      subject.poll {|s, e| start_time = s; end_time = e}

      # If the job has never been run before, the first start time defaults to 2000-01-01
      tz = ActiveSupport::TimeZone["UTC"]
      expect(start_time).to be_within(2.seconds).of(tz.parse(subject.null_start_time))
      expect(start_time.time_zone).to eq tz
      expect(end_time).to be_within(2.seconds).of(Time.zone.now)
      expect(end_time.time_zone).to eq tz

      # Look up the KeyJsonItem that should have been created and validate the last run time
      item = KeyJsonItem.polling_job("FakePollingJob").first
      expect(item.data['last_run']).to eq end_time.iso8601
    end

    it "updates an existing key json item object" do
      last_run = (Time.zone.now - 10.minutes)
      j = KeyJsonItem.polling_job("FakePollingJob").create! json_data: "{\"last_run\": \"#{last_run.iso8601}\"}"

      start_time = nil
      end_time = nil
      subject.poll {|s, e| start_time = s; end_time = e}

      expect(start_time.iso8601).to eq last_run.iso8601
      j.reload
      expect(j.data['last_run']).to eq end_time.iso8601
    end

    it "offsets times" do
      last_run = (Time.zone.now - 10.minutes)
      j = KeyJsonItem.polling_job("FakePollingJob").create! json_data: "{\"last_run\": \"#{last_run.iso8601}\"}"

      start_time = nil
      end_time = nil
      subject.poll(polling_offset: 60) {|s, e| start_time = s; end_time = e}

      # Offset the last start time that was in the key by subtracting one minute
      expect(start_time.iso8601).to eq (last_run - 1.minute).iso8601
      j.reload
      # The value in the last run key is going to be 1 minute quicker than the yielded end time due to the offset
      expect(j.data['last_run']).to eq (end_time + 1.minute).iso8601
    end

    it "uses different timezone if timezone method is overridden" do
      subject.should_receive(:timezone).and_return "Hawaii"

      start_time = nil
      end_time = nil
      subject.poll {|s, e| start_time = s; end_time = e}

      # If the job has never been run before, the first start time defaults to 2000-01-01
      tz = ActiveSupport::TimeZone["Hawaii"]
      expect(start_time).to eq tz.parse(subject.null_start_time)
      expect(start_time.time_zone).to eq tz
      expect(end_time).to be_within(2.seconds).of(Time.zone.now)
      expect(end_time.time_zone).to eq tz
    end

    it "raises an error (and doesn't log keyjsonitem) on bad timezone" do
      subject.stub(:timezone).and_return "Not a Timezone"

      expect { subject.poll {|s, e|} }.to raise_error "'Not a Timezone' is not a valid TimeZone."
      job = KeyJsonItem.polling_job("FakePollingJob").first
      expect(job.data).to be_empty
    end

    it "does not update key json item last_run if error is raised inside yielded block" do
      expect { subject.poll {|s, e| raise "Error"} }.to raise_error "Error"
      job = KeyJsonItem.polling_job("FakePollingJob").first
      expect(job.data).to be_empty
    end

    it "allows overridding null_start_time to provide different start time" do
      subject.stub(:null_start_time).and_return "2010-01-01T00:00:00-10:00"

      start_time = nil
      end_time = nil
      subject.poll {|s, e| start_time = s; end_time = e}
      tz = ActiveSupport::TimeZone["UTC"]
      expect(start_time).to eq tz.parse("2010-01-01T10:00:00Z")
      expect(start_time.time_zone).to eq tz
    end
  end

end