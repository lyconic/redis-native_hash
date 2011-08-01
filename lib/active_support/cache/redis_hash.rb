require 'redis/native_hash'

module ActiveSupport
  module Cache
    class RedisHash < Store
      def initialize(*options)
        options = options.extract_options!
        super(options)
        @hash = ::Redis::BigHash.new(options[:key], options[:namespace] || :rails_cache)
        extend Strategy::LocalCache
      end

      # Reads multiple values from the cache using a single call to the
      # servers for all keys.
      def read_multi(*names)
        @hash[*names]
      end

      # Clear the entire cache on server. This method should
      # be used with care when shared cache is being used.
      def clear(options = nil)
        @hash.destroy
      end

      protected

        # Read an entry from the cache.
        def read_entry(key, options)
          @hash[key]
        end

        # Write an entry to the cache.
        def write_entry(key, entry, options)
          if options && options[:unless_exist]
            @hash.add(key, entry)
          else
            @hash[key] = entry
          end
        end

        # Delete an entry from the cache.
        def delete_entry(key, options)
          @hash.delete(key)
        end
    end
  end
end

