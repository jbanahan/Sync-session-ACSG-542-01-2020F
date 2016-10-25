module OpenChain; module AwsConfigSupport

  # Passing a region param allows overriding the default region...needed for some cross region accesses.
  def aws_config region: nil
    conf = {region: AWS_CREDENTIALS["region"], credentials: ::Aws::Credentials.new(AWS_CREDENTIALS["access_key_id"], AWS_CREDENTIALS["secret_access_key"])}
    conf[:region] = region unless region.blank?
    conf
  end

end; end