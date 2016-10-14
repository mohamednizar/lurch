module Lurch
  class Relationship
    include Enumerable

    def initialize(relationship_key, store, document)
      @relationship_key = relationship_key
      @document = document
      @store = store
      create_resources(document["data"]) unless document["data"].nil?
    end

    def loaded?
      (one? && @resource.loaded?) || (many? && @resources.all?(&:loaded?))
    end

    def identifier?
      one? || many?
    end

    def link?
      !!(@document["links"] && @document["links"]["related"])
    end

    def one?
      !@resource.nil?
    end

    def many?
      !@resources.nil?
    end

    def each(&block)
      if one?
        [*@resource].each(&block)
      elsif many?
        @resources.each(&block)
      else
        raise Errors::RelationshipNotLoaded, @relationship_key
      end
    end

    def fetch
      if link?
        resources = @store.load_from_url(@document["links"]["related"])
        set_resources(resources.is_a?(Array), [*resources])
      elsif one?
        @resource.fetch
      elsif many?
        @resources.map(&:fetch)
      end

      self
    end

    def inspect
      if one?
        @resource.inspect
      elsif many?
        @resources.inspect
      elsif link?
        "#<#{self.class} link: #{@document['links']['related'].inspect} not loaded>"
      else
        "#<#{self.class} not loaded>"
      end
    end

  private

    def create_resources(data)
      relationship_data = Lurch.to_a(data)

      resources = relationship_data.map do |resource_object|
        Resource.new(@store, resource_object["type"], resource_object["id"])
      end

      set_resources(data.is_a?(Array), resources)
    end

    def set_resources(many, resources)
      if many
        @resources = resources
      else
        @resource = resources.first
      end
    end

    def respond_to_missing?(method, all)
      return super unless one?
      @resource.respond_to?(method, all) || super
    end

    def method_missing(method, *arguments, &block)
      return super unless one?
      return @resource.send(method, *arguments, &block) if @resource.respond_to?(method)
      raise Errors::ResourceNotLoaded, @resource.resource_class_name if one? && !@resource.loaded?
      super
    end
  end
end
