class Redis
  class LazyHash
    def initialize(args = nil)
      @hash = NativeHash.new(args)
      @loaded = false
    end

    def [](key)
      lazy_load!
      @hash[key]
    end

    def []=(key, value)
      lazy_load!
      @hash[key] = value
    end

    def delete(key)
      lazy_load!
      @hash.delete(key)
    end

    def key
      @hash.key
    end

    def namespace
      @hash.namespace
    end

    def namespace=(newspace)
      @hash.namespace = newspace
    end

    def update(data)
      lazy_load!
      @hash.update(data)
    end

    def save
      @hash.save if loaded?
    end

    def destroy
      @hash.destroy
    end

    def reload
      @hash.reload!
    end
    alias_method :reload!, :reload

    def renew_key(new_key = nil)
      lazy_load!
      @hash.renew_key(new_key)
    end
    alias_method :key=, :renew_key

    def expire(expiration)
      @hash.expire(expiration)
    end

    def loaded?
      @loaded
    end

    def inspect
      lazy_load!
      @hash.inspect
    end

    def size
      lazy_load!
      @hash.size
    end

    def replace(other_hash)
      lazy_load!
      @hash.replace(other_hash)
    end

    def to_hash
      lazy_load!
      @hash
    end

    private

      def lazy_load!
        unless loaded?
          reload!
          @hash.retrack!
          @loaded = true
        end
      end
    
    class << self
      def find(args)
        case args
        when Hash
          self.new(args)
        when String,Symbol
          self.new(nil=>args)
        end
      end
    end
  end
end