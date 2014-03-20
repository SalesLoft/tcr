module TCR
  class TCRError < StandardError; end
  class NoMoreSessionsError < TCRError; end
  class DirectionMismatchError < TCRError; end
end
