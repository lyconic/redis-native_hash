require 'securerandom'

class Redis
  class BigHash
    include ClientHelper
    include KeyHelper

    attr_reader :namespace

    def initialize( key = nil, namespace = nil )
      @key       = key
      @namespace = namespace
    end

    def [](*hash_keys)
      if hash_keys.one?
        Redis::Marshal.load( redis.hget(redis_key, convert_key(hash_keys.first)) )
      elsif hash_keys.any?
        values = redis.hmget( redis_key, *hash_keys.map{ |k| convert_key(k) } )
        values.map{ |v| Redis::Marshal.load(v) }
      end
    end

    def []=(hash_key, value)
      redis.hset( redis_key, convert_key(hash_key), Redis::Marshal.dump(value) )
    end

    # set only if key doesn't already exist
    # equivilent to doing `hash[:key] ||= value`, but more efficient
    def add(hash_key, value)
      redis.hsetnx( redis_key, convert_key(hash_key), Redis::Marshal.dump(value) )
    end

    def key=(new_key)
      new_key = generate_key if new_key.nil?
      unless @key.nil? || @key == new_key
        self.class.copy_hash( redis_key, redis_key(new_key) )
        clear
      end
      @key = new_key
    end

    def namespace=(new_namespace)
      unless new_namespace == namespace
        self.class.copy_hash( redis_key, redis_key(key, new_namespace) )
        clear
        @namespace = new_namespace
      end
    end

    def keys
      self.class.keys redis_key
    end

    def key?(hash_key)
      keys.include?(convert_key(hash_key))
    end
    alias_method :include?, :key?
    alias_method :has_key?, :key?
    alias_method :member?,  :key?

    def size
      redis.hlen redis_key
    end
    alias_method :count,  :size
    alias_method :length, :size

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

    class << self
      def keys(redis_key)
        redis.hkeys redis_key
      end

      def copy_hash(source_key, dest_key)
        keys(source_key).each do |k|
          redis.hset( dest_key, k,
            redis.hget(source_key, k) )
        end
      end
    end
  end
end

