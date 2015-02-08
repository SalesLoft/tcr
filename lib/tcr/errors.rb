module TCR
  class TCRError < StandardError; end
  class FormatError < TCRError; end
  class NoCassetteError < TCRError; end
  class NoMoreSessionsError < TCRError; end
  class DirectionMismatchError < TCRError; end
end
