require 'redis'
require 'core_ext/hash' unless defined?(ActiveSupport)
require 'redis/marshal'
require 'redis/tracked_hash'

if defined?(Rack::Session)
  require "rack/session/abstract/id"
  require 'rack/session/redis_hash'
end

require 'securerandom'

class Redis
  class NativeHash < TrackedHash

    attr_accessor :namespace

    def initialize(*args)
      super(nil)
      track!
      if args.first.kind_of?(String) or args.first.kind_of?(Symbol)
        self.namespace = args.shift
      elsif !self.instance_of?(NativeHash) # use class name as default namespace for user defined classes
        self.namespace = self.class.to_s.downcase
      end
      data = args.shift
      update(data) if data.kind_of?(Hash)
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

    def key
      @key ||= self.class.generate_key
    end

    def key=(new_key)
      renew_key(new_key)
    end

    attr_writer :version
    def version
      @version ||= self.class.generate_key
    end

    def save( attempt = 0 )
      fail "Unable to save Redis::Hash after max attempts." if attempt > 5
      redis.watch redis_key
      latest_version = redis.hget(redis_key, "__version")
      reload! unless ( latest_version.nil? || latest_version == self.version )
      self.version = nil # generate new version token
      changed_keys = (self.changed + self.added).uniq
      changes = []
      changed_keys.each do |key|
        changes.push( key, Redis::Marshal.dump(self[key]) )
      end
      deleted_keys = self.deleted
      unless deleted_keys.empty? and changes.empty?
        success = redis.multi do
          redis.hmset( redis_key, *changes.push("__version", self.version) ) unless changes.empty?
          deleted_keys.each { |key| redis.hdel( redis_key, key) }
        end
        if success
          untrack!; track! #reset!
        else
          save( attempt + 1 )
        end
      else
        redis.unwatch
      end
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

    def reload!
      self.update( self.class.find( {namespace=>key} ) )
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

    def self.redis
      @@redis ||= Redis.new
    end

    def self.redis=(resource)
      @@redis = resource
    end

    def self.generate_key
      t = Time.now
      t.strftime('%Y%m%d%H%M%S.') + t.usec.to_s.rjust(6,'0') + '.' + SecureRandom.hex(16)
    end

    def self.find(params)
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
      when String
        unless self.instance_of?(NativeHash)
          result = fetch_values( "#{self.new.namespace}:#{params}" )
        else
          result = fetch_values(params)
        end
        result.empty? ? nil : build(nil,params,result)
      end
    end

    def self.build(namespace, key, values)
      h = self.new
      h.namespace = namespace
      h.key = key
      h.populate(values)
      h
    end

    def self.fetch_values(key)
      results = redis.hgetall(key)
      results.each_pair { |key,value| results[key] = Redis::Marshal.load(value) }
    end

    def self.attr_persist(*attributes)
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

    protected
      def redis; self.class.redis; end
      def redis_key
        namespace.nil? ? key : "#{namespace}:#{key}"
      end
      def convert_key(key)
        key.to_s
      end
  end
end

