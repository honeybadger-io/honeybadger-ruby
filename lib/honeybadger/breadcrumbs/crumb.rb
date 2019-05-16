module Breadcrumbs
  class Crumb
    # Raw data structure for breadcrumbs.
    #
    attr_reader :category, :message, :metadata, :timestamp
    include Comparable

    def initialize(category: :custom, message: nil, metadata: {})
      @category = category
      @message = message
      @metadata = metadata
      @timestamp = DateTime.now
    end

    def to_hash
      {
        "category" => category,
        "message" => message,
        "metadata" => metadata,
        "timestamp" => timestamp
      }
    end

    def <=>(other)
      to_hash <=> other.to_hash
    end
  end
end
