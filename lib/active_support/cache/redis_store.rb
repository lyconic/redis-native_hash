module ActiveSupport
  module Cache
    class RedisStore < Store
      def initialize(*options)
        options = options.extract_options!
        super(options)
        extend Strategy::LocalCache
      end

      # Reads multiple values from the cache using a single call to the
      # servers for all keys.
      def read_multi(*names)
        values = redis.mget *names
        values.map{ |v| Redis::Marshal.load(v) }
      end

      # Clear the entire cache on server. This method should
      # be used with care when shared cache is being used.
      def clear(options = nil)
        redis.flushdb
      end

      protected

        # Read an entry from the cache.
        def read_entry(key, options)
          puts "inside #read_entry(#{key},#{options.inspect})"
          Redis::Marshal.load(redis.get(key))
        end

        # Write an entry to the cache.
        def write_entry(key, entry, options)
          puts "writing cache entry #{key}: #{entry.class} (#{entry.size rescue 0} bytes)"
          method = options && options[:unless_exist] ? :setnx : :set
          expires_in = options[:expires_in].to_i
          redis.send(method, key, Redis::Marshal.dump(entry))
          redis.expire(key, expires_in) if expires_in > 0
        end

        # Delete an entry from the cache.
        def delete_entry(key, options)
          redis.del(key)
        end
        def redis
          self.class.redis
        end

      class << self
        def redis
          @@redis ||= Redis::NativeHash.redis
        end
        def redis=(client)
          @@redis = client
        end
      end
    end
  end
end

