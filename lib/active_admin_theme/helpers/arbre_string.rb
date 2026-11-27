module ActiveAdminTheme
  module Helpers
    module ArbreString
      # aat_arbre { status_tag("Late", color: "#b91c1c") }
      #
      # Builds the block with Arbre, outside an Arbre context, and returns an
      # html_safe String without Arbre's trailing newline. For decorators and
      # helpers; the block runs in the Arbre context, with this object's
      # methods reachable as helpers.
      def aat_arbre(&block)
        ::Arbre::Context.new({}, self, &block).to_s.rstrip.html_safe
      end
    end
  end
end

ActiveSupport.on_load(:action_view) { include ActiveAdminTheme::Helpers::ArbreString }
