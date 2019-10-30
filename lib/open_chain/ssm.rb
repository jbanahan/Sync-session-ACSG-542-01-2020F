require 'aws-sdk-ssm'
require 'open_chain/aws_config_support'
require 'open_chain/aws_util_support'

module OpenChain; class Ssm
  extend OpenChain::AwsConfigSupport
  extend OpenChain::AwsUtilSupport

  def self.send_clear_upgrade_errors_command working_directory: nil, instance_targets: nil
    if instance_targets.blank?
      instance_targets = default_vfitrack_targets 
    else
      instance_targets = create_targets_params(instance_targets)
    end
    
    working_directory = MasterSetup.instance_directory.to_s if working_directory.blank?
    send_run_shell_script_command(working_directory, "script/clear_upgrade_errors.sh", instance_targets: instance_targets)
    true
  end

  class << self
    private 

    def send_run_shell_script_command working_directory, commands, instance_targets: nil, instance_ids: nil
      command_params = {
        document_name: run_script_document,
        targets: instance_targets,
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

    def default_vfitrack_targets
      group = InstanceInformation.deployment_group
      raise "AWS 'Group' tag must be set for all VFI Track instances." if group.blank?
      create_targets_params({"Application" => "VFI Track", "Role" => ["Web", "Job Queue"], "Group" => group})
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
  end
end; end;