require_relative "../redis_hash"

require 'securerandom'

class Redis
  class NativeHash < TrackedHash
    include ClientHelper
    include KeyHelper

    attr_accessor :namespace

    def initialize(aargh = nil)
      super(nil)
      case aargh
      when String,Symbol
        self.namespace = aargh
      when Hash
        self.namespace = aargh.keys.first
        self.key       = aargh.values.first
      end
      track!
    end

    def []=(key, value)
      super(convert_key(key), value)
    end
    alias_method :store, :[]=

    def fetch(key, *extras)
      super(convert_key(key),*extras)
    end

    def [](key)
       super convert_key(key)
    end

    def key?(key)
      super convert_key(key)
    end
    alias_method :include?, :key?
    alias_method :has_key?, :key?
    alias_method :member?,  :key?

    def delete(key)
      super convert_key(key)
    end

    def values_at(*indices)
      indices.collect { |key| self[ convert_key(key) ] }
    end

    def key=(new_key)
      renew_key(new_key)
    end

    attr_writer :version
    def version
      @version ||= generate_key
    end

    def save( max_attempts = 5 )
      (1..max_attempts).each do |n|
        redis.watch redis_key
        latest_version = redis.hget(redis_key, "__version")
        reload! unless ( latest_version.nil? || latest_version == self.version )
        self.version = nil # generate new version token
        changed_keys = (self.changed + self.added).uniq
        changes = []
        changed_keys.each do |key|
          changes.push( key, Redis::Marshaller.dump(self[key]) )
        end
        deleted_keys = self.deleted
        if deleted_keys.empty? and changes.empty?
          redis.unwatch
          return true
        end
        success = redis.multi do
          redis.hmset( redis_key, *changes.push("__version", self.version) ) unless changes.empty?
          deleted_keys.each { |key| redis.hdel( redis_key, key) }
        end
        if success
          untrack!; track! #reset hash
          return true
        end
      end
      raise "Unable to save hash after max attempts (#{max_attempts}). " +
            "Amazing concurrency event may be underway. " +
            "Make some popcorn."
      false
    end

    def update(data)
      v = case data
        when self.class
          data.version
        when ::Hash
          data.delete("__version")
        end
      self.version = v unless v.nil?
      super(data.stringify_keys!)
    end

    def replace(other_hash)
      clear
      update(other_hash)
    end

    def reload!
      hash = self.class.find( namespace ? {namespace => key} : key )
      self.update( hash ) if hash
    end
    alias_method :reload, :reload!

    def destroy
      redis.del( redis_key )
      untrack!
      clear
      self.key = nil
    end

    def renew_key(new_key = nil)
      unless @key.nil? || @key == new_key
        redis.del( redis_key )
        original.clear
      end
      @key = new_key
      key
    end

    def expire(seconds)
      redis.expire(redis_key, seconds)
    end

    class << self
      def find(params)
        case params
        when Hash
          hashes = []
          params.each_pair do |namespace, key|
            result = fetch_values( "#{namespace}:#{key}" )
            unless result.empty?
              hashes << build(namespace,key,result)
            end
          end
          unless hashes.empty?
            hashes.size == 1 ? hashes.first : hashes
          else
            nil
          end
        when String,Symbol
          unless self == Redis::NativeHash
            namespace = self.new.namespace.to_s
            namespace = "#{namespace}:" unless namespace.empty?
            result = fetch_values( "#{namespace}#{params}" )
          else
            result = fetch_values(params)
          end
          result.empty? ? nil : build(nil,params,result)
        end
      end

      def build(namespace, key, values)
        h = self.new
        h.namespace = namespace
        h.key = key
        h.populate(values)
        h
      end

      def fetch_values(key)
        results = redis.hgetall(key)
        results.each_pair { |key,value| results[key] = Redis::Marshaller.load(value) }
      end

      def attr_persist(*attributes)
        attributes.each do |attr|
          class_eval <<-EOS
            def #{attr}=(value)
              self["#{attr}"] = value
            end

            def #{attr}
              self["#{attr}"]
            end
          EOS
        end
      end

    end
  end
end

