require 'aws-sdk-cloudwatch'
require 'open_chain/aws_config_support'

module OpenChain; class CloudWatch
  extend OpenChain::AwsConfigSupport

  @@default_dimensions = {}
  cattr_reader :default_dimensions

  # Don't use this unless you know what you're doing and are intending on
  # adding new global dimensions to all metrics
  def self.add_default_dimension name, value
    default_dimensions[name] = value
    nil
  end

  # Logs the total number of queued jobs to the CloudWatch metric
  def self.send_delayed_job_queue_depth value
    put_metric_data("Delayed Job Queue Depth", value, "Count")
  end

  # Logs the total number of errored jobs to the CloudWatch metric
  def self.send_delayed_job_error_count value
    put_metric_data("Delayed Job Error Count", value, "Count")
  end

  class << self
    private

      # This method marshals the data together and sends it to Cloudwatch.
      # Metric Name - name of the metric
      # Value - the metric value (numeric)
      # Unit - One of the approved list of CloudWatch Units.  This is really just a graph label.
      # Dimensions - This basically is an additional set of name/value pairs you can associate with a specific custom metric as
      #              a way to partition the data.  By default, the System Code and Environment are added in production to ALL metrics.
      # Namespace - This is mostly just a way to categorize the metric data on the GUI for use under your own category/namespace.
      def put_metric_data metric_name, value, unit, dimensions: {}, namespace: "VFI Track", timestamp: Time.now, include_default_dimensions: true
        request = {
          namespace: namespace,
          metric_data: [metric_hash(metric_name, value, unit, dimensions, timestamp, include_default_dimensions)]
        }

        cloudwatch_client.put_metric_data request
        nil
      end

      def metric_hash metric_name, value, unit, dimensions, timestamp, include_default_dimensions
        h = {
          metric_name: metric_name,
          value: value,
          unit: unit,
          timestamp: timestamp
        }

        if include_default_dimensions
          dimensions = append_default_dimensions(dimensions)
        end

        if !dimensions.blank?
          h[:dimensions] = dimensions
        end

        h
      end

      def append_default_dimensions dimensions
        if default_dimensions.size > 0
          dimensions = default_dimensions.dup.merge dimensions
        end

        dimensions.map {|k, v| {name: k, value: v} }
      end

      def cloudwatch_client
        # Do not push cloudwatch metrics in test...each custom metric costs $.50, so lets not waste money
        # if something is accidently not mocked out (plus it muddies up the metric dashboard).
        raise "Client must be mocked out in test." if Rails.env.test?

        ::Aws::CloudWatch::Client.new(aws_config)
      end
  end

end; end