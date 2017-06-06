require 'open_chain/s3'
require 'digest/md5'

module OpenChain; module BulkAction; class BulkActionRunner
  def self.process_from_parameters user, params, action_class, opts
    if params['sr_id'] && params['sr_id'].to_s.match(/^[0-9]+$/)
      self.process_search_run user, SearchRun.find(params['sr_id']), action_class, opts
    elsif params['pk'].is_a?(Hash) && params['pk'].length > 0
      self.process_object_ids user, params['pk'].values, action_class, opts
    else
      raise "Invalid parameters, missing sr_id or pk array: #{params.to_s}"
    end
  end
  def self.process_search_run user, search_run, action_class, opts
    ids = search_run.find_all_object_keys.to_a
    raise TooManyBulkObjectsError if opts[:max_results].present? && opts[:max_results].to_i < ids.length
    process_object_ids user, ids, action_class, opts
  end
  def self.process_object_ids user, ids, action_class, opts
    data = {user_id:user.id,keys:ids,opts:opts}.to_json
    s3_key = "#{MasterSetup.get.uuid}/bulk_action_run/#{Digest::MD5.hexdigest(data)}-#{Time.now.to_i}.json"
    OpenChain::S3.upload_data OpenChain::S3.bucket_name, s3_key, data
    self.delay.run_s3 s3_key, action_class
  end
  def self.run_s3 key, action_class
    ActiveRecord::Base.transaction do
      data = JSON.parse(OpenChain::S3.get_data(OpenChain::S3.bucket_name,key))
      u = User.find data['user_id']
      BulkProcessLog.with_log(u,action_class.bulk_type) do |bpl|
        data['keys'].each_with_index do |id,idx|
          action_class.act u, id, data['opts'], bpl, idx+1
        end
      end
      OpenChain::S3.delete(OpenChain::S3.bucket_name,key)
    end
  end
end; end; end

module OpenChain; module BulkAction; class TooManyBulkObjectsError < StandardError

end; end; end;
