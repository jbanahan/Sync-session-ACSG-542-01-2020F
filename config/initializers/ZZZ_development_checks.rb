if Rails.env.development?
  # Ensure memcache and redis are running...otherwise many things will fail.  Only dev since that's the only environment where redis may actually not be there
  # (like on first time start-ups)
  CacheWrapper.ensure_memcache_access
  Lock.ensure_redis_access
end
