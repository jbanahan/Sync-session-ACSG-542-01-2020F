module OpenChain; module AwsConfigSupport

  def aws_config
    {region: AWS_CREDENTIALS["region"], credentials: ::Aws::Credentials.new(AWS_CREDENTIALS["access_key_id"], AWS_CREDENTIALS["secret_access_key"])}
  end

end; end