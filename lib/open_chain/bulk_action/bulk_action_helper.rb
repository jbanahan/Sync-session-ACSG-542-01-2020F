module OpenChain; module BulkAction; module BulkActionHelper

  def get_bulk_count pk_list, sr_id
    c = 0
    if pk_list
      c = pk_list.length
    elsif sr_id
      sr = SearchRun.find_by_id sr_id
      if sr
        c = sr.total_objects
      end
    end
    c
  end

end; end; end