require_relative 'rake_support'

class UploadEnvironment
  include Rake::DSL
  include OpenChain::RakeSupport

  def initialize
    namespace :environment do
      desc "Uploads specified environment variable file to AWS Parameter Store"
      task upload: :environment do
        upload_environment_file
      end
    end
  end

  private

    def upload_environment_file
      namespace = namespace_from_user
      environment_file = environment_file_from_user

      env = Dotenv::Environment.new(environment_file, true)
      parameters = format_environment_variables_for_ssm_upload(env)
      puts ""
      puts "Please review and confirm the parameter keys that will be created/updated: "
      puts ""
      parameters.each_pair do |key, value|
        puts "/#{MasterSetup.internal_product_name}/#{namespace}#{key} = #{value}"
      end
      puts ""
      proceed = get_user_response "Proceed with uploading all environment values (Y or N)?"
      exit(1) unless proceed.to_s.upcase.strip == "Y"

      upload_environment_variables namespace, parameters
      puts "All environment variables from file '#{environment_file}' have been uploaded to AWS Parameter Store."
    end

    def namespace_from_user
      namespace = nil
      while namespace.nil?
        namespace = get_user_response "What deployment namespace should I use?"
        valid = get_user_response "Using '#{namespace}'.  Is this correct (Y or N)?"
        namespace = nil unless valid.to_s.upcase.strip == "Y"
      end

      namespace
    end

    def environment_file_from_user
      environment_file = nil
      while environment_file.nil?
        response = get_user_response "What environment file should I upload?", default_value: default_environment_filename
        if File.exist? response
          environment_file = response
        else
          puts "Environment file '#{response}' does not exist."
        end
      end

      environment_file
    end

    def format_environment_variables_for_ssm_upload environment_variables
      parameters = {}
      environment_variables.each_pair do |key, value|
        parameters["/environment_variables/#{key}"] = value
      end
      parameters
    end

    def default_environment_filename
      ".env.production.local"
    end

    def upload_environment_variables namespace, parameters
      require 'open_chain/ssm' unless defined?(OpenChain::Ssm)
      OpenChain::Ssm.upload_parameters parameters, namespace: namespace
    end
end

UploadEnvironment.new