require 'open_chain/json_http_client'
require 'digest/md5'

# The whole purpose of this class is to provide a simple means of syncing
# object information via the VFI Track API from one source system to another 
# on a schedulable basis.
#
# The intent is that the system this code is running on is the 'master' data 
# source and the destination is merely a 'slave' or remote copy of all or a portion of the data. 
#
# You should extend this class and implement the following instance methods:
# 
# retrieve_remote_data - Using whatever API call you want, retrieve the remote data you want to sync.  The 
# default expectation is that this data has a to_json method on it - you may work around this expectation
# by providing your own implementation of #remote_data_fingerprint (which may return nil to disable remote fingerprinting)
#
# merge_remote_data_with_local - Write a process to merge the data returned by your retrieve_remote_data implementation
# with the ApiSyncObject#local_data returned from your local sync implementation (.ie the data returned by 
# 'process_query_result' or 'process_object_result')
#
# send_remote_data - Using whatever API call you want, push the merged data to the remote service.  The sync
# is considered to have been successful as long as no error is raised by this call.
#
# If you intend to retrieve sync data via a straight sql query, implement the following 2 methods:
#
# query - Return a sql query that will return all the product data that should be synced.
# process_query_result - Returns one or multiple ApiSyncObject structs that are the result of processing the result set row.
# Return nil to skip sending data for a particular row.  If you're buffering query result data, use the :last_result option
# passed to the  method to determine if any more result rows will be passed to this method.
#
# If you intend to retrieve sync data via an ActiveRecord base query, implement the following 2 methods:
# 
# objects_to_sync - Return an ActiveRecord::Relation that will return all the product data that should be synced.
# NOTE: the relation will have a limit applied to it and multiple passes over the data will be made until no results remain.
#
# process_object_result - Returns one or multiple ApiSyncObject structs that are the result of processing the result set row.
# Return nil to skip sending data for a particular object
#
module OpenChain; module CustomHandler; class ApiSyncClient

  ApiSyncObject = Struct.new(:syncable_id, :local_data)

  def sync
    raise "#{self.class} must respond to the 'query' method or the 'objects_to_sync' method." unless respond_to?(:query) || respond_to?(:objects_to_sync)

    @error_ids = Set.new
    if respond_to?(:objects_to_sync)
      sync_via_objects {|sync_objects| do_multiple_sync(sync_objects)}
    else
      sync_via_query {|sync_objects| do_multiple_sync(sync_objects)}
    end
  end

  protected 
    def sync_via_query
      results = nil
      # Just keep trying to sync while there are results remaining (and we acutally sent 
      # at least one valid result), this way the query can define a limit or not and we 
      # don't care about it either way.
      begin
        results = ActiveRecord::Base.connection.execute query

        num_results = results.size
        result_ids = nil
        results.each_with_index do |cols, x|
          result_ids = Set.new
          # Indicate a last_result option since preprocess rows might be internally buffering results
          # so as to merge multiple query rows into a single JSON object
          sync_objects = process_query_result cols, last_result: (num_results == (x + 1))
          if sync_objects
            result_ids.merge(Array.wrap(sync_objects).map(&:syncable_id))
            yield sync_objects
          end

        end
      end while results.size > 0 && had_valid_result_data?(result_ids)
      
    end

    def sync_via_objects
      max_results = max_object_results
      begin
        count = 0
        result_ids = nil
        # Objects to sync should return a relation that obeys limits
        objects_to_sync.limit(max_results).each do |obj|
          result_ids = Set.new
          count += 1
          sync_objects = process_object_result obj
          if sync_objects
            result_ids.merge(Array.wrap(sync_objects).map(&:syncable_id))
            yield sync_objects
          end
        end
      end while count == max_results && had_valid_result_data?(result_ids)
    end

    def do_sync sync_object
      # Don't bother re-syncing if the object errored in this session
      return if errored_ids.include?(sync_object.syncable_id)

      local_data = sync_object.local_data
      local_fingerprint = local_data_fingerprint local_data
      begin
        # Find the sync record associated w/ this product and see if we need to bother sending this data
        sr = nil
        synced = false
        if local_fingerprint
          sr = SyncRecord.where(syncable_id: sync_object.syncable_id, syncable_type: syncable_type, trading_partner: sync_code).first
          if sr
            # If there isn't a sent at date, or if there's a send problem then we should ignore the fingerprint and try resending regardless
            if sr.sent_at && !sr.problem? && local_fingerprint == sr.fingerprint
              save_sync_record sync_object, local_fingerprint, sr
              synced = true
            end
          end
        end

        return if synced

        # At this point, we need to request the remote data, then merge it with the localized data and then send it back to the remote server
        remote_data = retrieve_remote_data(local_data)

        # Another optimization..we can fingerprint the remote data as we've received it and then compare it to the data we get back from 
        # the merge call.  If it's the same, then we don't have to bother with the save/update call.
        remote_fingerprint = remote_data_fingerprint(remote_data) unless remote_data.nil?

        # Now merge the remote data w/ the local data
        remote_data = merge_remote_data_with_local remote_data, local_data

        # Take another fingerprint...if they are the same..then we don't have to bother pushing the record either
        if remote_fingerprint && remote_data_fingerprint(remote_data) == remote_fingerprint
          save_sync_record sync_object, local_fingerprint, sr
        else
          # Push the data to the remote server, as long as the call returns without raising an error we'll assume we can considering it synced
          send_remote_data(remote_data)

          save_sync_record sync_object, local_fingerprint, sr
        end
      rescue => e
        errored_ids << sync_object.syncable_id

        e.log_me ["Failed to sync #{syncable_type} data #{sync_object.local_data}."]
        save_sync_record sync_object, local_fingerprint, nil, e.message
        raise e if raise_sync_error?
      end
    end

    def local_data_fingerprint local_data
      # The simplest and most consistent way to get a fingerprint of the local data is to just 
      # jsonize it and md5 it.  This only works when the local data consists solely of json'izable 
      # types..primatives + hash + array.  If the local data isn't one of those, extending classes
      # will need to provide their own implementation of local_data_fingerprint...which could
      # just be returning nil and doing away w/ this optimization all-together
      Digest::MD5.hexdigest local_data.to_json
    end

    def remote_data_fingerprint remote_data
      Digest::MD5.hexdigest remote_data.to_json
    end

    def max_object_results
      500
    end

  private

    def raise_sync_error?
      Rails.env.test?
    end

    def do_multiple_sync sync_objects
      Array.wrap(sync_objects).each do |jo|
        do_sync jo
      end
    end

    def save_sync_record sync_object, local_fingerprint, sr = nil, sync_error = nil
      if sr.nil?
        sr = SyncRecord.where(syncable_id: sync_object.syncable_id, syncable_type: syncable_type, trading_partner: sync_code).first_or_create!
      end
      Lock.with_lock_retry(sr) do
        sr.fingerprint = local_fingerprint
        sr.sent_at = Time.zone.now
        # Don't set the confirmed at if there was a sync_error
        if sync_error.blank?
          sr.confirmed_at = (sr.sent_at + 1.minute)
        end
        sr.failure_message = sync_error
        sr.confirmation_file_name = nil
        sr.save!
      end
      sr
    end

    def had_valid_result_data? result_ids
      # If every result id is listed in the error list, then return false
      intersection = (result_ids & @error_ids)
      intersection.length < result_ids.length
    end

    def errored_ids
      @error_ids ||= Set.new
    end

end; end; end;