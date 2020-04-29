describe OpenChain::CloudWatch do
  subject { described_class }

  let (:client) { instance_double(Aws::CloudWatch::Client) }
  let (:default_dimensions) { {} }
  let (:now) { Time.zone.parse("2018-09-25 12:00") }

  before :each do
    allow(subject).to receive(:cloudwatch_client).and_return client
    allow(subject).to receive(:default_dimensions).and_return default_dimensions
  end

  around :each do |ex|
    Timecop.freeze(now) do
      ex.run
    end
  end

  describe "put_metric_data" do

    # This is testing a private method, but that's on purpose since every public method
    # for this class that sends metrics is just a feeder into this one w/ different params
    it "uses the cloudwatch client to send basic metric data" do
      expect(client).to receive(:put_metric_data).with({
        namespace: "VFI Track",
        metric_data: [
          {
            metric_name: "Name",
            value: 1,
            unit: "UNIT",
            timestamp: Time.zone.parse("2018-09-25 12:00")
          }
        ]
      })

      subject.send(:put_metric_data, "Name", 1, "UNIT")
    end

    it "includes default dimensions" do
      default_dimensions["Default1"] = "Value1"
      default_dimensions["Default2"] = "Value2"

      expect(client).to receive(:put_metric_data).with({
        namespace: "VFI Track",
        metric_data: [
          {
            metric_name: "Name",
            value: 1,
            unit: "UNIT",
            timestamp: Time.zone.parse("2018-09-25 12:00"),
            dimensions: [
              {name: "Default1", value: "Value1"},
              {name: "Default2", value: "Value2"}
            ]
          }
        ]
      })

      subject.send(:put_metric_data, "Name", 1, "UNIT")
    end

    it "allows overriding namespace" do
      expect(client).to receive(:put_metric_data).with({
        namespace: "NAMESPACE",
        metric_data: [
          {
            metric_name: "Name",
            value: 1,
            unit: "UNIT",
            timestamp: Time.zone.parse("2018-09-25 12:00")
          }
        ]
      })

      subject.send(:put_metric_data, "Name", 1, "UNIT", namespace: "NAMESPACE")
    end

    it "allows adding custom dimensions" do
      expect(client).to receive(:put_metric_data).with({
        namespace: "VFI Track",
        metric_data: [
          {
            metric_name: "Name",
            value: 1,
            unit: "UNIT",
            timestamp: Time.zone.parse("2018-09-25 12:00"),
            dimensions: [
              {name: "Dim1", value: "Val1"},
              {name: "Dim2", value: "Val2"}
            ]
          }
        ]
      })

      subject.send(:put_metric_data, "Name", 1, "UNIT", dimensions: {"Dim1" => "Val1", "Dim2" => "Val2"})
    end

    it "allows overriding timestamp" do
      ts = Time.zone.parse("2017-01-01 12:00")
      expect(client).to receive(:put_metric_data).with({
        namespace: "VFI Track",
        metric_data: [
          {
            metric_name: "Name",
            value: 1,
            unit: "UNIT",
            timestamp: ts
          }
        ]
      })

      subject.send(:put_metric_data, "Name", 1, "UNIT", timestamp: ts)
    end

    it "allows disabling the inclusion of default dimensions" do
      default_dimensions["Default1"] = "Value1"
      default_dimensions["Default2"] = "Value2"

      expect(client).to receive(:put_metric_data).with({
        namespace: "VFI Track",
        metric_data: [
          {
            metric_name: "Name",
            value: 1,
            unit: "UNIT",
            timestamp: Time.zone.parse("2018-09-25 12:00")
          }
        ]
      })

      subject.send(:put_metric_data, "Name", 1, "UNIT", include_default_dimensions: false)
    end

  end

  describe "send_delayed_job_queue_depth" do
    it "invokes put_metric_data" do
      expect(subject).to receive(:put_metric_data).with("Delayed Job Queue Depth", 10, "Count")

      subject.send_delayed_job_queue_depth 10
    end
  end

  describe "send_delayed_job_error_count" do
    it "invokes put_metric_data" do
      expect(subject).to receive(:put_metric_data).with("Delayed Job Error Count", 10, "Count")

      subject.send_delayed_job_error_count 10
    end
  end

  describe "add_default_dimension" do
    before :each do
      @dims = subject.default_dimensions.dup
      subject.default_dimensions.clear
    end

    after :each do
      subject.default_dimensions.clear
      subject.default_dimensions.merge! @dims
    end

    it "adds to default dimensions" do
      subject.add_default_dimension "Name", "Value"

      # adding a default dimension means it should show up in a metric put
      dimensions = nil
      expect(client).to receive(:put_metric_data) do |request|
        dimensions = request[:metric_data].first[:dimensions]
      end

      subject.send(:put_metric_data, "Name", 1, "Unit")
      expect(dimensions).not_to be_nil
      expect(dimensions).to eq [{name: "Name", value: "Value"}]
    end
  end
end