module OpenChain; module AwsConfigSupport

  # Passing a region param allows overriding the default region...needed for some cross region accesses.
  def aws_config region: nil
    conf = {region: MasterSetup.secrets["aws"]["region"], credentials: ::Aws::Credentials.new(MasterSetup.secrets["aws"]["access_key_id"], MasterSetup.secrets["aws"]["secret_access_key"])}
    conf[:region] = region unless region.blank?
    conf
  end

end; end