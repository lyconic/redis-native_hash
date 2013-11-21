module ActiveSupport
  module Cache
    class RedisStore < Store
      include Redis::ClientHelper
      def initialize(*options)
        options = options.extract_options!
        super(options)
        extend Strategy::LocalCache
      end

      # Reads multiple values from the cache using a single call to the
      # servers for all keys.
      def read_multi(*names)
        values = redis.mget *names
        values.map{ |v| Redis::Marshaller.load(v) }
      end

      # Clear the entire cache on server. This method should
      # be used with care when shared cache is being used.
      def clear(options = nil)
        redis.flushdb
      end

      protected

        # Read an entry from the cache.
        def read_entry(key, options)
          Redis::Marshaller.load(redis.get(key))
        end

        # Write an entry to the cache.
        def write_entry(key, entry, options)
          method = options && options[:unless_exist] ? :setnx : :set
          expires_in = options[:expires_in].to_i
          redis.send(method, key, Redis::Marshaller.dump(entry))
          redis.expire(key, expires_in) if expires_in > 0
        end

        # Delete an entry from the cache.
        def delete_entry(key, options)
          redis.del(key)
        end
    end
  end
end

