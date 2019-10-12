class String
  def sha256sum
    Digest::SHA256.hexdigest self
  end
end
