module Breadcrumbs
  class Crumb
    # Raw data structure for breadcrumbs.
    #
    attr_reader :category, :message, :metadata, :timestamp

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
  end
end
