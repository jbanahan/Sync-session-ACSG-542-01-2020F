class BuildEnvironment
  include Rake::DSL

  def initialize
    namespace :environment do
      desc "Downloads and builds environment files"

      task :build do # rubocop:disable Rails/RakeEnvironment
        load_environment_files
      end
    end
  end

  private

    def load_environment_files
      args = parse_args
      puts "Outputting Parameter Store environment variables using namespace '#{args[:namespace]}' to #{args[:filename]}..."
      params = retrieve_ssm_parameters args
      write_parameters args[:filename], params
    end

    def retrieve_ssm_parameters command_line_args
      require 'aws-sdk-ssm'
      parameters = {}

      # Purposely NOT using the MasterSetup.internal_product_name method (open_chain) because this rake task is meant to be run without the rails
      # environment initialized.
      path = "/open_chain/#{command_line_args[:namespace]}/environment_variables"
      response = nil
      begin
        # Uses the PageableResponse interface to make sure we get all vars downloaded...only 10 are returned
        # per API call
        if response.nil?
          response = ssm_client.get_parameters_by_path(path: path, recursive: true, with_decryption: true)
        else
          response = response.next_page
        end

        response.parameters.each do |param|
          # The apostrophe wrapping tells Dotenv the value is a literal - which we want everything to be

          # There's still some issues that may result from this if env vars have some character sequences.
          # The only true way to deal with that seems to potentially be using Base64 to encode the string
          # Perhaps we can mark the env var name as B64_VAR_NAME and then transform it when it's loaded?
          parameters[param["name"].split("/").last.upcase] = "'#{param["value"]}'"
        end
      end while response&.next_page?

      # Sort the params since they could get returned in any order...this just makes it easier
      # to find var names if you need to manually inspect the file.
      sorted_params = {}
      parameters.keys.sort.each do |key|
        sorted_params[key] = parameters[key]
      end
      sorted_params
    end

    def parse_args
      # Purposely NOT using the MasterSetup.env method because this rake task is meant to be run without the rails
      # environment initialized.
      options = {namespace: ENV["SSM_PARAMETER_STORE_NAMESPACE"]}
      # Use the cwd name as the default namespace.
      # We can do this at the moment, because all our deployment directory names are the namespace names we're looking for from the parameter store.
      # In other words, if the project is deployed into the /path/to/customer_name folder, customer_name is the namespace the parameters will have
      options[:namespace] = File.basename(Dir.pwd) if blank?(options[:namespace])

      if blank? ENV["DOTENV_FILENAME"]
        options[:filename] = ".env.#{ENV["RAILS_ENV"]}.local"
      else
        options[:filename] = ENV["DOTENV_FILENAME"]
      end

      options
    end

    def write_parameters filename, parameters
      File.open(filename, "w") do |file|
        parameters.each_pair do |key, value|
          file.puts "#{key}=#{value}"
        end
      end

      nil
    end

    def ssm_client
      # When an AWS client is initialized without any configuration values it falls back to loading from distinct system settings
      # (ENV vars, ~/.aws/config files, and then any role the server may be using).  We're relying on at least one of these being set up for the server,
      # in this particular case it should be that the server is running under an IAM role that can query the SSM parameter store
      region = blank?(ENV["AWS_REGION"]) ? 'us-east-1' : ENV["AWS_REGION"]
      Aws::SSM::Client.new region: region
    end

    def blank? string
      string.to_s.length == 0
    end
end

# This will actually associate the rake task w/ the rake (since the DSL is referenced in the constructor)
BuildEnvironment.new
