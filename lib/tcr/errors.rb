module TCR
  class TCRError < StandardError; end
  class NoCassetteError < TCRError; end
  class NoMoreSessionsError < TCRError; end
  class ExtraSessionsError < TCRError; end
  class DirectionMismatchError < TCRError; end
end
