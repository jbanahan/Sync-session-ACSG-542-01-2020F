class CacheWrapper

  def initialize(cache)
    @cache = cache
  end

  def set key, val
    error_wrap {@cache.set key, val}
  end

  def get key
    error_wrap {@cache.get key}
  end

  def delete key
    error_wrap {@cache.delete key}
  end

  private
  def error_wrap &block
    begin
      yield
    rescue
      $!.email_me
    end
  end

end
