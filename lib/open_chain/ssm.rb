require 'aws-sdk-ssm'
require 'open_chain/aws_config_support'
require 'open_chain/aws_util_support'

module OpenChain; class Ssm
  extend OpenChain::AwsConfigSupport
  extend OpenChain::AwsUtilSupport

  def self.send_clear_upgrade_errors_command
    send_run_shell_script_command("script/clear_upgrade_errors.sh", target_hash: vfitrack_all_servers())
    true
  end

  def self.send_restart_web_server_command
    send_run_shell_script_command("script/restart_application_server.sh", target_hash: vfitrack_web_servers())
    true
  end

  def self.send_restart_job_queue_command
    run_as_command = run_command_in_user_shell(MasterSetup.server_user_account, "script/restart_job_queue.sh", working_directory: MasterSetup.instance_directory.to_s)
    send_run_shell_script_command(run_as_command, target_hash: vfitrack_job_queue_servers())
    true
  end

  def self.send_restart_job_queue_service_command
    send_run_shell_script_command("script/restart_job_queue_service.sh", target_hash: vfitrack_job_queue_servers())
    true
  end

  def self.install_required_gems_command
    run_as_command = run_command_in_user_shell(MasterSetup.server_user_account, "bundle install", working_directory: MasterSetup.instance_directory.to_s)
    send_run_shell_script_command(run_as_command, target_hash: vfitrack_all_servers())
    true
  end

  # Uploads hash of parameters to SSM Parameter Store.
  # * parameters - The key of the parameters will be used as the SSM parameter "name" value. Each key will
  #   be prefixed using the given product_name and namespace.  Such that the parameter prefix will be composed like: "/#{product_name}/#{namespace}".
  # * product_name - Defaults to "open_chain", you shouldn't need to change this
  # * namespace - In general, this should be the deployment host (.ie www, target, polo, etc, MasterSetup.secrets.host).
  def self.upload_parameters parameters, namespace:, product_name: MasterSetup.internal_product_name, encrypt: true
    parameters.each_pair do |key, value|
      name = "/#{product_name}/#{namespace}/#{(key[0] == "/") ? key[1..-1] : key}"
      description = nil
      param_type = encrypt ? "SecureString" : "String"
      overwrite = true
      param_value = value
      if value.is_a?(Hash)
        param_value = value[:value]
        param_type = "String" if value[:encrypt] == false
        overwrite = value[:overwrite] if value[:overwrite] == false
        description = value[:description]
      end
      ssm_client.put_parameter(name: name, value: param_value, description: description, type: param_type, overwrite: overwrite)
    end

    true
  end

  class << self
    private

    def send_run_shell_script_command commands, target_hash: nil, instance_ids: nil, working_directory: nil
      # This SSM runs only on AWS managed instances, the ONLY time this call should be executed is on an ec2 instance (.ie in a production environment)
      return nil unless MasterSetup.production_env?

      # By default, we're going to exeute commands in the base directory of the instance that's executing the commands
      working_directory = MasterSetup.instance_directory.to_s if working_directory.blank?
      # Convert the simple hash into the actual target params the SSM command expectes
      instance_targets = target_hash.blank? ? nil : create_targets_params(target_hash)

      # We want to ensure in some manner that this command isn't invoked on every SSM capable system we have...so make sure
      # that instance_ids are specified or a target hash is given
      raise ArgumentError, "All SSM command invocations must include a target_hash or instance_ids." if target_hash.blank? && instance_ids.blank?

      command_params = {
        document_name: run_script_document,
        timeout_seconds: default_timeout,
        parameters: {
          commands: Array.wrap(commands),
          executionTimeout: ["3600"],
          workingDirectory: [working_directory]
        }
      }

      if !instance_targets.blank?
        command_params[:targets] = instance_targets
      end

      if !instance_ids.blank?
        command_params[:instance_ids] = Array.wrap(instance_ids)
      end

      ssm_client.send_command command_params
    end

    def vfitrack_all_servers
      add_roles(default_app_group_hash, ["Web", "Job Queue"])
    end

    def vfitrack_web_servers
      add_roles(default_app_group_hash, "Web")
    end

    def vfitrack_job_queue_servers
      add_roles(default_app_group_hash, "Job Queue")
    end

    def default_app_group_hash
      target_hash = {}
      add_default_application(target_hash)
      add_default_group(target_hash)
      target_hash
    end

    def add_default_application target_hash
      target_hash["Application"] = "VFI Track"
      target_hash
    end

    def add_default_group target_hash
      group = InstanceInformation.deployment_group
      raise "AWS 'Group' tag must be set for all VFI Track instances." if group.blank?

      target_hash["Group"] = group
      target_hash
    end

    def add_roles target_hash, roles
      target_hash["Role"] = roles
      target_hash
    end

    def create_targets_params tags
      targets = []
      tags.each_pair do |tag_name, tag_value|
        targets << {key: "tag:#{tag_name}", values: Array.wrap(tag_value)}
      end
      targets
    end

    def default_timeout
      600
    end

    def run_script_document
      "AWS-RunShellScript"
    end

    def ssm_client
      ::Aws::SSM::Client.new(aws_config)
    end

    # What's happening here is that an SSM command runs as root.  There are cases where we need to run a
    # command as a non-root user - generally as ubuntu.  This happens primarily because we're using rvm
    # to install / manage multiple ruby versions on the servers.  In that case, in order to execute any
    # scripts / services that rely on RVM setting up paths, we need to actually run the command through
    # a shell that's init with RVM in it under the user.
    #
    # This method uses some sudo tricks to be able to do that.
    def run_command_in_user_shell username, command, working_directory: nil
      escaped_command = escape_command(command)

      if !working_directory.blank?
        escaped_command = "cd #{escape_command(working_directory)} && #{escaped_command}"
      end

      # Because we're not wrapping username in quotes (the sudo command fails if we try that)
      # Then we should add standard shellword escaping for the username
      "sudo -n -H -i -u #{Shellwords.escape(username)} /bin/bash -l -c \"#{escaped_command}\""
    end

    def escape_command command
      # We're adding quotes to commands when we send them so we don't actually have to use Shellwords
      # to escape the command.  All we'd need to do is make sure that any "" are escaped as \"
      command.gsub('"', '\"')
    end
  end
end; end;