module TCR
  class TCRError < StandardError; end
  class NoMoreSessionsError < TCRError; end
  class CommandMismatchError < TCRError; end
  class DataMismatchError < TCRError; end
end
