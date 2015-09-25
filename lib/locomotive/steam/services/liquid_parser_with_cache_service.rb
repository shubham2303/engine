module Locomotive
  module Steam

    class LiquidParserWithCacheService < LiquidParserService

      UNMARSHALABLE_OPTIONS = %i(parser page parent_finder snippet_finder).freeze

      attr_accessor_initialize :current_site, :parent_finder, :snippet_finder, :locale

      def parse(page)
        return super unless current_site.cache_enabled

        read_template_from_cache(page) || write_template_in_cache(page, super)
      end

      def cache_key(page)
        "site/#{current_site._id}/template/#{current_site.template_version.to_i}/page/#{page._id}/#{locale}"
      end

      private

      def read_template_from_cache(page)
        if marshaled = Rails.cache.read(cache_key(page))
          Marshal.load(marshaled)
        end
      end

      def write_template_in_cache(page, template)
        begin
          Rails.cache.write(cache_key(page), marshal(template))
        rescue Exception => e
          Rails.logger.warn "Could not marshal #{cache_key(page)}, error: #{e.message}"
        end

        template
      end

      def marshal(template)
        _template = template.dup

        # get rid of options in any tags/blocks of the document
        # because options can not be marshaled
        remove_unmarshalable_options(_template)

        clean_template!(_template.root)

        Marshal.dump(_template)
      end

      def clean_template!(node)
        remove_unmarshalable_options(node)

        # special case
        clean_template!(node.descendant) if node.respond_to?(:descendant) && node.descendant

        if node.respond_to?(:nodelist) && node.nodelist
          node.nodelist.each do |_node|
            clean_template!(_node)
          end
        end
      end

      def remove_unmarshalable_options(node)
        options = node.instance_variable_get(:@options)

        return if options.blank?

        options.delete_if { |name, _| UNMARSHALABLE_OPTIONS.include?(name) }
      end

    end

  end
end
