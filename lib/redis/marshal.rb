class Redis
  class Marshal
    def self.dump(value)
      case value
      when String
        value
      else
        ::Marshal.dump(value)
      end
    end

    def self.load(value)
      return value unless value.start_with?("\004")
      ::Marshal.load(value) rescue value
    end
  end
end

