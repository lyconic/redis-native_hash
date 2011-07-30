require 'securerandom'

class Redis
  class BigHash
    include KeyHelpers

    attr_accessor :namespace

    def initialize( key = nil, namespace = nil )
      self.key       = key
      self.namespace = namespace
      super(nil)
    end

    def [](hash_key)
      Redis::Marshal.load( redis.hget(redis_key, convert_key(hash_key)) )
    end

    def []=(hash_key, value)
      redis.hset( redis_key, convert_key(hash_key), Redis::Marshal.dump(value) )
    end

    def key=(new_key)
      new_key = generate_key if new_key.nil?
      unless @key.nil? || @key == new_key
        keys.each do |k|
          redis.hset( redis_key(new_key), k,
            redis.hget(redis_key, k) )
        end
        clear
      end
      @key = new_key
    end

    def keys
      redis.hkeys redis_key
    end

    def key?(hash_key)
      keys.include?(convert_key(hash_key))
    end
    alias_method :include?, :key?
    alias_method :has_key?, :key?
    alias_method :member?,  :key?

    def update(other_hash)
      writes = []
      other_hash.each_pair do |hash_key, value|
        writes << hash_key.to_s
        writes << Redis::Marshal.dump( value )
      end
      redis.hmset(redis_key, *writes)
    end
    alias_method :merge,  :update
    alias_method :merge!, :update

    def delete(hash_key)
      current_value = self[hash_key]
      redis.hdel( redis_key, hash_key )
      current_value
    end

    def clear
      redis.del redis_key
    end
    alias_method :destroy, :clear

    private

      def redis
        NativeHash.redis
      end

  end
end

