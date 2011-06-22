require 'securerandom'

class RedisHash < TrackedHash

  attr_accessor :namespace

  def initialize(*args)
    super(nil)
    keys = args.shift
    case keys
    when Hash
      self.namespace, self.key = keys.first
    else
      self.namespace = keys.to_s
      track! # new hash. start tracking BEFORE merging any data.
    end
    data = args.shift
    case data
    when Hash
      update data
    end
    track! # this might be the second call, but near-zero cost to call again.
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

  attr_writer :key
  def key
    @key ||= self.class.generate_key
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
    changed_keys = self.changed
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
    super(data)
  end

  def reload!
    self.update( self.class.find( {namespace=>key} ) )
  end
  alias_method :reload, :reload!

  def destroy
    redis.del( redis_key )
    untrack!
    clear
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
          hashes << self.new( {namespace=>key}, result)
        end
      end
      unless hashes.empty?
        hashes.size == 1 ? hashes.first : hashes
      else
        nil
      end
    when String
      result = fetch_values(params)
      result.empty? ? nil : self.new(params, result)
    end
  end

  def self.fetch_values(key)
    results = redis.hgetall(key)
    results.each_pair { |key,value| results[key] = Redis::Marshal.load(value) }
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
