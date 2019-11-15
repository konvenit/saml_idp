require 'net/http'
require 'uri'
require 'saml_idp/attributeable'
require 'saml_idp/incoming_metadata'
require 'saml_idp/persisted_metadata'
module SamlIdp
  class ServiceProvider
    include Attributeable
    attribute :identifier
    attribute :cert
    attribute :fingerprint
    attribute :metadata_url
    attribute :validate_signature
    attribute :acs_url
    attribute :assertion_consumer_logout_service_url
    attribute :response_hosts

    delegate :config, to: :SamlIdp

    def valid?
      attributes.present?
    end

    def valid_signature?(doc, require_signature = false)
      if require_signature || should_validate_signature?
        doc.valid_signature?(fingerprint)
      else
        true
      end
    end

    def should_validate_signature?
      attributes[:validate_signature] ||
        persisted_metadata.respond_to?(:sign_assertions?) && persisted_metadata.sign_assertions?
    end

    def refresh_metadata
      fresh = fresh_incoming_metadata
      if valid_signature?(fresh.document)
        metadata_persister[identifier, fresh]
        @current_metadata = PersistedMetadata.new(fresh.to_h)
      end
    end

    def current_metadata
      @current_metadata ||= persisted_metadata || refresh_metadata
    end

    def acceptable_response_hosts
      hosts = Array(self.response_hosts)
      hosts.push(metadata_url_host) if metadata_url_host

      hosts
    end

    def metadata_url_host
      if metadata_url.present?
        URI(metadata_url).host
      end
    end

    private

    def persisted_metadata
      persisted = metadata_getter[identifier, self]
      if persisted.is_a? Hash
        PersistedMetadata.new(persisted)
      end
    end

    def metadata_getter
      config.service_provider.persisted_metadata_getter
    end

    def metadata_persister
      config.service_provider.metadata_persister
    end

    def fresh_incoming_metadata
      IncomingMetadata.new request_metadata
    end

    def request_metadata
      metadata_url.present? ? Net::HTTP.get(URI.parse(metadata_url)) : ""
    end
  end
end
