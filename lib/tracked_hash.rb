class TrackedHash < Hash

  def original
    @original ||= self.dup
  end
  alias_method :track,  :original
  alias_method :track!, :original

  def untrack
    @original = nil
  end
  alias_method :untrack!, :untrack

  def changed
    changes = keys.select do |key|
      self[key] != original[key]
    end
  end

  def deleted
    original.keys - self.keys
  end

  def added
    self.keys - original.keys
  end

  def update(other_hash)
    if other_hash.kind_of?(TrackedHash)
      other_original = other_hash.original
      other_hash.instance_variable_set('@original',original)
      other_changed = other_hash.changed
      other_hash.deleted.each { |key| delete(key) }
      other_hash.instance_variable_set('@original',other_original)
      updates = Hash[ other_changed.map { |k| [k, other_hash[k]] } ]
      super( updates )
    else
      super
    end
  end
  alias_method :merge!, :update

end

