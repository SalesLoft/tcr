module TCR
  class TCRError < StandardError; end
  class NoCassetteError < TCRError; end
  class DirectionMismatchError < TCRError; end
end
