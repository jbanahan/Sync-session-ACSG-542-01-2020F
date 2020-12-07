module OpenChain; module RakeSupport
  extend ActiveSupport::Concern

  def get_user_response message, default_value: nil, input_test: nil
    message += " [Default = #{default_value}]" unless default_value.nil?
    message += " : "

    valid = false
    value = nil
    while(!valid) do
      STDOUT.print message
      STDOUT.flush
      value = STDIN.gets.strip
      if !default_value.nil? && value.blank?
        value = default_value
      end
      value

      if input_test
        error = input_test.call(value)
        valid = error.blank?
        puts error unless valid
      else
        valid = true
      end
    end

    value
  end

  def run_command command, print_output: false, exit_on_failure: false
    stdout, stderr, status = Open3.capture3({}, *command)
    success = status.success?
    exit(1) if exit_on_failure && !success

    stderr = stderr.to_s.strip
    stdout = stdout.to_s.strip
    stderr = nil if stderr.length == 0
    stdout = nil if stdout.length == 0

    puts stdout if print_output && !stdout.nil?
    puts stderr if !success && !stderr.nil?
    [status, stdout, stderr]
  end

  def run command
    status, stdout, stderr = run_command(command, exit_on_failure: true)
    stdout
  end
end; end